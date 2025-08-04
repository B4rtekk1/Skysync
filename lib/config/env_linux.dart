import 'env_config.dart';

class LinuxEnvConfig {
  static void initialize() {
    // Konfiguracja dla Linux
    // Można dodać odczyt z zmiennych środowiskowych systemu
    EnvConfig.setConfig(
      apiKey: '', // Tutaj możesz dodać klucz API
      baseUrl: 'https://topical-sheep-apparently.ngrok-free.app', // URL twojego serwera
    );
  }
} 