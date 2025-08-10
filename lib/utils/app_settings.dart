import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart'; // Added for SystemUiOverlayStyle

class AppSettings extends ChangeNotifier {
  static const String _accentColorKey = 'accent_color';
  static const String _fontSizeKey = 'font_size';
  static const String _defaultViewKey = 'default_view';
  static const String _defaultSortKey = 'default_sort';

  // Singleton pattern
  static final AppSettings _instance = AppSettings._internal();
  factory AppSettings() => _instance;
  AppSettings._internal();

  // Default values
  Color _accentColor = const Color(0xFF667eea);
  String _fontSize = 'medium';
  String _defaultView = 'list';
  String _defaultSort = 'name';

  // Getters
  Color get accentColor => _accentColor;
  String get fontSize => _fontSize;
  String get defaultView => _defaultView;
  String get defaultSort => _defaultSort;

  // Initialize settings
  Future<void> initialize() async {
    await _loadSettings();
  }

  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    _accentColor = Color(prefs.getInt(_accentColorKey) ?? 0xFF667eea);
    _fontSize = prefs.getString(_fontSizeKey) ?? 'medium';
    _defaultView = prefs.getString(_defaultViewKey) ?? 'list';
    _defaultSort = prefs.getString(_defaultSortKey) ?? 'name';
  }

  // Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setInt(_accentColorKey, _accentColor.value);
    await prefs.setString(_fontSizeKey, _fontSize);
    await prefs.setString(_defaultViewKey, _defaultView);
    await prefs.setString(_defaultSortKey, _defaultSort);
  }

  // Update accent color
  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    await _saveSettings();
    notifyListeners();
  }

  // Update font size
  Future<void> setFontSize(String size) async {
    _fontSize = size;
    await _saveSettings();
    notifyListeners();
  }

  // Update default view
  Future<void> setDefaultView(String view) async {
    _defaultView = view;
    await _saveSettings();
    notifyListeners();
  }

  // Update default sort
  Future<void> setDefaultSort(String sort) async {
    _defaultSort = sort;
    await _saveSettings();
    notifyListeners();
  }

  // Get theme data based on current settings
  ThemeData getThemeData() {
    final colorScheme = ColorScheme.light(
      primary: _accentColor,
      secondary: _accentColor,
      surface: Colors.white,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.black87,
      error: Colors.red,
      onError: Colors.white,
    );
    
    return ThemeData(
      brightness: Brightness.light,
      primarySwatch: _createMaterialColor(_accentColor),
      primaryColor: _accentColor,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      cardTheme: CardTheme(
        color: colorScheme.surface,
        elevation: 2,
        shadowColor: Colors.grey,
      ),
      textTheme: _getTextTheme(colorScheme),
      appBarTheme: AppBarTheme(
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentColor,
          foregroundColor: Colors.white,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _accentColor, width: 2),
        ),
        labelStyle: TextStyle(
          color: Colors.grey.shade700,
        ),
        hintStyle: TextStyle(
          color: Colors.grey.shade500,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade300,
      ),
      iconTheme: IconThemeData(
        color: Colors.black87,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.white,
        textColor: Colors.black87,
        iconColor: Colors.black87,
      ),
    );
  }

  // Create MaterialColor from Color
  MaterialColor _createMaterialColor(Color color) {
    List<double> strengths = <double>[.05];
    Map<int, Color> swatch = {};
    final int r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.value, swatch);
  }

  // Get text theme based on font size and color scheme
  TextTheme _getTextTheme(ColorScheme colorScheme) {
    double baseSize;
    switch (_fontSize) {
      case 'small':
        baseSize = 12.0;
        break;
      case 'large':
        baseSize = 18.0;
        break;
      default: // medium
        baseSize = 14.0;
        break;
    }

    return TextTheme(
      displayLarge: TextStyle(
        fontSize: baseSize * 3.5,
        color: colorScheme.onSurface,
      ),
      displayMedium: TextStyle(
        fontSize: baseSize * 3.0,
        color: colorScheme.onSurface,
      ),
      displaySmall: TextStyle(
        fontSize: baseSize * 2.5,
        color: colorScheme.onSurface,
      ),
      headlineLarge: TextStyle(
        fontSize: baseSize * 2.0,
        color: colorScheme.onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: baseSize * 1.75,
        color: colorScheme.onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: baseSize * 1.5,
        color: colorScheme.onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: baseSize * 1.25,
        color: colorScheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: baseSize * 1.125,
        color: colorScheme.onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: baseSize,
        color: colorScheme.onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: baseSize,
        color: colorScheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: baseSize * 0.875,
        color: colorScheme.onSurface,
      ),
      bodySmall: TextStyle(
        fontSize: baseSize * 0.75,
        color: colorScheme.onSurface,
      ),
      labelLarge: TextStyle(
        fontSize: baseSize * 0.875,
        color: colorScheme.onSurface,
      ),
      labelMedium: TextStyle(
        fontSize: baseSize * 0.75,
        color: colorScheme.onSurface,
      ),
      labelSmall: TextStyle(
        fontSize: baseSize * 0.625,
        color: colorScheme.onSurface,
      ),
    );
  }

  // Get font size multiplier
  double getFontSizeMultiplier() {
    switch (_fontSize) {
      case 'small':
        return 0.8;
      case 'large':
        return 1.3;
      default: // medium
        return 1.0;
    }
  }

  // Available accent colors
  static List<Color> get availableAccentColors => [
    const Color(0xFF667eea), // Purple
    const Color(0xFF764ba2), // Deep Purple
    const Color(0xFFf093fb), // Pink
    const Color(0xFF4facfe), // Blue
    const Color(0xFF43e97b), // Green
    const Color(0xFFfa709a), // Rose
    const Color(0xFFffecd2), // Orange
    const Color(0xFFa8edea), // Teal
    const Color(0xFFff9a9e), // Coral
    const Color(0xFFa18cd1), // Lavender
  ];

  // Get color name
  static String getColorName(Color color) {
    switch (color.value) {
      case 0xFF667eea:
        return 'Purple';
      case 0xFF764ba2:
        return 'Deep Purple';
      case 0xFFf093fb:
        return 'Pink';
      case 0xFF4facfe:
        return 'Blue';
      case 0xFF43e97b:
        return 'Green';
      case 0xFFfa709a:
        return 'Rose';
      case 0xFFffecd2:
        return 'Orange';
      case 0xFFa8edea:
        return 'Teal';
      case 0xFFff9a9e:
        return 'Coral';
      case 0xFFa18cd1:
        return 'Lavender';
      default:
        return 'Custom';
    }
  }
} 