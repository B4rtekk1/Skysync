import 'dart:html' as html;
import 'env_config.dart';

class WebEnvConfig {
  static void initialize() {
    // Próbuj pobrać z localStorage, sessionStorage lub użyj domyślnych wartości
    String apiKey = '987654321POL';
    String baseUrl = 'https://topical-sheep-apparently.ngrok-free.app';
    
    try {
      apiKey = html.window.localStorage['API_KEY'] ?? 
               html.window.sessionStorage['API_KEY'] ?? 
               '';
      baseUrl = html.window.localStorage['BASE_URL'] ?? 
                html.window.sessionStorage['BASE_URL'] ?? 
                'https://topical-sheep-apparently.ngrok-free.app';
    } catch (e) {
      print('Warning: Could not access browser storage, using defaults');
    }
    
    // Ustaw konfigurację
    EnvConfig.setConfig(apiKey: apiKey, baseUrl: baseUrl);
  }
} 