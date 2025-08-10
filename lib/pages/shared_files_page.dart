import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import '../utils/custom_widgets.dart';
import '../utils/api_service.dart';
import '../utils/token_service.dart';
import '../utils/activity_service.dart';
import '../utils/file_utils.dart';
import '../widgets/shared_image_preview_widget.dart';
import '../widgets/shared_text_preview_widget.dart';
import '../widgets/shared_spreadsheet_preview_widget.dart';
import '../widgets/shared_pdf_preview_widget.dart';
import '../utils/notification_service.dart';
import '../utils/error_handler.dart';
import 'shared_folder_contents_page.dart';

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

      // Ładowanie plików udostępnionych bezpośrednio
      final filesResponse = await ApiService.getSharedFiles(token: token);
      final foldersResponse = await ApiService.getSharedFolders(token: token);
      
      // Ładowanie plików udostępnionych przez grupy
      final groupFilesResponse = await ApiService.getFilesSharedWithMeByGroups(token: token);
      final groupFoldersResponse = await ApiService.getFoldersSharedWithMeByGroups(token: token);

      if (!mounted) return;

      print('DEBUG: filesResponse.statusCode = ${filesResponse.statusCode}');
      print('DEBUG: foldersResponse.statusCode = ${foldersResponse.statusCode}');
      print('DEBUG: groupFilesResponse.statusCode = ${groupFilesResponse.statusCode}');
      print('DEBUG: groupFoldersResponse.statusCode = ${groupFoldersResponse.statusCode}');
      
      if (filesResponse.statusCode == 200 && foldersResponse.statusCode == 200 &&
          groupFilesResponse.statusCode == 200 && groupFoldersResponse.statusCode == 200) {
        final filesData = jsonDecode(filesResponse.body);
        final foldersData = jsonDecode(foldersResponse.body);
        final groupFilesData = jsonDecode(groupFilesResponse.body);
        final groupFoldersData = jsonDecode(groupFoldersResponse.body);
        
        print('DEBUG: filesData = $filesData');
        print('DEBUG: foldersData = $foldersData');
        print('DEBUG: groupFilesData = $groupFilesData');
        print('DEBUG: groupFoldersData = $groupFoldersData');
        
        final sharedFilesData = filesData['shared_files'] as List;
        final sharedFoldersData = foldersData['shared_folders'] as List;
        final groupSharedFilesData = groupFilesData['shared_files'] as List;
        final groupSharedFoldersData = groupFoldersData['shared_folders'] as List;
        
        print('DEBUG: sharedFilesData.length = ${sharedFilesData.length}');
        print('DEBUG: sharedFoldersData.length = ${sharedFoldersData.length}');
        print('DEBUG: groupSharedFilesData.length = ${groupSharedFilesData.length}');
        print('DEBUG: groupSharedFoldersData.length = ${groupSharedFoldersData.length}');
        
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
        
        // Dodaj foldery udostępnione bezpośrednio
        for (var folderData in sharedFoldersData) {
          final folderName = folderData['folder_name'] as String;
          final sizeBytes = folderData['total_size_bytes'] as int;
          final modificationDate = folderData['modification_date'] as String;
          final sharedAt = folderData['shared_at'] as String;
          final parentFolderName = folderData['folder_path'] as String;
          final sharedBy = folderData['shared_by'] as String;
          final sharedByEmail = folderData['shared_by_email'] as String;
          final fileCount = folderData['file_count'] as int;
          final folderCount = folderData['folder_count'] as int;
          
          allItems.add(SharedItem(
            name: folderName,
            size: _formatFileSize(sizeBytes),
            date: _formatDate(modificationDate),
            sharedDate: _formatDate(sharedAt),
            type: 'folder',
            fileType: 'folder',
            folderName: folderName, // Używamy tylko nazwy folderu, nie pełnej ścieżki
            sharedBy: sharedBy,
            sharedByEmail: sharedByEmail,
            fileCount: fileCount,
            folderCount: folderCount,
          ));
        }
        
        // Dodaj pliki udostępnione przez grupy
        for (var fileData in groupSharedFilesData) {
          final filename = fileData['filename'] as String;
          final fileSize = fileData['file_size'] as int;
          final sharedAt = fileData['shared_at'] as String;
          final folderName = fileData['folder_name'] as String;
          final sharedBy = fileData['shared_by'] as String;
          final groupName = fileData['group_name'] as String;
          
          allItems.add(SharedItem(
            name: filename,
            size: _formatFileSize(fileSize),
            date: _formatDate(sharedAt), // Używamy shared_at jako daty modyfikacji
            sharedDate: _formatDate(sharedAt),
            type: 'file',
            fileType: _getFileType(filename),
            folderName: folderName,
            sharedBy: sharedBy,
            sharedByEmail: '', // Brak email dla udostępnień grupowych
            fileCount: 0,
            folderCount: 0,
          ));
        }
        
        // Dodaj foldery udostępnione przez grupy
        for (var folderData in groupSharedFoldersData) {
          final folderPath = folderData['folder_path'] as String;
          final sharedAt = folderData['shared_at'] as String;
          final sharedBy = folderData['shared_by'] as String;
          final groupName = folderData['group_name'] as String;
          
          // Wyciągnij nazwę folderu z pełnej ścieżki
          final folderName = folderPath.split('/').last;
          
          allItems.add(SharedItem(
            name: folderName,
            size: '0 B', // Brak informacji o rozmiarze dla folderów grupowych
            date: _formatDate(sharedAt), // Używamy shared_at jako daty modyfikacji
            sharedDate: _formatDate(sharedAt),
            type: 'folder',
            fileType: 'folder',
            folderName: folderPath, // Używamy pełnej ścieżki folderu
            sharedBy: sharedBy,
            sharedByEmail: '', // Brak email dla udostępnień grupowych
            fileCount: 0, // Brak informacji o liczbie plików
            folderCount: 0, // Brak informacji o liczbie folderów
          ));
        }
        
        setState(() {
          _sharedItems = allItems;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'shared_files.load_error'.tr();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _errorMessage = 'shared_files.network_error'.tr(args: [e.toString()]);
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

  List<SharedItem> get _filteredItems {
    List<SharedItem> filtered = _sharedItems.where((item) {
      return item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             item.sharedBy.toLowerCase().contains(_searchQuery.toLowerCase());
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
        filtered.sort((a, b) => a.fileType.compareTo(b.fileType));
        break;
      case 'sharer':
        filtered.sort((a, b) => a.sharedBy.compareTo(b.sharedBy));
        break;
    }

    // Foldery zawsze na górze
    filtered.sort((a, b) {
      bool aIsFolder = a.type == 'folder';
      bool bIsFolder = b.type == 'folder';
      
      if (aIsFolder && !bIsFolder) return -1;
      if (!aIsFolder && bIsFolder) return 1;
      return 0;
    });

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

  void _handleItemAction(String action, SharedItem item) {
    switch (action) {
      case 'download':
        _downloadItem(item);
        break;
      case 'preview':
        _previewItem(item);
        break;
      case 'info':
        _showItemInfo(item);
        break;
    }
  }

  Future<void> _downloadItem(SharedItem item) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        NotificationService.showAuthError(context);
        return;
      }

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
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                const SizedBox(height: 20),
                Text(
                  'Downloading ${item.name}...',
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

      final response = await ApiService.downloadFile(
        token: token,
        filePath: '${item.sharedBy}/${item.folderName}/${item.name}',
      );

      Navigator.pop(context); // Zamknij dialog

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Dodaj aktywność
        await ActivityService.addActivity(
          ActivityService.createFileDownloadActivity(item.name),
        );
        
        NotificationService.showSuccess(
          context,
          'shared_files.download_success'.tr(),
        );
      } else {
        NotificationService.showEnhancedError(
          context,
          AppError(
            message: 'shared_files.download_error'.tr(),
            type: ErrorType.network,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Zamknij dialog jeśli jest otwarty
        NotificationService.showEnhancedError(
          context,
          AppError(
            message: 'shared_files.download_error'.tr(args: [e.toString()]),
            type: ErrorType.network,
          ),
        );
      }
    }
  }

  Future<void> _previewItem(SharedItem item) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        NotificationService.showAuthError(context);
        return;
      }

      // Sprawdź czy plik można podglądać
      if (!_isPreviewable(item.name)) {
        NotificationService.showInfo(
          context,
          'shared_files.preview_not_supported'.tr(),
        );
        return;
      }

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
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                const SizedBox(height: 20),
                Text(
                  'shared_files.loading_preview'.tr(args: [item.name]),
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

      // Sprawdź czy plik istnieje
      final response = await ApiService.downloadFile(
        token: token,
        filePath: '${item.sharedBy}/${item.folderName}/${item.name}',
      );

      Navigator.pop(context); // Zamknij dialog

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Dodaj aktywność
        await ActivityService.addActivity(
          ActivityService.createFilePreviewActivity(item.name),
        );
        
        // Otwórz podgląd
        _openPreview(item);
      } else {
        NotificationService.showEnhancedError(
          context,
          AppError(
            message: 'shared_files.preview_error'.tr(),
            type: ErrorType.network,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Zamknij dialog jeśli jest otwarty
        NotificationService.showEnhancedError(
          context,
          AppError(
            message: 'shared_files.preview_error'.tr(args: [e.toString()]),
            type: ErrorType.network,
          ),
        );
      }
    }
  }

  bool _isPreviewable(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    return [
      'pdf', 'jpg', 'jpeg', 'png', 'gif', 'bmp', 'txt', 'md', 
      'xls', 'xlsx', 'csv', 'doc', 'docx'
    ].contains(extension);
  }

  void _openPreview(SharedItem item) {
    final fileType = _getFileType(item.name);
    
    switch (fileType) {
      case 'image':
        _showImagePreview(item);
        break;
      case 'pdf':
        _showPdfPreview(item);
        break;
      case 'text':
        _showTextPreview(item);
        break;
      case 'spreadsheet':
        _showSpreadsheetPreview(item);
        break;
      default:
        NotificationService.showInfo(
          context,
          'shared_files.preview_not_supported'.tr(),
        );
    }
  }

  void _showImagePreview(SharedItem item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                // Image preview
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SharedImagePreviewWidget(
                      filename: item.name,
                      folderName: item.folderName,
                      sharedBy: item.sharedBy,
                      width: double.infinity,
                      height: double.infinity,
                      showFullScreenOnTap: true,
                      fit: BoxFit.contain,
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

  void _showPdfPreview(SharedItem item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                // PDF preview
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SharedPdfPreviewWidget(
                      filename: item.name,
                      folderName: item.folderName,
                      sharedBy: item.sharedBy,
                      width: double.infinity,
                      height: double.infinity,
                      showFullScreenOnTap: true,
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

  void _showTextPreview(SharedItem item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                // Text preview
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SharedTextPreviewWidget(
                      filename: item.name,
                      folderName: item.folderName,
                      sharedBy: item.sharedBy,
                      width: double.infinity,
                      height: double.infinity,
                      showFullScreenOnTap: true,
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

  void _showSpreadsheetPreview(SharedItem item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                // Spreadsheet preview
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SharedSpreadsheetPreviewWidget(
                      filename: item.name,
                      folderName: item.folderName,
                      sharedBy: item.sharedBy,
                      width: double.infinity,
                      height: double.infinity,
                      showFullScreenOnTap: true,
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

  void _showItemInfo(SharedItem item) {
    final location = item.folderName.isEmpty ? 'Root' : item.folderName;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('shared_files.file_info'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Name', item.name),
              _buildInfoRow('Type', item.type == 'folder' ? 'Folder' : 'File'),
              _buildInfoRow('Size', item.size),
              _buildInfoRow('Modified', item.date),
              _buildInfoRow('Shared by', item.sharedBy),
              _buildInfoRow('Shared on', item.sharedDate),
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

  void _navigateToSharedFolder(SharedItem folder) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        NotificationService.showAuthError(context);
        return;
      }

      // Navigate to a new page that shows the contents of the shared folder
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SharedFolderContentsPage(
            folderName: folder.name,
            sharedBy: folder.sharedBy,
            sharedByEmail: folder.sharedByEmail,
            folderPath: folder.folderName,
          ),
        ),
      );
    } catch (e) {
      NotificationService.showEnhancedError(
        context,
        AppError(
          message: 'Error navigating to folder: ${e.toString()}',
          type: ErrorType.network,
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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.folder_shared,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Shared Files',
              style: TextStyle(
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
      body: Column(
        children: [
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
                hintText: 'search.shared_files'.tr(),
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
          
          // Sort options and item count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
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
                                  'shared_files.sort_sharer'.tr(),
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
                            _sortBy == 'size' ? 'files.sort_size'.tr() :
                            _sortBy == 'type' ? 'files.sort_type'.tr() : 'shared_files.sort_sharer'.tr(),
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
                    color: const Color(0xFF667eea).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF667eea).withValues(alpha: 0.3)),
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
          
          const SizedBox(height: 8),
          
          // Items list
          Expanded(
            child: _buildItemsList(),
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
                    'shared_files.loading_files'.tr(),
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
                onPressed: _loadSharedItems,
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
                  'shared_files.retry'.tr(),
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
          icon: Icons.folder_shared,
          title: 'No shared files',
          subtitle: 'Files shared with you will appear here',
        );
      }
    }

    return _isGridView ? _buildGridView() : _buildListView();
  }

  Widget _buildListView() {
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
                color: Colors.black.withValues(alpha: 0.08),
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
            onTap: item.type == 'folder' ? () => _navigateToSharedFolder(item) : null,
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
                          return SharedImagePreviewWidget(
                            filename: item.name,
                            folderName: item.folderName,
                            sharedBy: item.sharedBy,
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
                          return SharedTextPreviewWidget(
                            filename: item.name,
                            folderName: item.folderName,
                            sharedBy: item.sharedBy,
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
                          return SharedSpreadsheetPreviewWidget(
                            filename: item.name,
                            folderName: item.folderName,
                            sharedBy: item.sharedBy,
                            width: 48,
                            height: 48,
                            showFullScreenOnTap: false,
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
                          return SharedPdfPreviewWidget(
                            filename: item.name,
                            folderName: item.folderName,
                            sharedBy: item.sharedBy,
                            width: 48,
                            height: 48,
                            showFullScreenOnTap: false,
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
                      color: _getFileColor(item.fileType).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getFileColor(item.fileType).withValues(alpha: 0.3),
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
                      color: Colors.blue.withValues(alpha: 0.1),
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
                              color: const Color(0xFF667eea).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.download_rounded, color: const Color(0xFF667eea), size: 18),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            item.type == 'folder' ? 'Download as ZIP' : 'shared_files.download'.tr(),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'preview',
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.visibility, color: Colors.purple, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'shared_files.preview'.tr(),
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

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 0.85,
      ),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        
        return Container(
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
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                // Górny rząd: menu po prawej
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        _handleItemAction(value, item);
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 8,
                      offset: const Offset(0, 8),
                      icon: const Icon(Icons.more_vert, size: 18),
                      itemBuilder: (context) => [
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
                              Text(
                                item.type == 'folder' ? 'Download as ZIP' : 'shared_files.download'.tr(),
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'preview',
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.visibility, color: Colors.purple, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'shared_files.preview'.tr(),
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
                
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Środkowa część: ikona pliku lub podgląd zdjęcia
                      if (FileUtils.isImage(item.name))
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
                                  return SharedImagePreviewWidget(
                                    filename: item.name,
                                    folderName: item.folderName,
                                    sharedBy: item.sharedBy,
                                    width: 80,
                                    height: 80,
                                    showFullScreenOnTap: false,
                                    fit: BoxFit.cover,
                                  );
                                },
                            ),
                          ),
                        )
                      else
                        // Ikona pliku
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _getFileColor(item.fileType).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getFileColor(item.fileType).withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            _getFileIcon(item.fileType),
                            color: _getFileColor(item.fileType),
                            size: 36,
                          ),
                        ),
                      
                      const SizedBox(height: 8),
                      
                      // Nazwa pliku w środku
                      Expanded(
                        child: Center(
                          child: Text(
                            item.name,
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
                  '${item.size} • ${item.date}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                
                // Informacja o udostępniającym
                Text(
                  'Shared by ${item.sharedBy}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
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
  final String fileType;
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