import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config.dart';

class ApiService {
  static String baseUrl = Config.baseUrl;

  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/api/login');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': Config.apiKey,
        },
        body: jsonEncode({'username': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to login: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error logging in: $e');
    }
  }

  Future<Map<String, dynamic>> register(
      String name, String email, String password) async {
    final url = Uri.parse('$baseUrl/api/register');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': Config.apiKey,
        },
        body: jsonEncode({
          'username': name,
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to register: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error registering: $e');
    }
  }
  Future<Map<String, dynamic>> verify(String email, String code) async {
    final url = Uri.parse('$baseUrl/api/verify');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': Config.apiKey,
        },
        body: jsonEncode({
          'email': email,
          'code': code,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to verify: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error verifying: $e');
    }
  }
  Future<void> resetPassword(String email) async {
    final url = Uri.parse('$baseUrl/api/reset_password');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': Config.apiKey,
        },
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to send reset link: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error sending reset link: $e');
    }
  }
  Future<void> confirmPasswordReset(String email, String code, String newPassword) async {
    final url = Uri.parse('$baseUrl/api/confirm_reset_password');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': Config.apiKey,
        },
        body: jsonEncode({
          'email': email,
          'code': code,
          'new_password': newPassword,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to reset password: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error resetting password: $e');
    }
  }
}

