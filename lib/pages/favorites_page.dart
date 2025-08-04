import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import '../utils/custom_widgets.dart';
import '../utils/api_service.dart';
import '../utils/token_service.dart';
import '../utils/activity_service.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'name'; // 'name', 'date', 'size', 'type'
  bool _isGridView = false;
  bool _isLoading = true;
  String? _errorMessage;
  String _username = 'loading';

  // Dane ulubionych plików z serwera
  List<FavoriteFile> _favorites = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadFavorites();
  }

  Future<void> _loadUserData() async {
    final username = await TokenService.getUsername();
    setState(() {
      _username = username ?? 'unknown';
    });
  }

  void _showSessionExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return SessionExpiredDialog(
          onLogin: () {
            Navigator.pushReplacementNamed(context, '/login');
          },
        );
      },
    );
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await TokenService.getToken();
      
      if (token == null) {
        setState(() {
          _errorMessage = 'favorites.not_logged_in'.tr();
          _isLoading = false;
        });
        _showSessionExpiredDialog();
        return;
      }

      final response = await ApiService.getFavorites(token: token);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final favoritesData = data['favorites'] as List;
        
        setState(() {
          _favorites = favoritesData.map((fileData) {
            final filename = fileData['filename'] as String;
            final sizeBytes = fileData['size_bytes'] as int;
            final modificationDate = fileData['modification_date'] as String;
            final favoritedAt = fileData['favorited_at'] as String;
            final folderName = fileData['folder_name'] as String;
            
            return FavoriteFile(
              name: filename,
              size: _formatFileSize(sizeBytes),
              date: _formatDate(modificationDate),
              favoritedDate: _formatDate(favoritedAt),
              type: _getFileType(filename),
              folderName: folderName,
            );
          }).toList();
          _isLoading = false;
        });
      } else {
        // Sprawdź czy to błąd wygasłego tokenu
        if (response.body.toLowerCase().contains('token expired') || 
            response.body.toLowerCase().contains('unauthorized') ||
            response.statusCode == 401) {
          setState(() {
            _isLoading = false;
          });
          _showSessionExpiredDialog();
        } else {
          setState(() {
            _errorMessage = 'Failed to load favorites: ${response.body}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
    } catch (e) {
      return isoDate;
    }
  }

  String _getFileType(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'pdf';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
        return 'image';
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'wmv':
        return 'video';
      case 'ppt':
      case 'pptx':
        return 'presentation';
      case 'xls':
      case 'xlsx':
        return 'spreadsheet';
      case 'doc':
      case 'docx':
        return 'document';
      case 'txt':
        return 'text';
      default:
        return 'file';
    }
  }

  IconData _getFileIcon(String type) {
    switch (type) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.video_file;
      case 'presentation':
        return Icons.slideshow;
      case 'spreadsheet':
        return Icons.table_chart;
      case 'document':
        return Icons.description;
      case 'text':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String type) {
    switch (type) {
      case 'pdf':
        return Colors.red;
      case 'image':
        return Colors.green;
      case 'video':
        return Colors.purple;
      case 'presentation':
        return Colors.orange;
      case 'spreadsheet':
        return Colors.green;
      case 'document':
        return Colors.blue;
      case 'text':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  List<FavoriteFile> get _filteredFiles {
    List<FavoriteFile> filtered = _favorites.where((file) =>
        file.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    // Sortowanie
    switch (_sortBy) {
      case 'name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'date':
        filtered.sort((a, b) => b.date.compareTo(a.date));
        break;
      case 'size':
        filtered.sort((a, b) => _parseSize(b.size).compareTo(_parseSize(a.size)));
        break;
      case 'type':
        filtered.sort((a, b) => a.type.compareTo(b.type));
        break;
    }

    return filtered;
  }

  double _parseSize(String size) {
    if (size.contains('MB')) {
      return double.parse(size.replaceAll(' MB', ''));
    } else if (size.contains('KB')) {
      return double.parse(size.replaceAll(' KB', '')) / 1024;
    }
    return 0;
  }

  Future<void> _removeFromFavorites(FavoriteFile file) async {
    final fileKey = '${file.folderName}/${file.name}';
    // Optymistycznie usuń z listy
    setState(() {
      _favorites.removeWhere((f) => f.name == file.name && f.folderName == file.folderName);
    });
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        _showSessionExpiredDialog();
        // Przywróć plik
        setState(() {
          _favorites.add(file);
        });
        return;
      }
      final response = await ApiService.toggleFavorite(
        filename: file.name,
        folderName: file.folderName,
        token: token,
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        // Dodaj aktywność usunięcia z ulubionych
        await ActivityService.addActivity(
          ActivityService.createFileUnfavoriteActivity(file.name),
        );
      } else {
        // Przywróć plik i pokaż błąd
        setState(() {
          _favorites.add(file);
        });
        

        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove from favorites: ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      // Przywróć plik i pokaż błąd
      setState(() {
        _favorites.add(file);
      });
      

      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleFileAction(String action, FavoriteFile file) async {
    switch (action) {
      case 'download':
        // Dodaj aktywność pobierania
        await ActivityService.addActivity(
          ActivityService.createFileDownloadActivity(file.name),
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('favorites.downloading_file'.tr(namedArgs: {'filename': file.name}))),
        );
        break;
      case 'share':
        // TODO: Implement share
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('favorites.sharing_file'.tr(namedArgs: {'filename': file.name}))),
        );
        break;
      case 'rename':
        // TODO: Implement rename
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('favorites.renaming_file'.tr(namedArgs: {'filename': file.name}))),
        );
        break;
      case 'delete':
        // TODO: Implement delete
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('favorites.deleting_file'.tr(namedArgs: {'filename': file.name}))),
        );
        break;
      case 'info':
        _showFileInfo(file);
        break;
    }
  }

  void _showFileInfo(FavoriteFile file) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                _getFileIcon(file.type),
                color: _getFileColor(file.type),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  file.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Type', file.type == 'folder' ? 'dialog_labels.folder'.tr() : 'dialog_labels.file'.tr()),
              _buildInfoRow('Size', file.size),
              _buildInfoRow('Modified', file.date),
              _buildInfoRow('Favorited', file.favoritedDate),
              _buildInfoRow('Location', file.folderName),
              _buildInfoRow('Status', 'Favorited'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('common.ok'.tr()),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Zmiana 2: Animacja serca ---
  // Dodaj mapę do śledzenia animacji dla każdego pliku
  final Map<String, bool> _favoriteAnim = {};

  void _triggerFavoriteAnim(String fileKey) {
    setState(() {
      _favoriteAnim[fileKey] = true;
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _favoriteAnim[fileKey] = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: CustomDrawer(
        username: _username,
        currentRoute: '/favorites',
        onSignOut: () {
          Navigator.pushReplacementNamed(context, '/login');
        },
      ),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF667eea), const Color(0xFF764ba2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'Favorites',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadFavorites,
          ),
          IconButton(
            icon: Icon(
              _isGridView ? Icons.list : Icons.grid_view,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFf8fafc),
      body: Column(
        children: [
          // Search bar
          Container(
            margin: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'search.favorites'.tr(),
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search, color: const Color(0xFF667eea)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey.shade600),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // Sort options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Sort dropdown
                Builder(
                  builder: (context) => GestureDetector(
                    onTap: () {
                      final RenderBox button = context.findRenderObject() as RenderBox;
                      final Offset offset = button.localToGlobal(Offset.zero);
                      
                      showMenu(
                        context: context,
                        position: RelativeRect.fromLTRB(
                          offset.dx,
                          offset.dy + button.size.height + 8,
                          offset.dx + button.size.width,
                          offset.dy + button.size.height + 200,
                        ),
                        items: [
                          PopupMenuItem<String>(
                            value: 'name',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.sort_by_alpha,
                                  size: 18,
                                  color: _sortBy == 'name' 
                                    ? Theme.of(context).colorScheme.primary 
                                    : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 12),
                                                                    Text(
                                      'files.sort_name'.tr(),
                                  style: TextStyle(
                                    color: _sortBy == 'name' 
                                      ? const Color(0xFF667eea)
                                      : Colors.grey.shade700,
                                    fontWeight: _sortBy == 'name' 
                                      ? FontWeight.w600 
                                      : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'date',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 18,
                                  color: _sortBy == 'date' 
                                    ? const Color(0xFF667eea)
                                    : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 12),
                                                                    Text(
                                      'files.sort_date'.tr(),
                                  style: TextStyle(
                                    color: _sortBy == 'date' 
                                      ? const Color(0xFF667eea)
                                      : Colors.grey.shade700,
                                    fontWeight: _sortBy == 'date' 
                                      ? FontWeight.w600 
                                      : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'size',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.storage,
                                  size: 18,
                                  color: _sortBy == 'size' 
                                    ? const Color(0xFF667eea)
                                    : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 12),
                                                                    Text(
                                      'files.sort_size'.tr(),
                                  style: TextStyle(
                                    color: _sortBy == 'size' 
                                      ? const Color(0xFF667eea)
                                      : Colors.grey.shade700,
                                    fontWeight: _sortBy == 'size' 
                                      ? FontWeight.w600 
                                      : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'type',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.category,
                                  size: 18,
                                  color: _sortBy == 'type' 
                                    ? const Color(0xFF667eea)
                                    : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 12),
                                                                    Text(
                                      'files.sort_type'.tr(),
                                  style: TextStyle(
                                    color: _sortBy == 'type' 
                                      ? const Color(0xFF667eea)
                                      : Colors.grey.shade700,
                                    fontWeight: _sortBy == 'type' 
                                      ? FontWeight.w600 
                                      : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ).then((value) {
                        if (value != null) {
                          setState(() {
                            _sortBy = value;
                          });
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sort,
                            size: 16,
                            color: const Color(0xFF667eea),
                          ),
                          const SizedBox(width: 6),
                                                        Text(
                                _sortBy == 'name' ? 'files.sort_name'.tr() :
                                _sortBy == 'date' ? 'files.sort_date'.tr() :
                                _sortBy == 'size' ? 'files.sort_size'.tr() : 'files.sort_type'.tr(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF667eea),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: const Color(0xFF667eea),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // File count
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF667eea).withOpacity(0.3)),
                  ),
                  child: Text(
                    _searchQuery.isNotEmpty 
                      ? '${_filteredFiles.length} of ${_favorites.length} files'
                      : '${_filteredFiles.length} files',
                    style: TextStyle(
                      color: const Color(0xFF667eea),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Files list
          Expanded(
            child: _isGridView ? _buildGridView() : _buildAnimatedFilesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedFilesList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade700),
            const SizedBox(height: 8),
            Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadFavorites, child: Text('favorites.retry'.tr())),
          ],
        ),
      );
    }
    if (_filteredFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(_searchQuery.isEmpty ? 'favorites.no_files'.tr() : 'favorites.no_files_found'.tr(),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text(_searchQuery.isEmpty ? 'favorites.add_files_tip'.tr() : 'favorites.try_different_search'.tr(),
                style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }
    return AnimatedList(
      key: _listKey,
      initialItemCount: _filteredFiles.length,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemBuilder: (context, index, animation) {
        final file = _filteredFiles[index];
        final fileKey = '${file.folderName}/${file.name}';
        return SlideTransition(
          position: animation.drive(
            Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeOutCubic)),
          ),
          child: FadeTransition(
            opacity: animation,
            child: Card(
              margin: const EdgeInsets.only(bottom: 8.0),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getFileColor(file.type).withOpacity(0.1),
                  child: Icon(_getFileIcon(file.type), color: _getFileColor(file.type)),
                ),
                title: Text(file.name, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                subtitle: Text('${file.size} • ${file.date} • Favorited: ${file.favoritedDate}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        _triggerFavoriteAnim(fileKey);
                        _removeFromFavoritesAnimated(file, index);
                      },
                      child: AnimatedScale(
                        scale: _favoriteAnim[fileKey] == true ? 1.4 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        child: Icon(Icons.favorite, color: Colors.red, size: 24),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        _handleFileAction(value, file);
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(value: 'download', child: Text('favorites.download'.tr())),
                        PopupMenuItem(value: 'share', child: Text('favorites.share'.tr())),
                        PopupMenuItem(value: 'rename', child: Text('favorites.rename'.tr())),
                        PopupMenuItem(value: 'delete', child: Text('favorites.delete'.tr())),
                        PopupMenuItem(value: 'info', child: Text('Info')),
                      ],
                      child: const Icon(Icons.more_vert),
                    ),
                  ],
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('favorites.opening_file'.tr(namedArgs: {'filename': file.name}))),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _removeFromFavoritesAnimated(FavoriteFile file, int index) async {
    final fileKey = '${file.folderName}/${file.name}';
    _listKey.currentState?.removeItem(
      index,
      (context, animation) {
        return SlideTransition(
          position: animation.drive(
            Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeOutCubic)),
          ),
          child: FadeTransition(
            opacity: animation,
            child: Card(
              margin: const EdgeInsets.only(bottom: 8.0),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getFileColor(file.type).withOpacity(0.1),
                  child: Icon(_getFileIcon(file.type), color: _getFileColor(file.type)),
                ),
                title: Text(file.name, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                subtitle: Text('${file.size} • ${file.date} • Favorited: ${file.favoritedDate}'),
              ),
            ),
          ),
        );
      },
      duration: const Duration(milliseconds: 350),
    );
    setState(() {
      _favorites.removeWhere((f) => f.name == file.name && f.folderName == file.folderName);
    });
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        _showSessionExpiredDialog();
        setState(() {
          _favorites.insert(index, file);
        });
        _listKey.currentState?.insertItem(index);
        return;
      }
      final response = await ApiService.toggleFavorite(
        filename: file.name,
        folderName: file.folderName,
        token: token,
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        // OK
      } else {
        setState(() {
          _favorites.insert(index, file);
        });
        _listKey.currentState?.insertItem(index);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove from favorites: ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _favorites.insert(index, file);
      });
      _listKey.currentState?.insertItem(index);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _filteredFiles.length,
      itemBuilder: (context, index) {
        final file = _filteredFiles[index];
        
        return Card(
          child: GestureDetector(
            onTap: () {
              _handleFileAction('open', file);
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: _getFileColor(file.type).withOpacity(0.1),
                  child: Icon(
                    _getFileIcon(file.type),
                    color: _getFileColor(file.type),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          file.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          file.size,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          file.date,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleFileAction(value, file),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'download',
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.download_rounded, color: Colors.green.shade600, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'favorites.download'.tr(),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.share, color: Colors.blue.shade600, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'favorites.share'.tr(),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.edit, color: Colors.orange.shade600, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'favorites.rename'.tr(),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.favorite_border, color: Colors.red.shade600, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'favorites.delete'.tr(),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'info',
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.info_outline, color: Colors.grey.shade600, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Info',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class FavoriteFile {
  final String name;
  final String size;
  final String date;
  final String favoritedDate;
  final String type;
  final String folderName;

  FavoriteFile({
    required this.name,
    required this.size,
    required this.date,
    required this.favoritedDate,
    required this.type,
    required this.folderName,
  });
} 