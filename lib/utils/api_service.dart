import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/env_config.dart';
import 'version_service.dart';

class ApiService {
  
  static String get apiKey => EnvConfig.apiKey;
  static String get baseUrl => EnvConfig.baseUrl;

  static Future<Map<String, dynamic>?> checkForUpdate() async{
    try {
      final response = await http.get(Uri.parse('$baseUrl/app_version'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Save the version returned by server
        final versionService = VersionService();
        final serverVersion = data['version'] ?? 'Unknown';
        await versionService.saveLastVersion(serverVersion);
        await versionService.saveLastCheckTime(DateTime.now());
        
        // Get current app version
        final appVersion = await versionService.getAppVersion();
        await versionService.saveAppVersion(appVersion);
        
        // Check if server version is newer than app version
        final isUpdateNeeded = await versionService.isUpdateNeeded(serverVersion);
        
        print('App version: $appVersion, Server version: $serverVersion, Update needed: $isUpdateNeeded');
        
        if (isUpdateNeeded) {
          final updateInfo = {
            'hasUpdate': true,
            'version': serverVersion,
            'appVersion': appVersion,
            'message': data['message'] ?? 'Dostępna jest nowa wersja aplikacji',
            'downloadUrl': data['downloadUrl'] ?? null,
          };
          
          // Save complete update info
          await versionService.saveLastUpdateInfo(updateInfo);
          
          return updateInfo;
        }
        
        // No update needed - versions are the same or app is newer
        final noUpdateInfo = {
          'hasUpdate': false,
          'version': serverVersion,
          'appVersion': appVersion,
          'message': data['message'] ?? 'Aplikacja jest aktualna',
        };
        await versionService.saveLastUpdateInfo(noUpdateInfo);
        
        return noUpdateInfo;
      }
      else {
        print('Error while loading app version ${response.statusCode}');
        return null;
      }
    }
     catch (e){
      print('An error occured: $e');
      return null;
     }
  }

  static Future<http.Response> registerUser({
    required String username,
    required String email,
    required String password,
  }) async {
    print('Connecting to: $baseUrl');
    print('API Key: ${apiKey.isNotEmpty ? "Set" : "Not set"}');
    final url = Uri.parse('$baseUrl/create_user');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'API_KEY': apiKey,
      },
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );
    print(response.body);
    return response;
  }

  static Future<http.Response> verifyUser({
    required String email,
    required String code,
  }) async {
    print('Connecting to: $baseUrl');
    print('API Key: ${apiKey.isNotEmpty ? "Set" : "Not set"}');
    final url = Uri.parse('$baseUrl/verify/$email');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'API_KEY': apiKey,
      },
      body: jsonEncode({
        'code': code,
      }),
    );
    print(response.body);
    return response;
  }

  static Future<http.Response> loginUser({
    required String email,
    required String password,
  }) async {
    print('Connecting to: $baseUrl');
    print('API Key: ${apiKey.isNotEmpty ? "Set" : "Not set"}');
    final url = Uri.parse('$baseUrl/login');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'API_KEY': apiKey,
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );
    print(response.body);
    return response;
  }

  static Future<http.Response> listFiles({
    required String username,
    required String folderName,
    required String token,
  }) async {
    print('Connecting to: $baseUrl');
    print('API Key: ${apiKey.isNotEmpty ? "Set" : "Not set"}');
    final url = Uri.parse('$baseUrl/list_files');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'API_KEY': apiKey,
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'folder_name': folderName,
        'username': username,
      }),
    );
    print(response.body);
    return response;
  }

  static Future<http.Response> renameFile({
    required String oldFilename,
    required String newFilename,
    required String folderName,
    required String token,
  }) async {
    print('Connecting to: $baseUrl');
    print('API Key: ${apiKey.isNotEmpty ? "Set" : "Not set"}');
    final url = Uri.parse('$baseUrl/rename_file');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'API_KEY': apiKey,
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'old_filename': oldFilename,
        'new_filename': newFilename,
        'folder_name': folderName,
      }),
    );
    print("old: $oldFilename new: $newFilename path: $folderName");
    print(response.body);
    return response;
  }

  static Future<http.Response> listSharedFolder({
    required String folderPath,
    required String sharedBy,
    required String token,
  }) async {
    print('Connecting to: $baseUrl');
    print('API Key: ${apiKey.isNotEmpty ? "Set" : "Not set"}');
    final url = Uri.parse('$baseUrl/list_shared_folder');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'API_KEY': apiKey,
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'folder_path': folderPath,
        'shared_by': sharedBy,
      }),
    );
    print(response.body);
    return response;
  }

  static Future<http.Response> uploadFile({
    required String username,
    required String folderName,
    required String token,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    print('Connecting to: $baseUrl');
    print('API Key: ${apiKey.isNotEmpty ? "Set" : "Not set"}');
    print('File name: $fileName');
    
    final url = Uri.parse('$baseUrl/upload_file');
    
    // Tworzenie multipart request
    var request = http.MultipartRequest('POST', url);
    
    // Dodanie headers
    request.headers['API_KEY'] = apiKey;
    request.headers['Authorization'] = 'Bearer $token';
    
    // Dodanie folder info jako form field
    request.fields['folder_info'] = jsonEncode({'folder': folderName});
    
    // Dodanie pliku
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
      ),
    );
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    print(response.body);
    return response;
  }

  static Future<http.Response> createFolder({
    required String username,
    required String folderName,
    required String token,
  }) async {
    print('Connecting to: $baseUrl');
    print('API Key: ${apiKey.isNotEmpty ? "Set" : "Not set"}');
    
    final url = Uri.parse('$baseUrl/create_folder');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'API_KEY': apiKey,
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'folder_name': folderName,
        'username': username,
      }),
    );
    
    print(response.body);
    return response;
  }

  static Future<http.Response> deleteAccount({
    required String email,
  }) async {
    print('Connecting to: $baseUrl');
    print('API Key: ${apiKey.isNotEmpty ? 'set' : ' Not set'}');

    final url = Uri.parse('$baseUrl/delete_account');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'API_KEY': apiKey
      },
      body: jsonEncode({
        'email': email,
      }),
    );

    print(response.body);
    return response;
  }

  static Future<http.Response> confirmDelete({
    required String token,
  }) async {
    print('Connecting to: $baseUrl');
    print('API Key: ${apiKey.isNotEmpty ? "Set" : "Not set"}');
    
    final url = Uri.parse('$baseUrl/confirm_delete');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'API_KEY': apiKey,
      },
      body: jsonEncode({
        'token': token,
      }),
    );
    
    print(response.body);
    return response;
  }

  static Future<http.Response> validateDeleteToken({
    required String token,
  }) async {
    print('Connecting to: $baseUrl');
    print('API Key: ${apiKey.isNotEmpty ? "Set" : "Not set"}');
    
    final url = Uri.parse('$baseUrl/delete-password?token=$token');
    
    final response = await http.get(
      url,
      headers: {
        'API_KEY': apiKey,
      },
    );
    
    print(response.body);
    return response;
  }

  static Future<http.Response> resetPassword({
    required String email,
  }) async {
    print('Connecting to: $baseUrl');
    print('API Key: ${apiKey.isNotEmpty ? "Set" : "Not set"}');
    
    final url = Uri.parse('$baseUrl/reset_password');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'API_KEY': apiKey,
      },
      body: jsonEncode({
        'email': email,
      }),
    );
    
    print(response.body);
    return response;
  }

  static Future<http.Response> confirmReset({
    required String token,
    required String newPassword,
  }) async {
    print('Connecting to: $baseUrl');
    print('API Key: ${apiKey.isNotEmpty ? "Set" : "Not set"}');
    
    final url = Uri.parse('$baseUrl/confirm_reset');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'API_KEY': apiKey,
      },
      body: jsonEncode({
        'token': token,
        'new_password': newPassword,
      }),
    );
    
    print(response.body);
    return response;
  }

  static Future<http.Response> validateResetToken({
    required String token,
  }) async {
    print('Connecting to: $baseUrl');
    print('API Key: ${apiKey.isNotEmpty ? "Set" : "Not set"}');
    
    final url = Uri.parse('$baseUrl/reset-password?token=$token');
    
    final response = await http.get(
      url,
      headers: {
        'API_KEY': apiKey,
      },
    );
    
    print(response.body);
    return response;
  }

  static Future<http.Response> validateToken({
    required String token,
  }) async {
    print('Connecting to: $baseUrl');
    print('API Key: ${apiKey.isNotEmpty ? "Set" : "Not set"}');
    
    final url = Uri.parse('$baseUrl/validate_token');
    
    final response = await http.get(
      url,
      headers: {
        'API_KEY': apiKey,
        'Authorization': 'Bearer $token',
      },
    );
    
    print(response.body);
    return response;
  }

  static Future<http.Response> toggleFavorite({
    required String filename,
    required String folderName,
    required String token,
  }) async {
    print('Connecting to: $baseUrl');
    print('API Key: ${apiKey.isNotEmpty ? "Set" : "Not set"}');
    
    final url = Uri.parse('$baseUrl/toggle_favorite');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'API_KEY': apiKey,
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'filename': filename,
        'folder_name': folderName,
      }),
    );
    
    print(response.body);
    return response;
  }

  static Future<http.Response> getFavorites({
    required String token,
  }) async {
    return await http.get(
      Uri.parse('$baseUrl/get_favorites'),
      headers: {
        'Authorization': 'Bearer $token',
        'API_KEY': apiKey,
      },
    );
  }

  static Future<http.Response> deleteFile({
    required String token,
    required String filePath,
  }) async {
    return await http.delete(
      Uri.parse('$baseUrl/delete_file/$filePath'),
      headers: {
        'Authorization': 'Bearer $token',
        'API_KEY': apiKey,
      },
    );
  }

  static Future<http.Response> downloadFile({
    required String token,
    required String filePath,
  }) async {
    return await http.get(
      Uri.parse('$baseUrl/download_file/$filePath'),
      headers: {
        'Authorization': 'Bearer $token',
        'API_KEY': apiKey,
      },
    );
  }

  static Future<http.Response> downloadFilesAsZip({
    required String token,
    required List<String> filePaths,
  }) async {
    return await http.post(
      Uri.parse('$baseUrl/download_files_as_zip'),
      headers: {
        'Authorization': 'Bearer $token',
        'API_KEY': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'file_paths': filePaths,
      }),
    );
  }

  static Future<http.Response> cleanupZip({
    required String token,
    required String zipFilename,
  }) async {
    return await http.post(
      Uri.parse('$baseUrl/cleanup_zip'),
      headers: {
        'Authorization': 'Bearer $token',
        'API_KEY': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'zip_filename': zipFilename,
      }),
    );
  }

  static Future<http.Response> createQuickShare({
    required String token,
    required String filePath,
  }) async {
    return await http.post(
      Uri.parse('$baseUrl/create_quick_share'),
      headers: {
        'Authorization': 'Bearer $token',
        'API_KEY': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'file_path': filePath,
      }),
    );
  }

  static Future<http.Response> moveFile({
    required String token,
    required String sourcePath,
    required String destinationFolder,
  }) async {
    return await http.post(
      Uri.parse('$baseUrl/move_file'),
      headers: {
        'Authorization': 'Bearer $token',
        'API_KEY': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'source_path': sourcePath,
        'destination_folder': destinationFolder,
      }),
    );
  }

  static Future<http.Response> shareFile({
    required String token,
    required String filename,
    required String folderName,
    required String shareWith,
  }) async {
    return await http.post(
      Uri.parse('$baseUrl/share_file'),
      headers: {
        'Authorization': 'Bearer $token',
        'API_KEY': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'filename': filename,
        'folder_name': folderName,
        'share_with': shareWith,
      }),
    );
  }

  static Future<http.Response> getSharedFiles({
    required String token,
  }) async {
    return await http.get(
      Uri.parse('$baseUrl/get_shared_files'),
      headers: {
        'Authorization': 'Bearer $token',
        'API_KEY': apiKey,
      },
    );
  }

  static Future<http.Response> shareFolder({
    required String token,
    required String folderPath,
    required String shareWith,
  }) async {
    return await http.post(
      Uri.parse('$baseUrl/share_folder'),
      headers: {
        'Authorization': 'Bearer $token',
        'API_KEY': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'folder_path': folderPath,
        'share_with': shareWith,
      }),
    );
  }

  static Future<http.Response> getSharedFolders({
    required String token,
  }) async {
    return await http.get(
      Uri.parse('$baseUrl/get_shared_folders'),
      headers: {
        'Authorization': 'Bearer $token',
        'API_KEY': apiKey,
      },
    );
  }

  static Future<http.Response> getMySharedFiles({
    required String token,
  }) async {
    final url = Uri.parse('$baseUrl/get_my_shared_files');
    
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'API_KEY': apiKey,
      },
    );
    
    return response;
  }

  static Future<http.Response> getMySharedFolders({
    required String token,
  }) async {
    final url = Uri.parse('$baseUrl/get_my_shared_folders');
    
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'API_KEY': apiKey,
      },
    );
    
    return response;
  }

  static Future<http.Response> unshareFile({
    required String token,
    required String filename,
    required String folderName,
    required String sharedWith,
  }) async {
    return await http.post(
      Uri.parse('$baseUrl/unshare_file'),
      headers: {
        'Authorization': 'Bearer $token',
        'API_KEY': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'filename': filename,
        'folder_name': folderName,
        'shared_with': sharedWith,
      }),
    );
  }

  static Future<http.Response> unshareFolder({
    required String token,
    required String folderPath,
    required String sharedWith,
  }) async {
    return await http.post(
      Uri.parse('$baseUrl/unshare_folder'),
      headers: {
        'Authorization': 'Bearer $token',
        'API_KEY': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'folder_path': folderPath,
        'shared_with': sharedWith,
      }),
    );
  }

  /// Tworzy nową grupę użytkowników
  static Future<http.Response> createGroup({
    required String name,
    String? description,
    required String token,
  }) async {
    final url = Uri.parse('$baseUrl/groups/create');
    
    return await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'API_KEY': apiKey,
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'description': description,
      }),
    );
  }

  /// Dodaje użytkownika do grupy (po nazwie użytkownika lub emailu)
  static Future<http.Response> addGroupMember({
    required String groupName,
    required String userIdentifier, // username or email
    bool isAdmin = false,
    required String token,
  }) async {
    final url = Uri.parse('$baseUrl/groups/add_member');
    
    return await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'API_KEY': apiKey,
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'group_name': groupName,
        'user_identifier': userIdentifier,
        'is_admin': isAdmin,
      }),
    );
  }

  /// Usuwa użytkownika z grupy
  static Future<http.Response> removeGroupMember({
    required String groupName,
    required String username,
    required String token,
  }) async {
    final url = Uri.parse('$baseUrl/groups/remove_member');
    
    return await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'API_KEY': apiKey,
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'group_name': groupName,
        'username': username,
      }),
    );
  }

  /// Pobiera listę grup użytkownika
  static Future<http.Response> listGroups({
    required String token,
  }) async {
    final url = Uri.parse('$baseUrl/groups/list');
    
    return await http.get(
      url,
      headers: {
        'API_KEY': apiKey,
        'Authorization': 'Bearer $token',
      },
    );
  }

  /// Pobiera listę członków grupy
  static Future<http.Response> listGroupMembers({
    required String groupName,
    required String token,
  }) async {
    final url = Uri.parse('$baseUrl/groups/$groupName/members');
    
    return await http.get(
      url,
      headers: {
        'API_KEY': apiKey,
        'Authorization': 'Bearer $token',
      },
    );
  }

  /// Udostępnia plik grupie
  static Future<http.Response> shareFileWithGroup({
    required String filename,
    required String folderName,
    required String groupName,
    required String token,
  }) async {
    final url = Uri.parse('$baseUrl/groups/share_file');
    
    return await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'API_KEY': apiKey,
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'filename': filename,
        'folder_name': folderName,
        'group_name': groupName,
      }),
    );
  }

  /// Udostępnia folder grupie
  static Future<http.Response> shareFolderWithGroup({
    required String folderPath,
    required String groupName,
    required String token,
  }) async {
    final url = Uri.parse('$baseUrl/groups/share_folder');
    
    return await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'API_KEY': apiKey,
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'folder_path': folderPath,
        'group_name': groupName,
      }),
    );
  }

  /// Pobiera pliki udostępnione z grupami (przez użytkownika)
  static Future<http.Response> getGroupSharedFiles({
    required String token,
  }) async {
    final url = Uri.parse('$baseUrl/groups/my_shared_files');
    
    final response = await http.get(
      url,
      headers: {
        'API_KEY': apiKey,
        'Authorization': 'Bearer $token',
      },
    );
    
    return response;
  }

  /// Pobiera foldery udostępnione z grupami (przez użytkownika)
  static Future<http.Response> getGroupSharedFolders({
    required String token,
  }) async {
    final url = Uri.parse('$baseUrl/groups/my_shared_folders');
    
    final response = await http.get(
      url,
      headers: {
        'API_KEY': apiKey,
        'Authorization': 'Bearer $token',
      },
    );
    
    return response;
  }

  /// Pobiera pliki udostępnione użytkownikowi przez grupy
  static Future<http.Response> getFilesSharedWithMeByGroups({
    required String token,
  }) async {
    final url = Uri.parse('$baseUrl/groups/shared_files');
    
    final response = await http.get(
      url,
      headers: {
        'API_KEY': apiKey,
        'Authorization': 'Bearer $token',
      },
    );
    
    return response;
  }

  /// Pobiera foldery udostępnione użytkownikowi przez grupy
  static Future<http.Response> getFoldersSharedWithMeByGroups({
    required String token,
  }) async {
    final url = Uri.parse('$baseUrl/groups/shared_folders');
    
    final response = await http.get(
      url,
      headers: {
        'API_KEY': apiKey,
        'Authorization': 'Bearer $token',
      },
    );
    
    return response;
  }

  /// Odusunięcie udostępnienia pliku z grupy
  static Future<http.Response> unshareFileFromGroup({
    required String filename,
    required String folderName,
    required String groupName,
    required String token,
  }) async {
    final url = Uri.parse('$baseUrl/groups/unshare_file');
    
    return await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'API_KEY': apiKey,
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'filename': filename,
        'folder_name': folderName,
        'group_name': groupName,
      }),
    );
  }

  /// Odusunięcie udostępnienia folderu z grupy
  static Future<http.Response> unshareFolderFromGroup({
    required String folderPath,
    required String groupName,
    required String token,
  }) async {
    final url = Uri.parse('$baseUrl/groups/unshare_folder');
    
    return await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'API_KEY': apiKey,
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'folder_path': folderPath,
        'group_name': groupName,
      }),
    );
  }
}