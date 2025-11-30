import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_service.dart';

class AuthService {
  final _storage = const FlutterSecureStorage();
  final _apiService = ApiService();

  static const _keyToken = 'jwt_token';
  static const _keyUsername = 'username';
  static const _keyEmail = 'email';

  Future<void> saveAuthData({
    required String token,
    required String username,
    required String email,
  }) async {
    await _storage.write(key: _keyToken, value: token);
    await _storage.write(key: _keyUsername, value: username);
    await _storage.write(key: _keyEmail, value: email);
  }

  Future<Map<String, String?>> getAuthData() async {
    final token = await _storage.read(key: _keyToken);
    final username = await _storage.read(key: _keyUsername);
    final email = await _storage.read(key: _keyEmail);
    return {'token': token, 'username': username, 'email': email};
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _keyToken);
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: _keyToken);
    return token != null;
  }

  Future<void> logout() async {
    final token = await _storage.read(key: _keyToken);
    if (token != null) {
      await _apiService.logout(token);
    }
    await _storage.deleteAll();
  }

  Future<bool> checkTokenValidity() async {
    final token = await _storage.read(key: _keyToken);
    if (token == null) return false;

    final isValid = await _apiService.verifyToken(token);
    if (!isValid) {
      await logout();
      return false;
    }
    return true;
  }

  Future<void> updateUsername(String newUsername, String password) async {
    final token = await _storage.read(key: _keyToken);
    if (token == null) throw Exception('Not authenticated');

    await _apiService.updateUsername(token, newUsername, password);
    await _storage.write(key: _keyUsername, value: newUsername);
  }
}
