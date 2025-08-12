import 'package:shared_preferences/shared_preferences.dart';

class TokenService {
  static const String _tokenKey = 'access_token';
  static const String _usernameKey = 'username';
  static const String _emailKey = 'email';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  static Future<void> removeUsername() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_usernameKey);
  }

  static Future<void> saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, email);
  }

  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  static Future<void> removeEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_emailKey);
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    final username = await getUsername();
    final email = await getEmail();
    return token != null && username != null && email != null;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_emailKey);
  }
} 