import 'env_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class WindowsEnvConfig {
  static Future<void> initialize() async {
    // Konfiguracja dla Windows - używa pliku .env
    try {
      await dotenv.load(fileName: ".env");
      EnvConfig.setConfig(
        apiKey: dotenv.env['API_KEY'] ?? '',
        baseUrl: dotenv.env['BASE_URL'] ?? 'https://topical-sheep-apparently.ngrok-free.app',
      );
    } catch (e) {
      print('Warning: Could not load .env file on Windows, using defaults');
      EnvConfig.setConfig(
        apiKey: '',
        baseUrl: 'https://topical-sheep-apparently.ngrok-free.app',
      );
    }
  }
} 