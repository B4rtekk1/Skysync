import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  static String get baseUrl {
    return dotenv.env['BASE_URL'] ?? 'http://localhost:8080/api';
  }

  static String get apiKey {
    return dotenv.env['API_KEY'] ?? '';
  }
}
