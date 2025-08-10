import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import '../utils/custom_widgets.dart';
import '../utils/api_service.dart';
import '../utils/token_service.dart';
import '../utils/notification_service.dart';
import '../utils/error_handler.dart';
import '../utils/activity_service.dart';
import '../utils/file_utils.dart';
import '../widgets/image_preview_widget.dart';
import '../widgets/text_preview_widget.dart';
import '../widgets/spreadsheet_preview_widget.dart';
import '../widgets/pdf_preview_widget.dart';

class SharedFolderContentsPage extends StatefulWidget {
  final String folderName;
  final String sharedBy;
  final String sharedByEmail;
  final String folderPath;

  const SharedFolderContentsPage({
    super.key,
    required this.folderName,
    required this.sharedBy,
    required this.sharedByEmail,
    required this.folderPath,
  });

  @override
  State<SharedFolderContentsPage> createState() => _SharedFolderContentsPageState();
}

class _SharedFolderContentsPageState extends State<SharedFolderContentsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'name';
  bool _isGridView = false;
  bool _isLoading = true;
  String? _errorMessage;
  String _username = 'loading';

  List<SharedFileItem> _files = [];
  String _currentPath = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadFolderContents();
  }

  Future<void> _loadUserData() async {
    final username = await TokenService.getUsername();
    setState(() {
      _username = username ?? 'unknown';
    });
  }

  Future<void> _loadFolderContents() async {
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
        return;
      }

      // Use the listSharedFolder API to get contents of the shared folder
      final response = await ApiService.listSharedFolder(
        folderPath: widget.folderPath,
        sharedBy: widget.sharedBy,
        token: token,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final filesData = data['files'] as List;
        
        List<SharedFileItem> allItems = [];
        
        for (var fileData in filesData) {
          final filename = fileData['filename'] as String;
          final sizeBytes = fileData['size_bytes'] as int;
          final modificationDate = fileData['modification_date'] as String;
          final isFolder = fileData['is_folder'] as bool;
          
          allItems.add(SharedFileItem(
            name: filename,
            size: _formatFileSize(sizeBytes),
            date: _formatDate(modificationDate),
            type: isFolder ? 'folder' : 'file',
            fileType: isFolder ? 'folder' : _getFileType(filename),
            isFolder: isFolder,
          ));
        }
        
        setState(() {
          _files = allItems;
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
        return 'video';
      case 'mp3':
      case 'wav':
      case 'flac':
        return 'audio';
      case 'txt':
      case 'md':
      case 'log':
        return 'text';
      case 'xls':
      case 'xlsx':
      case 'csv':
        return 'spreadsheet';
      case 'doc':
      case 'docx':
        return 'document';
      case 'zip':
      case 'rar':
      case '7z':
        return 'archive';
      default:
        return 'unknown';
    }
  }

  Color _getFileColor(String fileType) {
    switch (fileType) {
      case 'pdf':
        return Colors.red;
      case 'image':
        return Colors.green;
      case 'video':
        return Colors.purple;
      case 'audio':
        return Colors.orange;
      case 'text':
        return Colors.blue;
      case 'spreadsheet':
        return Colors.teal;
      case 'document':
        return Colors.indigo;
      case 'archive':
        return Colors.amber;
      case 'folder':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.video_file;
      case 'audio':
        return Icons.audio_file;
      case 'text':
        return Icons.text_snippet;
      case 'spreadsheet':
        return Icons.table_chart;
      case 'document':
        return Icons.description;
      case 'archive':
        return Icons.archive;
      case 'folder':
        return Icons.folder;
      default:
        return Icons.insert_drive_file;
    }
  }

  List<SharedFileItem> get _filteredItems {
    if (_searchQuery.isEmpty) {
      return _files;
    }
    return _files.where((item) =>
        item.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  void _handleItemAction(String action, SharedFileItem item) {
    switch (action) {
      case 'download':
        _downloadItem(item);
        break;
      case 'preview':
        if (item.type == 'file') {
          _previewItem(item);
        }
        break;
      case 'info':
        _showItemInfo(item);
        break;
    }
  }

  Future<void> _downloadItem(SharedFileItem item) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        NotificationService.showAuthError(context);
        return;
      }

      // Show loading dialog
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
        filePath: '${widget.sharedBy}/${widget.folderPath}/${item.name}',
      );

      Navigator.pop(context); // Close loading dialog

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Add activity
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
        Navigator.pop(context); // Close loading dialog if open
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

  Future<void> _previewItem(SharedFileItem item) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        NotificationService.showAuthError(context);
        return;
      }

      if (!_isPreviewable(item.name)) {
        NotificationService.showInfo(
          context,
          'shared_files.preview_not_supported'.tr(),
        );
        return;
      }

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

      final response = await ApiService.downloadFile(
        token: token,
        filePath: '${widget.sharedBy}/${widget.folderPath}/${item.name}',
      );

      Navigator.pop(context);

      if (!mounted) return;

      if (response.statusCode == 200) {
        await ActivityService.addActivity(
          ActivityService.createFilePreviewActivity(item.name),
        );
        
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
        Navigator.pop(context);
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

  void _openPreview(SharedFileItem item) {
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

  void _showImagePreview(SharedFileItem item) {
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
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ImagePreviewWidget(
                      filename: item.name,
                      folderName: widget.folderPath,
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

  void _showPdfPreview(SharedFileItem item) {
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
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: PdfPreviewWidget(
                      filename: item.name,
                      folderName: widget.folderPath,
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

  void _showTextPreview(SharedFileItem item) {
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
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextPreviewWidget(
                      filename: item.name,
                      folderName: widget.folderPath,
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

  void _showSpreadsheetPreview(SharedFileItem item) {
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
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SpreadsheetPreviewWidget(
                      filename: item.name,
                      folderName: widget.folderPath,
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

  void _showItemInfo(SharedFileItem item) {
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
              _buildInfoRow('Shared by', widget.sharedBy),
              _buildInfoRow('Folder', widget.folderName),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.folderName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Shared by ${widget.sharedBy}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadFolderContents,
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
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Search files...',
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
                    'Loading folder contents...',
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
                'Error loading folder contents',
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
                onPressed: _loadFolderContents,
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
                label: const Text(
                  'Retry',
                  style: TextStyle(
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
          title: 'No files found',
          subtitle: 'Try adjusting your search terms',
        );
      } else {
        return EmptyStateWidget(
          icon: Icons.folder_open,
          title: 'Empty folder',
          subtitle: 'This shared folder is empty',
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
            leading: Container(
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
              child: item.fileType == 'image' && !item.isFolder
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ImagePreviewWidget(
                        filename: item.name,
                        folderName: widget.folderPath,
                        width: 48,
                        height: 48,
                        showFullScreenOnTap: false,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Icon(
                      _getFileIcon(item.fileType),
                      color: _getFileColor(item.fileType),
                      size: 24,
                    ),
            ),
            title: Text(
              item.name, 
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('${item.size} • ${item.date}'),
            trailing: PopupMenuButton<String>(
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
                        'Download',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                if (item.type == 'file') PopupMenuItem(
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
                        'Preview',
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
                                'Download',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        if (item.type == 'file') PopupMenuItem(
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
                                'Preview',
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
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _getFileColor(item.fileType).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getFileColor(item.fileType).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: item.fileType == 'image' && !item.isFolder
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: ImagePreviewWidget(
                                  filename: item.name,
                                  folderName: widget.folderPath,
                                  width: 60,
                                  height: 60,
                                  showFullScreenOnTap: false,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(
                                _getFileIcon(item.fileType),
                                color: _getFileColor(item.fileType),
                                size: 30,
                              ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.size} • ${item.date}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SharedFileItem {
  final String name;
  final String size;
  final String date;
  final String type;
  final String fileType;
  final bool isFolder;

  SharedFileItem({
    required this.name,
    required this.size,
    required this.date,
    required this.type,
    required this.fileType,
    required this.isFolder,
  });
} 