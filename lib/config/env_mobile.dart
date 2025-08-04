import 'env_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MobileEnvConfig {
  static Future<void> initialize() async {
    // Dla platform mobilnych (Android/iOS) - używa pliku .env
    try {
      await dotenv.load(fileName: ".env");
      EnvConfig.setConfig(
        apiKey: dotenv.env['API_KEY'] ?? '',
        baseUrl: dotenv.env['BASE_URL'] ?? 'https://topical-sheep-apparently.ngrok-free.app',
      );
    } catch (e) {
      print('Warning: Could not load .env file on mobile, using defaults');
      EnvConfig.setConfig(
        apiKey: '',
        baseUrl: 'https://topical-sheep-apparently.ngrok-free.app',
      );
    }
  }
} 