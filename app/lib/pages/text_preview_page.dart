import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/file_item.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class TextPreviewPage extends StatefulWidget {
  final FileItem file;

  const TextPreviewPage({super.key, required this.file});

  @override
  State<TextPreviewPage> createState() => _TextPreviewPageState();
}

class _TextPreviewPageState extends State<TextPreviewPage> {
  String? _content;
  bool _isLoading = true;
  String? _error;
  double _fontSize = 14.0;
  bool _wordWrap = true;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
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

      String content;
      try {
        content = utf8.decode(bytes);
      } catch (_) {
        content = latin1.decode(bytes);
      }

      if (mounted) {
        setState(() {
          _content = content;
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

  void _increaseFontSize() {
    setState(() {
      _fontSize = (_fontSize + 2).clamp(10.0, 32.0);
    });
  }

  void _decreaseFontSize() {
    setState(() {
      _fontSize = (_fontSize - 2).clamp(10.0, 32.0);
    });
  }

  void _toggleWordWrap() {
    setState(() {
      _wordWrap = !_wordWrap;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D2D),
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
            if (_content != null)
              Text(
                '${_content!.split('\n').length} lines',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_decrease, color: Colors.white),
            onPressed: _decreaseFontSize,
            tooltip: 'Decrease font size',
          ),
          IconButton(
            icon: const Icon(Icons.text_increase, color: Colors.white),
            onPressed: _increaseFontSize,
            tooltip: 'Increase font size',
          ),
          IconButton(
            icon: Icon(
              _wordWrap ? Icons.wrap_text : Icons.notes,
              color: Colors.white,
            ),
            onPressed: _toggleWordWrap,
            tooltip: _wordWrap ? 'No wrap' : 'Word wrap',
          ),
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
              'Error loading file',
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
                _loadContent();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Container(
      color: const Color(0xFF1E1E1E),
      child: Scrollbar(
        child:
            _wordWrap
                ? SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    _content ?? '',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: _fontSize,
                      color: Colors.grey[300],
                      height: 1.5,
                    ),
                  ),
                )
                : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      _content ?? '',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: _fontSize,
                        color: Colors.grey[300],
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
      ),
    );
  }
}
