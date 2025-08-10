import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../utils/api_service.dart';
import '../utils/token_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PdfPreviewWidget extends StatelessWidget {
  final String filename;
  final String folderName;
  final double width;
  final double height;
  final bool showFullScreenOnTap;
  final BoxFit fit;

  const PdfPreviewWidget({
    Key? key,
    required this.filename,
    required this.folderName,
    this.width = 100,
    this.height = 100,
    this.showFullScreenOnTap = true,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  String get _pdfUrl => '${ApiService.baseUrl}/files/${folderName}/${filename}';

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
              
              return Container(
                color: Colors.white,
                padding: const EdgeInsets.all(4.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.picture_as_pdf,
                      size: width * 0.3,
                      color: Colors.red[600],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PDF',
                      style: TextStyle(
                        fontSize: width * 0.08,
                        color: Colors.red[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      filename,
                      style: TextStyle(
                        fontSize: width * 0.06,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
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
          Icons.picture_as_pdf,
          color: Colors.grey,
          size: 32,
        ),
      ),
    );
  }

  void _showFullScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenPdfView(
          filename: filename,
          folderName: folderName,
        ),
      ),
    );
  }
}

class FullScreenPdfView extends StatefulWidget {
  final String filename;
  final String folderName;

  const FullScreenPdfView({
    Key? key,
    required this.filename,
    required this.folderName,
  }) : super(key: key);

  @override
  State<FullScreenPdfView> createState() => _FullScreenPdfViewState();
}

class _FullScreenPdfViewState extends State<FullScreenPdfView> {
  bool isLoading = true;
  String? errorMessage;
  String? pdfUrl;

  @override
  void initState() {
    super.initState();
    _loadPdfUrl();
  }

  Future<void> _loadPdfUrl() async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        setState(() {
          errorMessage = 'Błąd autoryzacji';
          isLoading = false;
        });
        return;
      }

      setState(() {
        pdfUrl = '${ApiService.baseUrl}/files/${widget.folderName}/${widget.filename}';
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Błąd: $e';
        isLoading = false;
      });
    }
  }

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
            icon: const Icon(Icons.download),
            onPressed: () {
              // TODO: Implementacja pobierania
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Funkcja pobierania będzie dostępna wkrótce'),
                ),
              );
            },
            tooltip: 'Pobierz',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'Błąd ładowania',
                        style: const TextStyle(color: Colors.red, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : FutureBuilder<String?>(
                  future: TokenService.getToken(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    final token = snapshot.data;
                    if (token == null) {
                      return const Center(
                        child: Text('Błąd autoryzacji'),
                      );
                    }
                    
                    return SfPdfViewer.network(
                      pdfUrl!,
                      headers: {
                        'API_KEY': ApiService.apiKey,
                        'Authorization': 'Bearer $token',
                      },
                      canShowPaginationDialog: true,
                      canShowScrollHead: true,
                      canShowScrollStatus: true,
                      enableDoubleTapZooming: true,
                      enableTextSelection: true,
                      enableDocumentLinkAnnotation: true,
                      enableHyperlinkNavigation: true,
                    );
                  },
                ),
    );
  }
} 