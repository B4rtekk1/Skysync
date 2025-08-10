# ServApp - Aplikacja do Zarządzania Plikami

## Przegląd

ServApp to nowoczesna aplikacja do zarządzania plikami zbudowana w Flutter, która zapewnia bezpieczne przechowywanie, udostępnianie i zarządzanie plikami. Aplikacja zawiera zaawansowany system obsługi błędów, obsługę wielu języków i intuicyjny interfejs użytkownika.

## Funkcje

### 🔐 **Uwierzytelnianie i Bezpieczeństwo**

- Rejestracja i logowanie użytkowników z weryfikacją e-mail
- Uwierzytelnianie oparte na tokenach JWT
- Funkcjonalność resetowania hasła
- Bezpieczna kontrola dostępu do plików

### 📁 **Zarządzanie Plikami**

- Przesyłanie i pobieranie plików
- Tworzenie i zarządzanie folderami
- Organizacja i nawigacja plików
- Operacje na wielu plikach (wybór, usuwanie, przenoszenie)
- Wyszukiwanie i filtrowanie plików

### ⭐ **System Ulubionych**

- Oznaczanie plików jako ulubione dla szybkiego dostępu
- Dedykowana strona ulubionych
- Łatwe zarządzanie ulubionymi plikami

### 🔗 **Udostępnianie Plików**

- Udostępnianie plików innym użytkownikom
- Udostępnianie całych folderów
- Funkcjonalność szybkiego udostępniania
- Przeglądanie udostępnionych plików i folderów

### 🌐 **Obsługa Wiele Języków**

- Lokalizacja polska i angielska
- Automatyczne wykrywanie języka
- Łatwe rozszerzanie o nowe języki

### 🛡️ **Zaawansowana Obsługa Błędów**

- Kompleksowy system zarządzania błędami
- Przyjazne dla użytkownika komunikaty błędów
- Funkcjonalność ponowienia dla błędów tymczasowych
- Różne metody wyświetlania błędów (dialogi, snackbary, bannery)

## Technologie

- **Frontend**: Flutter 3.7.2+
- **Zarządzanie Stanem**: Provider
- **Klient HTTP**: pakiet http
- **Lokalne Przechowywanie**: SharedPreferences
- **Obsługa Plików**: file_picker, path_provider
- **Lokalizacja**: easy_localization
- **Kody QR**: qr_flutter

## Rozpoczęcie Pracy

### Wymagania

- Flutter SDK 3.7.2 lub wyższy
- Dart SDK
- Android Studio / VS Code
- Serwer API backend (patrz dokumentacja backend)

### Instalacja

1. **Sklonuj repozytorium**

   ```bash
   git clone <url-repozytorium>
   cd fileserver
   ```

2. **Zainstaluj zależności**

   ```bash
   flutter pub get
   ```

3. **Skonfiguruj środowisko**

   - Utwórz plik `.env` w katalogu głównym
   - Dodaj konfigurację API:

   ```

   API_KEY=twój_klucz_api
   BASE_URL=http://url-backend:8000
   ```

4. **Uruchom aplikację**

   ```bash
   flutter run
   ```

## Struktura Projektu

```

lib/
├── main.dart                 # Punkt wejścia aplikacji
├── pages/                    # Strony aplikacji
│   ├── login_page.dart       # Ekran logowania
│   ├── register_page.dart    # Ekran rejestracji
│   ├── main_page.dart        # Główny dashboard
│   ├── files_page.dart       # Zarządzanie plikami
│   ├── favorites_page.dart   # Ulubione
│   ├── shared_files_page.dart # Udostępnione pliki
│   └── settings_page.dart    # Ustawienia
├── utils/                    # Klasy narzędziowe
│   ├── api_service.dart      # Komunikacja z API
│   ├── token_service.dart    # Zarządzanie tokenami
│   ├── custom_widgets.dart   # Widgety wielokrotnego użytku
│   ├── error_handler.dart    # System obsługi błędów
│   └── error_widgets.dart    # Widgety wyświetlania błędów
└── assets/
    └── lang/                 # Pliki lokalizacji
        ├── en.json          # Tłumaczenia angielskie
        └── pl.json          # Tłumaczenia polskie
```

## System Obsługi Błędów

Aplikacja zawiera kompleksowy system obsługi błędów, który zapewnia:

- **Centralne Zarządzanie Błędami**: Wszystkie błędy są obsługiwane przez jeden system
- **Klasyfikacja Błędów**: Błędy są kategoryzowane według typu (sieć, uwierzytelnianie, walidacja, itp.)
- **Przyjazne Komunikaty**: Jasne, zlokalizowane komunikaty błędów
- **Funkcjonalność Ponowienia**: Automatyczne ponowienie dla błędów tymczasowych
- **Różne Metody Wyświetlania**: Dialogi, snackbary, bannery i widgety

### Typy Błędów

- `network` - Problemy z połączeniem sieciowym
- `authentication` - Błędy logowania/autoryzacji
- `authorization` - Błędy uprawnień
- `validation` - Błędy walidacji danych
- `server` - Błędy serwera backend
- `file` - Błędy operacji na plikach
- `unknown` - Błędy niesklasyfikowane

### Przykłady Użycia

```dart
// W wywołaniach API
try {
  final response = await ApiService.loginUser(email, password);
  // Obsługa sukcesu
} catch (e) {
  final appError = e is AppError ? e : ErrorHandler.handleError(e, null);
  ErrorHandler.showErrorSnackBar(context, appError);
}

// Używanie widgetów błędów
RetryableErrorWidget(
  error: appError,
  onRetry: () => _retryOperation(),
)
```

## Integracja z API

Aplikacja komunikuje się z API backend dla wszystkich operacji na plikach. Kluczowe endpointy obejmują:

- `POST /create_user` - Rejestracja użytkownika
- `POST /login` - Uwierzytelnianie użytkownika
- `POST /list_files` - Pobieranie listy plików
- `POST /upload_file` - Przesyłanie plików
- `DELETE /delete_file/{path}` - Usuwanie plików
- `GET /download_file/{path}` - Pobieranie plików
- `POST /share_file` - Udostępnianie plików
- `GET /get_shared_files` - Pobieranie udostępnionych plików

## Lokalizacja

Aplikacja obsługuje wiele języków przez pakiet `easy_localization`. Aby dodać nowy język:

1. Utwórz nowy plik JSON w `assets/lang/`
2. Dodaj wszystkie wymagane klucze tłumaczeń
3. Zaktualizuj obsługiwane lokalizacje w `main.dart`

## Budowanie dla Produkcji

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

## Dokumentacja

- **[README_EN.md](README_EN.md)** - English documentation
- **[ERROR_HANDLING.md](ERROR_HANDLING.md)** - System obsługi błędów (EN)
- **[ERROR_HANDLING_PL.md](ERROR_HANDLING_PL.md)** - System obsługi błędów (PL)

## Demo

- **Strona demo błędów**: `/error-demo` - pokazuje wszystkie typy błędów i sposoby ich wyświetlania

## Wsparcie

W przypadku pytań i problemów:

- Utwórz issue w repozytorium
- Sprawdź dokumentację w folderze `docs/`
- Przejrzyj demo obsługi błędów pod trasą `/error-demo`

## Roadmap

- [ ] Obsługa trybu offline
- [ ] Funkcjonalność podglądu plików
- [ ] Zaawansowane filtry wyszukiwania
- [ ] Wersjonowanie plików
- [ ] Współpraca w czasie rzeczywistym
- [ ] Powiadomienia push na urządzeniach mobilnych
- [ ] Integracja z chmurą
- [ ] Zaawansowane funkcje bezpieczeństwa (2FA, szyfrowanie)
