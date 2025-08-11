import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static String get apiKey => _apiKey;
  static String get baseUrl => _baseUrl;

  static String _apiKey = dotenv.env['API_KEY'] ?? '';
  static String _baseUrl = dotenv.env['BASE_URL'] ?? '';
  
  static void setConfig({String? apiKey, String? baseUrl}) {
    if (apiKey != null) _apiKey = apiKey;
    if (baseUrl != null) _baseUrl = baseUrl;
  }
}

 