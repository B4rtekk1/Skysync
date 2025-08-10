import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/api_service.dart';
import '../utils/token_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SharedTextPreviewWidget extends StatelessWidget {
  final String filename;
  final String folderName;
  final String sharedBy;
  final double width;
  final double height;
  final bool showFullScreenOnTap;
  final BoxFit fit;

  const SharedTextPreviewWidget({
    Key? key,
    required this.filename,
    required this.folderName,
    required this.sharedBy,
    this.width = 100,
    this.height = 100,
    this.showFullScreenOnTap = true,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  String get _previewUrl => '${ApiService.baseUrl}/files/${sharedBy}/${folderName}/${filename}?preview=true';

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
              color: Colors.black.withValues(alpha: 0.1),
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
        builder: (context) => SharedFullScreenTextView(
          filename: filename,
          folderName: folderName,
          sharedBy: sharedBy,
        ),
      ),
    );
  }
}

class SharedFullScreenTextView extends StatelessWidget {
  final String filename;
  final String folderName;
  final String sharedBy;

  const SharedFullScreenTextView({
    Key? key,
    required this.filename,
    required this.folderName,
    required this.sharedBy,
  }) : super(key: key);

  String get _previewUrl => '${ApiService.baseUrl}/files/${sharedBy}/${folderName}/${filename}?preview=true';

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
              child: Text('Błąd autoryzacji'),
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
              
              if (textSnapshot.hasError || !textSnapshot.hasData) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Nie można załadować zawartości pliku',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                );
              }
              
              final data = textSnapshot.data!;
              final content = data['content'] as String;
              final truncated = data['truncated'] as bool;
              
              return Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (truncated)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.orange.shade800,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Plik został obcięty dla podglądu. Pobierz pełną wersję, aby zobaczyć całą zawartość.',
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: SelectableText(
                          content,
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'monospace',
                            color: Colors.black87,
                            height: 1.5,
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
      throw Exception('Failed to load text content');
    }
  }

  void _downloadFile(BuildContext context) {
    // Implementacja pobierania pliku
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
          const SnackBar(content: Text('Błąd autoryzacji')),
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
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Zawartość skopiowana do schowka')),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nie można skopiować zawartości')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: ${e.toString()}')),
        );
      }
    }
  }
} 