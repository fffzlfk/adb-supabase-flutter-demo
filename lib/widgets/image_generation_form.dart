import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/image_generation_provider.dart';
import '../screens/edit_result_screen.dart';

class ImageEditingForm extends StatefulWidget {
  const ImageEditingForm({super.key});

  @override
  State<ImageEditingForm> createState() => _ImageEditingFormState();
}

class _ImageEditingFormState extends State<ImageEditingForm> {
  final _promptController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _editImage() async {
    // Unfocus text field to prevent keyboard event issues
    _focusNode.unfocus();
    
    if (_formKey.currentState!.validate()) {
      final promptText = _promptController.text.trim();
      final provider = context.read<ImageEditingProvider>();
      
      // Start editing process
      final editedImage = await provider.editImage(promptText);
      
      // Navigate to results page if editing was successful and widget is still mounted
      if (editedImage != null && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => EditResultScreen(editedImage: editedImage),
          ),
        );
        
        // Clear the form after successful edit if still mounted
        if (mounted) {
          _promptController.clear();
          provider.clearSelectedImage();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ImageEditingProvider>(
      builder: (context, provider, child) {
        return GestureDetector(
          onTap: () {
            // Unfocus when tapping outside text field
            _focusNode.unfocus();
          },
          child: KeyboardListener(
            focusNode: FocusNode(),
            onKeyEvent: (KeyEvent event) {
              // Handle escape key to unfocus and prevent keyboard event conflicts
              if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
                _focusNode.unfocus();
              }
            },
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Edit Image', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),

                      // Prompt input
                      TextFormField(
                        controller: _promptController,
                        focusNode: _focusNode,
                        maxLines: 3,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          labelText: 'Describe your edit',
                          hintText: 'e.g., "Change the sky to sunset", "Add flowers to the garden"',
                          border: OutlineInputBorder(),
                          helperText: 'Enter your editing instructions in any language',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a prompt';
                          }
                          if (value.trim().length < 3) {
                            return 'Prompt must be at least 3 characters';
                          }
                          return null;
                        },
                        onFieldSubmitted: (value) {
                          // Unfocus to prevent keyboard event conflicts
                          _focusNode.unfocus();
                          if (_formKey.currentState!.validate() && context.read<ImageEditingProvider>().hasSelectedImage) {
                            _editImage();
                          }
                        },
                        onTap: () {
                          // Ensure proper focus handling
                          if (!_focusNode.hasFocus) {
                            _focusNode.requestFocus();
                          }
                        },
                      ),

                      const SizedBox(height: 20),

                      // Edit button
                      ElevatedButton.icon(
                        onPressed: (provider.isEditing || !provider.hasSelectedImage) ? null : _editImage,
                        icon: provider.isEditing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.edit),
                        label: Text(provider.isEditing ? 'Editing...' : 'Edit Image'),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}