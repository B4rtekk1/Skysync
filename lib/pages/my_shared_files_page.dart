import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/custom_widgets.dart';
import '../utils/token_service.dart';
import '../utils/api_service.dart';
import '../utils/error_handler.dart';
import '../utils/error_widgets.dart';
import '../utils/activity_service.dart';
import '../utils/file_utils.dart';
import '../widgets/image_preview_widget.dart';
import '../widgets/text_preview_widget.dart';
import '../widgets/spreadsheet_preview_widget.dart';
import '../widgets/pdf_preview_widget.dart';
import 'package:easy_localization/easy_localization.dart';

class MySharedFilesPage extends StatefulWidget {
  const MySharedFilesPage({super.key});

  @override
  State<MySharedFilesPage> createState() => _MySharedFilesPageState();
}

class _MySharedFilesPageState extends State<MySharedFilesPage> {
  List<MySharedItem> _sharedItems = [];
  List<MySharedItem> _filteredItems = [];
  bool _isLoading = true;
  bool _isGridView = false;
  String? _errorMessage;
  String _username = '';
  String _searchQuery = '';
  String _sortBy = 'date';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadMySharedItems();
  }

  Future<void> _loadUserData() async {
    final username = await TokenService.getUsername();
    setState(() {
      _username = username ?? '';
    });
  }

  Future<void> _loadMySharedItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await TokenService.getToken();
      if (token == null) {
        setState(() {
          _errorMessage = 'my_shared_files.not_logged_in'.tr();
          _isLoading = false;
        });
        _showSessionExpiredDialog();
        return;
      }

      // Pobierz pliki i foldery udostępnione przez użytkownika (zarówno użytkownikom jak i grupom)
      final filesResponse = await ApiService.getMySharedFiles(token: token);
      final foldersResponse = await ApiService.getMySharedFolders(token: token);
      final groupFilesResponse = await ApiService.getGroupSharedFiles(token: token);
      final groupFoldersResponse = await ApiService.getGroupSharedFolders(token: token);

      if (!mounted) return;

      // Sprawdź czy to błąd wygasłego tokenu
      if ((filesResponse.statusCode == 401) || (foldersResponse.statusCode == 401) ||
          (groupFilesResponse.statusCode == 401) || (groupFoldersResponse.statusCode == 401)) {
        setState(() {
          _isLoading = false;
        });
        _showSessionExpiredDialog();
        return;
      }

      final List<MySharedItem> allItems = [];
      
      // Przetwórz pliki udostępnione użytkownikom (jeśli sukces)
      if (filesResponse.statusCode == 200) {
        try {
          final filesData = jsonDecode(filesResponse.body);
          final sharedFilesData = filesData['my_shared_files'] as List;
          
          for (var fileData in sharedFilesData) {
            final filename = fileData['filename'] as String;
            final sizeBytes = fileData['size_bytes'] as int;
            final modificationDate = fileData['modification_date'] as String;
            final sharedAt = fileData['shared_at'] as String;
            final folderName = fileData['folder_name'] as String;
            final sharedWith = fileData['shared_with'] as String;
            final sharedWithEmail = fileData['shared_with_email'] as String;
            
            allItems.add(MySharedItem(
              name: filename,
              size: _formatFileSize(sizeBytes),
              date: _formatDate(modificationDate),
              sharedDate: _formatDate(sharedAt),
              type: 'file',
              fileType: _getFileType(filename),
              folderName: folderName,
              sharedWith: sharedWith,
              sharedWithEmail: sharedWithEmail,
              fileCount: 0,
              folderCount: 0,
              isSharedWithGroup: false,
            ));
          }
        } catch (e) {
          // Handle parsing error silently
        }
      }
      
      // Przetwórz foldery udostępnione użytkownikom (jeśli sukces)
      if (foldersResponse.statusCode == 200) {
        try {
          final foldersData = jsonDecode(foldersResponse.body);
          final sharedFoldersData = foldersData['my_shared_folders'] as List;
          
          for (var folderData in sharedFoldersData) {
            final folderName = folderData['folder_name'] as String;
            final totalSizeBytes = folderData['total_size_bytes'] as int;
            final modificationDate = folderData['modification_date'] as String;
            final sharedAt = folderData['shared_at'] as String;
            final folderPath = folderData['folder_path'] as String;
            final sharedWith = folderData['shared_with'] as String;
            final sharedWithEmail = folderData['shared_with_email'] as String;
            final fileCount = folderData['file_count'] as int;
            final folderCount = folderData['folder_count'] as int;
            
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
            
            allItems.add(MySharedItem(
              name: folderName,
              size: displaySize,
              date: _formatDate(modificationDate),
              sharedDate: _formatDate(sharedAt),
              type: 'folder',
              fileType: 'folder',
              folderName: folderPath,
              sharedWith: sharedWith,
              sharedWithEmail: sharedWithEmail,
              fileCount: fileCount,
              folderCount: folderCount,
              isSharedWithGroup: false,
            ));
          }
        } catch (e) {
          // Handle parsing error silently
        }
      }
      
      // Przetwórz pliki udostępnione grupie (jeśli sukces)
      if (groupFilesResponse.statusCode == 200) {
        try {
          final groupFilesData = jsonDecode(groupFilesResponse.body);
          final groupSharedFilesData = groupFilesData['group_shared_files'] as List;
          
          for (var fileData in groupSharedFilesData) {
            final filename = fileData['filename'] as String;
            final sizeBytes = fileData['size_bytes'] as int;
            final modificationDate = fileData['modification_date'] as String;
            final sharedAt = fileData['shared_at'] as String;
            final folderName = fileData['folder_name'] as String;
            final groupName = fileData['group_name'] as String;
            final groupDescription = fileData['group_description'] as String?;
            
            allItems.add(MySharedItem(
              name: filename,
              size: _formatFileSize(sizeBytes),
              date: _formatDate(modificationDate),
              sharedDate: _formatDate(sharedAt),
              type: 'file',
              fileType: _getFileType(filename),
              folderName: folderName,
              sharedWith: groupName,
              sharedWithEmail: groupDescription ?? groupName,
              fileCount: 0,
              folderCount: 0,
              isSharedWithGroup: true,
            ));
          }
        } catch (e) {
          // Handle parsing error silently
        }
      }
      
      // Przetwórz foldery udostępnione grupie (jeśli sukces)
      if (groupFoldersResponse.statusCode == 200) {
        try {
          final groupFoldersData = jsonDecode(groupFoldersResponse.body);
          final groupSharedFoldersData = groupFoldersData['group_shared_folders'] as List;
          
          for (var folderData in groupSharedFoldersData) {
            final folderName = folderData['folder_name'] as String;
            final totalSizeBytes = folderData['total_size_bytes'] as int;
            final modificationDate = folderData['modification_date'] as String;
            final sharedAt = folderData['shared_at'] as String;
            final folderPath = folderData['folder_path'] as String;
            final groupName = folderData['group_name'] as String;
            final groupDescription = folderData['group_description'] as String?;
            final fileCount = folderData['file_count'] as int;
            final folderCount = folderData['folder_count'] as int;
            
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
            
            allItems.add(MySharedItem(
              name: folderName,
              size: displaySize,
              date: _formatDate(modificationDate),
              sharedDate: _formatDate(sharedAt),
              type: 'folder',
              fileType: 'folder',
              folderName: folderPath,
              sharedWith: groupName,
              sharedWithEmail: groupDescription ?? groupName,
              fileCount: fileCount,
              folderCount: folderCount,
              isSharedWithGroup: true,
            ));
          }
        } catch (e) {
          // Handle parsing error silently
        }
      }
      
      setState(() {
        _sharedItems = allItems;
        _filteredItems = allItems;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'my_shared_files.network_error'.tr(namedArgs: {'error': e.toString()});
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
        return Icons.folder_shared;
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

  void _handleItemAction(String action, MySharedItem item) {
    switch (action) {
      case 'download':
        _downloadItem(item);
        break;
      case 'info':
        _showItemInfo(item);
        break;
      case 'unshare':
        _unshareItem(item);
        break;
    }
  }

  void _downloadItem(MySharedItem item) {
    // Implementacja pobierania
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('my_shared_files.downloading'.tr(namedArgs: {'name': item.name}))),
    );
  }

  void _showItemInfo(MySharedItem item) async {
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
              _buildInfoRow('Shared with', item.sharedWith),
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

  void _unshareItem(MySharedItem item) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('share.unshare'.tr()),
          content: Text(
            item.type == 'folder' 
              ? 'share.confirm_unshare_folder'.tr(namedArgs: {'foldername': item.name})
              : 'share.confirm_unshare_file'.tr(namedArgs: {'filename': item.name})
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('share.cancel'.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('share.unshare'.tr()),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final token = await TokenService.getToken();
      if (token == null) {
        _showSessionExpiredDialog();
        return;
      }

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('share.unsharing'.tr(namedArgs: {
            'filename': item.name,
            'user': item.sharedWith
          })),
        ),
      );

      http.Response response;
      if (item.isSharedWithGroup) {
        // Odusunięcie udostępnienia z grupy
        if (item.type == 'folder') {
          response = await ApiService.unshareFolderFromGroup(
            token: token,
            folderPath: '${item.folderName}/${item.name}',
            groupName: item.sharedWith,
          );
        } else {
          response = await ApiService.unshareFileFromGroup(
            token: token,
            filename: item.name,
            folderName: item.folderName,
            groupName: item.sharedWith,
          );
        }
      } else {
        // Odusunięcie udostępnienia użytkownikowi
        if (item.type == 'folder') {
          response = await ApiService.unshareFolder(
            token: token,
            folderPath: '${item.folderName}/${item.name}',
            sharedWith: item.sharedWithEmail,
          );
        } else {
          response = await ApiService.unshareFile(
            token: token,
            filename: item.name,
            folderName: item.folderName,
            sharedWith: item.sharedWithEmail,
          );
        }
      }

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Dodaj aktywność odusunięcia udostępnienia
        await ActivityService.addActivity(
          ActivityService.createFileUnshareActivity(item.name, item.sharedWith),
        );
        
        // Remove item from the list
        setState(() {
          _sharedItems.removeWhere((element) => 
            element.name == item.name && 
            element.folderName == item.folderName &&
            element.sharedWith == item.sharedWith &&
            element.isSharedWithGroup == item.isSharedWithGroup
          );
          _filterAndSortItems();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('share.unshare_success'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['detail'] ?? 'share.unshare_error'.tr(namedArgs: {'error': 'Unknown error'});
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('share.unshare_error'.tr(namedArgs: {'error': errorMessage})),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('share.unshare_error'.tr(namedArgs: {'error': e.toString()})),
          backgroundColor: Colors.red,
        ),
      );
    }
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

  void _filterAndSortItems() {
    List<MySharedItem> filtered = _sharedItems.where((item) {
      if (_searchQuery.isEmpty) return true;
      return item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             item.sharedWith.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    // Sort items
    switch (_sortBy) {
      case 'name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'date':
        filtered.sort((a, b) => b.date.compareTo(a.date));
        break;
      case 'size':
        filtered.sort((a, b) {
          // Extract numeric size for comparison
          double sizeA = _extractSize(a.size);
          double sizeB = _extractSize(b.size);
          return sizeB.compareTo(sizeA);
        });
        break;
      case 'type':
        filtered.sort((a, b) => a.type.compareTo(b.type));
        break;
      case 'shared_with':
        filtered.sort((a, b) => a.sharedWith.compareTo(b.sharedWith));
        break;
    }

    setState(() {
      _filteredItems = filtered;
    });
  }

  double _extractSize(String sizeStr) {
    if (sizeStr.contains('MB')) {
      return double.tryParse(sizeStr.split(' ').first) ?? 0;
    } else if (sizeStr.contains('KB')) {
      return (double.tryParse(sizeStr.split(' ').first) ?? 0) / 1024;
    } else if (sizeStr.contains('B')) {
      return (double.tryParse(sizeStr.split(' ').first) ?? 0) / (1024 * 1024);
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: CustomDrawer(
        username: _username,
        currentRoute: '/my-shared-files',
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
              colors: [
                const Color(0xFF667eea), 
                const Color(0xFF764ba2),
                const Color(0xFFf093fb)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.share,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'my_shared_files.title'.tr(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 22,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadMySharedItems,
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
                          _filterAndSortItems();
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
                _filterAndSortItems();
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
                            value: 'shared_with',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  size: 18,
                                  color: _sortBy == 'shared_with' 
                                    ? Theme.of(context).colorScheme.primary 
                                    : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'files.sort_sharer'.tr(),
                                  style: TextStyle(
                                    color: _sortBy == 'shared_with' 
                                      ? Theme.of(context).colorScheme.primary 
                                      : Colors.grey.shade700,
                                    fontWeight: _sortBy == 'shared_with' 
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
                          _filterAndSortItems();
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
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
                          const SizedBox(width: 8),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        const Color(0xFF667eea),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'my_shared_files.loading_files'.tr(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF667eea),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 50,
                  color: Colors.red.shade400,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Error loading shared files',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadMySharedItems,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(
                  'common.retry'.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredItems.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return EmptyStateWidget(
          icon: Icons.search_off,
          title: 'No shared files found',
          subtitle: 'Try adjusting your search terms',
        );
      } else {
        return EmptyStateWidget(
          icon: Icons.share,
          title: 'No shared files yet',
          subtitle: 'Files you share with others will appear here',
        );
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: ListTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (FileUtils.isImage(item.name))
                  // Podgląd zdjęcia
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: FutureBuilder<String?>(
                        future: TokenService.getUsername(),
                        builder: (context, snapshot) {
                          final username = snapshot.data ?? 'unknown';
                          return ImagePreviewWidget(
                            filename: item.name,
                            folderName: item.folderName,
                            width: 48,
                            height: 48,
                            showFullScreenOnTap: false,
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                    ),
                  )
                else if (FileUtils.isTextFile(item.name))
                  // Podgląd pliku tekstowego
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: FutureBuilder<String?>(
                        future: TokenService.getUsername(),
                        builder: (context, snapshot) {
                          final username = snapshot.data ?? 'unknown';
                          return TextPreviewWidget(
                            filename: item.name,
                            folderName: item.folderName,
                            width: 48,
                            height: 48,
                            showFullScreenOnTap: false,
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                    ),
                  )
                else if (FileUtils.isSpreadsheet(item.name))
                  // Podgląd arkusza kalkulacyjnego
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: FutureBuilder<String?>(
                        future: TokenService.getUsername(),
                        builder: (context, snapshot) {
                          final username = snapshot.data ?? 'unknown';
                          return SpreadsheetPreviewWidget(
                            filename: item.name,
                            folderName: item.folderName,
                            width: 48,
                            height: 48,
                            showFullScreenOnTap: false,
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                    ),
                  )
                else if (FileUtils.isPdf(item.name))
                  // Podgląd PDF
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: FutureBuilder<String?>(
                        future: TokenService.getUsername(),
                        builder: (context, snapshot) {
                          final username = snapshot.data ?? 'unknown';
                          return PdfPreviewWidget(
                            filename: item.name,
                            folderName: item.folderName,
                            width: 48,
                            height: 48,
                            showFullScreenOnTap: false,
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                    ),
                  )
                else
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getFileColor(item.fileType).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getFileColor(item.fileType).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      _getFileIcon(item.fileType),
                      color: _getFileColor(item.fileType),
                      size: 24,
                    ),
                  ),
              ],
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
                      '${item.fileCount} plików',
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
                Text(
                  item.isSharedWithGroup 
                    ? 'my_shared_files.shared_with_group'.tr(namedArgs: {'group': item.sharedWith}) + ' on ${item.sharedDate}'
                    : 'my_shared_files.shared_with'.tr(namedArgs: {'user': item.sharedWith}) + ' on ${item.sharedDate}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.share, color: Colors.green, size: 20),
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
                              color: const Color(0xFF667eea).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.download_rounded, color: const Color(0xFF667eea), size: 18),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            item.type == 'folder' ? 'Download as ZIP' : 'my_shared_files.download'.tr(),
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
                    PopupMenuItem(
                      value: 'unshare',
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.link_off, color: Colors.red.shade600, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'share.unshare'.tr(),
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('my_shared_files.opening_item'.tr(namedArgs: {'name': item.name}))),
              );
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('my_shared_files.opening_item'.tr(namedArgs: {'name': item.name}))),
              );
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
                          item.isSharedWithGroup 
                            ? 'my_shared_files.shared_with_group'.tr(namedArgs: {'group': item.sharedWith})
                            : 'my_shared_files.shared_with'.tr(namedArgs: {'user': item.sharedWith}),
                          style: TextStyle(
                            color: Colors.green.shade600,
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
                            item.type == 'folder' ? 'Download as ZIP' : 'my_shared_files.download'.tr(),
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
                    PopupMenuItem(
                      value: 'unshare',
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.link_off, color: Colors.red.shade600, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'share.unshare'.tr(),
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

class MySharedItem {
  final String name;
  final String size;
  final String date;
  final String sharedDate;
  final String type; // 'file' or 'folder'
  final String fileType; // 'pdf', 'image', 'folder', etc.
  final String folderName;
  final String sharedWith;
  final String sharedWithEmail;
  final int fileCount;
  final int folderCount;
  final bool isSharedWithGroup; // true if shared with group, false if shared with user

  MySharedItem({
    required this.name,
    required this.size,
    required this.date,
    required this.sharedDate,
    required this.type,
    required this.fileType,
    required this.folderName,
    required this.sharedWith,
    required this.sharedWithEmail,
    required this.fileCount,
    required this.folderCount,
    this.isSharedWithGroup = false,
  });
} 