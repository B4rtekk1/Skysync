import 'env_config.dart';

class MacOSEnvConfig {
  static void initialize() {
    // Konfiguracja dla macOS
    // Można dodać odczyt z plików konfiguracyjnych macOS
    EnvConfig.setConfig(
      apiKey: '', // Tutaj możesz dodać klucz API
      baseUrl: 'https://topical-sheep-apparently.ngrok-free.app', // URL twojego serwera
    );
  }
} 