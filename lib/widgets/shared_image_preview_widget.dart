import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/api_service.dart';
import '../utils/token_service.dart';
import '../utils/cache_service.dart';

class SharedImagePreviewWidget extends StatelessWidget {
  final String filename;
  final String folderName;
  final String sharedBy;
  final double width;
  final double height;
  final bool showFullScreenOnTap;
  final BoxFit fit;

  const SharedImagePreviewWidget({
    Key? key,
    required this.filename,
    required this.folderName,
    required this.sharedBy,
    this.width = 100,
    this.height = 100,
    this.showFullScreenOnTap = true,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  String get _imageUrl => '${ApiService.baseUrl}/files/${sharedBy}/${folderName}/${filename}?webp=true&max_width=800';

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
        builder: (context) => SharedFullScreenImageView(
          imageUrl: _imageUrl,
          filename: filename,
        ),
      ),
    );
  }
}

class SharedFullScreenImageView extends StatelessWidget {
  final String imageUrl;
  final String filename;

  const SharedFullScreenImageView({
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
                return PhotoView(
                  imageProvider: FileImage(File(cachedPath)),
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
              } else {
                return _buildGalleryNetworkImage(token, imageUrl);
              }
            },
          );
        },
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

  void _downloadImage(BuildContext context) {
    // Implementacja pobierania obrazu
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Funkcja pobierania będzie dostępna wkrótce'),
      ),
    );
  }
} 