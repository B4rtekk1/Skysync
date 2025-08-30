import 'dart:io';
import 'package:path_provider/path_provider.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  /// Pobiera informacje o storage na urządzeniu
  Future<Map<String, dynamic>> getDeviceStorageInfo() async {
    try {
      // Pobierz katalogi aplikacji
      final appDir = await getApplicationDocumentsDirectory();
      final tempDir = await getTemporaryDirectory();
      final cacheDir = await getApplicationSupportDirectory();
      
      // Sprawdź rozmiar katalogów aplikacji
      final appSize = await _getDirectorySize(appDir);
      final tempSize = await _getDirectorySize(tempDir);
      final cacheSize = await _getDirectorySize(cacheDir);
      
      // Sprawdź dostępne miejsce na urządzeniu (Android/iOS)
      final deviceInfo = await _getDeviceStorageInfo();
      
      // Waliduj dane storage przed zwróceniem
      final validatedStorage = _validateStorageData(deviceInfo);
      
      final result = {
        'app_size_mb': (appSize / (1024 * 1024)).toStringAsFixed(2),
        'temp_size_mb': (tempSize / (1024 * 1024)).toStringAsFixed(2),
        'cache_size_mb': (cacheSize / (1024 * 1024)).toStringAsFixed(2),
        'total_app_size_mb': ((appSize + tempSize + cacheSize) / (1024 * 1024)).toStringAsFixed(2),
        'device_total_gb': validatedStorage['total_gb'],
        'device_available_gb': validatedStorage['available_gb'],
        'device_used_gb': validatedStorage['used_gb'],
        'device_used_percentage': validatedStorage['used_percentage'],
      };
      
      // Dodaj logowanie dla debugowania
      print('Storage info result: $result');
      
      return result;
    } catch (e) {
      print('Błąd podczas pobierania informacji o storage: $e');
      return {
        'app_size_mb': '0.0',
        'temp_size_mb': '0.0',
        'cache_size_mb': '0.0',
        'total_app_size_mb': '0.0',
        'device_total_gb': '0.0',
        'device_available_gb': '0.0',
        'device_used_gb': '0.0',
        'device_used_percentage': '0.0',
      };
    }
  }

  /// Pobiera rozmiar katalogu rekurencyjnie
  Future<int> _getDirectorySize(Directory directory) async {
    try {
      int totalSize = 0;
      
      if (await directory.exists()) {
        await for (final entity in directory.list(recursive: true)) {
          if (entity is File) {
            try {
              totalSize += await entity.length();
            } catch (e) {
              // Ignoruj błędy przy odczycie rozmiaru pliku
            }
          }
        }
      }
      
      return totalSize;
    } catch (e) {
      print('Błąd podczas sprawdzania rozmiaru katalogu: $e');
      return 0;
    }
  }

  /// Pobiera informacje o storage urządzenia
  Future<Map<String, dynamic>> _getDeviceStorageInfo() async {
    try {
      print('Platform detection: Android=${Platform.isAndroid}, iOS=${Platform.isIOS}, Windows=${Platform.isWindows}, macOS=${Platform.isMacOS}, Linux=${Platform.isLinux}');
      
      if (Platform.isAndroid) {
        print('Using Android storage method');
        return await _getAndroidStorageInfo();
      } else if (Platform.isIOS) {
        print('Using iOS storage method');
        return await _getIOSStorageInfo();
      } else if (Platform.isWindows) {
        print('Using Windows storage method');
        return await _getWindowsStorageInfo();
      } else if (Platform.isMacOS) {
        print('Using macOS storage method');
        return await _getMacOSStorageInfo();
      } else if (Platform.isLinux) {
        print('Using Linux storage method');
        return await _getLinuxStorageInfo();
      } else {
        print('Unknown platform, using fallback values');
        // Dla innych platform zwróć domyślne wartości
        return {
          'total_gb': '0.0',
          'available_gb': '0.0',
          'used_gb': '0.0',
          'used_percentage': '0.0',
        };
      }
    } catch (e) {
      print('Błąd podczas sprawdzania storage urządzenia: $e');
      return {
        'total_gb': '0.0',
        'available_gb': '0.0',
        'used_gb': '0.0',
        'used_percentage': '0.0',
      };
    }
  }

  /// Pobiera informacje o storage na Android
  Future<Map<String, dynamic>> _getAndroidStorageInfo() async {
    try {
      // Na Android używamy StatFs do sprawdzenia storage
      // To jest uproszczona implementacja - w rzeczywistej aplikacji
      // możesz użyć native code lub plugin
      final appDir = await getApplicationDocumentsDirectory();
      final path = appDir.path;
      
      // Sprawdź dostępne miejsce w katalogu aplikacji
      final stat = await Process.run('df', ['-h', path]);
      if (stat.exitCode == 0) {
        final lines = stat.stdout.toString().split('\n');
        if (lines.length > 1) {
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            final total = parts[1];
            final used = parts[2];
            final available = parts[3];
            
            // Konwertuj na GB
            final totalGB = _convertToGB(total);
            final usedGB = _convertToGB(used);
            final availableGB = _convertToGB(available);
            
            final percentage = totalGB > 0 ? ((usedGB / totalGB) * 100) : 0.0;
            return {
              'total_gb': totalGB.toStringAsFixed(1),
              'available_gb': availableGB.toStringAsFixed(1),
              'used_gb': usedGB.toStringAsFixed(1),
              'used_percentage': percentage.toStringAsFixed(1),
            };
          }
        }
      }
      
      // Fallback - zwróć domyślne wartości
      return {
        'total_gb': '32.0',
        'available_gb': '16.0',
        'used_gb': '16.0',
        'used_percentage': '50.0',
      };
    } catch (e) {
      print('Błąd podczas sprawdzania Android storage: $e');
      return {
        'total_gb': '32.0',
        'available_gb': '16.0',
        'used_gb': '16.0',
        'used_percentage': '50.0',
      };
    }
  }

  /// Pobiera informacje o storage na Windows
  /// Pobiera informacje o storage na Windows
Future<Map<String, dynamic>> _getWindowsStorageInfo() async {
  try {
    // Na Windows używamy wmic do sprawdzenia storage
    final appDir = await getApplicationDocumentsDirectory();
    final driveLetter = appDir.path.split(':')[0];
    
    print('Windows storage check - App directory: ${appDir.path}, Drive letter: $driveLetter');
    
    // Sprawdź dostępne miejsce na dysku
    final stat = await Process.run('wmic', ['logicaldisk', 'where', 'DeviceID="$driveLetter:"', 'get', 'Size,FreeSpace,VolumeName', '/format:csv']);
    
    print('WMIC command result - Exit code: ${stat.exitCode}');
    print('WMIC stdout: ${stat.stdout}');
    print('WMIC stderr: ${stat.stderr}');
    
    if (stat.exitCode == 0) {
      final lines = stat.stdout.toString().split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
      print('WMIC output lines: ${lines.length}');
      
      // Znajdź linię z danymi (pomijając nagłówek)
      if (lines.length > 1) {
        // Linia z danymi to zazwyczaj lines[1] (po pominięciu pustych linii i nagłówka)
        final dataLine = lines[1]; // Druga niepusta linia
        print('WMIC data line: "$dataLine"');
        
        final parts = dataLine.split(',');
        print('WMIC parts: $parts (length: ${parts.length})');
        
        if (parts.length >= 3) {
          // FreeSpace jest w parts[1], Size w parts[2]
          final freeBytes = int.tryParse(parts[1].trim()) ?? 0;
          final totalBytes = int.tryParse(parts[2].trim()) ?? 0;
          final usedBytes = totalBytes - freeBytes;
          
          print('Parsed values - Total: $totalBytes, Free: $freeBytes, Used: $usedBytes');
          
          // Konwertuj na GB
          final totalGB = totalBytes / (1024 * 1024 * 1024);
          final usedGB = usedBytes / (1024 * 1024 * 1024);
          final availableGB = freeBytes / (1024 * 1024 * 1024);
          
          print('Converted to GB - Total: ${totalGB.toStringAsFixed(1)}, Used: ${usedGB.toStringAsFixed(1)}, Available: ${availableGB.toStringAsFixed(1)}');
          
          // Sprawdź czy totalGB nie jest zerem przed obliczeniem procentu
          final percentage = totalGB > 0 ? ((usedGB / totalGB) * 100) : 0.0;
          return {
            'total_gb': totalGB.toStringAsFixed(1),
            'available_gb': availableGB.toStringAsFixed(1),
            'used_gb': usedGB.toStringAsFixed(1),
            'used_percentage': percentage.toStringAsFixed(1),
          };
        }
      }
    }
    
    print('Using fallback values for Windows');
    // Fallback - zwróć domyślne wartości
    return {
      'total_gb': '500.0',
      'available_gb': '250.0',
      'used_gb': '250.0',
      'used_percentage': '50.0',
    };
  } catch (e) {
    print('Błąd podczas sprawdzania Windows storage: $e');
    return {
      'total_gb': '500.0',
      'available_gb': '250.0',
      'used_gb': '250.0',
      'used_percentage': '50.0',
    };
  }
}

  /// Pobiera informacje o storage na macOS
  Future<Map<String, dynamic>> _getMacOSStorageInfo() async {
    try {
      // Na macOS używamy df do sprawdzenia storage
      final appDir = await getApplicationDocumentsDirectory();
      final path = appDir.path;
      
      // Sprawdź dostępne miejsce w katalogu aplikacji
      final stat = await Process.run('df', ['-h', path]);
      if (stat.exitCode == 0) {
        final lines = stat.stdout.toString().split('\n');
        if (lines.length > 1) {
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            final total = parts[1];
            final used = parts[2];
            final available = parts[3];
            
            // Konwertuj na GB
            final totalGB = _convertToGB(total);
            final usedGB = _convertToGB(used);
            final availableGB = _convertToGB(available);
            
            // Sprawdź czy totalGB nie jest zerem przed obliczeniem procentu
            final percentage = totalGB > 0 ? ((usedGB / totalGB) * 100) : 0.0;
            return {
              'total_gb': totalGB.toStringAsFixed(1),
              'available_gb': availableGB.toStringAsFixed(1),
              'used_gb': usedGB.toStringAsFixed(1),
              'used_percentage': percentage.toStringAsFixed(1),
            };
          }
        }
      }
      
      // Fallback - zwróć domyślne wartości
      return {
        'total_gb': '256.0',
        'available_gb': '128.0',
        'used_gb': '128.0',
        'used_percentage': '50.0',
      };
    } catch (e) {
      print('Błąd podczas sprawdzania macOS storage: $e');
      return {
        'total_gb': '256.0',
        'available_gb': '128.0',
        'used_gb': '128.0',
        'used_percentage': '50.0',
      };
    }
  }

  /// Pobiera informacje o storage na Linux
  Future<Map<String, dynamic>> _getLinuxStorageInfo() async {
    try {
      // Na Linux używamy df do sprawdzenia storage
      final appDir = await getApplicationDocumentsDirectory();
      final path = appDir.path;
      
      // Sprawdź dostępne miejsce w katalogu aplikacji
      final stat = await Process.run('df', ['-h', path]);
      if (stat.exitCode == 0) {
        final lines = stat.stdout.toString().split('\n');
        if (lines.length > 1) {
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            final total = parts[1];
            final used = parts[2];
            final available = parts[3];
            
            // Konwertuj na GB
            final totalGB = _convertToGB(total);
            final usedGB = _convertToGB(used);
            final availableGB = _convertToGB(available);
            
            // Sprawdź czy totalGB nie jest zerem przed obliczeniem procentu
            final percentage = totalGB > 0 ? ((usedGB / totalGB) * 100) : 0.0;
            return {
              'total_gb': totalGB.toStringAsFixed(1),
              'available_gb': availableGB.toStringAsFixed(1),
              'used_gb': usedGB.toStringAsFixed(1),
              'used_percentage': percentage.toStringAsFixed(1),
            };
          }
        }
      }
      
      // Fallback - zwróć domyślne wartości
      return {
        'total_gb': '100.0',
        'available_gb': '50.0',
        'used_gb': '50.0',
        'used_percentage': '50.0',
      };
    } catch (e) {
      print('Błąd podczas sprawdzania Linux storage: $e');
      return {
        'total_gb': '100.0',
        'available_gb': '50.0',
        'used_gb': '50.0',
        'used_percentage': '50.0',
      };
    }
  }

  /// Pobiera informacje o storage na iOS
  Future<Map<String, dynamic>> _getIOSStorageInfo() async {
    try {
      // Na iOS używamy NSFileManager do sprawdzenia storage
      // To jest uproszczona implementacja
      final appDir = await getApplicationDocumentsDirectory();
      final path = appDir.path;
      
      // Sprawdź dostępne miejsce w katalogu aplikacji
      final stat = await Process.run('df', ['-h', path]);
      if (stat.exitCode == 0) {
        final lines = stat.stdout.toString().split('\n');
        if (lines.length > 1) {
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            final total = parts[1];
            final used = parts[2];
            final available = parts[3];
            
            // Konwertuj na GB
            final totalGB = _convertToGB(total);
            final usedGB = _convertToGB(used);
            final availableGB = _convertToGB(available);
            
            // Sprawdź czy totalGB nie jest zerem przed obliczeniem procentu
            final percentage = totalGB > 0 ? ((usedGB / totalGB) * 100) : 0.0;
            return {
              'total_gb': totalGB.toStringAsFixed(1),
              'available_gb': availableGB.toStringAsFixed(1),
              'used_gb': usedGB.toStringAsFixed(1),
              'used_percentage': percentage.toStringAsFixed(1),
            };
          }
        }
      }
      
      // Fallback - zwróć domyślne wartości
      return {
        'total_gb': '64.0',
        'available_gb': '32.0',
        'used_gb': '32.0',
        'used_percentage': '50.0',
      };
    } catch (e) {
      print('Błąd podczas sprawdzania iOS storage: $e');
      return {
        'total_gb': '64.0',
        'available_gb': '32.0',
        'used_gb': '32.0',
        'used_percentage': '50.0',
      };
    }
  }

  /// Konwertuje rozmiar z różnych jednostek na GB
  double _convertToGB(String size) {
    try {
      final value = double.parse(size.replaceAll(RegExp(r'[A-Za-z]'), ''));
      if (size.endsWith('T') || size.endsWith('t')) {
        return value * 1024;
      } else if (size.endsWith('G') || size.endsWith('g')) {
        return value;
      } else if (size.endsWith('M') || size.endsWith('m')) {
        return value / 1024;
      } else if (size.endsWith('K') || size.endsWith('k')) {
        return value / (1024 * 1024);
      } else {
        return value / (1024 * 1024 * 1024);
      }
    } catch (e) {
      return 0.0;
    }
  }

  /// Waliduje i normalizuje dane storage
  Map<String, dynamic> _validateStorageData(Map<String, dynamic> data) {
    try {
      // Upewnij się, że wszystkie wartości są dodatnie i skończone
      final totalGB = (double.tryParse(data['total_gb'] ?? '0.0') ?? 0.0).abs();
      final usedGB = (double.tryParse(data['used_gb'] ?? '0.0') ?? 0.0).abs();
      final availableGB = (double.tryParse(data['available_gb'] ?? '0.0') ?? 0.0).abs();
      
      // Oblicz procent użytkowania tylko jeśli totalGB > 0
      final percentage = totalGB > 0 ? ((usedGB / totalGB) * 100).clamp(0.0, 100.0) : 0.0;
      
      // Dodaj logowanie dla debugowania
      print('Storage validation - Total: ${totalGB}GB, Used: ${usedGB}GB, Available: ${availableGB}GB, Percentage: ${percentage}%');
      
      return {
        'total_gb': totalGB.toStringAsFixed(1),
        'available_gb': availableGB.toStringAsFixed(1),
        'used_gb': usedGB.toStringAsFixed(1),
        'used_percentage': percentage.toStringAsFixed(1),
      };
    } catch (e) {
      print('Błąd podczas walidacji danych storage: $e');
      return {
        'total_gb': '0.0',
        'available_gb': '0.0',
        'used_gb': '0.0',
        'used_percentage': '0.0',
      };
    }
  }

  /// Czyści cache aplikacji
  Future<void> clearAppCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = await getApplicationSupportDirectory();
      
      await _clearDirectory(tempDir);
      await _clearDirectory(cacheDir);
    } catch (e) {
      print('Błąd podczas czyszczenia cache: $e');
    }
  }

  /// Czyści zawartość katalogu
  Future<void> _clearDirectory(Directory directory) async {
    try {
      if (await directory.exists()) {
        await for (final entity in directory.list(recursive: true)) {
          if (entity is File) {
            try {
              await entity.delete();
            } catch (e) {
              // Ignoruj błędy przy usuwaniu plików
            }
          }
        }
      }
    } catch (e) {
      print('Błąd podczas czyszczenia katalogu: $e');
    }
  }
} 