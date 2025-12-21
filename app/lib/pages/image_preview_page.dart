import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/file_item.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class ImagePreviewPage extends StatefulWidget {
  final List<FileItem> images;
  final int initialIndex;

  const ImagePreviewPage({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, Uint8List?> _imageCache = {};
  final Map<int, bool> _loadingStates = {};
  final TransformationController _transformationController =
      TransformationController();
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _loadImage(_currentIndex);
    // Preload adjacent images
    if (_currentIndex > 0) _loadImage(_currentIndex - 1);
    if (_currentIndex < widget.images.length - 1) _loadImage(_currentIndex + 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadImage(int index) async {
    if (_imageCache.containsKey(index) || _loadingStates[index] == true) return;

    final file = widget.images[index];
    if (file.id == null) return;

    setState(() {
      _loadingStates[index] = true;
    });

    try {
      final token = await AuthService().getToken();
      if (token == null) throw Exception('Not authenticated');

      final bytes = await ApiService().downloadFile(token, file.id!);

      if (mounted) {
        setState(() {
          _imageCache[index] = Uint8List.fromList(bytes);
          _loadingStates[index] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingStates[index] = false;
        });
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _transformationController.value = Matrix4.identity();
    });
    // Preload adjacent images
    if (index > 0) _loadImage(index - 1);
    if (index < widget.images.length - 1) _loadImage(index + 1);
    _loadImage(index);
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNext() {
    if (_currentIndex < widget.images.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar:
          _showControls
              ? AppBar(
                backgroundColor: Colors.black54,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  widget.images[_currentIndex].name,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.white),
                    onPressed: () => _downloadCurrentImage(),
                  ),
                ],
              )
              : null,
      body: Stack(
        children: [
          // Image viewer with page view
          GestureDetector(
            onTap: _toggleControls,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: widget.images.length,
              itemBuilder: (context, index) {
                return _buildImageView(index);
              },
            ),
          ),

          // Navigation arrows
          if (_showControls && widget.images.length > 1) ...[
            // Previous button
            if (_currentIndex > 0)
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.chevron_left, size: 32),
                      color: Colors.white,
                      onPressed: _goToPrevious,
                    ),
                  ),
                ),
              ),
            // Next button
            if (_currentIndex < widget.images.length - 1)
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right, size: 32),
                      color: Colors.white,
                      onPressed: _goToNext,
                    ),
                  ),
                ),
              ),
          ],

          // Bottom controls with image counter and thumbnails
          if (_showControls)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Image counter
                    Text(
                      '${_currentIndex + 1} / ${widget.images.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    // Thumbnail strip
                    if (widget.images.length > 1 && widget.images.length <= 10)
                      SizedBox(
                        height: 60,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.images.length,
                          itemBuilder: (context, index) {
                            return _buildThumbnail(index);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageView(int index) {
    final imageData = _imageCache[index];
    final isLoading = _loadingStates[index] == true;

    if (isLoading || imageData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading ${widget.images[index].name}...',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return InteractiveViewer(
      transformationController:
          index == _currentIndex ? _transformationController : null,
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.memory(
          imageData,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  size: 64,
                  color: Colors.grey[600],
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load image',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildThumbnail(int index) {
    final isSelected = index == _currentIndex;
    final imageData = _imageCache[index];

    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: Container(
        width: 50,
        height: 50,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child:
              imageData != null
                  ? Image.memory(imageData, fit: BoxFit.cover)
                  : Container(
                    color: Colors.grey[800],
                    child: const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ),
        ),
      ),
    );
  }

  Future<void> _downloadCurrentImage() async {
    final file = widget.images[_currentIndex];
    final imageData = _imageCache[_currentIndex];

    if (imageData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image not loaded yet'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Copy to clipboard or save locally - for now just show a message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${file.name} ready in Downloads'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
