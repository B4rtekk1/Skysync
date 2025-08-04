// Plik konfiguracyjny dla zmiennych środowiskowych
class EnvConfig {
  static String get apiKey => _apiKey;
  static String get baseUrl => _baseUrl;
  
  // Prywatne zmienne do przechowywania wartości
  static String _apiKey = '987654321POL';
  static String _baseUrl = 'https://topical-sheep-apparently.ngrok-free.app';
  
  // Metoda do ustawiania wartości
  static void setConfig({String? apiKey, String? baseUrl}) {
    if (apiKey != null) _apiKey = apiKey;
    if (baseUrl != null) _baseUrl = baseUrl;
  }
}

 