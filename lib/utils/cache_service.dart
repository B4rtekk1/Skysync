import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

class CacheService {
  static const String _filesCacheKey = 'files_cache';
  static const String _imagesCacheKey = 'images_cache';
  static const String _cacheVersionKey = 'cache_version';
  static const int _cacheVersion = 1;
  static const Duration _filesCacheDuration = Duration(minutes: 5);
  static const Duration _imagesCacheDuration = Duration(hours: 24);
  
  // Singleton pattern
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  // Cache dla listy plików
  Map<String, CachedFilesData> _filesCache = {};
  
  // Cache dla podglądów zdjęć
  Map<String, CachedImageData> _imagesCache = {};

  /// Inicjalizacja cache'owania
  Future<void> initialize() async {
    await _loadCacheFromStorage();
  }

  /// Generuje klucz cache dla listy plików
  String _generateFilesCacheKey(String username, String path) {
    final data = '$username:$path';
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return 'files_${digest.toString()}';
  }

  /// Generuje klucz cache dla podglądu zdjęcia
  String _generateImageCacheKey(String imageUrl) {
    final bytes = utf8.encode(imageUrl);
    final digest = sha256.convert(bytes);
    return 'image_${digest.toString()}';
  }

  /// Pobiera listę plików z cache
  List<Map<String, dynamic>>? getCachedFiles(String username, String path) {
    final cacheKey = _generateFilesCacheKey(username, path);
    final cachedData = _filesCache[cacheKey];
    
    if (cachedData == null) return null;
    
    // Sprawdź czy cache nie wygasł
    if (DateTime.now().difference(cachedData.timestamp) > _filesCacheDuration) {
      _filesCache.remove(cacheKey);
      return null;
    }
    
    return cachedData.files;
  }

  /// Zapisuje listę plików do cache
  Future<void> cacheFiles(String username, String path, List<Map<String, dynamic>> files) async {
    final cacheKey = _generateFilesCacheKey(username, path);
    _filesCache[cacheKey] = CachedFilesData(
      files: files,
      timestamp: DateTime.now(),
    );
    
    await _saveCacheToStorage();
  }

  /// Pobiera podgląd zdjęcia z cache
  String? getCachedImagePath(String imageUrl) {
    final cacheKey = _generateImageCacheKey(imageUrl);
    final cachedData = _imagesCache[cacheKey];
    
    if (cachedData == null) return null;
    
    // Sprawdź czy cache nie wygasł
    if (DateTime.now().difference(cachedData.timestamp) > _imagesCacheDuration) {
      _imagesCache.remove(cacheKey);
      return null;
    }
    
    // Sprawdź czy plik nadal istnieje
    final file = File(cachedData.localPath);
    if (!file.existsSync()) {
      _imagesCache.remove(cacheKey);
      return null;
    }
    
    return cachedData.localPath;
  }

  /// Zapisuje podgląd zdjęcia do cache
  Future<void> cacheImage(String imageUrl, List<int> imageBytes) async {
    try {
      final cacheKey = _generateImageCacheKey(imageUrl);
      final cacheDir = await _getCacheDirectory();
      final fileName = '${cacheKey}.jpg';
      final filePath = '${cacheDir.path}/$fileName';
      
      // Zapisz plik
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);
      
      // Zapisz metadane do cache
      _imagesCache[cacheKey] = CachedImageData(
        localPath: filePath,
        timestamp: DateTime.now(),
        size: imageBytes.length,
      );
      
      await _saveCacheToStorage();
    } catch (e) {
      print('Błąd podczas cache\'owania obrazu: $e');
    }
  }

  /// Czyści cache dla określonej ścieżki
  Future<void> clearFilesCache(String username, String path) async {
    final cacheKey = _generateFilesCacheKey(username, path);
    _filesCache.remove(cacheKey);
    await _saveCacheToStorage();
  }

  /// Czyści cache dla określonego obrazu
  Future<void> clearImageCache(String imageUrl) async {
    final cacheKey = _generateImageCacheKey(imageUrl);
    final cachedData = _imagesCache[cacheKey];
    
    if (cachedData != null) {
      // Usuń plik
      final file = File(cachedData.localPath);
      if (file.existsSync()) {
        await file.delete();
      }
      
      // Usuń z cache
      _imagesCache.remove(cacheKey);
      await _saveCacheToStorage();
    }
  }

  /// Czyści cały cache
  Future<void> clearAllCache() async {
    // Usuń wszystkie pliki obrazów
    for (final cachedData in _imagesCache.values) {
      final file = File(cachedData.localPath);
      if (file.existsSync()) {
        await file.delete();
      }
    }
    
    // Wyczyść cache w pamięci
    _filesCache.clear();
    _imagesCache.clear();
    
    // Wyczyść SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_filesCacheKey);
    await prefs.remove(_imagesCacheKey);
  }

  /// Czyści wygasłe cache
  Future<void> clearExpiredCache() async {
    final now = DateTime.now();
    final expiredFilesKeys = <String>[];
    final expiredImagesKeys = <String>[];
    
    // Sprawdź wygasłe pliki
    for (final entry in _filesCache.entries) {
      if (now.difference(entry.value.timestamp) > _filesCacheDuration) {
        expiredFilesKeys.add(entry.key);
      }
    }
    
    // Sprawdź wygasłe obrazy
    for (final entry in _imagesCache.entries) {
      if (now.difference(entry.value.timestamp) > _imagesCacheDuration) {
        expiredImagesKeys.add(entry.key);
        
        // Usuń plik
        final file = File(entry.value.localPath);
        if (file.existsSync()) {
          await file.delete();
        }
      }
    }
    
    // Usuń wygasłe wpisy
    for (final key in expiredFilesKeys) {
      _filesCache.remove(key);
    }
    
    for (final key in expiredImagesKeys) {
      _imagesCache.remove(key);
    }
    
    if (expiredFilesKeys.isNotEmpty || expiredImagesKeys.isNotEmpty) {
      await _saveCacheToStorage();
    }
  }

  /// Pobiera statystyki cache
  Map<String, dynamic> getCacheStats() {
    int totalFilesSize = 0;
    int totalImagesSize = 0;
    
    for (final cachedData in _imagesCache.values) {
      totalImagesSize += cachedData.size;
    }
    
    return {
      'files_cache_count': _filesCache.length,
      'images_cache_count': _imagesCache.length,
      'images_cache_size_bytes': totalImagesSize,
      'images_cache_size_mb': (totalImagesSize / (1024 * 1024)).toStringAsFixed(2),
    };
  }

  /// Pobiera katalog cache
  Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/image_cache');
    
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    
    return cacheDir;
  }

  /// Ładuje cache z SharedPreferences
  Future<void> _loadCacheFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Sprawdź wersję cache
      final cacheVersion = prefs.getInt(_cacheVersionKey) ?? 0;
      if (cacheVersion != _cacheVersion) {
        // Wersja cache się zmieniła, wyczyść stary cache
        await clearAllCache();
        await prefs.setInt(_cacheVersionKey, _cacheVersion);
        return;
      }
      
      // Ładuj cache plików
      final filesCacheJson = prefs.getString(_filesCacheKey);
      if (filesCacheJson != null) {
        final filesCacheMap = jsonDecode(filesCacheJson) as Map<String, dynamic>;
        _filesCache = filesCacheMap.map((key, value) {
          final data = value as Map<String, dynamic>;
          return MapEntry(key, CachedFilesData(
            files: List<Map<String, dynamic>>.from(data['files']),
            timestamp: DateTime.parse(data['timestamp']),
          ));
        });
      }
      
      // Ładuj cache obrazów
      final imagesCacheJson = prefs.getString(_imagesCacheKey);
      if (imagesCacheJson != null) {
        final imagesCacheMap = jsonDecode(imagesCacheJson) as Map<String, dynamic>;
        _imagesCache = imagesCacheMap.map((key, value) {
          final data = value as Map<String, dynamic>;
          return MapEntry(key, CachedImageData(
            localPath: data['localPath'],
            timestamp: DateTime.parse(data['timestamp']),
            size: data['size'],
          ));
        });
      }
    } catch (e) {
      print('Błąd podczas ładowania cache: $e');
      // W przypadku błędu, wyczyść cache
      _filesCache.clear();
      _imagesCache.clear();
    }
  }

  /// Zapisuje cache do SharedPreferences
  Future<void> _saveCacheToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Zapisz cache plików
      final filesCacheMap = _filesCache.map((key, value) {
        return MapEntry(key, {
          'files': value.files,
          'timestamp': value.timestamp.toIso8601String(),
        });
      });
      await prefs.setString(_filesCacheKey, jsonEncode(filesCacheMap));
      
      // Zapisz cache obrazów
      final imagesCacheMap = _imagesCache.map((key, value) {
        return MapEntry(key, {
          'localPath': value.localPath,
          'timestamp': value.timestamp.toIso8601String(),
          'size': value.size,
        });
      });
      await prefs.setString(_imagesCacheKey, jsonEncode(imagesCacheMap));
    } catch (e) {
      print('Błąd podczas zapisywania cache: $e');
    }
  }
}

/// Klasa reprezentująca cache'owane dane plików
class CachedFilesData {
  final List<Map<String, dynamic>> files;
  final DateTime timestamp;

  CachedFilesData({
    required this.files,
    required this.timestamp,
  });
}

/// Klasa reprezentująca cache'owane dane obrazów
class CachedImageData {
  final String localPath;
  final DateTime timestamp;
  final int size;

  CachedImageData({
    required this.localPath,
    required this.timestamp,
    required this.size,
  });
} 