import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/api_service.dart';
import '../utils/token_service.dart';
import '../utils/cache_service.dart';

class ImagePreviewWidget extends StatelessWidget {
  final String filename;
  final String folderName;
  final double width;
  final double height;
  final bool showFullScreenOnTap;
  final BoxFit fit;

  const ImagePreviewWidget({
    Key? key,
    required this.filename,
    required this.folderName,
    this.width = 100,
    this.height = 100,
    this.showFullScreenOnTap = true,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  String get _imageUrl => '${ApiService.baseUrl}/files/${folderName}/${filename}?webp=true&max_width=800';

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
              
              return FutureBuilder<String?>(
                future: _getCachedImagePath(),
                builder: (context, cacheSnapshot) {
                  if (cacheSnapshot.connectionState == ConnectionState.waiting) {
                    return _buildPlaceholder();
                  }
                  
                  final cachedPath = cacheSnapshot.data;
                  if (cachedPath != null) {
                    // Użyj cache'owanego obrazu
                    return Image.file(
                      File(cachedPath),
                      fit: fit,
                      errorBuilder: (context, error, stackTrace) {
                        // Jeśli cache'owany plik jest uszkodzony, usuń go i pobierz ponownie
                        CacheService().clearImageCache(_imageUrl);
                        return _buildNetworkImage(token);
                      },
                    );
                  } else {
                    // Pobierz z sieci i cache'uj
                    return _buildNetworkImage(token);
                  }
                },
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
          Icons.broken_image,
          color: Colors.grey,
          size: 32,
        ),
      ),
    );
  }

  /// Pobiera ścieżkę cache'owanego obrazu
  Future<String?> _getCachedImagePath() async {
    return CacheService().getCachedImagePath(_imageUrl);
  }

  /// Buduje widget obrazu z sieci z cache'owaniem
  Widget _buildNetworkImage(String token) {
    return FutureBuilder<http.Response>(
      future: http.get(
        Uri.parse(_imageUrl),
        headers: {
          'API_KEY': ApiService.apiKey,
          'Authorization': 'Bearer $token',
        },
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildPlaceholder();
        }
        
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.statusCode != 200) {
          return _buildErrorWidget();
        }
        
        final response = snapshot.data!;
        final imageBytes = response.bodyBytes;
        
        // Cache'uj obraz
        CacheService().cacheImage(_imageUrl, imageBytes);
        
        return Image.memory(
          imageBytes,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
        );
      },
    );
  }

  void _showFullScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenImageView(
          imageUrl: _imageUrl,
          filename: filename,
        ),
      ),
    );
  }

  /// Buduje widget obrazu z sieci dla galerii z cache'owaniem
  Widget _buildGalleryNetworkImage(String token, String imageUrl) {
    return FutureBuilder<http.Response>(
      future: http.get(
        Uri.parse(imageUrl),
        headers: {
          'API_KEY': ApiService.apiKey,
          'Authorization': 'Bearer $token',
        },
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.statusCode != 200) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Nie można załadować obrazu',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        }
        
        final response = snapshot.data!;
        final imageBytes = response.bodyBytes;
        
        // Cache'uj obraz
        CacheService().cacheImage(imageUrl, imageBytes);
        
        return PhotoView(
          imageProvider: MemoryImage(imageBytes),
          loadingBuilder: (context, event) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          errorBuilder: (context, error, stackTrace) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Nie można załadować obrazu',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2.0,
          initialScale: PhotoViewComputedScale.contained,
          heroAttributes: PhotoViewHeroAttributes(tag: imageUrl),
        );
      },
    );
  }
}

class FullScreenImageView extends StatelessWidget {
  final String imageUrl;
  final String filename;

  const FullScreenImageView({
    Key? key,
    required this.imageUrl,
    required this.filename,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          filename,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _downloadImage(context),
          ),
        ],
      ),
      body: FutureBuilder<String?>(
        future: TokenService.getToken(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          
          final token = snapshot.data;
          if (token == null) {
            return const Center(
              child: Text(
                'Błąd autoryzacji',
                style: TextStyle(color: Colors.white),
              ),
            );
          }
          
          return FutureBuilder<String?>(
            future: Future.value(CacheService().getCachedImagePath(imageUrl)),
            builder: (context, cacheSnapshot) {
              if (cacheSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }
              
              final cachedPath = cacheSnapshot.data;
              if (cachedPath != null) {
                // Użyj cache'owanego obrazu
                return PhotoView(
                  imageProvider: FileImage(File(cachedPath)),
                  loadingBuilder: (context, event) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorBuilder: (context, error, stackTrace) {
                    // Jeśli cache'owany plik jest uszkodzony, usuń go i pobierz ponownie
                    CacheService().clearImageCache(imageUrl);
                    return _buildFullScreenNetworkImage(token);
                  },
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2.0,
                  initialScale: PhotoViewComputedScale.contained,
                  heroAttributes: PhotoViewHeroAttributes(tag: imageUrl),
                );
              } else {
                // Pobierz z sieci i cache'uj
                return _buildFullScreenNetworkImage(token);
              }
            },
          );
        },
      ),
    );
  }

  void _downloadImage(BuildContext context) {
    // Pobierz oryginalny plik (bez WebP)
    final originalImageUrl = imageUrl.replaceAll('?webp=true&max_width=1920', '');
    
    // TODO: Implementacja pobierania obrazu
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Funkcja pobierania będzie dostępna wkrótce'),
      ),
    );
  }

  /// Buduje widget obrazu z sieci dla pełnego ekranu z cache'owaniem
  Widget _buildFullScreenNetworkImage(String token) {
    return FutureBuilder<http.Response>(
      future: http.get(
        Uri.parse(imageUrl),
        headers: {
          'API_KEY': ApiService.apiKey,
          'Authorization': 'Bearer $token',
        },
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.statusCode != 200) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Nie można załadować obrazu',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        }
        
        final response = snapshot.data!;
        final imageBytes = response.bodyBytes;
        
        // Cache'uj obraz
        CacheService().cacheImage(imageUrl, imageBytes);
        
        return PhotoView(
          imageProvider: MemoryImage(imageBytes),
          loadingBuilder: (context, event) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          errorBuilder: (context, error, stackTrace) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Nie można załadować obrazu',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2.0,
          initialScale: PhotoViewComputedScale.contained,
          heroAttributes: PhotoViewHeroAttributes(tag: imageUrl),
        );
      },
    );
  }
}

class ImageGalleryView extends StatefulWidget {
  final List<Map<String, String>> images; // Lista map z 'filename' i 'folderName'
  final int initialIndex;

  const ImageGalleryView({
    Key? key,
    required this.images,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<ImageGalleryView> createState() => _ImageGalleryViewState();
}

class _ImageGalleryViewState extends State<ImageGalleryView> {
  late int _currentIndex;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  void _goToNext() {
    if (_currentIndex < widget.images.length - 1) {
      setState(() {
        _currentIndex++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentImage = widget.images[_currentIndex];
    final imageUrl = '${ApiService.baseUrl}/files/${currentImage['folderName']}/${currentImage['filename']}?webp=true&max_width=1920';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            switch (event.logicalKey) {
              case LogicalKeyboardKey.arrowLeft:
                _goToPrevious();
                return KeyEventResult.handled;
              case LogicalKeyboardKey.arrowRight:
                _goToNext();
                return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Stack(
          children: [
            // Główna zawartość galerii
            GestureDetector(
              onTap: () {
                _focusNode.requestFocus();
              },
              child: FutureBuilder<String?>(
                future: TokenService.getToken(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }
                  
                  final token = snapshot.data;
                  if (token == null) {
                    return const Center(
                      child: Text(
                        'Błąd autoryzacji',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }
                  
                  return FutureBuilder<String?>(
                    future: Future.value(CacheService().getCachedImagePath(imageUrl)),
                    builder: (context, cacheSnapshot) {
                      if (cacheSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      }
                      
                      final cachedPath = cacheSnapshot.data;
                      if (cachedPath != null) {
                        // Użyj cache'owanego obrazu
                        return PhotoView(
                          imageProvider: FileImage(File(cachedPath)),
                          loadingBuilder: (context, event) => const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          ),
                          errorBuilder: (context, error, stackTrace) {
                            // Jeśli cache'owany plik jest uszkodzony, usuń go i pobierz ponownie
                            CacheService().clearImageCache(imageUrl);
                            return _buildGalleryNetworkImage(token, imageUrl);
                          },
                          minScale: PhotoViewComputedScale.contained,
                          maxScale: PhotoViewComputedScale.covered * 2.0,
                          initialScale: PhotoViewComputedScale.contained,
                          heroAttributes: PhotoViewHeroAttributes(tag: imageUrl),
                        );
                      } else {
                        // Pobierz z sieci i cache'uj
                        return _buildGalleryNetworkImage(token, imageUrl);
                      }
                    },
                  );
                },
              ),
            ),
            
            // Strzałka w lewo
            if (_currentIndex > 0)
              Positioned(
                left: 20,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: IconButton(
                      onPressed: _goToPrevious,
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                        size: 30,
                      ),
                      iconSize: 30,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
              ),
            
            // Strzałka w prawo
            if (_currentIndex < widget.images.length - 1)
              Positioned(
                right: 20,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: IconButton(
                      onPressed: _goToNext,
                      icon: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 30,
                      ),
                      iconSize: 30,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
              ),
            
            // Wskaźnik pozycji na dole
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _currentIndex > 0 ? _goToPrevious : null,
                        icon: Icon(
                          Icons.arrow_back_ios,
                          color: _currentIndex > 0 ? Colors.white : Colors.grey,
                          size: 20,
                        ),
                        iconSize: 20,
                        padding: const EdgeInsets.all(4),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_currentIndex + 1} / ${widget.images.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _currentIndex < widget.images.length - 1 ? _goToNext : null,
                        icon: Icon(
                          Icons.arrow_forward_ios,
                          color: _currentIndex < widget.images.length - 1 ? Colors.white : Colors.grey,
                          size: 20,
                        ),
                        iconSize: 20,
                        padding: const EdgeInsets.all(4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Buduje widget obrazu z sieci dla galerii z cache'owaniem
  Widget _buildGalleryNetworkImage(String token, String imageUrl) {
    return FutureBuilder<http.Response>(
      future: http.get(
        Uri.parse(imageUrl),
        headers: {
          'API_KEY': ApiService.apiKey,
          'Authorization': 'Bearer $token',
        },
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.statusCode != 200) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Nie można załadować obrazu',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        }
        
        final response = snapshot.data!;
        final imageBytes = response.bodyBytes;
        
        // Cache'uj obraz
        CacheService().cacheImage(imageUrl, imageBytes);
        
        return PhotoView(
          imageProvider: MemoryImage(imageBytes),
          loadingBuilder: (context, event) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          errorBuilder: (context, error, stackTrace) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Nie można załadować obrazu',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2.0,
          initialScale: PhotoViewComputedScale.contained,
          heroAttributes: PhotoViewHeroAttributes(tag: imageUrl),
        );
      },
    );
  }
} 