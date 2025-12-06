// TODO: API service improvements
// TODO: Replace generic Map<String, dynamic> responses with typed model classes.
// TODO: Add centralized error mapping, retry/backoff strategy and request timeouts.
// TODO: Implement token refresh handling on 401 responses and improve logging.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
    String name,
    String email,
    String password,
  ) async {
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
        body: jsonEncode({'email': email, 'code': code}),
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

  Future<void> confirmPasswordReset(
    String email,
    String code,
    String newPassword,
  ) async {
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

  Future<List<Map<String, dynamic>>> listFiles(
    String token,
    String username, {
    String folder = '',
  }) async {
    final url = Uri.parse('$baseUrl/api/list_files');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': Config.apiKey,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'username': username, 'folder_name': folder}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['files'] ?? []);
      } else {
        throw Exception('Failed to load files: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error loading files: $e');
    }
  }

  Future<void> uploadFile(
    String token,
    String username,
    File file, {
    String folder = '',
  }) async {
    final url = Uri.parse('$baseUrl/api/upload_file');
    final request = http.MultipartRequest('POST', url);
    request.headers.addAll({
      'X-API-Key': Config.apiKey,
      'Authorization': 'Bearer $token',
    });
    request.fields['username'] = username;
    request.fields['folder'] = folder;

    final stream = http.ByteStream(file.openRead());
    final length = await file.length();

    final multipartFile = http.MultipartFile(
      'file',
      stream,
      length,
      filename: file.path.split(Platform.pathSeparator).last,
    );

    request.files.add(multipartFile);

    try {
      final response = await request.send();
      if (response.statusCode != 200) {
        final respStr = await response.stream.bytesToString();
        throw Exception('Failed to upload file: $respStr');
      }
    } catch (e) {
      throw Exception('Error uploading file: $e');
    }
  }

  Future<void> createFolder(
    String token,
    String username,
    String folderName, {
    String currentPath = '',
  }) async {
    final url = Uri.parse('$baseUrl/api/create_folder');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': Config.apiKey,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'folder_name': '${currentPath == "/" ? "" : currentPath}/$folderName',
        }),
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Failed to create folder: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating folder: $e');
    }
  }

  Future<void> toggleFavorite(
    String token,
    String filename,
    String folderName,
  ) async {
    final url = Uri.parse('$baseUrl/api/toggle_favorite');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': Config.apiKey,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'filename': filename, 'folder_name': folderName}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to toggle favorite: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error toggling favorite: $e');
    }
  }

  Future<List<int>> downloadFolder(String token, String folderName) async {
    final url = Uri.parse('$baseUrl/api/download_folder');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': Config.apiKey,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'folder_name': folderName}),
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Failed to download folder: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error downloading folder: $e');
    }
  }

  Future<void> logout(String token) async {
    final url = Uri.parse('$baseUrl/api/logout');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': Config.apiKey,
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        debugPrint('Failed to logout on server: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error logging out: $e');
    }
  }

  Future<bool> verifyToken(String token) async {
    final url = Uri.parse('$baseUrl/api/verify_token');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': Config.apiKey,
          'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> updateUsername(
    String token,
    String newUsername,
    String password,
  ) async {
    final url = Uri.parse('$baseUrl/api/update_username');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': Config.apiKey,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'new_username': newUsername, 'password': password}),
      );

      if (response.statusCode != 200) {
        final error =
            jsonDecode(response.body)['error'] ?? 'Failed to update username';
        throw Exception(error);
      }
    } catch (e) {
      throw Exception('Error updating username: $e');
    }
  }

  Future<void> renameFile(String token, int fileId, String newName) async {
    final url = Uri.parse('$baseUrl/api/rename_file');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': Config.apiKey,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'file_id': fileId, 'new_name': newName}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to rename file: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error renaming file: $e');
    }
  }

  Future<Map<String, dynamic>> createGroup(
    String token,
    String name,
    String description,
  ) async {
    final url = Uri.parse('$baseUrl/api/groups/create');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': Config.apiKey,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'name': name, 'description': description}),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create group: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating group: $e');
    }
  }

  Future<List<Map<String, dynamic>>> listGroups(String token) async {
    final url = Uri.parse('$baseUrl/api/groups/list');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': Config.apiKey,
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['groups'] ?? []);
      } else {
        throw Exception('Failed to load groups: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error loading groups: $e');
    }
  }

  Future<Map<String, dynamic>> getGroupDetails(
    String token,
    int groupId,
  ) async {
    final url = Uri.parse('$baseUrl/api/groups/$groupId');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': Config.apiKey,
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get group details: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error getting group details: $e');
    }
  }

  Future<void> addMemberToGroup(
    String token,
    int groupId,
    String emailOrUsername, {
    bool isAdmin = false,
  }) async {
    final url = Uri.parse('$baseUrl/api/groups/add_member');
    try {
      final isEmail = emailOrUsername.contains('@');
      final body = {
        'group_id': groupId,
        isEmail ? 'email' : 'username': emailOrUsername,
        'is_admin': isAdmin,
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': Config.apiKey,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        throw Exception(
          jsonDecode(response.body)['error'] ?? 'Failed to add member',
        );
      }
    } catch (e) {
      throw Exception('Error adding member: $e');
    }
  }

  Future<void> removeMemberFromGroup(
    String token,
    int groupId,
    int userId,
  ) async {
    final url = Uri.parse('$baseUrl/api/groups/remove_member');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': Config.apiKey,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'group_id': groupId, 'user_id': userId}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to remove member: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error removing member: $e');
    }
  }

  Future<void> deleteGroup(String token, int groupId) async {
    final url = Uri.parse('$baseUrl/api/groups/$groupId');
    try {
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': Config.apiKey,
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete group: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error deleting group: $e');
    }
  }

  Future<void> shareFileWithGroup(String token, int groupId, int fileId) async {
    final url = Uri.parse('$baseUrl/api/groups/share_file');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': Config.apiKey,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'group_id': groupId, 'file_id': fileId}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to share file: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error sharing file: $e');
    }
  }

  Future<void> shareFolderWithGroup(
    String token,
    int groupId,
    String folderPath,
  ) async {
    final url = Uri.parse('$baseUrl/api/groups/share_folder');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': Config.apiKey,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'group_id': groupId, 'folder_path': folderPath}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to share folder: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error sharing folder: $e');
    }
  }

  Future<Map<String, dynamic>> getGroupFiles(String token, int groupId) async {
    final url = Uri.parse('$baseUrl/api/groups/$groupId/files');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': Config.apiKey,
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get group files: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error getting group files: $e');
    }
  }

  Future<void> unshareFileFromGroup(
    String token,
    int groupId,
    int fileId,
  ) async {
    final url = Uri.parse('$baseUrl/api/groups/unshare_file');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': Config.apiKey,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'group_id': groupId, 'file_id': fileId}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to unshare file: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error unsharing file: $e');
    }
  }

  Future<void> unshareFolderFromGroup(
    String token,
    int groupId,
    String folderPath,
  ) async {
    final url = Uri.parse('$baseUrl/api/groups/unshare_folder');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': Config.apiKey,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'group_id': groupId, 'folder_path': folderPath}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to unshare folder: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error unsharing folder: $e');
    }
  }

  Future<void> shareFileWithUser(
    String token,
    int fileId,
    String emailOrUsername,
  ) async {
    final url = Uri.parse('$baseUrl/api/share_file_user');
    try {
      final isEmail = emailOrUsername.contains('@');
      final body = {
        'file_id': fileId,
        isEmail ? 'email' : 'username': emailOrUsername,
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': Config.apiKey,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        final error =
            jsonDecode(response.body)['error'] ?? 'Failed to share file';
        throw Exception(error);
      }
    } catch (e) {
      throw Exception(e);
    }
  }
}
