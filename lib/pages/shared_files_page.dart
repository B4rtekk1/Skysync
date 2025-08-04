import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import '../utils/custom_widgets.dart';
import '../utils/api_service.dart';
import '../utils/token_service.dart';
import '../utils/activity_service.dart';

class SharedFilesPage extends StatefulWidget {
  const SharedFilesPage({super.key});

  @override
  State<SharedFilesPage> createState() => _SharedFilesPageState();
}

class _SharedFilesPageState extends State<SharedFilesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'name'; // 'name', 'date', 'size', 'type', 'sharer'
  bool _isGridView = false;
  bool _isLoading = true;
  String? _errorMessage;
  String _username = 'loading';

  // Dane plików i folderów udostępnionych z serwera
  List<SharedItem> _sharedItems = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSharedItems();
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

  Future<void> _loadSharedItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await TokenService.getToken();
      
      if (token == null) {
        setState(() {
          _errorMessage = 'shared_files.not_logged_in'.tr();
          _isLoading = false;
        });
        _showSessionExpiredDialog();
        return;
      }

      // Ładowanie plików udostępnionych
      final filesResponse = await ApiService.getSharedFiles(token: token);
      final foldersResponse = await ApiService.getSharedFolders(token: token);

      if (!mounted) return;

      if (filesResponse.statusCode == 200 && foldersResponse.statusCode == 200) {
        final filesData = jsonDecode(filesResponse.body);
        final foldersData = jsonDecode(foldersResponse.body);
        
        final sharedFilesData = filesData['shared_files'] as List;
        final sharedFoldersData = foldersData['shared_folders'] as List;
        
        List<SharedItem> allItems = [];
        
        // Dodaj pliki
        for (var fileData in sharedFilesData) {
          final filename = fileData['filename'] as String;
          final sizeBytes = fileData['size_bytes'] as int;
          final modificationDate = fileData['modification_date'] as String;
          final sharedAt = fileData['shared_at'] as String;
          final folderName = fileData['folder_name'] as String;
          final sharedBy = fileData['shared_by'] as String;
          final sharedByEmail = fileData['shared_by_email'] as String;
          
          allItems.add(SharedItem(
            name: filename,
            size: _formatFileSize(sizeBytes),
            date: _formatDate(modificationDate),
            sharedDate: _formatDate(sharedAt),
            type: 'file',
            fileType: _getFileType(filename),
            folderName: folderName,
            sharedBy: sharedBy,
            sharedByEmail: sharedByEmail,
            fileCount: 0,
            folderCount: 0,
          ));
        }
        
        // Dodaj foldery
        for (var folderData in sharedFoldersData) {
          final folderName = folderData['folder_name'] as String;
          final totalSizeBytes = folderData['total_size_bytes'] as int;
          final modificationDate = folderData['modification_date'] as String;
          final sharedAt = folderData['shared_at'] as String;
          final folderPath = folderData['folder_path'] as String;
          final sharedBy = folderData['shared_by'] as String;
          final sharedByEmail = folderData['shared_by_email'] as String;
          final fileCount = folderData['file_count'] as int;
          final folderCount = folderData['folder_count'] as int? ?? 0;
          
          // Formatuj rozmiar z informacją o liczbie plików i folderów
          String displaySize;
          final filesLabel = _getPluralLabel(fileCount, 'folder_info.file_singular', 'folder_info.file_plural');
          final foldersLabel = _getPluralLabel(folderCount, 'folder_info.folder_singular', 'folder_info.folder_plural');
          
          if (totalSizeBytes > 0) {
            displaySize = '${_formatFileSize(totalSizeBytes)} (${'folder_info.files_and_folders'.tr(namedArgs: {
              'files': fileCount.toString(), 
              'folders': folderCount.toString(),
              'files_label': filesLabel,
              'folders_label': foldersLabel,
            })})';
          } else {
            displaySize = '-- (${'folder_info.files_and_folders'.tr(namedArgs: {
              'files': fileCount.toString(), 
              'folders': folderCount.toString(),
              'files_label': filesLabel,
              'folders_label': foldersLabel,
            })})';
          }
          
          allItems.add(SharedItem(
            name: folderName,
            size: displaySize,
            date: _formatDate(modificationDate),
            sharedDate: _formatDate(sharedAt),
            type: 'folder',
            fileType: 'folder',
            folderName: folderPath,
            sharedBy: sharedBy,
            sharedByEmail: sharedByEmail,
            fileCount: fileCount,
            folderCount: folderCount,
          ));
        }
        
        setState(() {
          _sharedItems = allItems;
          _isLoading = false;
        });
      } else {
        // Sprawdź czy to błąd wygasłego tokenu
        if ((filesResponse.statusCode == 401) || (foldersResponse.statusCode == 401)) {
          setState(() {
            _isLoading = false;
          });
          _showSessionExpiredDialog();
        } else {
          setState(() {
            _errorMessage = 'shared_files.error_loading'.tr(namedArgs: {'error': 'Failed to load shared items'});
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'shared_files.network_error'.tr(namedArgs: {'error': e.toString()});
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

  String _getPluralLabel(int count, String singularKey, String pluralKey) {
    return count == 1 ? singularKey.tr() : pluralKey.tr();
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
      case 'folder':
        return Icons.folder;
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
      case 'folder':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  List<SharedItem> get _filteredItems {
    List<SharedItem> filtered = _sharedItems.where((item) =>
        item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        item.sharedBy.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

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
      case 'sharer':
        filtered.sort((a, b) => a.sharedBy.compareTo(b.sharedBy));
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

  void _handleItemAction(String action, SharedItem item) async {
    switch (action) {
      case 'download':
        if (item.type == 'folder') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('shared_files.downloading_folder'.tr(namedArgs: {'foldername': item.name}))),
          );
        } else {
          // Dodaj aktywność pobierania
          await ActivityService.addActivity(
            ActivityService.createFileDownloadActivity(item.name),
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('shared_files.downloading_file'.tr(namedArgs: {'filename': item.name}))),
          );
        }
        break;
      case 'share':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('shared_files.sharing_file'.tr(namedArgs: {'filename': item.name}))),
        );
        break;
      case 'info':
        _showItemInfo(item);
        break;
    }
  }

  void _showItemInfo(SharedItem item) async {
    final email = await TokenService.getEmail();
    final location = item.folderName.isEmpty ? (email?.split('@')[0] ?? 'Unknown') : item.folderName;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                _getFileIcon(item.fileType),
                color: _getFileColor(item.fileType),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.name,
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
              _buildInfoRow('Type', item.type == 'folder' ? 'dialog_labels.folder'.tr() : 'dialog_labels.file'.tr()),
              _buildInfoRow('Size', item.size),
              _buildInfoRow('Modified', item.date),
              _buildInfoRow('Shared by', item.sharedBy),
              _buildInfoRow('Shared on', item.sharedDate),
              if (item.type == 'folder') ...[
                _buildInfoRow('dialog_labels.files'.tr(), 'folder_info.files_count'.tr(namedArgs: {
                  'count': item.fileCount.toString(),
                  'files_label': _getPluralLabel(item.fileCount, 'folder_info.file_singular', 'folder_info.file_plural'),
                })),
                _buildInfoRow('dialog_labels.folders'.tr(), 'folder_info.folders_count'.tr(namedArgs: {
                  'count': item.folderCount.toString(),
                  'folders_label': _getPluralLabel(item.folderCount, 'folder_info.folder_singular', 'folder_info.folder_plural'),
                })),
              ],
              _buildInfoRow('Location', location),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: CustomDrawer(
        username: _username,
        currentRoute: '/shared-files',
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
        title: Text(
          'shared_files.title'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadSharedItems,
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
                hintText: 'search.shared_files'.tr(),
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
                                    ? const Color(0xFF667eea)
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
                          PopupMenuItem<String>(
                            value: 'sharer',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  size: 18,
                                  color: _sortBy == 'sharer' 
                                    ? const Color(0xFF667eea)
                                    : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'files.sort_sharer'.tr(),
                                  style: TextStyle(
                                    color: _sortBy == 'sharer' 
                                      ? const Color(0xFF667eea)
                                      : Colors.grey.shade700,
                                    fontWeight: _sortBy == 'sharer' 
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
                                _sortBy == 'size' ? 'files.sort_size'.tr() :
                                _sortBy == 'type' ? 'files.sort_type'.tr() : 'files.sort_sharer'.tr(),
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
                
                // Item count
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF667eea).withOpacity(0.3)),
                  ),
                  child: Text(
                    _searchQuery.isNotEmpty 
                      ? '${_filteredItems.length} of ${_sharedItems.length} items'
                      : '${_filteredItems.length} items',
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
          
          // Items list
          Expanded(
            child: _isGridView ? _buildGridView() : _buildItemsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
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
            ElevatedButton(onPressed: _loadSharedItems, child: Text('shared_files.retry'.tr())),
          ],
        ),
      );
    }
    if (_filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_shared, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(_searchQuery.isEmpty ? 'shared_files.no_files'.tr() : 'shared_files.no_files_found'.tr(),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text(_searchQuery.isEmpty ? 'shared_files.no_files_tip'.tr() : 'shared_files.try_different_search'.tr(),
                style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getFileColor(item.fileType).withOpacity(0.1),
              child: Icon(_getFileIcon(item.fileType), color: _getFileColor(item.fileType)),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    item.name, 
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item.type == 'folder') ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'shared_files.file_count'.tr(namedArgs: {'count': item.fileCount.toString()}),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item.size} • ${item.date}'),
                Text('shared_files.shared_by'.tr(namedArgs: {'username': item.sharedBy}) + ' on ${item.sharedDate}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder_shared, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    _handleItemAction(value, item);
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 8,
                  offset: const Offset(0, 8),
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
                            item.type == 'folder' ? 'Download as ZIP' : 'shared_files.download'.tr(),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    if (item.type == 'file')
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
                              'shared_files.share'.tr(),
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
            onTap: () {
              if (item.type == 'folder') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('shared_files.opening_folder'.tr(namedArgs: {'foldername': item.name}))),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('shared_files.opening_file'.tr(namedArgs: {'filename': item.name}))),
                );
              }
            },
          ),
        );
      },
    );
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
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        
        return Card(
          child: GestureDetector(
            onTap: () {
              if (item.type == 'folder') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('shared_files.opening_folder'.tr(namedArgs: {'foldername': item.name}))),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('shared_files.opening_file'.tr(namedArgs: {'filename': item.name}))),
                );
              }
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: _getFileColor(item.fileType).withOpacity(0.1),
                  child: Icon(
                    _getFileIcon(item.fileType),
                    color: _getFileColor(item.fileType),
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
                          item.name,
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
                          item.size,
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
                          'shared_files.shared_by'.tr(namedArgs: {'username': item.sharedBy}),
                          style: TextStyle(
                            color: Colors.blue.shade600,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
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
                  onSelected: (value) => _handleItemAction(value, item),
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
                            item.type == 'folder' ? 'Download as ZIP' : 'shared_files.download'.tr(),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    if (item.type == 'file')
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
                              'shared_files.share'.tr(),
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

class SharedItem {
  final String name;
  final String size;
  final String date;
  final String sharedDate;
  final String type; // 'file' or 'folder'
  final String fileType; // 'pdf', 'image', 'folder', etc.
  final String folderName;
  final String sharedBy;
  final String sharedByEmail;
  final int fileCount;
  final int folderCount;

  SharedItem({
    required this.name,
    required this.size,
    required this.date,
    required this.sharedDate,
    required this.type,
    required this.fileType,
    required this.folderName,
    required this.sharedBy,
    required this.sharedByEmail,
    required this.fileCount,
    required this.folderCount,
  });
} 