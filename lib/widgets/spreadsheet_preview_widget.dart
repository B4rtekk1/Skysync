import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import '../utils/api_service.dart';
import '../utils/token_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SpreadsheetPreviewWidget extends StatelessWidget {
  final String filename;
  final String folderName;
  final double width;
  final double height;
  final bool showFullScreenOnTap;
  final BoxFit fit;

  const SpreadsheetPreviewWidget({
    Key? key,
    required this.filename,
    required this.folderName,
    this.width = 100,
    this.height = 100,
    this.showFullScreenOnTap = true,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  String get _downloadUrl => '${ApiService.baseUrl}/download_file/${folderName}/${filename}';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: showFullScreenOnTap ? () => _openInExternalApp(context) : null,
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
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.table_chart,
                  size: width * 0.4,
                  color: Colors.grey[600],
                ),
                const SizedBox(height: 4),
                Text(
                  'Kliknij aby otworzyć',
                  style: TextStyle(
                    fontSize: width * 0.08,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  filename,
                  style: TextStyle(
                    fontSize: width * 0.06,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openInExternalApp(BuildContext context) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        _showError(context, 'Błąd autoryzacji');
        return;
      }

      // Pokaż loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Pobieranie pliku...'),
              ],
            ),
          );
        },
      );

      // Pobierz plik
      final response = await http.get(
        Uri.parse(_downloadUrl),
        headers: {
          'API_KEY': ApiService.apiKey,
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Zapisz plik lokalnie
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/$filename');
        await file.writeAsBytes(response.bodyBytes);

        // Zamknij loading dialog
        Navigator.of(context).pop();

        // Otwórz plik w zewnętrznej aplikacji
        final result = await OpenFile.open(file.path);
        if (result.type != ResultType.done) {
          _showError(context, 'Nie można otworzyć pliku: ${result.message}');
        }
      } else {
        // Zamknij loading dialog
        Navigator.of(context).pop();
        _showError(context, 'Błąd pobierania pliku: ${response.statusCode}');
      }
    } catch (e) {
      // Zamknij loading dialog jeśli jest otwarty
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      _showError(context, 'Błąd: $e');
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

class FullScreenSpreadsheetView extends StatefulWidget {
  final String filename;
  final String folderName;

  const FullScreenSpreadsheetView({
    Key? key,
    required this.filename,
    required this.folderName,
  }) : super(key: key);

  @override
  State<FullScreenSpreadsheetView> createState() => _FullScreenSpreadsheetViewState();
}

class _FullScreenSpreadsheetViewState extends State<FullScreenSpreadsheetView> {
  bool isLoading = false;

  String get _downloadUrl => '${ApiService.baseUrl}/download_file/${widget.folderName}/${widget.filename}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.grey[800],
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.filename,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: _openInExternalApp,
            tooltip: 'Otwórz w zewnętrznej aplikacji',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.table_chart,
              size: 120,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Plik arkusza kalkulacyjnego',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.filename,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: isLoading ? null : _openInExternalApp,
              icon: isLoading 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.open_in_new),
              label: Text(isLoading ? 'Otwieranie...' : 'Otwórz w zewnętrznej aplikacji'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Plik zostanie otwarty w aplikacji\nobsługującej pliki ${_getFileExtension()}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getFileExtension() {
    final extension = widget.filename.split('.').last.toLowerCase();
    switch (extension) {
      case 'csv':
        return 'CSV';
      case 'xlsx':
      case 'xls':
        return 'Excel';
      case 'ods':
        return 'OpenDocument';
      default:
        return extension.toUpperCase();
    }
  }

  Future<void> _openInExternalApp() async {
    setState(() {
      isLoading = true;
    });

    try {
      final token = await TokenService.getToken();
      if (token == null) {
        _showError('Błąd autoryzacji');
        return;
      }

      // Pobierz plik
      final response = await http.get(
        Uri.parse(_downloadUrl),
        headers: {
          'API_KEY': ApiService.apiKey,
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Zapisz plik lokalnie
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/${widget.filename}');
        await file.writeAsBytes(response.bodyBytes);

        // Otwórz plik w zewnętrznej aplikacji
        final result = await OpenFile.open(file.path);
        if (result.type != ResultType.done) {
          _showError('Nie można otworzyć pliku: ${result.message}');
        }
      } else {
        _showError('Błąd pobierania pliku: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Błąd: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
} 