import 'env_config.dart';

class WebEnvConfig {
  static void initialize() {
    // Stub dla platform desktopowych - używa domyślnych wartości
    EnvConfig.setConfig(
      apiKey: '987654321POL',
      baseUrl: 'https://topical-sheep-apparently.ngrok-free.app',
    );
  }
} 