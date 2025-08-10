import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import '../utils/custom_widgets.dart';
import '../utils/api_service.dart';
import '../utils/token_service.dart';
import '../utils/notification_service.dart';
import '../utils/error_handler.dart';
import '../utils/activity_service.dart';
import '../utils/cache_service.dart';
import 'dart:async';
import '../widgets/image_preview_widget.dart';
import '../widgets/text_preview_widget.dart';
import '../widgets/spreadsheet_preview_widget.dart';
import '../widgets/pdf_preview_widget.dart';
import '../utils/file_utils.dart';

class FilesPage extends StatefulWidget {
  const FilesPage({super.key});

  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  String _sortBy = 'name';
  bool _isGridView = false;
  bool _isLoading = true;
  String? _errorMessage;
  String _email = 'loading@example.com';
  String _currentPath = '';

  bool _isSelectionMode = false;
  Set<String> _selectedFiles = {};

  List<FileItem> _files = [];

  Timer? _scrollTimer;
  bool _isDragging = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadFiles();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadFiles();
  }

  Future<void> _loadUserData() async {
    final email = await TokenService.getEmail();
    setState(() {
      _email = email ?? 'unknown@example.com';
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

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await TokenService.getToken();
      final username = await TokenService.getUsername();
      
      if (token == null || username == null) {
        setState(() {
          _errorMessage = 'files.not_logged_in'.tr();
          _isLoading = false;
        });
        _showSessionExpiredDialog();
        return;
      }

      final cachedFiles = CacheService().getCachedFiles(username, _currentPath);
      if (cachedFiles != null) {
        print('Używam cache\'owanych plików dla: $username/$_currentPath');
        _processFilesData(cachedFiles);
        return;
      }

      final folderPath = _currentPath.isEmpty ? username : '$username/$_currentPath';
      print('Ładowanie plików z: $folderPath');
      
      final response = await ApiService.listFiles(
        username: username,
        folderName: folderPath,
        token: token,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final filesData = data['files'] as List;
        
        await CacheService().cacheFiles(username, _currentPath, filesData.cast<Map<String, dynamic>>());
        
        _processFilesData(filesData.cast<Map<String, dynamic>>());
      } else {
        if (response.body.toLowerCase().contains('token expired') || 
            response.body.toLowerCase().contains('unauthorized') ||
            response.statusCode == 401) {
          setState(() {
            _isLoading = false;
          });
          _showSessionExpiredDialog();
        } else {
          setState(() {
            _errorMessage = 'Failed to load files: ${response.body}';
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

  void _processFilesData(List<Map<String, dynamic>> filesData) {
    setState(() {
      _files = filesData.map((fileData) {
        final filename = fileData['filename'] as String;
        final sizeBytes = fileData['size_bytes'] as int;
        final modificationDate = fileData['modification_date'] as String;
        final type = fileData['type'] as String;
        final isFavorite = fileData['is_favorite'] as bool? ?? false;
        
        String displaySize;
        if (type == 'folder') {
          final fileCount = fileData['file_count'] as int? ?? 0;
          final folderCount = fileData['folder_count'] as int? ?? 0;
          
          final filesLabel = _getPluralLabel(fileCount, 'folder_info.file_singular', 'folder_info.file_plural');
          final foldersLabel = _getPluralLabel(folderCount, 'folder_info.folder_singular', 'folder_info.folder_plural');
          
          if (sizeBytes > 0) {
            displaySize = '${_formatFileSize(sizeBytes)} (${'folder_info.files_and_folders'.tr(namedArgs: {
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
        } else {
          displaySize = _formatFileSize(sizeBytes);
        }
        
        return FileItem(
          name: filename,
          size: displaySize,
          date: _formatDate(modificationDate),
          type: type == 'folder' ? 'folder' : _getFileType(filename),
          isFavorite: isFavorite,
        );
      }).toList();
      _isLoading = false;
    });
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

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.upload_file, color: const Color(0xFF667eea)),
                ),
                        title: Text('files.upload_files'.tr()),
        subtitle: Text('files.upload_files_desc'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  _uploadFile();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.folder, color: Colors.amber.shade600),
                ),
                        title: Text('files.create_folder'.tr()),
        subtitle: Text('files.create_folder_desc'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  _createFolder();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createFolder() async {
    final folderName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text('files.create_folder'.tr()),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'folder.name'.tr(),
              hintText: 'folder.enter_name'.tr(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('files.cancel'.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text('files.create'.tr()),
            ),
          ],
        );
      },
    );

    if (folderName == null || folderName.isEmpty) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                const SizedBox(height: 20),
                Text(
                  'folder.creating'.tr(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );

      final token = await TokenService.getToken();
      final username = await TokenService.getUsername();
      
      if (token == null || username == null) {
        Navigator.pop(context);
        NotificationService.showAuthError(context);
        return;
      }

      final fullFolderPath = _currentPath.isEmpty ? '$username/$folderName' : '$username/$_currentPath/$folderName';
      print('Creating folder: $fullFolderPath in path: $_currentPath');
      final response = await ApiService.createFolder(
        username: username,
        folderName: fullFolderPath,
        token: token,
      );

      Navigator.pop(context);

      if (!mounted) return;

      if (response.statusCode == 200) {
        await ActivityService.addActivity(
          ActivityService.createFolderCreateActivity(folderName),
        );
        
        _showFolderCreatedSuccessDialog(folderName);
        await CacheService().clearFilesCache(username, _currentPath);
        _loadFiles();
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['detail'] ?? response.body;
        NotificationService.showValidationError(context, errorMessage);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        final error = ErrorHandler.handleError(e, null);
        NotificationService.showEnhancedError(context, error);
      }
    }
  }

  Future<void> _uploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) return;

      final files = result.files;
      
      final token = await TokenService.getToken();
      final username = await TokenService.getUsername();
      
      if (token == null || username == null) {
        NotificationService.showAuthError(context);
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      files.length == 1 
                        ? 'Uploading file...' 
                        : 'Uploading ${files.length} files...',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (files.length > 1) ...[
                      Text(
                        '0/${files.length} completed',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          );
        },
      );

      final uploadFolder = _currentPath.isEmpty ? username : '$username/$_currentPath';
      int completedFiles = 0;
      List<String> failedFiles = [];
      List<String> successfulFiles = [];

      for (final file in files) {
        try {
          if (file.path == null) {
            failedFiles.add('${file.name} (Could not access file)');
            continue;
          }

          final fileBytes = await File(file.path!).readAsBytes();

          final response = await ApiService.uploadFile(
            username: username,
            folderName: uploadFolder,
            token: token,
            fileBytes: fileBytes,
            fileName: file.name,
          );

          if (response.statusCode == 200) {
            successfulFiles.add(file.name);
          } else {
            failedFiles.add('${file.name} (${response.body})');
          }

          completedFiles++;
        } catch (e) {
          failedFiles.add('${file.name} ($e)');
          completedFiles++;
        }
      }

      Navigator.pop(context);

      if (!mounted) return;

      if (successfulFiles.isNotEmpty && failedFiles.isEmpty) {
        if (successfulFiles.length == 1) {
          _showUploadSuccessDialog(successfulFiles.first);
        } else {
          _showMultipleUploadSuccessDialog(successfulFiles);
        }
      } else if (successfulFiles.isNotEmpty && failedFiles.isNotEmpty) {
        _showPartialUploadDialog(successfulFiles, failedFiles);
      } else {
        _showUploadFailureDialog(failedFiles);
      }

      await CacheService().clearFilesCache(username, _currentPath);
      _loadFiles();
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('files.upload_error'.tr(args: [e.toString()]))),
        );
      }
    }
  }

  void _navigateToFolder(String folderName) {
    setState(() {
      if (_currentPath.isEmpty) {
        _currentPath = folderName;
      } else {
        _currentPath = '$_currentPath/$folderName';
      }
    });
    _loadFiles();
  }

  void _navigateBack() {
    if (_currentPath.isEmpty) return;
    
    final pathParts = _currentPath.split('/');
    if (pathParts.length == 1) {
      setState(() {
        _currentPath = '';
      });
    } else {
      setState(() {
        _currentPath = pathParts.sublist(0, pathParts.length - 1).join('/');
      });
    }
    _loadFiles();
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedFiles.clear();
      }
    });
  }

  void _toggleFileSelection(String fileName) {
    setState(() {
      if (_selectedFiles.contains(fileName)) {
        _selectedFiles.remove(fileName);
      } else {
        _selectedFiles.add(fileName);
      }
    });
  }

  void _selectAllFiles() {
    setState(() {
      _selectedFiles = _filteredFiles.map((file) => file.name).toSet();
    });
  }

  void _deselectAllFiles() {
    setState(() {
      _selectedFiles.clear();
    });
  }

  List<FileItem> _getSelectedFiles() {
    return _filteredFiles.where((file) => _selectedFiles.contains(file.name)).toList();
  }

  void _showSelectionActions() {
    final selectedFiles = _getSelectedFiles();
    if (selectedFiles.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${selectedFiles.length} file${selectedFiles.length == 1 ? '' : 's'} selected',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'Choose an action to perform',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),
              
              // Action buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Download action
                    _buildActionTile(
                      icon: Icons.download_rounded,
                      iconColor: const Color(0xFF667eea),
                      iconBgColor: const Color(0xFF667eea).withValues(alpha: 0.1),
                      title: selectedFiles.any((file) => file.type == 'folder') 
                        ? 'Download as ZIP'
                        : selectedFiles.length == 1 
                          ? 'Download File'
                          : 'Download Files',
                      subtitle: selectedFiles.any((file) => file.type == 'folder')
                        ? 'Download files and folders as ZIP archive'
                        : 'Download selected files directly',
                      onTap: () {
                        Navigator.pop(context);
                        _downloadSelectedFiles(selectedFiles);
                      },
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Move action
                    _buildActionTile(
                      icon: Icons.drive_file_move_rounded,
                      iconColor: Colors.blue.shade600,
                      iconBgColor: Colors.blue.shade50,
                      title: 'Move Selected',
                      subtitle: 'Move files to another folder',
                      onTap: () {
                        Navigator.pop(context);
                        _showMoveDialog(selectedFiles);
                      },
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Delete action
                    _buildActionTile(
                      icon: Icons.delete_forever_rounded,
                      iconColor: Colors.red.shade600,
                      iconBgColor: Colors.red.shade50,
                      title: 'Delete Selected',
                      subtitle: 'Permanently delete selected files',
                      onTap: () {
                        Navigator.pop(context);
                        _showDeleteSelectedDialog(selectedFiles);
                      },
                    ),
                  ],
                ),
              ),
              
              // Cancel button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade100),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Arrow icon
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.grey.shade400,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteSelectedDialog(List<FileItem> selectedFiles) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ConfirmationDialog(
          title: 'Delete ${selectedFiles.length} file${selectedFiles.length == 1 ? '' : 's'}',
          message: 'Are you sure you want to delete ${selectedFiles.length} file${selectedFiles.length == 1 ? '' : 's'}? This action cannot be undone.',
          confirmText: 'Delete',
          cancelText: 'Cancel',
          icon: Icons.delete_forever,
          iconColor: Colors.red.shade600,
          onConfirm: () {
            _deleteSelectedFiles(selectedFiles);
          },
        );
      },
    );
  }

  Future<void> _deleteSelectedFiles(List<FileItem> selectedFiles) async {
    try {
      // Pokaż dialog z progressem
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return ProgressDialog(
            message: 'Deleting ${selectedFiles.length} file${selectedFiles.length == 1 ? '' : 's'}...',
            color: Colors.red,
          );
        },
      );

      final token = await TokenService.getToken();
      final username = await TokenService.getUsername();
      
      if (token == null || username == null) {
        Navigator.pop(context);
        NotificationService.showAuthError(context);
        return;
      }

      final folderPath = _currentPath.isEmpty ? username : '$username/$_currentPath';
      int deletedCount = 0;
      List<String> failedFiles = [];

      for (final file in selectedFiles) {
        try {
          final filePath = '$folderPath/${file.name}';
          final response = await ApiService.deleteFile(
            token: token,
            filePath: filePath,
          );

          if (response.statusCode == 200) {
            deletedCount++;
          } else {
            failedFiles.add(file.name);
          }
        } catch (e) {
          failedFiles.add(file.name);
        }
      }

      Navigator.pop(context); // Zamknij dialog

      if (!mounted) return;

      // Wyczyść cache dla bieżącej ścieżki
      await CacheService().clearFilesCache(username, _currentPath);
      
      // Aktualizuj lokalną listę plików
      setState(() {
        _files.removeWhere((file) => selectedFiles.any((selected) => selected.name == file.name));
        _selectedFiles.clear();
        _isSelectionMode = false;
      });

      // Pokaż komunikat o wyniku
      if (failedFiles.isEmpty) {
        _showDeleteSuccessDialog(deletedCount);
      } else {
        _showPartialDeleteDialog(deletedCount, failedFiles);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        final error = ErrorHandler.handleError(e, null);
        NotificationService.showEnhancedError(context, error);
      }
    }
  }

  void _showMoveDialog(List<FileItem> selectedFiles) {
    // TODO: Implement move functionality
    NotificationService.showInfo(
      context,
      'files.move_functionality_soon'.tr(),
      title: 'Info',
    );
  }

  List<FileItem> get _filteredFiles {
    List<FileItem> filtered = _files.where((file) {
      return file.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

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

    // Foldery zawsze na górze
    filtered.sort((a, b) {
      bool aIsFolder = a.type == 'folder';
      bool bIsFolder = b.type == 'folder';
      
      if (aIsFolder && !bIsFolder) return -1;
      if (!aIsFolder && bIsFolder) return 1;
      return 0; // Oba są folderami lub oba są plikami - zachowaj obecne sortowanie
    });

    return filtered;
  }

  double _parseSize(String size) {
    // Dla folderów, rozmiar ma format "34.6 (2 files, 0 folders)"
    // Wyciągamy tylko część z rozmiarem
    if (size.contains('(')) {
      String sizePart = size.split('(')[0].trim();
      if (sizePart.contains('MB')) {
        return double.parse(sizePart.replaceAll(' MB', ''));
      } else if (sizePart.contains('KB')) {
        return double.parse(sizePart.replaceAll(' KB', '')) / 1024;
      } else if (sizePart.contains('B')) {
        return double.parse(sizePart.replaceAll(' B', '')) / (1024 * 1024);
      }
    } else {
      // Dla plików, rozmiar ma format "34.6 MB" lub "1.2 KB"
      if (size.contains('MB')) {
        return double.parse(size.replaceAll(' MB', ''));
      } else if (size.contains('KB')) {
        return double.parse(size.replaceAll(' KB', '')) / 1024;
      } else if (size.contains('B')) {
        return double.parse(size.replaceAll(' B', '')) / (1024 * 1024);
      }
    }
    return 0;
  }

  IconData _getFileIcon(String type) {
    switch (type) {
      case 'folder':
        return Icons.folder;
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
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String type) {
    switch (type) {
      case 'folder':
        return Colors.amber;
      case 'pdf':
        return Colors.red;
      case 'image':
        return const Color(0xFF667eea);
      case 'video':
        return Colors.purple;
      case 'presentation':
        return Colors.orange;
      case 'spreadsheet':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: CustomDrawer(
        username: _email,
        currentRoute: '/files',
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
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isSelectionMode ? Icons.check_circle : Icons.folder,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isSelectionMode 
                    ? '${_selectedFiles.length} selected'
                    : 'My Files',
                  key: ValueKey(_isSelectionMode),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        leading: _isSelectionMode
          ? IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _toggleSelectionMode,
            )
          : null,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: Icon(
                _selectedFiles.length == _filteredFiles.length 
                  ? Icons.check_box_outline_blank 
                  : Icons.check_box,
                color: Colors.white,
              ),
              onPressed: _selectedFiles.length == _filteredFiles.length 
                ? _deselectAllFiles 
                : _selectAllFiles,
            ),
            if (_selectedFiles.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onPressed: _showSelectionActions,
              ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadFiles,
            ),
            IconButton(
              icon: const Icon(Icons.check_box_outline_blank, color: Colors.white),
              tooltip: 'Select multiple files',
              onPressed: _toggleSelectionMode,
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
        ],
      ),
      body: Column(
        children: [
          // BREADCRUMB
          Container(
            margin: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: _buildBreadcrumb(),
          ),
          // Search bar
          Container(
            margin: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667eea).withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'search.files'.tr(),
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.search, 
                    color: const Color(0xFF667eea),
                    size: 20,
                  ),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? Container(
                        margin: const EdgeInsets.all(8),
                        child: IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.clear, 
                              color: Colors.grey.shade600,
                              size: 16,
                            ),
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        ),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // Sort options, Add File button, and file count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                Row(
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
                                          : Colors.grey.shade600,
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
                                color: Colors.black.withValues(alpha: 0.05),
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
                    
                    // Add Files button
                    TextButton.icon(
                      onPressed: _uploadFile,
                      icon: Icon(Icons.add, size: 18, color: const Color(0xFF667eea)),
                      label: Text('files.add_files'.tr(), style: TextStyle(fontSize: 14, color: const Color(0xFF667eea))),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        foregroundColor: const Color(0xFF667eea),
                      ),
                    ),
                    
                    const SizedBox(width: 7),
                    
                    // File count
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667eea).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF667eea).withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _searchQuery.isNotEmpty 
                          ? '${_filteredFiles.length} of ${_files.length} files'
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
                if (!_isSelectionMode && _filteredFiles.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'files.tip_d'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Files list
          Expanded(
            child: _buildFilesList(),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667eea).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _showAddOptions,
          backgroundColor: const Color(0xFF667eea),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(4),
            child: const Icon(
              Icons.add,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilesList() {
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
                    color: Colors.black.withValues(alpha: 0.1),
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
                    'files.loading_files'.tr(),
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
                color: Colors.black.withValues(alpha: 0.1),
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
                'Error loading files',
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
                onPressed: _loadFiles,
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
                  'files.retry'.tr(),
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

    if (_filteredFiles.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return EmptyStateWidget(
          icon: Icons.search_off,
          title: 'No files found',
          subtitle: 'Try adjusting your search terms',
        );
      } else {
        return EmptyStateWidget(
          icon: Icons.folder_open,
          title: 'No files found',
          subtitle: 'Upload your first file to get started',
          onAction: _uploadFile,
          actionText: 'Upload File',
        );
      }
    }

    return _isGridView ? _buildGridView() : _buildListView();
  }

  Widget _buildListView() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: _filteredFiles.length,
      itemBuilder: (context, index) {
        final file = _filteredFiles[index];
        final isSelected = _selectedFiles.contains(file.name);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16.0),
          clipBehavior: Clip.antiAlias, // Dodane aby zapobiec overflow
          decoration: BoxDecoration(
            gradient: isSelected 
              ? LinearGradient(
                  colors: [
                    const Color(0xFF667eea).withValues(alpha: 0.15),
                    const Color(0xFF764ba2).withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
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
                color: isSelected 
                  ? const Color(0xFF667eea).withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.08),
                blurRadius: isSelected ? 15 : 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: isSelected 
              ? Border.all(
                  color: const Color(0xFF667eea), 
                  width: 2,
                )
              : Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
          ),
          child: Material(
            color: Colors.transparent,
            child: LongPressDraggable<String>(
            data: _isSelectionMode 
              ? (_selectedFiles.isNotEmpty ? _selectedFiles.join(',') : file.name) // W trybie wyboru: wszystkie zaznaczone lub pojedynczy
              : file.name, // Poza trybem wyboru: tylko pojedynczy plik
            onDragStarted: () {
              setState(() {
                _isDragging = true;
              });
            },
            onDragEnd: (details) {
              _stopAutoScroll();
            },
            onDragUpdate: (details) {
              _startAutoScroll(details);
            },
            feedback: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 200,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF667eea), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667eea).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      _isSelectionMode && _selectedFiles.isNotEmpty
                        ? Icons.folder_copy // Ikona dla wielu plików
                        : _getFileIcon(file.type),
                      color: _isSelectionMode && _selectedFiles.isNotEmpty
                        ? Colors.blue
                        : _getFileColor(file.type),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isSelectionMode && _selectedFiles.isNotEmpty
                          ? '${_selectedFiles.length} items'
                          : file.name,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            child: file.type == 'folder'
                ? DragTarget<String>(
                    onWillAccept: (data) => true,
                    onAccept: (data) {
                      _moveFilesToFolder(data, file.name);
                    },
                    builder: (context, candidateData, rejectedData) {
                      final isActive = candidateData.isNotEmpty;
                      return Container(
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.blue.withValues(alpha: 0.15)
                              : isSelected
                                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                                  : null,
                          borderRadius: BorderRadius.circular(8),
                          border: isActive
                              ? Border.all(color: Colors.blue, width: 2)
                              : null,
                        ),
                        child: GestureDetector(
                          onTap: () {
                            // Dodajemy małe opóźnienie aby uniknąć konfliktu z double tap
                            Future.delayed(const Duration(milliseconds: 200), () {
                              if (mounted) {
                                if (_isSelectionMode) {
                                  _toggleFileSelection(file.name);
                                } else if (file.type == 'folder') {
                                  _navigateToFolder(file.name);
                                } else if (FileUtils.isTextFile(file.name)) {
                                  _showTextFullScreen(file.name);
                                } else if (FileUtils.isSpreadsheet(file.name)) {
                                  _showSpreadsheetFullScreen(file.name);
                                } else if (FileUtils.isPdf(file.name)) {
                                  _showPdfFullScreen(file.name);
                                } else if (FileUtils.isImage(file.name)) {
                                  _showImageFullScreen(file);
                                }
                              }
                            });
                          },
                          onDoubleTap: () {
                            if (!_isSelectionMode) {
                              setState(() {
                                _isSelectionMode = true;
                              });
                            }
                            _toggleFileSelection(file.name);
                          },
                          child: ListTile(
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (_isSelectionMode)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Checkbox(
                                      value: isSelected,
                                      onChanged: (value) {
                                        _toggleFileSelection(file.name);
                                      },
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      activeColor: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                if (FileUtils.isImage(file.name))
                                  // Podgląd zdjęcia
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.1),
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
                                            filename: file.name,
                                            folderName: _currentPath.isEmpty ? username : _currentPath,
                                            width: 48,
                                            height: 48,
                                            showFullScreenOnTap: false,
                                            fit: BoxFit.cover,
                                          );
                                        },
                                      ),
                                    ),
                                  )
                                else if (FileUtils.isTextFile(file.name))
                                  // Podgląd pliku tekstowego
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.1),
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
                                            filename: file.name,
                                            folderName: _currentPath.isEmpty ? username : _currentPath,
                                            width: 48,
                                            height: 48,
                                            showFullScreenOnTap: false,
                                            fit: BoxFit.cover,
                                          );
                                        },
                                      ),
                                    ),
                                  )
                                                        else if (FileUtils.isSpreadsheet(file.name))
                          // Podgląd arkusza kalkulacyjnego
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
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
                                    filename: file.name,
                                    folderName: _currentPath.isEmpty ? username : _currentPath,
                                    width: 48,
                                    height: 48,
                                    showFullScreenOnTap: false,
                                    fit: BoxFit.cover,
                                  );
                                },
                              ),
                            ),
                          )
                        else if (FileUtils.isPdf(file.name))
                          // Podgląd PDF
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
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
                                    filename: file.name,
                                    folderName: _currentPath.isEmpty ? username : _currentPath,
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
                                      color: _getFileColor(file.type).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _getFileColor(file.type).withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      _getFileIcon(file.type),
                                      color: _getFileColor(file.type),
                                      size: 24,
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              file.name,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text('${file.size} • ${file.date}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (file.type != 'folder')
                                  GestureDetector(
                                    onTap: () {
                                      _toggleFavorite(file);
                                    },
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 300),
                                      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                                      child: Icon(
                                        file.isFavorite ? Icons.favorite : Icons.favorite_border,
                                        key: ValueKey(file.isFavorite),
                                        color: file.isFavorite ? Colors.red : Colors.grey,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    _handleFileAction(value, file);
                                  },
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 8,
                                  offset: const Offset(0, 8),
                                  itemBuilder: (context) => [
                                    if (file.type != 'folder')
                                      PopupMenuItem(
                                        value: 'download',
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF667eea).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(Icons.download_rounded, color: const Color(0xFF667eea), size: 18),
                                            ),
                                            const SizedBox(width: 12),
                                            const Text(
                                              'Download',
                                              style: TextStyle(fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      PopupMenuItem(
                                        value: 'download',
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF667eea).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(Icons.download_rounded, color: const Color(0xFF667eea), size: 18),
                                            ),
                                            const SizedBox(width: 12),
                                            const Text(
                                              'Download as ZIP',
                                              style: TextStyle(fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      ),
                                    PopupMenuItem(
                                      value: 'quick_share',
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.purple.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(Icons.qr_code, color: Colors.purple.shade600, size: 18),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'files.quick_share'.tr(),
                                            style: TextStyle(fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!_currentPath.contains('shared'))
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
                                              'share.title'.tr(),
                                              style: TextStyle(fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(Icons.delete_forever, color: Colors.red.shade600, size: 18),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Delete',
                                            style: TextStyle(fontWeight: FontWeight.w500, color: Colors.red.shade600),
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
                                              color: Colors.green.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(Icons.edit, color: Colors.green.shade600, size: 18),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Rename',
                                            style: TextStyle(fontWeight: FontWeight.w500, color: Colors.green.shade600),
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
                        )
                      );
                    },
                  )
                : GestureDetector(
                    onTap: () {
                      if (_isSelectionMode) {
                        _toggleFileSelection(file.name);
                      } else if (file.type == 'folder') {
                        _navigateToFolder(file.name);
                      } else if (FileUtils.isTextFile(file.name)) {
                        _showTextFullScreen(file.name);
                      } else if (FileUtils.isSpreadsheet(file.name)) {
                        _showSpreadsheetFullScreen(file.name);
                      } else if (FileUtils.isPdf(file.name)) {
                        _showPdfFullScreen(file.name);
                      } else if (FileUtils.isImage(file.name)) {
                        _showImageFullScreen(file);
                      }
                    },
                    onDoubleTap: () {
                      if (!_isSelectionMode) {
                        setState(() {
                          _isSelectionMode = true;
                        });
                      }
                      _toggleFileSelection(file.name);
                    },
                    child: ListTile(
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (_isSelectionMode)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Checkbox(
                                value: isSelected,
                                onChanged: (value) {
                                  _toggleFileSelection(file.name);
                                },
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                activeColor: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _getFileColor(file.type).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _getFileColor(file.type).withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              _getFileIcon(file.type),
                              color: _getFileColor(file.type),
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                      title: Text(
                        file.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('${file.size} • ${file.date}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (file.type != 'folder')
                            GestureDetector(
                              onTap: () {
                                _toggleFavorite(file);
                              },
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                                child: Icon(
                                  file.isFavorite ? Icons.favorite : Icons.favorite_border,
                                  key: ValueKey(file.isFavorite),
                                  color: file.isFavorite ? Colors.red : Colors.grey,
                                  size: 24,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              _handleFileAction(value, file);
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 8,
                            offset: const Offset(0, 8),
                            itemBuilder: (context) => [
                              if (file.type != 'folder')
                                PopupMenuItem(
                                  value: 'download',
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF667eea).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(Icons.download_rounded, color: const Color(0xFF667eea), size: 18),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Download',
                                        style: TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                PopupMenuItem(
                                  value: 'download',
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF667eea).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(Icons.download_rounded, color: const Color(0xFF667eea), size: 18),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Download as ZIP',
                                        style: TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              PopupMenuItem(
                                value: 'quick_share',
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.qr_code, color: Colors.purple.shade600, size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'files.quick_share'.tr(),
                                      style: TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                              if (!_currentPath.contains('shared'))
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
                                        'share.title'.tr(),
                                        style: TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.delete_forever, color: Colors.red.shade600, size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Delete',
                                      style: TextStyle(fontWeight: FontWeight.w500, color: Colors.red.shade600),
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
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.edit, color: const Color.fromARGB(255, 72, 162, 19), size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Rename',
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
                  ),
          ),
          )
        );
      },
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 0.85,
      ),
      itemCount: _filteredFiles.length,
      itemBuilder: (context, index) {
        final file = _filteredFiles[index];
        final isSelected = _selectedFiles.contains(file.name);
        
        return Container(
          decoration: BoxDecoration(
            gradient: isSelected 
              ? LinearGradient(
                  colors: [
                    const Color(0xFF667eea).withValues(alpha: 0.15),
                    const Color(0xFF764ba2).withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
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
                color: isSelected 
                  ? const Color(0xFF667eea).withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.08),
                blurRadius: isSelected ? 15 : 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: isSelected 
              ? Border.all(
                  color: const Color(0xFF667eea), 
                  width: 2,
                )
              : Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
          ),
          child: LongPressDraggable<String>(
            data: _isSelectionMode 
              ? (_selectedFiles.isNotEmpty ? _selectedFiles.join(',') : file.name) // W trybie wyboru: wszystkie zaznaczone lub pojedynczy
              : file.name, // Poza trybem wyboru: tylko pojedynczy plik
            onDragStarted: () {
              setState(() {
                _isDragging = true;
              });
            },
            onDragEnd: (details) {
              _stopAutoScroll();
            },
            onDragUpdate: (details) {
              _startAutoScroll(details);
            },
            feedback: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 150,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isSelectionMode && _selectedFiles.isNotEmpty
                        ? Icons.folder_copy // Ikona dla wielu plików
                        : _getFileIcon(file.type),
                      color: _isSelectionMode && _selectedFiles.isNotEmpty
                        ? Colors.blue
                        : _getFileColor(file.type),
                      size: 32,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isSelectionMode && _selectedFiles.isNotEmpty
                        ? '${_selectedFiles.length} items'
                        : file.name,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            child: file.type == 'folder'
                ? DragTarget<String>(
                    onWillAccept: (data) => true,
                    onAccept: (data) {
                      _moveFilesToFolder(data, file.name);
                    },
                    builder: (context, candidateData, rejectedData) {
                      final isActive = candidateData.isNotEmpty;
                      return Container(
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.blue.withValues(alpha: 0.15)
                              : isSelected
                                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                                  : null,
                          borderRadius: BorderRadius.circular(8),
                          border: isActive
                              ? Border.all(color: Colors.blue, width: 2)
                              : null,
                        ),
                        child: GestureDetector(
                          onTap: () {
                            if (_isSelectionMode) {
                              _toggleFileSelection(file.name);
                            } else if (file.type == 'folder') {
                              _navigateToFolder(file.name);
                            } else if (FileUtils.isTextFile(file.name)) {
                              _showTextFullScreen(file.name);
                            } else if (FileUtils.isSpreadsheet(file.name)) {
                              _showSpreadsheetFullScreen(file.name);
                            } else if (FileUtils.isPdf(file.name)) {
                              _showPdfFullScreen(file.name);
                            } else if (FileUtils.isImage(file.name)) {
                              _showImageFullScreen(file);
                            }
                          },
                          onDoubleTap: () {
                            if (!_isSelectionMode) {
                              setState(() {
                                _isSelectionMode = true;
                              });
                            }
                            _toggleFileSelection(file.name);
                          },
                          child: _buildGridItem(file, isSelected),
                        ),
                      );
                    },
                  )
                : GestureDetector(
                    onTap: () {
                      // Dodajemy małe opóźnienie aby uniknąć konfliktu z double tap
                      Future.delayed(const Duration(milliseconds: 200), () {
                        if (mounted) {
                          if (_isSelectionMode) {
                            _toggleFileSelection(file.name);
                          } else if (file.type == 'folder') {
                            _navigateToFolder(file.name);
                          } else if (FileUtils.isTextFile(file.name)) {
                            _showTextFullScreen(file.name);
                          } else if (FileUtils.isSpreadsheet(file.name)) {
                            _showSpreadsheetFullScreen(file.name);
                          } else if (FileUtils.isPdf(file.name)) {
                            _showPdfFullScreen(file.name);
                          } else if (FileUtils.isImage(file.name)) {
                            _showImageFullScreen(file);
                          }
                        }
                      });
                    },
                    onDoubleTap: () {
                      if (!_isSelectionMode) {
                        setState(() {
                          _isSelectionMode = true;
                        });
                      }
                      _toggleFileSelection(file.name);
                    },
                    child: _buildGridItem(file, isSelected),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildGridItem(FileItem file, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          // Górny rząd: serduszko po lewej, checkbox i menu po prawej
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Serduszko (ulubione) po lewej
              if (file.type != 'folder')
                GestureDetector(
                  onTap: () {
                    _toggleFavorite(file);
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                    child: Icon(
                      file.isFavorite ? Icons.favorite : Icons.favorite_border,
                      key: ValueKey(file.isFavorite),
                      color: file.isFavorite ? Colors.red : Colors.grey,
                      size: 18,
                    ),
                  ),
                )
              else
                const SizedBox(width: 18), // Placeholder dla folderów
              
              // Checkbox i menu po prawej
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isSelectionMode)
                    Checkbox(
                      value: isSelected,
                      onChanged: (value) {
                        _toggleFileSelection(file.name);
                      },
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      _handleFileAction(value, file);
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 8,
                    offset: const Offset(0, 8),
                    icon: const Icon(Icons.more_vert, size: 18),
                    itemBuilder: (context) => [
                      if (file.type != 'folder')
                        PopupMenuItem(
                          value: 'download',
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF667eea).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.download_rounded, color: const Color(0xFF667eea), size: 18),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Download',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        )
                      else
                        PopupMenuItem(
                          value: 'download',
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF667eea).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.download_rounded, color: const Color(0xFF667eea), size: 18),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Download as ZIP',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'quick_share',
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.qr_code, color: Colors.purple.shade600, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'files.quick_share'.tr(),
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      if (!_currentPath.contains('shared'))
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
                                'share.title'.tr(),
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.delete_forever, color: Colors.red.shade600, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Delete',
                              style: TextStyle(fontWeight: FontWeight.w500, color: Colors.red.shade600),
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
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.edit, color: Colors.green.shade600, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Rename',
                              style: TextStyle(fontWeight: FontWeight.w500, color: Colors.green.shade600),
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
            ],
          ),
          
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Środkowa część: ikona pliku lub podgląd zdjęcia
                if (FileUtils.isImage(file.name))
                  // Podgląd zdjęcia
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: FutureBuilder<String?>(
                        future: TokenService.getUsername(),
                        builder: (context, snapshot) {
                          final username = snapshot.data ?? 'unknown';
                          return ImagePreviewWidget(
                            filename: file.name,
                            folderName: _currentPath.isEmpty ? username : _currentPath,
                            width: 80,
                            height: 80,
                            showFullScreenOnTap: false, // Nie otwieraj pełnego ekranu przy tap na miniaturę
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                    ),
                  )
                else if (FileUtils.isTextFile(file.name))
                  // Ikona pliku tekstowego (bez podglądu w grid view)
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _getFileColor(file.type).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getFileColor(file.type).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      _getFileIcon(file.type),
                      color: _getFileColor(file.type),
                      size: 36,
                    ),
                  )
                                        else if (FileUtils.isSpreadsheet(file.name))
                          // Ikona arkusza kalkulacyjnego (bez podglądu w grid view)
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: _getFileColor(file.type).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getFileColor(file.type).withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              _getFileIcon(file.type),
                              color: _getFileColor(file.type),
                              size: 36,
                            ),
                          )
                        else if (FileUtils.isPdf(file.name))
                          // Ikona PDF (bez podglądu w grid view)
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: _getFileColor(file.type).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getFileColor(file.type).withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              _getFileIcon(file.type),
                              color: _getFileColor(file.type),
                              size: 36,
                            ),
                          )
                else
                  // Ikona pliku
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _getFileColor(file.type).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getFileColor(file.type).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      _getFileIcon(file.type),
                      color: _getFileColor(file.type),
                      size: 36,
                    ),
                  ),
                
                const SizedBox(height: 8),
                
                // Nazwa pliku w środku
                Expanded(
                  child: Center(
                    child: Text(
                      file.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Dolna część: data i rozmiar
          Text(
            '${file.size} • ${file.date}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _handleFileAction(String action, FileItem file) {
    switch (action) {
      case 'download':
        if (file.type == 'folder') {
          _downloadSelectedFiles([file]); // Folder będzie pobrany jako ZIP
        } else {
          _downloadSelectedFiles([file]); // Plik będzie pobrany bezpośrednio
        }
        break;
      case 'quick_share':
        _createQuickShare(file);
        break;
      case 'share':
        _showShareDialog(file);
        break;
      case 'rename':
        _showRenameDialog(file);
        break;
      case 'delete':
        _showDeleteConfirmationDialog(file);
        break;
      case 'info':
        _showFileInfo(file);
        break;
    }
  }

  void _showImageFullScreen(FileItem file) {
    // Pobierz wszystkie pliki multimedialne w bieżącym folderze
    final mediaFiles = _filteredFiles.where((f) => 
      FileUtils.isImage(f.name) || FileUtils.isVideo(f.name)
    ).toList();
    
    // Znajdź indeks bieżącego pliku
    final currentIndex = mediaFiles.indexWhere((f) => f.name == file.name);
    
    if (currentIndex == -1) {
      // Jeśli plik nie jest multimedialny, pokaż pojedynczy widok
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FutureBuilder<String?>(
            future: TokenService.getUsername(),
            builder: (context, snapshot) {
              final username = snapshot.data ?? 'unknown';
              return FullScreenImageView(
                imageUrl: '${ApiService.baseUrl}/files/${_currentPath.isEmpty ? username : _currentPath}/${file.name}',
                filename: file.name,
              );
            },
          ),
        ),
      );
      return;
    }
    
    // Pobierz username dla folderName
    TokenService.getUsername().then((username) {
      if (username != null) {
        // Utwórz listę plików dla galerii z poprawną ścieżką
        final images = mediaFiles.map((f) => {
          'filename': f.name,
          'folderName': _currentPath.isEmpty ? username : '$username/$_currentPath',
        }).toList();
        

        
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ImageGalleryView(
              images: images,
              initialIndex: currentIndex,
            ),
          ),
        );
      }
    });
  }

  void _showTextFullScreen(String filename) {
    TokenService.getUsername().then((username) {
      if (username != null) {
        final folderName = _currentPath.isEmpty ? username : _currentPath;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FullScreenTextView(
              filename: filename,
              folderName: folderName,
            ),
          ),
        );
      }
    });
  }

  void _showSpreadsheetFullScreen(String filename) {
    TokenService.getUsername().then((username) {
      if (username != null) {
        final folderName = _currentPath.isEmpty ? username : _currentPath;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FullScreenSpreadsheetView(
              filename: filename,
              folderName: folderName,
            ),
          ),
        );
      }
    });
  }

  void _showPdfFullScreen(String filename) {
    TokenService.getUsername().then((username) {
      if (username != null) {
        final folderName = _currentPath.isEmpty ? username : _currentPath;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FullScreenPdfView(
              filename: filename,
              folderName: folderName,
            ),
          ),
        );
      }
    });
  }

  void _showShareDialog(FileItem file) {
    final TextEditingController emailController = TextEditingController();
    bool shareWithUser = true;
    List<Map<String, dynamic>> groups = [];
    String? selectedGroupName;
    bool isLoadingGroups = false;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('share.title'.tr()),
              content: SizedBox(
                width: 400,
                height: 400,
                child: Column(
                  children: [
                    // Toggle buttons
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => shareWithUser = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: shareWithUser ? const Color(0xFF667eea) : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'share.with_user'.tr(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: shareWithUser ? Colors.white : Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                shareWithUser = false;
                                selectedGroupName = null;
                              });
                              // Załaduj grupy gdy przełączamy na grupy
                              if (groups.isEmpty && !isLoadingGroups) {
                                _loadGroupsForSharing(setState, groups, isLoadingGroups);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: !shareWithUser ? const Color(0xFF667eea) : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'share.with_group'.tr(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: !shareWithUser ? Colors.white : Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Content area
                    if (shareWithUser) ...[
                      Text('share.enter_email_or_username'.tr()),
                      const SizedBox(height: 16),
                      TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: 'share.email_or_username'.tr(),
                          border: const OutlineInputBorder(),
                          hintText: 'share.email_or_username_hint'.tr(),
                        ),
                      ),
                    ] else ...[
                      Text(
                        'share.select_group'.tr(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (isLoadingGroups)
                        const Center(
                          child: CircularProgressIndicator(),
                        )
                      else if (groups.isEmpty)
                        Center(
                          child: Text(
                            'share.no_groups_available'.tr(),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            itemCount: groups.length,
                            itemBuilder: (context, index) {
                              final group = groups[index];
                              final isSelected = selectedGroupName == group['name'];
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF667eea).withValues(alpha: 0.1) : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF667eea) : Colors.grey[300]!,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF667eea).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        group['name'][0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Color(0xFF667eea),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    group['name'],
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (group['description'] != null && group['description'].isNotEmpty)
                                        Text(
                                          group['description'],
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.people,
                                            size: 14,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${group['member_count']} ${'groups.members'.tr()}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: isSelected
                                      ? const Icon(
                                          Icons.check_circle,
                                          color: Color(0xFF667eea),
                                          size: 24,
                                        )
                                      : null,
                                  onTap: () {
                                    setState(() {
                                      selectedGroupName = group['name'];
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('share.cancel'.tr()),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (shareWithUser) {
                      final text = emailController.text.trim();
                      if (text.isNotEmpty) {
                        Navigator.of(context).pop();
                        _shareFile(file, text);
                      }
                    } else {
                      if (selectedGroupName != null) {
                        Navigator.of(context).pop();
                        _shareFileWithGroup(file, selectedGroupName!);
                      }
                    }
                  },
                  child: Text('share.share'.tr()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _shareFile(FileItem file, String shareWith) async {
    try {
      // Pokaż dialog z progressem
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return ProgressDialog(
            message: 'share.sharing'.tr(namedArgs: {'filename': file.name, 'user': shareWith}),
            color: Colors.blue,
          );
        },
      );

      final token = await TokenService.getToken();
      final username = await TokenService.getUsername();
      
      if (token == null || username == null) {
        Navigator.pop(context); // Zamknij dialog
        _showSessionExpiredDialog();
        return;
      }

      http.Response response;
      
      if (file.type == 'folder') {
        // Udostępnianie folderu
        final folderPath = _currentPath.isEmpty ? username : '$username/$_currentPath';
        final fullFolderPath = '$folderPath/${file.name}';
        
        response = await ApiService.shareFolder(
          token: token,
          folderPath: fullFolderPath,
          shareWith: shareWith,
        );
      } else {
        // Udostępnianie pliku
        final folderPath = _currentPath.isEmpty ? username : '$username/$_currentPath';
        
        response = await ApiService.shareFile(
          token: token,
          filename: file.name,
          folderName: folderPath,
          shareWith: shareWith,
        );
      }

      Navigator.pop(context); // Zamknij dialog

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        NotificationService.showFileShared(context, file.name, shareWith);
      } else {
        final data = jsonDecode(response.body);
        final errorMessage = data['detail'] ?? response.body;
        NotificationService.showValidationError(context, errorMessage);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Zamknij dialog jeśli jest otwarty
        final error = ErrorHandler.handleError(e, null);
        NotificationService.showEnhancedError(context, error);
      }
    }
  }

  Future<void> _createQuickShare(FileItem file) async {
    try {
      // Pokaż dialog z progressem
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
                  return ProgressDialog(
          message: 'files.creating_quick_share'.tr(),
          color: Colors.blue,
        );
        },
      );

      final token = await TokenService.getToken();
      final username = await TokenService.getUsername();
      
      if (token == null || username == null) {
        Navigator.pop(context); // Zamknij dialog
        _showSessionExpiredDialog();
        return;
      }

      // Przygotuj ścieżkę pliku
      final folderPath = _currentPath.isEmpty ? username : '$username/$_currentPath';
      final filePath = '$folderPath/${file.name}';

      final response = await ApiService.createQuickShare(
        token: token,
        filePath: filePath,
      );

      Navigator.pop(context); // Zamknij dialog

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final shareUrl = data['share_url'];
        final expiresAt = data['expires_at'];
        
        // Pokaż dialog z kodem QR
        final itemType = file.type == 'folder' ? 'folder' : 'file';
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return QRCodeDialog(
              data: shareUrl,
              title: '${'files.quick_share'.tr()}: ${file.name}',
              subtitle: 'Scan this QR code to download the $itemType\nExpires: ${DateTime.parse(expiresAt).toString().substring(0, 19)}',
            );
          },
        );
      } else {
        final data = jsonDecode(response.body);
        final errorMessage = data['detail'] ?? response.body;
        NotificationService.showValidationError(context, errorMessage);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Zamknij dialog jeśli jest otwarty
        final error = ErrorHandler.handleError(e, null);
        NotificationService.showEnhancedError(context, error);
      }
    }
  }

  Future<void> _loadGroupsForSharing(
    StateSetter setState,
    List<Map<String, dynamic>> groups,
    bool isLoadingGroups,
  ) async {
    setState(() {
      isLoadingGroups = true;
    });

    try {
      final token = await TokenService.getToken();
      if (token == null) {
        setState(() {
          isLoadingGroups = false;
        });
        return;
      }

      final response = await ApiService.listGroups(token: token);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          groups.clear();
          groups.addAll(List<Map<String, dynamic>>.from(data['groups']));
          isLoadingGroups = false;
        });
      } else {
        setState(() {
          isLoadingGroups = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoadingGroups = false;
      });
    }
  }

  Future<void> _shareFileWithGroup(FileItem file, String groupName) async {
    try {
      // Pokaż dialog z progressem
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return ProgressDialog(
            message: 'share.sharing_with_group'.tr(namedArgs: {'filename': file.name, 'group': groupName}),
            color: Colors.blue,
          );
        },
      );

      final token = await TokenService.getToken();
      final username = await TokenService.getUsername();
      
      if (token == null || username == null) {
        Navigator.pop(context); // Zamknij dialog
        _showSessionExpiredDialog();
        return;
      }

      http.Response response;
      
      if (file.type == 'folder') {
        // Udostępnianie folderu grupie
        final folderPath = _currentPath.isEmpty ? username : '$username/$_currentPath';
        final fullFolderPath = '$folderPath/${file.name}';
        
        // Dla folderów, file.name to nazwa folderu, więc fullFolderPath to ścieżka do folderu
        // Ale jeśli _currentPath już zawiera file.name, to nie dodajemy go ponownie
        final actualFolderPath = _currentPath.endsWith(file.name) 
            ? '$username/$_currentPath' 
            : fullFolderPath;
        
        response = await ApiService.shareFolderWithGroup(
          folderPath: actualFolderPath,
          groupName: groupName,
          token: token,
        );
      } else {
        // Udostępnianie pliku grupie
        final folderPath = _currentPath.isEmpty ? username : '$username/$_currentPath';
        
        response = await ApiService.shareFileWithGroup(
          filename: file.name,
          folderName: folderPath,
          groupName: groupName,
          token: token,
        );
      }

      Navigator.pop(context); // Zamknij dialog

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        NotificationService.showFileSharedWithGroup(context, file.name, groupName);
      } else {
        final data = jsonDecode(response.body);
        final errorMessage = data['detail'] ?? response.body;
        NotificationService.showValidationError(context, errorMessage);
      }
    } catch (e) {
      Navigator.pop(context); // Zamknij dialog
      if (!mounted) return;
      NotificationService.showValidationError(context, 'Network error: $e');
    }
  }

  void _showFileInfo(FileItem file) async {
    final email = await TokenService.getEmail();
    final location = _currentPath.isEmpty ? email ?? 'Unknown' : '${email ?? 'Unknown'}/$_currentPath';
    
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
              _buildInfoRow('Location', location),
              if (file.isFavorite) _buildInfoRow('Status', 'Favorited'),
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

  void _showDeleteConfirmationDialog(FileItem file) {
    final itemType = file.type == 'folder' ? 'folder' : 'file';
    final itemName = file.name;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ConfirmationDialog(
          title: 'Delete $itemType',
          message: 'Are you sure you want to delete "$itemName"? This action cannot be undone.',
          confirmText: 'Delete',
          cancelText: 'Cancel',
          icon: Icons.delete_forever,
          iconColor: Colors.red.shade600,
          onConfirm: () {
            _deleteFile(file);
          },
        );
      },
    );
  }

  Future<void> _deleteFile(FileItem file) async {
    try {
      // Pokaż dialog z progressem
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return ProgressDialog(
            message: 'Deleting file...',
            color: Colors.red,
          );
        },
      );

      final token = await TokenService.getToken();
      final username = await TokenService.getUsername();
      
      if (token == null || username == null) {
        Navigator.pop(context); // Zamknij dialog
        _showSessionExpiredDialog();
        return;
      }

      // Utwórz ścieżkę do pliku
      final folderPath = _currentPath.isEmpty ? username : '$username/$_currentPath';
      final filePath = '$folderPath/${file.name}';
      
      final response = await ApiService.deleteFile(
        token: token,
        filePath: filePath,
      );

      Navigator.pop(context); // Zamknij dialog

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Wyczyść cache dla bieżącej ścieżki
        await CacheService().clearFilesCache(username, _currentPath);
        
        // Usuń plik z lokalnej listy
        setState(() {
          _files.removeWhere((f) => f.name == file.name);
        });
        
        // Dodaj aktywność
        await ActivityService.addActivity(
          ActivityService.createFileDeleteActivity(file.name),
        );
        
        // Pokaż komunikat o sukcesie
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${file.name} deleted successfully'),
            backgroundColor: const Color(0xFF667eea),
          ),
        );
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete ${file.name}: ${data['detail'] ?? response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Zamknij dialog jeśli jest otwarty
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting ${file.name}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleFavorite(FileItem file) async {
    if (file.type == 'folder') {
      NotificationService.showInfo(
        context,
        'files.folders_cannot_favorited'.tr(),
        title: 'Info',
      );
      return;
    }

    // Optymistyczna zmiana stanu
    final fileIndex = _files.indexWhere((f) => f.name == file.name);
    if (fileIndex == -1) return;
    final prevFavorite = _files[fileIndex].isFavorite;
    setState(() {
      _files[fileIndex] = FileItem(
        name: _files[fileIndex].name,
        size: _files[fileIndex].size,
        date: _files[fileIndex].date,
        type: _files[fileIndex].type,
        isFavorite: !prevFavorite,
      );
    });

    try {
      final token = await TokenService.getToken();
      final username = await TokenService.getUsername();
      
      if (token == null || username == null) {
        NotificationService.showAuthError(context);
        // Cofnij zmianę
        setState(() {
          _files[fileIndex] = FileItem(
            name: _files[fileIndex].name,
            size: _files[fileIndex].size,
            date: _files[fileIndex].date,
            type: _files[fileIndex].type,
            isFavorite: prevFavorite,
          );
        });
        return;
      }

      final folderPath = _currentPath.isEmpty ? username : '$username/$_currentPath';
      
      // Debug printy
      print('=== DEBUG: toggleFavorite ===');
      print('File name: ${file.name}');
      print('Current path: $_currentPath');
      print('Folder path: $folderPath');
      print('Username: $username');
      print('Previous favorite state: $prevFavorite');
      print('===========================');
      
      final response = await ApiService.toggleFavorite(
        filename: file.name, // Tylko nazwa pliku
        folderName: folderPath, // Pełna ścieżka folderu
        token: token,
      );

      // Debug response
      print('=== DEBUG: Response ===');
      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');
      print('=====================');

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Nic nie rób, stan już zaktualizowany optymistycznie
        print('✅ Successfully toggled favorite for: ${file.name}');
        
        // Dodaj aktywność (bez powiadomienia o sukcesie)
        if (!prevFavorite) {
          await ActivityService.addActivity(
            ActivityService.createFileFavoriteActivity(file.name),
          );
        } else {
          await ActivityService.addActivity(
            ActivityService.createFileUnfavoriteActivity(file.name),
          );
        }
      } else {
        // Cofnij zmianę i pokaż błąd
        setState(() {
          _files[fileIndex] = FileItem(
            name: _files[fileIndex].name,
            size: _files[fileIndex].size,
            date: _files[fileIndex].date,
            type: _files[fileIndex].type,
            isFavorite: prevFavorite,
          );
        });
        print('❌ Failed to toggle favorite for: ${file.name}');
        

        
        NotificationService.showValidationError(context, response.body);
      }
    } catch (e) {
      // Cofnij zmianę i pokaż błąd
      setState(() {
        _files[fileIndex] = FileItem(
          name: _files[fileIndex].name,
          size: _files[fileIndex].size,
          date: _files[fileIndex].date,
          type: _files[fileIndex].type,
          isFavorite: prevFavorite,
        );
      });
      

      
      final error = ErrorHandler.handleError(e, null);
      NotificationService.showEnhancedError(context, error);
    }
  }

  void _showUploadSuccessDialog(String fileName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animowana ikona sukcesu
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 60,
                    color: const Color(0xFF667eea),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Tytuł
                const Text(
                  'Upload Successful!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Nazwa pliku
                Text(
                  fileName,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                
                // Opis
                const Text(
                  'Your file has been uploaded successfully to your storage.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // Przycisk OK
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMultipleUploadSuccessDialog(List<String> successfulFiles) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animowana ikona sukcesu
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 60,
                    color: const Color(0xFF667eea),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Tytuł
                const Text(
                  'Upload Successful!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Liczba plików
                Text(
                  '${successfulFiles.length} files uploaded successfully!',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                
                // Opis
                const Text(
                  'Your files have been uploaded successfully to your storage.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // Przycisk OK
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPartialUploadDialog(List<String> successfulFiles, List<String> failedFiles) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animowana ikona sukcesu
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.info,
                    size: 60,
                    color: Colors.orange.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Tytuł
                const Text(
                  'Upload Completed with Errors',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Liczba plików
                Text(
                  '${successfulFiles.length} files uploaded successfully, ${failedFiles.length} failed.',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                
                // Opis
                const Text(
                  'Some files might have failed to upload. Please check the console for details.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // Przycisk OK
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUploadFailureDialog(List<String> failedFiles) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animowana ikona błędu
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error,
                    size: 60,
                    color: Colors.red.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Tytuł
                const Text(
                  'Upload Failed',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Liczba plików
                Text(
                  '${failedFiles.length} files failed to upload.',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                
                // Opis
                const Text(
                  'Please check your internet connection and try again.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // Przycisk OK
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFolderCreatedSuccessDialog(String folderName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SuccessDialog(
          title: 'Folder Created!',
          message: 'Folder "$folderName" has been created successfully.',
        );
      },
    );
  }

  void _showDeleteSuccessDialog(int deletedCount) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SuccessDialog(
          title: 'Delete Successful!',
          message: '$deletedCount file${deletedCount == 1 ? '' : 's'} deleted\nThe selected files have been permanently deleted.',
        );
      },
    );
  }

  void _showPartialDeleteDialog(int deletedCount, List<String> failedFiles) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animowana ikona częściowego sukcesu
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.info,
                    size: 60,
                    color: Colors.orange.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Tytuł
                const Text(
                  'Delete Completed with Errors',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Liczba plików
                Text(
                  '$deletedCount deleted, ${failedFiles.length} failed',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                
                // Opis
                const Text(
                  'Some files could not be deleted. Please try again later.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // Przycisk OK
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadSelectedFiles(List<FileItem> selectedFiles) async {
    try {
      final token = await TokenService.getToken();
      final username = await TokenService.getUsername();
      
      if (token == null || username == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not logged in. Please login again.')),
        );
        return;
      }

      // Sprawdź czy są foldery w zaznaczonych plikach
      final hasFolders = selectedFiles.any((file) => file.type == 'folder');
      final hasFiles = selectedFiles.any((file) => file.type != 'folder');

      // Jeśli są tylko pojedyncze pliki (bez folderów), pobierz je bezpośrednio
      if (!hasFolders && hasFiles) {
        await _downloadSingleFiles(selectedFiles, token, username);
        return;
      }

      // Jeśli są foldery lub mieszanka, użyj ZIP
      await _downloadAsZip(selectedFiles, token, username);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadSingleFiles(List<FileItem> files, String token, String username) async {
    // Pokaż dialog z progressem
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ProgressDialog(
          message: 'Downloading ${files.length} file${files.length == 1 ? '' : 's'}...',
          color: Colors.blue,
        );
      },
    );

    try {
      final folderPath = _currentPath.isEmpty ? username : '$username/$_currentPath';
      int downloadedCount = 0;
      List<String> failedFiles = [];

      for (final file in files) {
        try {
          final filePath = '$folderPath/${file.name}';
          final response = await ApiService.downloadFile(
            token: token,
            filePath: filePath,
          );

          if (response.statusCode == 200) {
            // Zapisz plik na urządzeniu
            final directory = await getDownloadsDirectory();
            if (directory != null) {
              final localFile = File('${directory.path}/${file.name}');
              await localFile.writeAsBytes(response.bodyBytes);
              downloadedCount++;
            } else {
              failedFiles.add(file.name);
            }
          } else {
            failedFiles.add(file.name);
          }
        } catch (e) {
          failedFiles.add(file.name);
        }
      }

      Navigator.pop(context); // Zamknij dialog

      if (!mounted) return;

      if (failedFiles.isEmpty) {
        _showDownloadSuccessDialog(downloadedCount);
      } else {
        _showPartialDownloadDialog(downloadedCount, failedFiles);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadAsZip(List<FileItem> selectedFiles, String token, String username) async {
    // Pokaż dialog z progressem
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ProgressDialog(
          message: 'Creating ZIP archive...',
          color: Colors.blue,
        );
      },
    );

    try {
      // Przygotuj ścieżki plików do pobrania
      final folderPath = _currentPath.isEmpty ? username : '$username/$_currentPath';
      final filePaths = selectedFiles.map((file) => '$folderPath/${file.name}').toList();

      final response = await ApiService.downloadFilesAsZip(
        token: token,
        filePaths: filePaths,
      );

      Navigator.pop(context); // Zamknij dialog

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Pobierz nazwę pliku ZIP z nagłówków odpowiedzi
        final contentDisposition = response.headers['content-disposition'];
        String? zipFilename;
        
        if (contentDisposition != null) {
          final filenameMatch = RegExp(r'filename="([^"]+)"').firstMatch(contentDisposition);
          if (filenameMatch != null) {
            zipFilename = filenameMatch.group(1);
          }
        }
        
        // Jeśli nie udało się pobrać nazwy z nagłówków, użyj domyślnej
        if (zipFilename == null) {
          zipFilename = '${username}_files_${DateTime.now().millisecondsSinceEpoch}.zip';
        }
        
        // Pobierz dane pliku
        final bytes = response.bodyBytes;
        
        // Zapisz plik na urządzeniu użytkownika
        try {
          final directory = await getDownloadsDirectory();
          if (directory == null) {
            throw Exception('Could not access downloads directory');
          }
          
          final file = File('${directory.path}/$zipFilename');
          await file.writeAsBytes(bytes);
          
          _showDownloadSuccessDialog(selectedFiles.length);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save file: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        
        // Wyczyść plik ZIP na serwerze
        try {
          await ApiService.cleanupZip(
            token: token,
            zipFilename: zipFilename,
          );
        } catch (e) {
          // Ignore cleanup errors
          print('Failed to cleanup ZIP file: $e');
        }
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download files: ${data['detail'] ?? response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Zamknij dialog jeśli jest otwarty
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDownloadSuccessDialog(int downloadedCount) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SuccessDialog(
          title: 'Download Successful!',
          message: '$downloadedCount file${downloadedCount == 1 ? '' : 's'} downloaded\nThe selected files have been downloaded to your device.',
        );
      },
    );
  }

  void _showPartialDownloadDialog(int downloadedCount, List<String> failedFiles) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animowana ikona częściowego sukcesu
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.info,
                    size: 60,
                    color: Colors.orange.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Tytuł
                const Text(
                  'Download Completed with Errors',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Liczba plików
                Text(
                  '$downloadedCount downloaded, ${failedFiles.length} failed',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                
                // Opis
                const Text(
                  'Some files might have failed to download. Please check the console for details.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // Przycisk OK
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _moveFilesToFolder(String data, String destinationFolder) async {
    await _moveFileToFolder(data, destinationFolder);
  }

  Future<void> _moveFilesToParentFolder(String data) async {
    await _moveFileToParentFolder(data);
  }

  Future<void> _moveFilesToSpecificFolder(String data, String targetPath) async {
    await _moveFileToSpecificFolder(data, targetPath);
  }

  Future<void> _moveFilesToRootFolder(String data) async {
    await _moveFileToRootFolder(data);
  }

  Future<void> _moveFileToFolder(String fileName, String destinationFolder) async {
    try {
      // Sprawdź czy to wiele plików (oddzielonych przecinkami)
      final fileNames = fileName.split(',');
      final isMultipleFiles = fileNames.length > 1;
      // Pokaż dialog z progressem
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return ProgressDialog(
            message: isMultipleFiles 
              ? 'files.moving_multiple_items'.tr(namedArgs: {'count': fileNames.length.toString(), 'folder': destinationFolder})
              : 'files.moving_single_item'.tr(namedArgs: {'filename': fileName, 'folder': destinationFolder}),
            color: Colors.blue,
          );
        },
      );
      final token = await TokenService.getToken();
      final username = await TokenService.getUsername();
      if (token == null || username == null) {
        Navigator.pop(context); // Zamknij dialog
        _showSessionExpiredDialog();
        return;
      }
      // Przygotuj ścieżki
      final currentFolderPath = _currentPath.isEmpty ? username : '$username/$_currentPath';
      final destinationPath = '$currentFolderPath/$destinationFolder';
      
      // Sprawdź czy próbujemy przenieść do tego samego folderu
      final currentFolderName = _currentPath.isEmpty ? '' : _currentPath.split('/').last;
      if (destinationFolder.isEmpty || destinationFolder == '.' || destinationFolder == currentFolderName) {
        Navigator.pop(context); // Zamknij dialog
        if (!mounted) return;
        _showSameFolderDialog(fileName);
        return;
      }
      
      bool allSuccess = true;
      String errorMessage = '';
      // Przenieś wszystkie pliki
      for (final singleFileName in fileNames) {
        final sourcePath = '$currentFolderPath/$singleFileName';
        final response = await ApiService.moveFile(
          token: token,
          sourcePath: sourcePath,
          destinationFolder: destinationPath,
        );
        if (response.statusCode != 200) {
          allSuccess = false;
          final data = jsonDecode(response.body);
          errorMessage = data['detail'] ?? response.body;
          
          // Sprawdź czy to błąd związany z tym samym folderem
          if (errorMessage.toLowerCase().contains('same') || 
              errorMessage.toLowerCase().contains('already') ||
              errorMessage.toLowerCase().contains('exists')) {
            Navigator.pop(context); // Zamknij dialog
            if (!mounted) return;
            _showSameFolderDialog(singleFileName);
            return;
          }
          break;
        }
      }
      Navigator.pop(context); // Zamknij dialog
      if (!mounted) return;
      if (allSuccess) {
        // Dodaj aktywności dla każdego przeniesionego pliku
        for (final singleFileName in fileNames) {
          await ActivityService.addActivity(
            ActivityService.createFileMoveActivity(singleFileName, destinationFolder),
          );
        }
        
        // Wyczyść cache dla bieżącej ścieżki
        await CacheService().clearFilesCache(username, _currentPath);
        // Odśwież listę plików
        await _loadFiles();
        // Wyjdź z trybu wyboru jeśli przeniesiono wiele plików
        if (isMultipleFiles) {
          setState(() {
            _isSelectionMode = false;
            _selectedFiles.clear();
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isMultipleFiles 
              ? 'files.moved_multiple_success'.tr(namedArgs: {'count': fileNames.length.toString(), 'folder': destinationFolder})
              : 'files.moved_single_success'.tr(namedArgs: {'filename': fileName, 'folder': destinationFolder})),
            backgroundColor: const Color(0xFF667eea),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('files.failed_to_move_files'.tr(args: [errorMessage])),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Zamknij dialog jeśli jest otwarty
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('files.error_moving_files'.tr(args: [e.toString()])),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _moveFileToParentFolder(String fileName) async {
    try {
      // Sprawdź czy to wiele plików (oddzielonych przecinkami)
      final fileNames = fileName.split(',');
      final isMultipleFiles = fileNames.length > 1;
      // Pokaż dialog z progressem
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return ProgressDialog(
            message: isMultipleFiles 
              ? 'Moving ${fileNames.length} items to parent folder...'
              : 'Moving $fileName to parent folder...',
            color: Colors.blue,
          );
        },
      );
      final token = await TokenService.getToken();
      final username = await TokenService.getUsername();
      if (token == null || username == null) {
        Navigator.pop(context); // Zamknij dialog
        _showSessionExpiredDialog();
        return;
      }
      // Przygotuj ścieżki - folder nadrzędny
      final currentFolderPath = _currentPath.isEmpty ? username : '$username/$_currentPath';
      final parentPath = _currentPath.isEmpty ? username : '$username/${_currentPath.split('/').sublist(0, _currentPath.split('/').length - 1).join('/')}';
      bool allSuccess = true;
      String errorMessage = '';
      // Przenieś wszystkie pliki
      for (final singleFileName in fileNames) {
        final sourcePath = '$currentFolderPath/$singleFileName';
        final response = await ApiService.moveFile(
          token: token,
          sourcePath: sourcePath,
          destinationFolder: parentPath,
        );
        if (response.statusCode != 200) {
          allSuccess = false;
          final data = jsonDecode(response.body);
          errorMessage = data['detail'] ?? response.body;
          break;
        }
      }
      Navigator.pop(context); // Zamknij dialog
      if (!mounted) return;
      if (allSuccess) {
        // Odśwież listę plików
        await _loadFiles();
        // Wyjdź z trybu wyboru jeśli przeniesiono wiele plików
        if (isMultipleFiles) {
          setState(() {
            _isSelectionMode = false;
            _selectedFiles.clear();
          });
        }
        // Wyczyść cache dla bieżącej ścieżki
        await CacheService().clearFilesCache(username, _currentPath);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isMultipleFiles 
              ? 'Successfully moved ${fileNames.length} items to parent folder'
              : 'Successfully moved $fileName to parent folder'),
            backgroundColor: const Color(0xFF667eea),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('files.failed_to_move_files'.tr(args: [errorMessage])),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Zamknij dialog jeśli jest otwarty
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('files.error_moving_files'.tr(args: [e.toString()])),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _moveFileToSpecificFolder(String fileName, String targetPath) async {
    try {
      // Sprawdź czy to wiele plików (oddzielonych przecinkami)
      final fileNames = fileName.split(',');
      final isMultipleFiles = fileNames.length > 1;
      // Pokaż dialog z progressem
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return ProgressDialog(
            message: isMultipleFiles 
              ? 'Moving ${fileNames.length} items to ${targetPath.split('/').last}...'
              : 'Moving $fileName to ${targetPath.split('/').last}...',
            color: Colors.blue,
          );
        },
      );
      final token = await TokenService.getToken();
      final username = await TokenService.getUsername();
      if (token == null || username == null) {
        Navigator.pop(context); // Zamknij dialog
        _showSessionExpiredDialog();
        return;
      }
      // Przygotuj ścieżki
      final currentFolderPath = _currentPath.isEmpty ? username : '$username/$_currentPath';
      final destinationPath = '$username/$targetPath';
      
      // Sprawdź czy próbujemy przenieść do tego samego folderu
      if (targetPath == _currentPath) {
        Navigator.pop(context); // Zamknij dialog
        if (!mounted) return;
        _showSameFolderDialog(fileName);
        return;
      }
      
      bool allSuccess = true;
      String errorMessage = '';
      // Przenieś wszystkie pliki
      for (final singleFileName in fileNames) {
        final sourcePath = '$currentFolderPath/$singleFileName';
        final response = await ApiService.moveFile(
          token: token,
          sourcePath: sourcePath,
          destinationFolder: destinationPath,
        );
        if (response.statusCode != 200) {
          allSuccess = false;
          final data = jsonDecode(response.body);
          errorMessage = data['detail'] ?? response.body;
          break;
        }
      }
      Navigator.pop(context); // Zamknij dialog
      if (!mounted) return;
      if (allSuccess) {
        // Odśwież listę plików
        await _loadFiles();
        // Wyjdź z trybu wyboru jeśli przeniesiono wiele plików
        if (isMultipleFiles) {
          setState(() {
            _isSelectionMode = false;
            _selectedFiles.clear();
          });
        }
        // Wyczyść cache dla bieżącej ścieżki
        await CacheService().clearFilesCache(username, _currentPath);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isMultipleFiles 
              ? 'Successfully moved ${fileNames.length} items to ${targetPath.split('/').last}'
              : 'Successfully moved $fileName to ${targetPath.split('/').last}'),
            backgroundColor: const Color(0xFF667eea),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('files.failed_to_move_files'.tr(args: [errorMessage])),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Zamknij dialog jeśli jest otwarty
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('files.error_moving_files'.tr(args: [e.toString()])),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _moveFileToRootFolder(String fileName) async {
    try {
      // Sprawdź czy to wiele plików (oddzielonych przecinkami)
      final fileNames = fileName.split(',');
      final isMultipleFiles = fileNames.length > 1;
      // Pokaż dialog z progressem
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return ProgressDialog(
            message: isMultipleFiles 
              ? 'Moving ${fileNames.length} items to root folder...'
              : 'Moving $fileName to root folder...',
            color: Colors.blue,
          );
        },
      );
      final token = await TokenService.getToken();
      final username = await TokenService.getUsername();
      if (token == null || username == null) {
        Navigator.pop(context); // Zamknij dialog
        _showSessionExpiredDialog();
        return;
      }
      // Przygotuj ścieżki - folder główny
      final currentFolderPath = _currentPath.isEmpty ? username : '$username/$_currentPath';
      final rootPath = username; // Folder główny użytkownika
      bool allSuccess = true;
      String errorMessage = '';
      // Przenieś wszystkie pliki
      for (final singleFileName in fileNames) {
        final sourcePath = '$currentFolderPath/$singleFileName';
        final response = await ApiService.moveFile(
          token: token,
          sourcePath: sourcePath,
          destinationFolder: rootPath,
        );
        if (response.statusCode != 200) {
          allSuccess = false;
          final data = jsonDecode(response.body);
          errorMessage = data['detail'] ?? response.body;
          break;
        }
      }
      Navigator.pop(context); // Zamknij dialog
      if (!mounted) return;
      if (allSuccess) {
        // Odśwież listę plików
        await _loadFiles();
        // Wyjdź z trybu wyboru jeśli przeniesiono wiele plików
        if (isMultipleFiles) {
          setState(() {
            _isSelectionMode = false;
            _selectedFiles.clear();
          });
        }
        // Wyczyść cache dla bieżącej ścieżki
        await CacheService().clearFilesCache(username, _currentPath);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isMultipleFiles 
              ? 'Successfully moved ${fileNames.length} items to root folder'
              : 'Successfully moved $fileName to root folder'),
            backgroundColor: const Color(0xFF667eea),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('files.failed_to_move_files'.tr(args: [errorMessage])),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Zamknij dialog jeśli jest otwarty
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('files.error_moving_files'.tr(args: [e.toString()])),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Funkcje do automatycznego przewijania podczas przeciągania
  void _startAutoScroll(DragUpdateDetails details) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final listHeight = renderBox.size.height;
    final scrollArea = 80.0; // Zwiększona czułość
    final topThreshold = scrollArea;
    final bottomThreshold = listHeight - scrollArea;
    final dragY = localPosition.dy;
    double scrollSpeed = 0;
    if (dragY < topThreshold && _scrollController.offset > 0) {
      // Przewijaj w dół (pokazuj więcej plików na górze)
      scrollSpeed = -(topThreshold - dragY) / 10;
    } else if (dragY > bottomThreshold && _scrollController.offset < _scrollController.position.maxScrollExtent) {
      // Przewijaj w górę (pokazuj więcej plików na dole)
      scrollSpeed = (dragY - bottomThreshold) / 10;
    }
    if (scrollSpeed != 0) {
      _scrollTimer?.cancel();
      _scrollTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
        if (_scrollController.hasClients) {
          final newOffset = _scrollController.offset + scrollSpeed;
          if (newOffset >= 0 && newOffset <= _scrollController.position.maxScrollExtent) {
            _scrollController.jumpTo(newOffset);
          }
        }
      });
    } else {
      _scrollTimer?.cancel();
    }
  }

  void _stopAutoScroll() {
    _scrollTimer?.cancel();
    _isDragging = false;
  }

  Widget _buildBreadcrumb() {
    final List<String> parts = _currentPath.isEmpty ? [] : _currentPath.split('/');
    List<Widget> widgets = [];
    
    // Dodaj DragTarget dla folderu głównego (jeśli nie jesteśmy w folderze głównym)
    if (_currentPath.isNotEmpty) {
      widgets.add(
        DragTarget<String>(
          onWillAccept: (data) => true,
          onAccept: (data) {
            _moveFilesToRootFolder(data);
          },
          builder: (context, candidateData, rejectedData) {
            final isActive = candidateData.isNotEmpty;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: isActive 
                  ? LinearGradient(
                      colors: [
                        const Color(0xFF667eea).withValues(alpha: 0.2),
                        const Color(0xFF764ba2).withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        const Color(0xFF667eea).withValues(alpha: 0.1),
                        const Color(0xFF764ba2).withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                borderRadius: BorderRadius.circular(12),
                border: isActive 
                  ? Border.all(color: const Color(0xFF667eea), width: 2)
                  : Border.all(color: const Color(0xFF667eea).withValues(alpha: 0.3), width: 1),
                boxShadow: isActive ? [
                  BoxShadow(
                    color: const Color(0xFF667eea).withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ] : null,
              ),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _currentPath = '';
                  });
                  _loadFiles();
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667eea).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.home, 
                        size: 16, 
                        color: const Color(0xFF667eea),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'files.my_files'.tr(), 
                      style: const TextStyle(
                        fontWeight: FontWeight.w600, 
                        color: Color(0xFF667eea),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } else {
      // Jeśli jesteśmy w folderze głównym, nie dodawaj DragTarget
      widgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF667eea).withValues(alpha: 0.15),
                const Color(0xFF764ba2).withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF667eea).withValues(alpha: 0.4), 
              width: 1,
            ),
          ),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _currentPath = '';
              });
              _loadFiles();
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.home, 
                    size: 16, 
                    color: const Color(0xFF667eea),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'files.my_files'.tr(), 
                  style: const TextStyle(
                    fontWeight: FontWeight.w600, 
                    color: Color(0xFF667eea),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Dodaj DragTarget dla każdego folderu w ścieżce
    for (int i = 0; i < parts.length; i++) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade500),
        ),
      );
      
      // Jeśli to nie jest ostatni folder w ścieżce, dodaj DragTarget
      if (i < parts.length - 1) {
        widgets.add(
          DragTarget<String>(
            onWillAccept: (data) => true,
            onAccept: (data) {
              final targetPath = parts.sublist(0, i + 1).join('/');
              _moveFilesToSpecificFolder(data, targetPath);
            },
            builder: (context, candidateData, rejectedData) {
              final isActive = candidateData.isNotEmpty;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? Colors.blue.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isActive ? Border.all(color: Colors.blue, width: 2) : null,
                ),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentPath = parts.sublist(0, i + 1).join('/');
                    });
                    _loadFiles();
                  },
                  child: Text(
                    parts[i],
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      } else {
        // Ostatni folder w ścieżce (bieżący folder)
        widgets.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF667eea).withValues(alpha: 0.15),
                  const Color(0xFF764ba2).withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF667eea).withValues(alpha: 0.4), 
                width: 1,
              ),
            ),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _currentPath = parts.sublist(0, i + 1).join('/');
                });
                _loadFiles();
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667eea).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.folder, 
                      size: 16, 
                      color: const Color(0xFF667eea),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    parts[i],
                    style: const TextStyle(
                      fontWeight: FontWeight.w600, 
                      color: Color(0xFF667eea),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: widgets,
      ),
    );
  }

  Widget _buildViewToggleButton(IconData icon, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isGridView = icon == Icons.grid_view;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF667eea) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.grey.shade600,
          size: 20,
        ),
      ),
    );
  }

  IconData _getSortIcon() {
    switch (_sortBy) {
      case 'name':
        return Icons.sort_by_alpha;
      case 'date':
        return Icons.calendar_today;
      case 'size':
        return Icons.storage;
      case 'type':
        return Icons.category;
      default:
        return Icons.sort_by_alpha;
    }
  }

  String _getSortText() {
    switch (_sortBy) {
      case 'name':
        return 'Name';
      case 'date':
        return 'Date';
      case 'size':
        return 'Size';
      case 'type':
        return 'Type';
      default:
        return 'Name';
    }
  }

  void _showSameFolderDialog(String fileName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('files.same_folder_title'.tr()),
          content: Text('files.same_folder_message'.tr(namedArgs: {'filename': fileName})),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('common.ok'.tr()),
            ),
          ],
        );
      },
    );
  }

  void _showRenameDialog(FileItem file) {
    final TextEditingController nameController = TextEditingController();
    
    // Wypełnij pole tekstowe aktualną nazwą pliku
    nameController.text = file.name;
    
    // Jeśli to plik (nie folder), zaznacz nazwę bez rozszerzenia
    if (file.type != 'folder' && file.name.contains('.')) {
      final lastDotIndex = file.name.lastIndexOf('.');
      nameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: lastDotIndex,
      );
    } else {
      // Dla folderów zaznacz całą nazwę
      nameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: file.name.length,
      );
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.edit,
                  color: Colors.green.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  file.type == 'folder' ? 'Rename Folder' : 'Rename File',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter new name for "${file.name}":',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: file.type == 'folder' ? 'Folder name' : 'File name',
                  hintText: 'Enter new name...',
                  prefixIcon: Icon(
                    file.type == 'folder' ? Icons.folder : Icons.insert_drive_file,
                    color: Colors.grey.shade600,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.green.shade600,
                      width: 2,
                    ),
                  ),
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty && value.trim() != file.name) {
                    Navigator.pop(context);
                    _renameFile(file, value.trim());
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty && newName != file.name) {
                  Navigator.pop(context);
                  _renameFile(file, newName);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Rename',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _renameFile(FileItem file, String newName) async {
    try {
      // Pokaż dialog z progressem
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                ),
                const SizedBox(height: 20),
                Text(
                  'Renaming ${file.type == 'folder' ? 'folder' : 'file'}...',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );

      final token = await TokenService.getToken();
      final username = await TokenService.getUsername();
      
      if (token == null || username == null) {
        Navigator.pop(context); // Zamknij dialog
        NotificationService.showAuthError(context);
        return;
      }

      // Przygotuj ścieżkę folderu
      final folderPath = _currentPath.isEmpty ? username : '$username/$_currentPath';
      
      // Wywołaj API do zmiany nazwy
      final response = await ApiService.renameFile(
        oldFilename: file.name,
        newFilename: newName,
        folderName: folderPath,
        token: token,
      );

      Navigator.pop(context); // Zamknij dialog

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Dodaj aktywność
        await ActivityService.addActivity(
          ActivityService.createFileRenameActivity(file.name, newName),
        );
        
        // Pokaż dialog sukcesu
        _showRenameSuccessDialog(file.name, newName);
        
        // Wyczyść cache dla bieżącej ścieżki
        await CacheService().clearFilesCache(username, _currentPath);
        
        // Odśwież listę plików
        _loadFiles();
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['detail'] ?? response.body;
        NotificationService.showValidationError(context, errorMessage);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Zamknij dialog jeśli jest otwarty
        final error = ErrorHandler.handleError(e, null);
        NotificationService.showEnhancedError(context, error);
      }
    }
  }

  void _showRenameSuccessDialog(String oldName, String newName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 48,
                  color: Colors.green.shade600,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Renamed Successfully!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 12),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  children: [
                    const TextSpan(text: '"'),
                    TextSpan(
                      text: oldName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const TextSpan(text: '" has been renamed to "'),
                    TextSpan(
                      text: newName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade600,
                      ),
                    ),
                    const TextSpan(text: '"'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class FileItem {
  final String name;
  final String size;
  final String date;
  final String type;
  final bool isFavorite;

  FileItem({
    required this.name,
    required this.size,
    required this.date,
    required this.type,
    required this.isFavorite,
  });
}
