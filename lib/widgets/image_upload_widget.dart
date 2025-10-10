import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/image_generation_provider.dart';

class ImageUploadWidget extends StatefulWidget {
  const ImageUploadWidget({super.key});

  @override
  State<ImageUploadWidget> createState() => _ImageUploadWidgetState();
}

class _ImageUploadWidgetState extends State<ImageUploadWidget> {
  bool _isProcessing = false;

  Future<void> _pickImage(BuildContext context) async {
    setState(() {
      _isProcessing = true;
    });
    
    try {
      if (kIsWeb) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        
        if (result != null && result.files.isNotEmpty && result.files.first.bytes != null) {
          if (context.mounted) {
            context.read<ImageEditingProvider>().setSelectedImageBytes(
              result.files.first.bytes!,
              result.files.first.name,
            );
          }
        }
      } else {
        final picker = ImagePicker();
        final image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 2048,
          maxHeight: 2048,
          imageQuality: 85,
        );
        
        if (image != null && context.mounted) {
          final file = File(image.path);
          context.read<ImageEditingProvider>().setSelectedImageFile(file);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error in _pickImage: $e');
      debugPrint('StackTrace: $stackTrace');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ImageEditingProvider>(
      builder: (context, provider, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Select Image', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                if (provider.hasSelectedImage)
                  Container(
                    height: 120,
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: double.infinity,
                            height: double.infinity,
                            child: provider.selectedImageFile != null
                                ? Image.file(provider.selectedImageFile!, fit: BoxFit.cover)
                                : Image.memory(provider.selectedImageBytes!, fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          top: 8, right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: provider.clearSelectedImage,
                            style: IconButton.styleFrom(backgroundColor: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  InkWell(
                    onTap: () {
                      _pickImage(context);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400, width: 2, style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.shade50,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Icon(Icons.cloud_upload_outlined, size: 24, color: Colors.grey.shade400),
                            Flexible(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Upload Image to Edit',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Tap to select from gallery',
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 28,
                              child: ElevatedButton.icon(
                                onPressed: _isProcessing ? null : () {
                                  _pickImage(context);
                                },
                                icon: _isProcessing 
                                    ? const SizedBox(
                                        width: 12, 
                                        height: 12, 
                                        child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white)
                                      )
                                    : const Icon(Icons.image, size: 14),
                                label: Text(
                                  _isProcessing ? 'Processing...' : 'Choose Image',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                  minimumSize: const Size(0, 28),
                                  maximumSize: const Size(double.infinity, 28),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}