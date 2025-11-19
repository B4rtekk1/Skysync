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
}
