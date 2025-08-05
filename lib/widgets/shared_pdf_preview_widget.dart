import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../utils/api_service.dart';
import '../utils/token_service.dart';
import 'package:http/http.dart' as http;

class SharedPdfPreviewWidget extends StatelessWidget {
  final String filename;
  final String folderName;
  final String sharedBy;
  final double width;
  final double height;
  final bool showFullScreenOnTap;

  const SharedPdfPreviewWidget({
    Key? key,
    required this.filename,
    required this.folderName,
    required this.sharedBy,
    this.width = 100,
    this.height = 100,
    this.showFullScreenOnTap = true,
  }) : super(key: key);

  String get _pdfUrl => '${ApiService.baseUrl}/files/${sharedBy}/${folderName}/${filename}';

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
              
              return FutureBuilder<http.Response>(
                future: _checkPdfExists(token),
                builder: (context, responseSnapshot) {
                  if (responseSnapshot.connectionState == ConnectionState.waiting) {
                    return _buildPlaceholder();
                  }
                  
                  if (responseSnapshot.hasError || 
                      !responseSnapshot.hasData || 
                      responseSnapshot.data!.statusCode != 200) {
                    return _buildErrorWidget();
                  }
                  
                  return Container(
                    color: Colors.grey[50],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.picture_as_pdf,
                          size: 32,
                          color: Colors.red[600],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          filename,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kliknij, aby otworzyć',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.grey[600],
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

  Future<http.Response> _checkPdfExists(String token) async {
    return await http.head(
      Uri.parse(_pdfUrl),
      headers: {
        'API_KEY': ApiService.apiKey,
        'Authorization': 'Bearer $token',
      },
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
        builder: (context) => SharedFullScreenPdfView(
          filename: filename,
          folderName: folderName,
          sharedBy: sharedBy,
        ),
      ),
    );
  }
}

class SharedFullScreenPdfView extends StatefulWidget {
  final String filename;
  final String folderName;
  final String sharedBy;

  const SharedFullScreenPdfView({
    Key? key,
    required this.filename,
    required this.folderName,
    required this.sharedBy,
  }) : super(key: key);

  @override
  State<SharedFullScreenPdfView> createState() => _SharedFullScreenPdfViewState();
}

class _SharedFullScreenPdfViewState extends State<SharedFullScreenPdfView> {
  String? pdfUrl;
  bool isLoading = true;
  String? errorMessage;

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

      final url = '${ApiService.baseUrl}/files/${widget.sharedBy}/${widget.folderName}/${widget.filename}';
      
      // Sprawdź czy plik istnieje
      final response = await http.head(
        Uri.parse(url),
        headers: {
          'API_KEY': ApiService.apiKey,
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          pdfUrl = url;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Nie można załadować pliku PDF';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Błąd: ${e.toString()}';
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
            onPressed: () => _downloadPdf(context),
          ),
        ],
      ),
      body: FutureBuilder<String?>(
        future: TokenService.getToken(),
        builder: (context, tokenSnapshot) {
          if (tokenSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          
          final token = tokenSnapshot.data;
          if (token == null) {
            return const Center(
              child: Text('Błąd autoryzacji'),
            );
          }
          
          if (isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          
          if (errorMessage != null) {
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
                  Text(
                    errorMessage!,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        isLoading = true;
                        errorMessage = null;
                      });
                      _loadPdfUrl();
                    },
                    child: const Text('Spróbuj ponownie'),
                  ),
                ],
              ),
            );
          }
          
          if (pdfUrl == null) {
            return const Center(
              child: Text('Nie można załadować pliku PDF'),
            );
          }
          
          return SfPdfViewer.network(
            pdfUrl!,
            headers: {
              'API_KEY': ApiService.apiKey,
              'Authorization': 'Bearer $token',
            },
          );
        },
      ),
    );
  }

  void _downloadPdf(BuildContext context) {
    // Implementacja pobierania PDF
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Funkcja pobierania będzie dostępna wkrótce'),
      ),
    );
  }
} 