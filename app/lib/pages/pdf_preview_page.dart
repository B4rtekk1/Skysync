import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../models/file_item.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class PdfPreviewPage extends StatefulWidget {
  final FileItem file;

  const PdfPreviewPage({super.key, required this.file});

  @override
  State<PdfPreviewPage> createState() => _PdfPreviewPageState();
}

class _PdfPreviewPageState extends State<PdfPreviewPage> {
  Uint8List? _pdfBytes;
  bool _isLoading = true;
  String? _error;
  final PdfViewerController _pdfController = PdfViewerController();
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  Future<void> _loadPdf() async {
    if (widget.file.id == null) {
      setState(() {
        _error = 'Invalid file';
        _isLoading = false;
      });
      return;
    }

    try {
      final token = await AuthService().getToken();
      if (token == null) throw Exception('Not authenticated');

      final bytes = await ApiService().downloadFile(token, widget.file.id!);

      if (mounted) {
        setState(() {
          _pdfBytes = Uint8List.fromList(bytes);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _goToPage(int page) {
    if (page >= 1 && page <= _totalPages) {
      _pdfController.jumpToPage(page);
    }
  }

  void _showPageDialog() {
    final controller = TextEditingController(text: _currentPage.toString());

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Go to Page'),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter page number (1-$_totalPages)',
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final page = int.tryParse(controller.text);
                  if (page != null) {
                    _goToPage(page);
                  }
                  Navigator.pop(context);
                },
                child: const Text('Go'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.file.name,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
            if (_totalPages > 0)
              Text(
                'Page $_currentPage of $_totalPages',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
          ],
        ),
        actions: [
          if (_totalPages > 0) ...[
            IconButton(
              icon: const Icon(Icons.first_page, color: Colors.white),
              onPressed: _currentPage > 1 ? () => _goToPage(1) : null,
              tooltip: 'First page',
            ),
            IconButton(
              icon: const Icon(Icons.navigate_before, color: Colors.white),
              onPressed:
                  _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
              tooltip: 'Previous page',
            ),
            GestureDetector(
              onTap: _showPageDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.navigate_next, color: Colors.white),
              onPressed:
                  _currentPage < _totalPages
                      ? () => _goToPage(_currentPage + 1)
                      : null,
              tooltip: 'Next page',
            ),
            IconButton(
              icon: const Icon(Icons.last_page, color: Colors.white),
              onPressed:
                  _currentPage < _totalPages
                      ? () => _goToPage(_totalPages)
                      : null,
              tooltip: 'Last page',
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text(
              'Loading ${widget.file.name}...',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error loading PDF',
              style: TextStyle(color: Colors.grey[300], fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadPdf();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_pdfBytes == null) {
      return const Center(
        child: Text('No PDF data', style: TextStyle(color: Colors.white70)),
      );
    }

    return SfPdfViewer.memory(
      _pdfBytes!,
      controller: _pdfController,
      canShowScrollHead: true,
      canShowScrollStatus: true,
      enableDoubleTapZooming: true,
      onDocumentLoaded: (details) {
        setState(() {
          _totalPages = details.document.pages.count;
        });
      },
      onPageChanged: (details) {
        setState(() {
          _currentPage = details.newPageNumber;
        });
      },
    );
  }
}
