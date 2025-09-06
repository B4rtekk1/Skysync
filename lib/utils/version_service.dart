import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

class VersionService {
  static const String _lastVersionKey = 'last_server_version';
  static const String _lastUpdateInfoKey = 'last_update_info';
  static const String _lastCheckTimeKey = 'last_version_check_time';
  static const String _appVersionKey = 'app_version';

  static final VersionService _instance = VersionService._internal();
  factory VersionService() => _instance;
  VersionService._internal();

  Future<void> saveLastVersion(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastVersionKey, version);
    } catch (e) {
      print('Error saving last version: $e');
    }
  }

  Future<String?> getLastVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      print('Last version: ${prefs.getString(_lastVersionKey)}');
      return prefs.getString(_lastVersionKey);
    } catch (e) {
      print('Error getting last version: $e');
      return null;
    }
  }

  Future<void> saveLastUpdateInfo(Map<String, dynamic> updateInfo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastUpdateInfoKey, updateInfo.toString());
    } catch (e) {
      print('Error saving last update info: $e');
    }
  }

  Future<Map<String, dynamic>?> getLastUpdateInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final infoString = prefs.getString(_lastUpdateInfoKey);
      if (infoString != null) {
        return _parseUpdateInfoString(infoString);
      }
      return null;
    } catch (e) {
      print('Error getting last update info: $e');
      return null;
    }
  }

  Future<void> saveLastCheckTime(DateTime checkTime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastCheckTimeKey, checkTime.toIso8601String());
    } catch (e) {
      print('Error saving last check time: $e');
    }
  }

  Future<DateTime?> getLastCheckTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeString = prefs.getString(_lastCheckTimeKey);
      if (timeString != null) {
        return DateTime.parse(timeString);
      }
      return null;
    } catch (e) {
      print('Error getting last check time: $e');
      return null;
    }
  }

  Future<void> clearVersionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastVersionKey);
      await prefs.remove(_lastUpdateInfoKey);
      await prefs.remove(_lastCheckTimeKey);
    } catch (e) {
      print('Error clearing version data: $e');
    }
  }

  Future<bool> hasVersionChanged(String currentVersion) async {
    final lastVersion = await getLastVersion();
    return lastVersion != currentVersion;
  }

  Future<String> getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      print('Error getting app version: $e');
      return '1.0.0';
    }
  }

  Future<void> saveAppVersion(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_appVersionKey, version);
    } catch (e) {
      print('Error saving app version: $e');
    }
  }

  Future<String?> getSavedAppVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_appVersionKey);
    } catch (e) {
      print('Error getting saved app version: $e');
      return null;
    }
  }

  Future<bool> isServerVersionNewer(String serverVersion, String appVersion) async {
    try {
      final serverParts = serverVersion.split('.').map(int.parse).toList();
      final appParts = appVersion.split('.').map(int.parse).toList();
      
      while (serverParts.length < appParts.length) serverParts.add(0);
      while (appParts.length < serverParts.length) appParts.add(0);
      
      for (int i = 0; i < serverParts.length; i++) {
        if (serverParts[i] > appParts[i]) return true;
        if (serverParts[i] < appParts[i]) return false;
      }
      
      return false;
    } catch (e) {
      print('Error comparing versions: $e');
      return false;
    }
  }

  Future<bool> isUpdateNeeded(String serverVersion) async {
    try {
      final appVersion = await getAppVersion();
      return await isServerVersionNewer(serverVersion, appVersion);
    } catch (e) {
      print('Error checking if update is needed: $e');
      return false;
    }
  }

  Map<String, dynamic> _parseUpdateInfoString(String infoString) {
    try {
      final cleanString = infoString.replaceAll('{', '').replaceAll('}', '');
      final parts = cleanString.split(', ');
      final Map<String, dynamic> result = {};
      
      for (final part in parts) {
        final keyValue = part.split(': ');
        if (keyValue.length == 2) {
          final key = keyValue[0].trim();
          final value = keyValue[1].trim();
          result[key] = value;
        }
      }
      
      return result;
    } catch (e) {
      print('Error parsing update info string: $e');
      return {};
    }
  }
}
