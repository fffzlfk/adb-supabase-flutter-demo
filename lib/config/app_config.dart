/// Application configuration constants
class AppConfig {
  // App Information
  static const String appName = 'AI Image Generator';
  static const String appVersion = '1.0.0';
  
  // Image Generation Settings
  static const int maxPromptLength = 500;
  static const int defaultImageSize = 512;
  static const double defaultGuidanceScale = 7.5;
  static const int defaultInferenceSteps = 50;
  static const int maxHistoryItems = 100;
  
  // Supported Models
  static const List<String> supportedModels = [
    'stable-diffusion',
    'stable-diffusion-xl',
    'dalle-2',
    'dalle-3',
    'midjourney',
  ];
  
  // Image Sizes
  static const Map<String, Map<String, int>> imageSizes = {
    'Square': {'width': 512, 'height': 512},
    'Portrait': {'width': 512, 'height': 768},
    'Landscape': {'width': 768, 'height': 512},
    'HD Portrait': {'width': 720, 'height': 1280},
    'HD Landscape': {'width': 1280, 'height': 720},
  };
  
  // UI Configuration
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 8.0;
  static const int maxRecentImages = 5;
  static const int historyGridColumns = 2;
  
  // Error Messages
  static const String networkErrorMessage = 'Please check your internet connection and try again.';
  static const String supabaseErrorMessage = 'Unable to connect to the service. Please try again later.';
  static const String generationErrorMessage = 'Failed to generate image. Please try with a different prompt.';
}