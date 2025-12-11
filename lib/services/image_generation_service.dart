import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/generated_image.dart';

/// Image editing service using Supabase for storage and Edge Functions
/// 
/// This service uses the anon key for accessing public storage buckets
/// and calling edge functions. The storage bucket should be configured as public.
class ImageEditingService {
  static const _uuid = Uuid();

  /// Test network connectivity to Supabase
  static Future<bool> testConnection() async {
    try {
      // Test basic connectivity by making a simple request
      await SupabaseConfig.client.storage.listBuckets();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Extract image URL from edge function response
  /// Expected format: {"message": [{"image": "url"}]}
  static String? _extractImageUrl(dynamic responseData) {
    if (responseData == null || responseData is! Map<String, dynamic>) {
      return null;
    }
    
    final message = responseData['message'];
    if (message is List && message.isNotEmpty) {
      final firstItem = message[0];
      if (firstItem is Map && firstItem['image'] != null) {
        return firstItem['image'] as String?;
      }
    }
    
    return null;
  }

  /// Uploads an image file and calls the Supabase Edge Function to edit it
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
        'image-edit',
        body: {
          'image_url': originalImageUrl,
          'prompt': prompt,
        },
      );

      final editedImageUrl = _extractImageUrl(response.data);
      
      if (editedImageUrl == null || editedImageUrl.isEmpty) {
        throw Exception('Failed to edit image: No edited image URL returned. Response: ${response.data}');
      }

      final editedImage = EditedImage(
        id: _uuid.v4(),
        prompt: prompt,
        originalImageUrl: originalImageUrl,
        editedImageUrl: editedImageUrl,
        createdAt: DateTime.now(),
      );

      await _saveToHistory(editedImage);
      return editedImage;
    } catch (e) {
      debugPrint('Image editing error: $e');
      
      // Provide more specific error messages
      if (e.toString().contains('NoSuchMethodError')) {
        throw Exception('Edge Function response format error. Please check the function output structure.');
      } else if (e.toString().contains('Connection failed')) {
        throw Exception('Failed to connect to Edge Function. Please check your internet connection.');
      } else if (e.toString().contains('404')) {
        throw Exception('Edge Function "image-edit" not found. Please check the function name and deployment.');
      } else if (e.toString().contains('500')) {
        throw Exception('Edge Function internal error. Please check the function logs.');
      }
      
      rethrow;
    }
  }

  /// Upload image to Supabase Storage
  static Future<String?> _uploadImageToStorage(File imageFile) async {
    try {
      // Check if user is authenticated
      final currentUser = SupabaseConfig.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('Please sign in to upload images');
      }

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

      // Use user ID in file path for better organization and RLS compliance
      final userId = currentUser.id;
      final fileName = '$userId/${_uuid.v4()}.${_getFileExtension(imageFile.path)}';
      final bytes = await imageFile.readAsBytes();
      final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';
      
      // Upload with retry logic
      const maxRetries = 3;
      Exception? lastException;
      
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          
          await SupabaseConfig.client.storage
              .from('images')
              .uploadBinary(
                fileName,
                bytes,
                fileOptions: FileOptions(
                  contentType: mimeType,
                ),
              );

          // Get public URL
          final publicUrl = SupabaseConfig.client.storage
              .from('images')
              .getPublicUrl(fileName);

          return publicUrl;
          
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
      if (e.toString().contains('Please sign in')) {
        rethrow; // Re-throw authentication errors as-is
      } else if (e.toString().contains('row-level security') || e.toString().contains('RLS')) {
        throw Exception('Storage access denied. Please ensure you are signed in and the storage bucket has proper RLS policies configured.');
      } else if (e.toString().contains('Connection failed')) {
        throw Exception('Network connection failed. Please check your internet connection and try again.');
      } else if (e.toString().contains('Operation not permitted')) {
        throw Exception('Network access denied. Please check app permissions.');
      } else if (e.toString().contains('bucket does not exist')) {
        throw Exception('Storage bucket not configured. Please contact support.');
      } else if (e.toString().contains('unauthorized') || e.toString().contains('403')) {
        throw Exception('Storage access denied. Please ensure you are signed in and have permission to upload files.');
      } else if (e.toString().contains('bucket is private')) {
        throw Exception('Storage bucket is private. Please configure the bucket as public or use Row Level Security policies.');
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
      // Check if user is authenticated
      final currentUser = SupabaseConfig.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('Please sign in to upload images');
      }

      // Use user ID in file path for better organization and RLS compliance
      final userId = currentUser.id;
      final uploadFileName = '$userId/${_uuid.v4()}.${_getFileExtension(fileName)}';
      
      await SupabaseConfig.client.storage
          .from('images')
          .uploadBinary(
            uploadFileName,
            imageBytes,
            fileOptions: FileOptions(
              contentType: lookupMimeType(fileName),
            ),
          );

      // Get public URL
      final originalImageUrl = SupabaseConfig.client.storage
          .from('images')
          .getPublicUrl(uploadFileName);

      debugPrint('Original image URL: $originalImageUrl');

      // Call the Edge Function for image editing
      final editResponse = await SupabaseConfig.client.functions.invoke(
        'image-edit',
        body: {
          'image_url': originalImageUrl,
          'prompt': prompt,
        },
      );

      debugPrint('Edit response: ${editResponse.data}');

      final editedImageUrl = _extractImageUrl(editResponse.data);
      
      if (editedImageUrl == null || editedImageUrl.isEmpty) {
        throw Exception('Failed to edit image: No edited image URL returned');
      }

      final editedImage = EditedImage(
        id: _uuid.v4(),
        prompt: prompt,
        originalImageUrl: originalImageUrl,
        editedImageUrl: editedImageUrl,
        createdAt: DateTime.now(),
      );

      await _saveToHistory(editedImage);
      return editedImage;
    } catch (e) {
      debugPrint('Image editing error: $e');
      rethrow;
    }
  }

  /// Save edited image to history
  static Future<void> _saveToHistory(EditedImage image) async {
    try {
      final currentUser = SupabaseConfig.client.auth.currentUser;
      if (currentUser == null) {
        debugPrint('Cannot save to history: user not authenticated');
        return;
      }

      final imageData = image.toJson();
      imageData['user_id'] = currentUser.id;
      
      await SupabaseConfig.client
          .from('edited_images')
          .insert(imageData);
    } catch (e) {
      debugPrint('Failed to save to history: $e');
    }
  }

  /// Get editing history from Supabase
  static Future<List<EditedImage>> getHistory({int limit = 20}) async {
    try {
      final currentUser = SupabaseConfig.client.auth.currentUser;
      if (currentUser == null) {
        debugPrint('Cannot load history: user not authenticated');
        return [];
      }

      final response = await SupabaseConfig.client
          .from('edited_images')
          .select()
          .eq('user_id', currentUser.id)
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
      final currentUser = SupabaseConfig.client.auth.currentUser;
      if (currentUser == null) {
        debugPrint('Cannot delete from history: user not authenticated');
        return false;
      }

      await SupabaseConfig.client
          .from('edited_images')
          .delete()
          .eq('id', imageId)
          .eq('user_id', currentUser.id);
      return true;
    } catch (e) {
      debugPrint('Failed to delete from history: $e');
      return false;
    }
  }
}
