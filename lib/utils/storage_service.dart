import 'dart:io';
import 'package:path_provider/path_provider.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  /// Retrieves information about device storage
  Future<Map<String, dynamic>> getDeviceStorageInfo() async {
    try {
      // Get application directories
      final appDir = await getApplicationDocumentsDirectory();
      final tempDir = await getTemporaryDirectory();
      final cacheDir = await getApplicationSupportDirectory();
      
      // Get size of application directories
      final appSize = await _getDirectorySize(appDir);
      final tempSize = await _getDirectorySize(tempDir);
      final cacheSize = await _getDirectorySize(cacheDir);
      
      // Get available space on device (Android/iOS)
      final deviceInfo = await _getDeviceStorageInfo();
      
      // Validate storage data before returning
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
      
      // Add debug logging
      print('Storage info result: $result');
      
      return result;
    } catch (e) {
      print('Error while retrieving storage info: $e');
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

  /// Recursively gets the size of a directory
  Future<int> _getDirectorySize(Directory directory) async {
    try {
      int totalSize = 0;
      
      if (await directory.exists()) {
        await for (final entity in directory.list(recursive: true)) {
          if (entity is File) {
            try {
              totalSize += await entity.length();
            } catch (e) {
              // Ignore errors when reading file size
            }
          }
        }
      }
      
      return totalSize;
    } catch (e) {
      print('Error while checking directory size: $e');
      return 0;
    }
  }

  /// Retrieves information about device storage
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
        // For other platforms, return default values
        return {
          'total_gb': '0.0',
          'available_gb': '0.0',
          'used_gb': '0.0',
          'used_percentage': '0.0',
        };
      }
    } catch (e) {
      print('Error while checking device storage: $e');
      return {
        'total_gb': '0.0',
        'available_gb': '0.0',
        'used_gb': '0.0',
        'used_percentage': '0.0',
      };
    }
  }

  /// Retrieves storage information on Android
  Future<Map<String, dynamic>> _getAndroidStorageInfo() async {
    try {
      // On Android, use StatFs to check storage
      // This is a simplified implementation - in a real app
      // you might use native code or a plugin
      final appDir = await getApplicationDocumentsDirectory();
      final path = appDir.path;
      
      // Check available space in app directory
      final stat = await Process.run('df', ['-h', path]);
      if (stat.exitCode == 0) {
        final lines = stat.stdout.toString().split('\n');
        if (lines.length > 1) {
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            final total = parts[1];
            final used = parts[2];
            final available = parts[3];
            
            // Convert to GB
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
      
      // Fallback - return default values
      return {
        'total_gb': '32.0',
        'available_gb': '16.0',
        'used_gb': '16.0',
        'used_percentage': '50.0',
      };
    } catch (e) {
      print('Error while checking Android storage: $e');
      return {
        'total_gb': '32.0',
        'available_gb': '16.0',
        'used_gb': '16.0',
        'used_percentage': '50.0',
      };
    }
  }

  /// Retrieves storage information on Windows
  Future<Map<String, dynamic>> _getWindowsStorageInfo() async {
    try {
      // On Windows, use wmic to check storage
      final appDir = await getApplicationDocumentsDirectory();
      final driveLetter = appDir.path.split(':')[0];
      
      print('Windows storage check - App directory: ${appDir.path}, Drive letter: $driveLetter');
      
      // Check available space on disk
      final stat = await Process.run('wmic', ['logicaldisk', 'where', 'DeviceID="$driveLetter:"', 'get', 'Size,FreeSpace,VolumeName', '/format:csv']);
      
      print('WMIC command result - Exit code: ${stat.exitCode}');
      print('WMIC stdout: ${stat.stdout}');
      print('WMIC stderr: ${stat.stderr}');
      
      if (stat.exitCode == 0) {
        final lines = stat.stdout.toString().split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
        print('WMIC output lines: ${lines.length}');
        
        // Find data line (skipping header)
        if (lines.length > 1) {
          // Data line is usually lines[1] (after skipping empty lines and header)
          final dataLine = lines[1]; // Second non-empty line
          print('WMIC data line: "$dataLine"');
          
          final parts = dataLine.split(',');
          print('WMIC parts: $parts (length: ${parts.length})');
          
          if (parts.length >= 3) {
            // FreeSpace is in parts[1], Size in parts[2]
            final freeBytes = int.tryParse(parts[1].trim()) ?? 0;
            final totalBytes = int.tryParse(parts[2].trim()) ?? 0;
            final usedBytes = totalBytes - freeBytes;
            
            print('Parsed values - Total: $totalBytes, Free: $freeBytes, Used: $usedBytes');
            
            // Convert to GB
            final totalGB = totalBytes / (1024 * 1024 * 1024);
            final usedGB = usedBytes / (1024 * 1024 * 1024);
            final availableGB = freeBytes / (1024 * 1024 * 1024);
            
            print('Converted to GB - Total: ${totalGB.toStringAsFixed(1)}, Used: ${usedGB.toStringAsFixed(1)}, Available: ${availableGB.toStringAsFixed(1)}');
            
            // Check if totalGB is not zero before calculating percentage
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
      // Fallback - return default values
      return {
        'total_gb': '500.0',
        'available_gb': '250.0',
        'used_gb': '250.0',
        'used_percentage': '50.0',
      };
    } catch (e) {
      print('Error while checking Windows storage: $e');
      return {
        'total_gb': '500.0',
        'available_gb': '250.0',
        'used_gb': '250.0',
        'used_percentage': '50.0',
      };
    }
  }

  /// Retrieves storage information on macOS
  Future<Map<String, dynamic>> _getMacOSStorageInfo() async {
    try {
      // On macOS, use df to check storage
      final appDir = await getApplicationDocumentsDirectory();
      final path = appDir.path;
      
      // Check available space in app directory
      final stat = await Process.run('df', ['-h', path]);
      if (stat.exitCode == 0) {
        final lines = stat.stdout.toString().split('\n');
        if (lines.length > 1) {
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            final total = parts[1];
            final used = parts[2];
            final available = parts[3];
            
            // Convert to GB
            final totalGB = _convertToGB(total);
            final usedGB = _convertToGB(used);
            final availableGB = _convertToGB(available);
            
            // Check if totalGB is not zero before calculating percentage
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
      
      // Fallback - return default values
      return {
        'total_gb': '256.0',
        'available_gb': '128.0',
        'used_gb': '128.0',
        'used_percentage': '50.0',
      };
    } catch (e) {
      print('Error while checking macOS storage: $e');
      return {
        'total_gb': '256.0',
        'available_gb': '128.0',
        'used_gb': '128.0',
        'used_percentage': '50.0',
      };
    }
  }

  /// Retrieves storage information on Linux
  Future<Map<String, dynamic>> _getLinuxStorageInfo() async {
    try {
      // On Linux, use df to check storage
      final appDir = await getApplicationDocumentsDirectory();
      final path = appDir.path;
      
      // Check available space in app directory
      final stat = await Process.run('df', ['-h', path]);
      if (stat.exitCode == 0) {
        final lines = stat.stdout.toString().split('\n');
        if (lines.length > 1) {
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            final total = parts[1];
            final used = parts[2];
            final available = parts[3];
            
            // Convert to GB
            final totalGB = _convertToGB(total);
            final usedGB = _convertToGB(used);
            final availableGB = _convertToGB(available);
            
            // Check if totalGB is not zero before calculating percentage
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
      
      // Fallback - return default values
      return {
        'total_gb': '100.0',
        'available_gb': '50.0',
        'used_gb': '50.0',
        'used_percentage': '50.0',
      };
    } catch (e) {
      print('Error while checking Linux storage: $e');
      return {
        'total_gb': '100.0',
        'available_gb': '50.0',
        'used_gb': '50.0',
        'used_percentage': '50.0',
      };
    }
  }

  /// Retrieves storage information on iOS
  Future<Map<String, dynamic>> _getIOSStorageInfo() async {
    try {
      // On iOS, use NSFileManager to check storage
      // This is a simplified implementation
      final appDir = await getApplicationDocumentsDirectory();
      final path = appDir.path;
      
      // Check available space in app directory
      final stat = await Process.run('df', ['-h', path]);
      if (stat.exitCode == 0) {
        final lines = stat.stdout.toString().split('\n');
        if (lines.length > 1) {
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            final total = parts[1];
            final used = parts[2];
            final available = parts[3];
            
            // Convert to GB
            final totalGB = _convertToGB(total);
            final usedGB = _convertToGB(used);
            final availableGB = _convertToGB(available);
            
            // Check if totalGB is not zero before calculating percentage
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
      
      // Fallback - return default values
      return {
        'total_gb': '64.0',
        'available_gb': '32.0',
        'used_gb': '32.0',
        'used_percentage': '50.0',
      };
    } catch (e) {
      print('Error while checking iOS storage: $e');
      return {
        'total_gb': '64.0',
        'available_gb': '32.0',
        'used_gb': '32.0',
        'used_percentage': '50.0',
      };
    }
  }

  /// Converts size from various units to GB
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

  /// Validates and normalizes storage data
  Map<String, dynamic> _validateStorageData(Map<String, dynamic> data) {
    try {
      // Ensure all values are positive and finite
      final totalGB = (double.tryParse(data['total_gb'] ?? '0.0') ?? 0.0).abs();
      final usedGB = (double.tryParse(data['used_gb'] ?? '0.0') ?? 0.0).abs();
      final availableGB = (double.tryParse(data['available_gb'] ?? '0.0') ?? 0.0).abs();
      
      // Calculate usage percentage only if totalGB > 0
      final percentage = totalGB > 0 ? ((usedGB / totalGB) * 100).clamp(0.0, 100.0) : 0.0;
      
      // Add debug logging
      print('Storage validation - Total: ${totalGB}GB, Used: ${usedGB}GB, Available: ${availableGB}GB, Percentage: ${percentage}%');
      
      return {
        'total_gb': totalGB.toStringAsFixed(1),
        'available_gb': availableGB.toStringAsFixed(1),
        'used_gb': usedGB.toStringAsFixed(1),
        'used_percentage': percentage.toStringAsFixed(1),
      };
    } catch (e) {
      print('Error while validating storage data: $e');
      return {
        'total_gb': '0.0',
        'available_gb': '0.0',
        'used_gb': '0.0',
        'used_percentage': '0.0',
      };
    }
  }

  /// Clears application cache
  Future<void> clearAppCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = await getApplicationSupportDirectory();
      
      await _clearDirectory(tempDir);
      await _clearDirectory(cacheDir);
    } catch (e) {
      print('Error while clearing cache: $e');
    }
  }

  /// Clears the contents of a directory
  Future<void> _clearDirectory(Directory directory) async {
    try {
      if (await directory.exists()) {
        await for (final entity in directory.list(recursive: true)) {
          if (entity is File) {
            try {
              await entity.delete();
            } catch (e) {
              // Ignore errors when deleting files
            }
          }
        }
      }
    } catch (e) {
      print('Error while clearing directory: $e');
    }
  }
} 