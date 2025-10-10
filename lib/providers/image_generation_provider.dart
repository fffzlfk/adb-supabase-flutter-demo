import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/generated_image.dart';
import '../services/image_generation_service.dart';

class ImageEditingProvider extends ChangeNotifier {
  bool _isEditing = false;
  String? _error;
  EditedImage? _currentImage;
  List<EditedImage> _history = [];
  bool _isLoadingHistory = false;
  File? _selectedImageFile;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  bool get isEditing => _isEditing;
  String? get error => _error;
  EditedImage? get currentImage => _currentImage;
  List<EditedImage> get history => _history;
  bool get isLoadingHistory => _isLoadingHistory;
  File? get selectedImageFile => _selectedImageFile;
  Uint8List? get selectedImageBytes => _selectedImageBytes;
  String? get selectedImageName => _selectedImageName;
  bool get hasSelectedImage => _selectedImageFile != null || _selectedImageBytes != null;

  /// Set selected image file (for mobile platforms)
  void setSelectedImageFile(File imageFile) {
    _selectedImageFile = imageFile;
    _selectedImageBytes = null;
    _selectedImageName = null;
    _error = null;
    notifyListeners();
  }

  /// Set selected image bytes (for web platforms)
  void setSelectedImageBytes(Uint8List imageBytes, String fileName) {
    _selectedImageBytes = imageBytes;
    _selectedImageName = fileName;
    _selectedImageFile = null;
    _error = null;
    notifyListeners();
  }

  /// Clear selected image
  void clearSelectedImage() {
    _selectedImageFile = null;
    _selectedImageBytes = null;
    _selectedImageName = null;
    _error = null;
    notifyListeners();
  }

  /// Edit the selected image with text prompt
  /// Returns the edited image if successful, null otherwise
  Future<EditedImage?> editImage(String prompt) async {
    if (prompt.trim().isEmpty) {
      _error = 'Please enter a prompt';
      notifyListeners();
      return null;
    }

    if (!hasSelectedImage) {
      _error = 'Please select an image first';
      notifyListeners();
      return null;
    }

    _isEditing = true;
    _error = null;
    notifyListeners();

    try {
      // Test connection first
      final canConnect = await ImageEditingService.testConnection();
      if (!canConnect) {
        throw Exception('Cannot connect to Supabase. Please check your internet connection and try again.');
      }
      
      EditedImage? editedImage;
      
      if (_selectedImageFile != null) {
        // Edit from file
        editedImage = await ImageEditingService.editImage(
          imageFile: _selectedImageFile!,
          prompt: prompt,
        );
      } else if (_selectedImageBytes != null && _selectedImageName != null) {
        // Edit from bytes (web)
        editedImage = await ImageEditingService.editImageFromBytes(
          imageBytes: _selectedImageBytes!,
          fileName: _selectedImageName!,
          prompt: prompt,
        );
      }

      if (editedImage != null) {
        _currentImage = editedImage;
        _history.insert(0, editedImage); // Add to the beginning of history
        _error = null;
        return editedImage;
      } else {
        _error = 'Failed to edit image';
        return null;
      }
    } catch (e) {
      _error = 'Error editing image: ${e.toString()}';
      _currentImage = null;
      return null;
    } finally {
      _isEditing = false;
      notifyListeners();
    }
  }

  /// Load editing history
  Future<void> loadHistory() async {
    _isLoadingHistory = true;
    notifyListeners();

    try {
      _history = await ImageEditingService.getHistory();
      _error = null;
    } catch (e) {
      _error = 'Failed to load history: ${e.toString()}';
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  /// Delete an image from history
  Future<void> deleteImage(String imageId) async {
    try {
      final success = await ImageEditingService.deleteFromHistory(imageId);
      if (success) {
        _history.removeWhere((image) => image.id == imageId);
        if (_currentImage?.id == imageId) {
          _currentImage = null;
        }
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to delete image: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Set current image for viewing
  void setCurrentImage(EditedImage image) {
    _currentImage = image;
    notifyListeners();
  }
}