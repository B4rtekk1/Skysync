import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/api_service.dart';
import '../utils/token_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TextPreviewWidget extends StatelessWidget {
  final String filename;
  final String folderName;
  final double width;
  final double height;
  final bool showFullScreenOnTap;
  final BoxFit fit;

  const TextPreviewWidget({
    Key? key,
    required this.filename,
    required this.folderName,
    this.width = 100,
    this.height = 100,
    this.showFullScreenOnTap = true,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  String get _previewUrl => '${ApiService.baseUrl}/files/${folderName}/${filename}?preview=true';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: showFullScreenOnTap ? () => _showFullScreen(context) : null,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: FutureBuilder<String?>(
            future: TokenService.getToken(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildPlaceholder();
              }
              
              final token = snapshot.data;
              if (token == null) {
                return _buildErrorWidget();
              }
              
              return FutureBuilder<Map<String, dynamic>>(
                future: _fetchTextContent(token),
                builder: (context, textSnapshot) {
                  if (textSnapshot.connectionState == ConnectionState.waiting) {
                    return _buildPlaceholder();
                  }
                  
                  if (textSnapshot.hasError || !textSnapshot.hasData) {
                    return _buildErrorWidget();
                  }
                  
                  final data = textSnapshot.data!;
                  final content = data['content'] as String;
                  final truncated = data['truncated'] as bool;
                  
                  return Container(
                    color: Colors.grey[50],
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                              content,
                              style: const TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                                color: Colors.black87,
                              ),
                              maxLines: null,
                            ),
                          ),
                        ),
                        if (truncated)
                          const Text(
                            '... (plik został obcięty)',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _fetchTextContent(String token) async {
    final response = await http.get(
      Uri.parse(_previewUrl),
      headers: {
        'API_KEY': ApiService.apiKey,
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load text content');
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(
          Icons.description,
          color: Colors.grey,
          size: 32,
        ),
      ),
    );
  }

  void _showFullScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenTextView(
          filename: filename,
          folderName: folderName,
        ),
      ),
    );
  }
}

class FullScreenTextView extends StatelessWidget {
  final String filename;
  final String folderName;

  const FullScreenTextView({
    Key? key,
    required this.filename,
    required this.folderName,
  }) : super(key: key);

  String get _previewUrl => '${ApiService.baseUrl}/files/${folderName}/${filename}?preview=true';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.grey[800],
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          filename,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _downloadFile(context),
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () => _copyToClipboard(context),
          ),
        ],
      ),
      body: FutureBuilder<String?>(
        future: TokenService.getToken(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          
          final token = snapshot.data;
          if (token == null) {
            return const Center(
              child: Text(
                'Błąd autoryzacji',
                style: TextStyle(color: Colors.red),
              ),
            );
          }
          
          return FutureBuilder<Map<String, dynamic>>(
            future: _fetchTextContent(token),
            builder: (context, textSnapshot) {
              if (textSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
              
              if (textSnapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error,
                        color: Colors.red,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Nie można załadować pliku',
                        style: TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Błąd: ${textSnapshot.error}',
                        style: const TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }
              
              if (!textSnapshot.hasData) {
                return const Center(
                  child: Text(
                    'Brak danych',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }
              
              final data = textSnapshot.data!;
              final content = data['content'] as String;
              final truncated = data['truncated'] as bool;
              final size = data['size'] as int;
              
              return Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header z informacjami o pliku
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.description, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  filename,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Rozmiar: ${_formatFileSize(size)}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (truncated)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'OBCIĘTY',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Zawartość pliku
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            content,
                            style: const TextStyle(
                              fontSize: 14,
                              fontFamily: 'monospace',
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _fetchTextContent(String token) async {
    final response = await http.get(
      Uri.parse(_previewUrl),
      headers: {
        'API_KEY': ApiService.apiKey,
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load text content: ${response.statusCode}');
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _downloadFile(BuildContext context) {
    // TODO: Implementacja pobierania pliku
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Funkcja pobierania będzie dostępna wkrótce'),
      ),
    );
  }

  void _copyToClipboard(BuildContext context) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Błąd autoryzacji'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final response = await http.get(
        Uri.parse(_previewUrl),
        headers: {
          'API_KEY': ApiService.apiKey,
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['content'] as String;
        
        await Clipboard.setData(ClipboardData(text: content));
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Zawartość skopiowana do schowka'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to load content');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Błąd: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 