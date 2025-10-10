import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/generated_image.dart';

/// Image editing service using Supabase for storage and Edge Functions
/// 
/// This service uses the service role key for direct access to private
/// storage buckets without requiring user authentication. This approach
/// is suitable for server-side operations or when anonymous auth is disabled.
class ImageEditingService {
  static const _uuid = Uuid();

  /// Test network connectivity to Supabase
  static Future<bool> testConnection() async {
    try {
      // Test basic connectivity by making a simple request
      // Service role key should have access without authentication
      await SupabaseConfig.client.storage.listBuckets();
      return true;
    } catch (e) {
      // If anonymous auth is disabled, that's expected with service role
      if (e.toString().contains('anonymous_provider_disabled')) {
        return true; // Continue anyway, service role should work
      }
      
      return false;
    }
  }

  /// Uploads an image file and calls the Supabase Edge Function to edit it
  /// Replace 'image-edit' with your actual Edge Function name
  static Future<EditedImage?> editImage({
    required File imageFile,
    required String prompt,
  }) async {
    try {
      // First upload the image to Supabase Storage
      final originalImageUrl = await _uploadImageToStorage(imageFile);
      
      if (originalImageUrl == null) {
        throw Exception('Failed to upload image');
      }

      // Call the Edge Function for image editing
      final response = await SupabaseConfig.client.functions.invoke(
        'wan', // Replace with your Edge Function name
        body: {
          'image_url': originalImageUrl,
          'prompt': prompt,
        },
      );

      if (response.data != null) {
        // Try different possible response structures
        String? editedImageUrl;
        
        // Check different possible response formats
        if (response.data is Map<String, dynamic>) {
          final data = response.data as Map<String, dynamic>;
          
          // Try: response.data['message'][0]['image'] (message as array)
          if (data['message'] != null && data['message'] is List && (data['message'] as List).isNotEmpty) {
            final messageList = data['message'] as List;
            if (messageList[0] is Map && messageList[0]['image'] != null) {
              editedImageUrl = messageList[0]['image'] as String?;
            }
          }
          
          // Try: response.data['message']['image'] (message as object)
          if (editedImageUrl == null && data['message'] != null && data['message'] is Map) {
            editedImageUrl = data['message']['image'] as String?;
          }
          
          // Try: response.data['image'] 
          if (editedImageUrl == null && data['image'] != null) {
            editedImageUrl = data['image'] as String?;
          }
          
          // Try: response.data['edited_image_url']
          if (editedImageUrl == null && data['edited_image_url'] != null) {
            editedImageUrl = data['edited_image_url'] as String?;
          }
          
          // Try: response.data['result']
          if (editedImageUrl == null && data['result'] != null) {
            if (data['result'] is String) {
              editedImageUrl = data['result'] as String?;
            } else if (data['result'] is Map && data['result']['image'] != null) {
              editedImageUrl = data['result']['image'] as String?;
            }
          }
        }
        
        if (editedImageUrl != null && editedImageUrl.isNotEmpty) {
          final editedImage = EditedImage(
            id: _uuid.v4(),
            prompt: prompt,
            originalImageUrl: originalImageUrl,
            editedImageUrl: editedImageUrl,
            createdAt: DateTime.now(),
          );

          // Save to history
          await _saveToHistory(editedImage);
          
          return editedImage;
        }
      }
      
      throw Exception('Failed to edit image: No edited image URL returned. Response: ${response.data}');
    } catch (e) {
      debugPrint('Image editing error: $e');
      
      // Provide more specific error messages
      if (e.toString().contains('NoSuchMethodError')) {
        throw Exception('Edge Function response format error. Please check the function output structure.');
      } else if (e.toString().contains('Connection failed')) {
        throw Exception('Failed to connect to Edge Function. Please check your internet connection.');
      } else if (e.toString().contains('404')) {
        throw Exception('Edge Function "wan" not found. Please check the function name and deployment.');
      } else if (e.toString().contains('500')) {
        throw Exception('Edge Function internal error. Please check the function logs.');
      }
      
      rethrow;
    }
  }

  /// Upload image to Supabase Storage
  static Future<String?> _uploadImageToStorage(File imageFile) async {
    try {
      // Service role key should have direct access to private buckets
      // No authentication needed when using service role
      
      // Validate file exists and is readable
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }

      final fileSize = await imageFile.length();
      
      if (fileSize == 0) {
        throw Exception('Image file is empty');
      }

      // Check file size limit (10MB)
      if (fileSize > 10 * 1024 * 1024) {
        throw Exception('Image file too large (max 10MB)');
      }

      final fileName = '${_uuid.v4()}.${_getFileExtension(imageFile.path)}';
      final bytes = await imageFile.readAsBytes();
      final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';
      
      // Upload with retry logic
      const maxRetries = 3;
      Exception? lastException;
      
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          
          await SupabaseConfig.client.storage
              .from('images') // Make sure this bucket exists in your Supabase project
              .uploadBinary(
                fileName,
                bytes,
                fileOptions: FileOptions(
                  contentType: mimeType,
                ),
              );

          // Get signed URL for private bucket (valid for 1 hour)
          final signedUrl = await SupabaseConfig.client.storage
              .from('images')
              .createSignedUrl(fileName, 3600); // 1 hour expiry

          return signedUrl;
          
        } catch (e) {
          lastException = e is Exception ? e : Exception(e.toString());
          
          if (attempt < maxRetries) {
            // Wait before retry with exponential backoff
            await Future.delayed(Duration(seconds: attempt * 2));
          }
        }
      }
      
      throw lastException ?? Exception('Upload failed after $maxRetries attempts');
      
    } catch (e) {
      debugPrint('Failed to upload image: $e');
      
      // Provide more specific error messages
      if (e.toString().contains('Connection failed')) {
        throw Exception('Network connection failed. Please check your internet connection and try again.');
      } else if (e.toString().contains('Operation not permitted')) {
        throw Exception('Network access denied. Please check app permissions.');
      } else if (e.toString().contains('bucket does not exist')) {
        throw Exception('Storage bucket not configured. Please contact support.');
      } else if (e.toString().contains('unauthorized') || e.toString().contains('403')) {
        throw Exception('Storage access denied. Please check your Supabase service role key configuration.');
      } else if (e.toString().contains('bucket is private')) {
        throw Exception('Storage bucket is private. Using service role key for access.');
      } else if (e.toString().contains('anonymous_provider_disabled')) {
        throw Exception('Anonymous authentication is disabled. This is expected when using service role key.');
      }
      
      rethrow;
    }
  }

  /// Get file extension from path
  static String _getFileExtension(String path) {
    return path.split('.').last.toLowerCase();
  }

  /// Edit image from bytes (for web or when you have image data)
  static Future<EditedImage?> editImageFromBytes({
    required Uint8List imageBytes,
    required String fileName,
    required String prompt,
  }) async {
    try {
      // Service role key should have direct access to private buckets
      // No authentication needed when using service role
      
      // Upload bytes to storage
      final uploadFileName = '${_uuid.v4()}.${_getFileExtension(fileName)}';
      
      await SupabaseConfig.client.storage
          .from('images')
          .uploadBinary(
            uploadFileName,
            imageBytes,
            fileOptions: FileOptions(
              contentType: lookupMimeType(fileName),
            ),
          );

      // Get signed URL for private bucket (valid for 1 hour)
      final originalImageUrl = await SupabaseConfig.client.storage
          .from('images')
          .createSignedUrl(uploadFileName, 3600);

      // Call the Edge Function for image editing
      final editResponse = await SupabaseConfig.client.functions.invoke(
        'image-edit',
        body: {
          'image_url': originalImageUrl,
          'prompt': prompt,
        },
      );

      debugPrint('Edit response: ${editResponse.data}');

      if (editResponse.data != null) {
        // Try different possible response formats
        String? editedImageUrl;
        
        if (editResponse.data is Map<String, dynamic>) {
          final data = editResponse.data as Map<String, dynamic>;
          
          // Try: response.data['message'][0]['image'] (message as array)
          if (data['message'] != null && data['message'] is List && (data['message'] as List).isNotEmpty) {
            final messageList = data['message'] as List;
            if (messageList[0] is Map && messageList[0]['image'] != null) {
              editedImageUrl = messageList[0]['image'] as String?;
            }
          }
          
          // Try common response formats as fallbacks
          editedImageUrl = editedImageUrl ??
                          (data['edited_image_url'] as String?) ??
                          (data['image'] as String?) ??
                          (data['message']?['image'] as String?) ??
                          (data['result']?['image'] as String?);
        }
        
        if (editedImageUrl != null && editedImageUrl.isNotEmpty) {
          final editedImage = EditedImage(
            id: _uuid.v4(),
            prompt: prompt,
            originalImageUrl: originalImageUrl,
            editedImageUrl: editedImageUrl,
            createdAt: DateTime.now(),
          );

          await _saveToHistory(editedImage);
          return editedImage;
        }
      }
      
      throw Exception('Failed to edit image: No edited image URL returned');
    } catch (e) {
      debugPrint('Image editing error: $e');
      rethrow;
    }
  }

  /// Save edited image to history
  static Future<void> _saveToHistory(EditedImage image) async {
    try {
      await SupabaseConfig.client
          .from('edited_images')
          .insert(image.toJson());
    } catch (e) {
      debugPrint('Failed to save to history: $e');
    }
  }

  /// Get editing history from Supabase
  static Future<List<EditedImage>> getHistory({int limit = 20}) async {
    try {
      final response = await SupabaseConfig.client
          .from('edited_images')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((item) => EditedImage.fromJson(item))
          .toList();
    } catch (e) {
      debugPrint('Failed to load history: $e');
      return [];
    }
  }

  /// Delete an image from history
  static Future<bool> deleteFromHistory(String imageId) async {
    try {
      await SupabaseConfig.client
          .from('edited_images')
          .delete()
          .eq('id', imageId);
      return true;
    } catch (e) {
      debugPrint('Failed to delete from history: $e');
      return false;
    }
  }
}