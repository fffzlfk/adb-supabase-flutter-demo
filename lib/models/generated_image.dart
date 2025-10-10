class EditedImage {
  final String id;
  final String prompt;
  final String originalImageUrl;
  final String editedImageUrl;
  final DateTime createdAt;

  EditedImage({
    required this.id,
    required this.prompt,
    required this.originalImageUrl,
    required this.editedImageUrl,
    required this.createdAt,
  });

  factory EditedImage.fromJson(Map<String, dynamic> json) {
    return EditedImage(
      id: json['id'] as String,
      prompt: json['prompt'] as String,
      originalImageUrl: json['original_image_url'] as String,
      editedImageUrl: json['edited_image_url'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prompt': prompt,
      'original_image_url': originalImageUrl,
      'edited_image_url': editedImageUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }
}