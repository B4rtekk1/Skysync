import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/file_item.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/error_view.dart';
import '../widgets/error_box.dart';

class MyFilesPage extends StatefulWidget {
  final String username;
  final String email;

  const MyFilesPage({super.key, required this.username, required this.email});

  @override
  State<MyFilesPage> createState() => _MyFilesPageState();
}

class _MyFilesPageState extends State<MyFilesPage> {
  List<FileItem> _files = [];
  bool _isLoading = false;
  bool _isUploading = false;
  String? _errorMessage;
  bool _isGridView = false;
  String _sortBy = 'name';
  bool _sortAscending = true;
  String _selectedFilter = 'All';
  String _searchQuery = '';
  String _includeFormats = '';
  String _excludeFormats = '';
  final List<String> _filters = [
    'All',
    'Favorites',
    'Folders',
    'Images',
    'Videos',
    'Documents',
    'Audio',
  ];
  String _dateFilter = 'All Time';
  String _sizeFilter = 'Any Size';
  String _currentPath = '/';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  double? _dragStartX;
  double _dragAccumDx = 0.0;
  double _dragAccumDy = 0.0;

  final List<String> _dateFilters = [
    'All Time',
    'Today',
    'Last 7 Days',
    'Last 30 Days',
  ];
  final List<String> _sizeFilters = [
    'Any Size',
    'Small (<1MB)',
    'Medium (1-100MB)',
    'Large (>100MB)',
  ];

  List<FileItem> get _filteredFiles {
    var filtered = _files;

    if (_selectedFilter != 'All') {
      filtered =
          filtered.where((file) {
            if (_selectedFilter == 'Favorites') return file.isFavorite;
            if (_selectedFilter == 'Folders') return file.isFolder;
            if (_selectedFilter == 'Images') {
              return file.mimeType.startsWith('image/');
            }
            if (_selectedFilter == 'Videos') {
              return file.mimeType.startsWith('video/');
            }
            if (_selectedFilter == 'Audio') {
              return file.mimeType.startsWith('audio/');
            }
            if (_selectedFilter == 'Documents') {
              return file.mimeType.contains('pdf') ||
                  file.mimeType.contains('document') ||
                  file.mimeType.contains('word') ||
                  file.mimeType.contains('text') ||
                  file.mimeType.contains('spreadsheet') ||
                  file.mimeType.contains('presentation');
            }
            return false;
          }).toList();
    }

    final now = DateTime.now();
    if (_dateFilter == 'Today') {
      filtered =
          filtered.where((f) {
            return f.lastModified.year == now.year &&
                f.lastModified.month == now.month &&
                f.lastModified.day == now.day;
          }).toList();
    } else if (_dateFilter == 'Last 7 Days') {
      final limit = now.subtract(const Duration(days: 7));
      filtered = filtered.where((f) => f.lastModified.isAfter(limit)).toList();
    } else if (_dateFilter == 'Last 30 Days') {
      final limit = now.subtract(const Duration(days: 30));
      filtered = filtered.where((f) => f.lastModified.isAfter(limit)).toList();
    }

    if (_sizeFilter == 'Small (<1MB)') {
      filtered = filtered.where((f) => f.size < 1024 * 1024).toList();
    } else if (_sizeFilter == 'Medium (1-100MB)') {
      filtered =
          filtered
              .where((f) => f.size >= 1024 * 1024 && f.size < 100 * 1024 * 1024)
              .toList();
    } else if (_sizeFilter == 'Large (>100MB)') {
      filtered = filtered.where((f) => f.size >= 100 * 1024 * 1024).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered
              .where(
                (f) =>
                    f.name.toLowerCase().contains(_searchQuery.toLowerCase()),
              )
              .toList();
    }

    if (_includeFormats.isNotEmpty) {
      final formats =
          _includeFormats
              .toLowerCase()
              .split(',')
              .map((e) => e.trim())
              .toList();
      filtered =
          filtered.where((f) {
            final ext = f.name.split('.').last.toLowerCase();
            return formats.contains(ext);
          }).toList();
    }

    if (_excludeFormats.isNotEmpty) {
      final formats =
          _excludeFormats
              .toLowerCase()
              .split(',')
              .map((e) => e.trim())
              .toList();
      filtered =
          filtered.where((f) {
            final ext = f.name.split('.').last.toLowerCase();
            return !formats.contains(ext);
          }).toList();
    }

    return filtered;
  }

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authData = await AuthService().getAuthData();
      final token = authData['token'];

      if (token == null) {
        throw Exception('Not authenticated');
      }

      final apiService = ApiService();
      final filesData = await apiService.listFiles(
        token,
        widget.username,
        folder: _currentPath,
      );

      final newFiles =
          filesData.map((json) => FileItem.fromJson(json)).toList();

      setState(() {
        final updatedFiles = <FileItem>[];
        final existingFileMap = {for (var f in _files) f.name: f};

        for (final newFile in newFiles) {
          final existingFile = existingFileMap[newFile.name];

          if (existingFile == null) {
            updatedFiles.add(newFile);
          } else if (_hasFileChanged(existingFile, newFile)) {
            updatedFiles.add(newFile);
          } else {
            updatedFiles.add(existingFile);
          }
        }

        _files = updatedFiles;
        _sortFiles();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshFilesSilently() async {
    try {
      final authData = await AuthService().getAuthData();
      final token = authData['token'];

      if (token == null) {
        throw Exception('Not authenticated');
      }

      final apiService = ApiService();
      final filesData = await apiService.listFiles(
        token,
        widget.username,
        folder: _currentPath,
      );

      final newFiles =
          filesData.map((json) => FileItem.fromJson(json)).toList();

      setState(() {
        final updatedFiles = <FileItem>[];
        final existingFileMap = {for (var f in _files) f.name: f};

        for (final newFile in newFiles) {
          final existingFile = existingFileMap[newFile.name];

          if (existingFile == null) {
            updatedFiles.add(newFile);
          } else if (_hasFileChanged(existingFile, newFile)) {
            updatedFiles.add(newFile);
          } else {
            updatedFiles.add(existingFile);
          }
        }

        _files = updatedFiles;
        _sortFiles();
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  bool _hasFileChanged(FileItem old, FileItem newFile) {
    return old.size != newFile.size ||
        old.lastModified != newFile.lastModified ||
        old.isFavorite != newFile.isFavorite ||
        old.mimeType != newFile.mimeType ||
        old.fileCount != newFile.fileCount ||
        old.folderCount != newFile.folderCount ||
        old.totalSize != newFile.totalSize;
  }

  Future<void> _showCreateFolderDialog() async {
    final controller = TextEditingController();
    return showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10.0,
                      offset: Offset(0.0, 10.0),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.create_new_folder_outlined,
                        size: 40,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Create New Folder',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter a name for your new folder',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Folder Name',
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.blue,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        prefixIcon: const Icon(Icons.folder_open),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (controller.text.trim().isEmpty) return;
                              Navigator.pop(context);
                              await _createFolder(controller.text.trim());
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Create',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Future<void> _createFolder(String folderName) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authData = await AuthService().getAuthData();
      final token = authData['token'];

      if (token == null) {
        throw Exception('Not authenticated');
      }

      final apiService = ApiService();
      await apiService.createFolder(
        token,
        widget.username,
        folderName,
        currentPath: _currentPath,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _refreshFilesSilently();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ErrorBox.show(
          context,
          message: e.toString().replaceAll('Exception: ', ''),
          title: 'Failed to Create Folder',
          onRetry: () => _createFolder(folderName),
        );
      }
    }
  }

  void _sortFiles() {
    setState(() {
      _files.sort((a, b) {
        if (a.isFolder && !b.isFolder) return -1;
        if (!a.isFolder && b.isFolder) return 1;

        int comparison;
        switch (_sortBy) {
          case 'name':
            comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
            break;
          case 'date':
            comparison = a.lastModified.compareTo(b.lastModified);
            break;
          case 'size':
            comparison = a.size.compareTo(b.size);
            break;
          default:
            comparison = 0;
        }
        return _sortAscending ? comparison : -comparison;
      });
    });
  }

  Future<void> _toggleFavorite(FileItem file) async {
    try {
      final authData = await AuthService().getAuthData();
      final token = authData['token'];
      if (token == null) throw Exception('Not authenticated');

      final apiService = ApiService();

      setState(() {
        final index = _files.indexWhere((f) => f.name == file.name);
        if (index != -1) {
          _files[index] = FileItem(
            id: file.id,
            name: file.name,
            size: file.size,
            mimeType: file.mimeType,
            lastModified: file.lastModified,
            isFavorite: !file.isFavorite,
            fileCount: file.fileCount,
            folderCount: file.folderCount,
            totalSize: file.totalSize,
          );
        }
      });

      await apiService.toggleFavorite(token, file.name, _currentPath);
    } catch (e) {
      setState(() {
        final index = _files.indexWhere((f) => f.name == file.name);
        if (index != -1) {
          _files[index] = file;
        }
      });

      if (mounted) {
        ErrorBox.show(
          context,
          message: e.toString().replaceAll('Exception: ', ''),
          title: 'Failed to Toggle Favorite',
          onRetry: () => _toggleFavorite(file),
        );
      }
    }
  }

  Future<void> _showRenameDialog(FileItem file) async {
    final controller = TextEditingController(text: file.name);

    if (!file.isFolder && file.name.contains('.')) {
      final lastDotIndex = file.name.lastIndexOf('.');
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: lastDotIndex,
      );
    } else {
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: file.name.length,
      );
    }

    return showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10.0,
                      offset: Offset(0.0, 10.0),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.drive_file_rename_outline,
                        size: 40,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Rename ${file.isFolder ? 'Folder' : 'File'}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter a new name',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: file.isFolder ? 'Folder Name' : 'File Name',
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.blue,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        prefixIcon: Icon(
                          file.isFolder
                              ? Icons.folder_outlined
                              : Icons.insert_drive_file_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (controller.text.trim().isEmpty) return;
                              if (controller.text.trim() == file.name) {
                                Navigator.pop(context);
                                return;
                              }
                              Navigator.pop(context);
                              await _renameFile(file, controller.text.trim());
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Rename',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Future<void> _renameFile(FileItem file, String newName) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authData = await AuthService().getAuthData();
      final token = authData['token'];

      if (token == null) {
        throw Exception('Not authenticated');
      }

      if (file.id == null) {
        throw Exception('File ID not available');
      }

      final apiService = ApiService();
      await apiService.renameFile(token, file.id!, newName);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Renamed to "$newName"'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _refreshFilesSilently();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ErrorBox.show(
          context,
          message: e.toString().replaceAll('Exception: ', ''),
          title: 'Failed to Rename',
          onRetry: () => _renameFile(file, newName),
        );
      }
    }
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setModalState) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Sort By',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Done'),
                            ),
                          ],
                        ),
                      ),
                      _buildSortOption(
                        'Name',
                        'name',
                        Icons.sort_by_alpha,
                        setModalState,
                      ),
                      _buildSortOption(
                        'Date Modified',
                        'date',
                        Icons.access_time,
                        setModalState,
                      ),
                      _buildSortOption(
                        'Size',
                        'size',
                        Icons.data_usage,
                        setModalState,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
          ),
    );
  }

  Widget _buildSortOption(
    String title,
    String value,
    IconData icon,
    StateSetter setModalState,
  ) {
    final isSelected = _sortBy == value;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? Colors.blue.withValues(alpha: 0.1)
                  : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: isSelected ? Colors.blue : Colors.grey[600]),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.blue : Colors.black87,
        ),
      ),
      trailing:
          isSelected
              ? Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                color: Colors.blue,
              )
              : null,
      onTap: () {
        setState(() {
          if (_sortBy == value) {
            _sortAscending = !_sortAscending;
          } else {
            _sortBy = value;
            _sortAscending = true;
          }
          _sortFiles();
        });
        setModalState(() {});
      },
    );
  }

  void _showAdvancedFilters() {
    final nameController = TextEditingController(text: _searchQuery);
    final includeController = TextEditingController(text: _includeFormats);
    final excludeController = TextEditingController(text: _excludeFormats);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setModalState) => Container(
                  padding: const EdgeInsets.all(24),
                  height: MediaQuery.of(context).size.height * 0.85,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Advanced Filters',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'File Name',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            hintText: 'Search by name...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Include Formats',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Comma separated (e.g. jpg, png, pdf)',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: includeController,
                          decoration: InputDecoration(
                            hintText: 'e.g. jpg, png',
                            prefixIcon: const Icon(Icons.check_circle_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Exclude Formats',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Comma separated (e.g. exe, bat)',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: excludeController,
                          decoration: InputDecoration(
                            hintText: 'e.g. exe, bat',
                            prefixIcon: const Icon(Icons.block),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Date Modified',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              _dateFilters.map((filter) {
                                final isSelected = _dateFilter == filter;
                                return FilterChip(
                                  label: Text(filter),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      _dateFilter = filter;
                                    });
                                    setModalState(() {});
                                  },
                                  backgroundColor: Colors.grey[100],
                                  selectedColor: Colors.blue.shade50,
                                  labelStyle: TextStyle(
                                    color:
                                        isSelected
                                            ? Colors.blue
                                            : Colors.black87,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(
                                      color:
                                          isSelected
                                              ? Colors.blue.withValues(
                                                alpha: 0.5,
                                              )
                                              : Colors.transparent,
                                    ),
                                  ),
                                  showCheckmark: false,
                                );
                              }).toList(),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'File Size',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              _sizeFilters.map((filter) {
                                final isSelected = _sizeFilter == filter;
                                return FilterChip(
                                  label: Text(filter),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      _sizeFilter = filter;
                                    });
                                    setModalState(() {});
                                  },
                                  backgroundColor: Colors.grey[100],
                                  selectedColor: Colors.blue.shade50,
                                  labelStyle: TextStyle(
                                    color:
                                        isSelected
                                            ? Colors.blue
                                            : Colors.black87,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(
                                      color:
                                          isSelected
                                              ? Colors.blue.withValues(
                                                alpha: 0.5,
                                              )
                                              : Colors.transparent,
                                    ),
                                  ),
                                  showCheckmark: false,
                                );
                              }).toList(),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  nameController.clear();
                                  includeController.clear();
                                  excludeController.clear();
                                  setState(() {
                                    _dateFilter = 'All Time';
                                    _sizeFilter = 'Any Size';
                                    _searchQuery = '';
                                    _includeFormats = '';
                                    _excludeFormats = '';
                                  });
                                  setModalState(() {});
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Reset'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = nameController.text.trim();
                                    _includeFormats =
                                        includeController.text.trim();
                                    _excludeFormats =
                                        excludeController.text.trim();
                                  });
                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Apply Filters',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  Future<void> _pickAndUploadFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      setState(() {
        _isUploading = true;
      });

      final authData = await AuthService().getAuthData();
      final token = authData['token'];

      if (token == null) {
        throw Exception('Not authenticated');
      }

      final apiService = ApiService();
      List<String> errors = [];

      for (final file in result.files) {
        if (file.path != null) {
          try {
            await apiService.uploadFile(
              token,
              widget.username,
              File(file.path!),
              folder: _currentPath,
            );
          } catch (e) {
            errors.add('Failed to upload ${file.name}');
          }
        }
      }

      if (mounted) {
        setState(() {
          _isUploading = false;
        });

        _refreshFilesSilently();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        ErrorBox.show(
          context,
          message: e.toString().replaceAll('Exception: ', ''),
          title: 'Upload Failed',
          onRetry: _pickAndUploadFiles,
        );
      }
    }
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: const Text(
                      'Create New',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.cloud_upload_rounded,
                        color: Colors.blue,
                      ),
                    ),
                    title: const Text('Upload Files'),
                    subtitle: const Text('Select files from your device'),
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndUploadFiles();
                    },
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.create_new_folder_rounded,
                        color: Colors.blue,
                      ),
                    ),
                    title: const Text('Create Folder'),
                    subtitle: const Text('Create a new folder'),
                    onTap: () {
                      Navigator.pop(context);
                      _showCreateFolderDialog();
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
    );
  }

  void _navigateToFolder(String folderName) {
    setState(() {
      if (_currentPath == '/') {
        _currentPath = '/$folderName';
      } else {
        _currentPath = '$_currentPath/$folderName';
      }
    });
    _loadFiles();
  }

  void _navigateUp() {
    if (_currentPath == '/') return;
    setState(() {
      final lastSlashIndex = _currentPath.lastIndexOf('/');
      if (lastSlashIndex == 0) {
        _currentPath = '/';
      } else {
        _currentPath = _currentPath.substring(0, lastSlashIndex);
      }
    });
    _loadFiles();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentPath == '/',
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && _currentPath != '/') {
          _navigateUp();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        key: _scaffoldKey,
        drawerEnableOpenDragGesture: true,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            _currentPath == '/' ? 'My Files' : _currentPath.split('/').last,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: false,
          iconTheme: const IconThemeData(color: Colors.black87),
          leading: Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(Icons.menu, color: Colors.black87),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              );
            },
          ),
          actions: [
            if (_isUploading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
                ),
              ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _isGridView
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded,
                  size: 20,
                ),
              ),
              onPressed: () => setState(() => _isGridView = !_isGridView),
            ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      (_dateFilter != 'All Time' ||
                              _sizeFilter != 'Any Size' ||
                              _includeFormats.isNotEmpty ||
                              _excludeFormats.isNotEmpty)
                          ? Colors.blue.shade50
                          : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color:
                      (_dateFilter != 'All Time' ||
                              _sizeFilter != 'Any Size' ||
                              _includeFormats.isNotEmpty ||
                              _excludeFormats.isNotEmpty)
                          ? Colors.blue
                          : Colors.black87,
                ),
              ),
              onPressed: _showAdvancedFilters,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.sort_rounded, size: 20),
              ),
              onPressed: _showSortOptions,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.create_new_folder_rounded,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              onPressed: _showCreateFolderDialog,
            ),
            const SizedBox(width: 16),
          ],
        ),
        drawer: AppDrawer(
          username: widget.username,
          email: widget.email,
          currentPage: 'My Files',
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (details) {
            _dragStartX = details.globalPosition.dx;
            _dragAccumDx = 0.0;
            _dragAccumDy = 0.0;
          },
          onPanUpdate: (details) {
            _dragAccumDx += details.delta.dx;
            _dragAccumDy += details.delta.dy.abs();

            if (_dragStartX != null &&
                _dragStartX! < 100 &&
                _dragAccumDx > 60 &&
                _dragAccumDx > _dragAccumDy * 1.5) {
              _scaffoldKey.currentState?.openDrawer();
              _dragStartX = null;
              _dragAccumDx = 0.0;
              _dragAccumDy = 0.0;
            }
          },
          onPanEnd: (_) {
            _dragStartX = null;
            _dragAccumDx = 0.0;
            _dragAccumDy = 0.0;
          },
          child: Column(
            children: [
              _buildBreadcrumbs(),
              _buildFilterBar(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddOptions,
          backgroundColor: Colors.blue,
          elevation: 4,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            'New',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs() {
    final pathSegments =
        _currentPath.split('/').where((s) => s.isNotEmpty).toList();

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            InkWell(
              onTap: () {
                if (_currentPath != '/') {
                  setState(() {
                    _currentPath = '/';
                  });
                  _loadFiles();
                }
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(
                  Icons.home_rounded,
                  size: 20,
                  color: _currentPath == '/' ? Colors.grey[800] : Colors.blue,
                ),
              ),
            ),
            if (pathSegments.isNotEmpty) ...[
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: Colors.grey,
              ),
              for (int i = 0; i < pathSegments.length; i++) ...[
                InkWell(
                  onTap:
                      i == pathSegments.length - 1
                          ? null
                          : () {
                            final newPath =
                                '/${pathSegments.sublist(0, i + 1).join('/')}';
                            setState(() {
                              _currentPath = newPath;
                            });
                            _loadFiles();
                          },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Text(
                      pathSegments[i],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color:
                            i == pathSegments.length - 1
                                ? Colors.grey[800]
                                : Colors.blue,
                      ),
                    ),
                  ),
                ),
                if (i < pathSegments.length - 1)
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: Colors.grey,
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: Colors.white,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;
          return FilterChip(
            label: Text(filter),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                _selectedFilter = filter;
              });
            },
            backgroundColor: Colors.grey[100],
            selectedColor: Colors.blue.withValues(alpha: 0.1),
            labelStyle: TextStyle(
              color: isSelected ? Colors.blue : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color:
                    isSelected
                        ? Colors.blue.withValues(alpha: 0.5)
                        : Colors.transparent,
              ),
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return ErrorView(message: _errorMessage!, onRetry: _loadFiles);
    }

    final filesToShow = _filteredFiles;

    if (filesToShow.isEmpty) {
      return Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_open_rounded,
                size: 64,
                color: Colors.blue[300],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _selectedFilter == 'All'
                  ? 'No files yet'
                  : 'No $_selectedFilter found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload files or create a folder to get started',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _showCreateFolderDialog,
                  icon: const Icon(Icons.create_new_folder_rounded),
                  label: const Text('Create Folder'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _pickAndUploadFiles,
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: const Text('Upload Files'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFiles,
      child:
          _isGridView
              ? _buildGridBody(filesToShow)
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filesToShow.length,
                itemBuilder: (context, index) {
                  final file = filesToShow[index];
                  return _buildFileCard(file);
                },
              ),
    );
  }

  Widget _buildGridBody(List<FileItem> files) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        return _buildGridItem(files[index]);
      },
    );
  }

  Widget _buildGridItem(FileItem file) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (file.isFolder) {
                    _navigateToFolder(file.name);
                  } else {
                    // TODO: Open file preview
                  }
                },
                onLongPress: () => _showFileOptions(file),
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: _getFileColor(file).withValues(alpha: 0.1),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        child: Center(child: _buildFileIcon(file, size: 48)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            file.isFolder
                                ? file.folderInfo
                                : file.formattedSize,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _toggleFavorite(file),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    file.isFavorite ? Icons.favorite : Icons.favorite_border,
                    size: 20,
                    color: file.isFavorite ? Colors.red : Colors.grey[400],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard(FileItem file) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getFileColor(file).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: _buildFileIcon(file, size: 24)),
          ),
          title: Text(
            file.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                file.isFolder
                    ? file.folderInfo
                    : '${file.formattedSize} • ${_formatDate(file.lastModified)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  file.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: file.isFavorite ? Colors.red : Colors.grey[400],
                ),
                onPressed: () => _toggleFavorite(file),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded),
                color: Colors.grey[400],
                onPressed: () => _showFileOptions(file),
              ),
            ],
          ),
          onTap: () {
            if (file.isFolder) {
              _navigateToFolder(file.name);
            } else {
              // TODO: Open file preview
            }
          },
        ),
      ),
    );
  }

  Future<void> _downloadFolder(FileItem file) async {
    if (!file.isFolder) return;

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Text('Downloading ${file.name}...'),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      final token = await AuthService().getToken();
      if (token == null) {
        throw Exception('No token found');
      }

      String folderPath =
          _currentPath == '/' ? '/${file.name}' : '$_currentPath/${file.name}';

      final zipBytes = await ApiService().downloadFolder(token, folderPath);

      final directory = await getDownloadsDirectory();
      final filePath = path.join(directory!.path, '${file.name}.zip');
      final zipFile = File(filePath);
      await zipFile.writeAsBytes(zipBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded ${file.name}.zip to Downloads'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'OPEN',
              textColor: Colors.white,
              onPressed: () {
                // TODO: Open file location
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading folder: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showShareOptions(FileItem file) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.share_rounded,
                            size: 28,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Share "${file.name}"',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Choose how you want to share this file',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.group_add_rounded,
                        color: Colors.purple,
                      ),
                    ),
                    title: const Text('Share with Group'),
                    subtitle: const Text('Add to an existing group'),
                    onTap: () {
                      Navigator.pop(context);
                      _shareWithGroupList(file);
                    },
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.person_add_rounded,
                        color: Colors.teal,
                      ),
                    ),
                    title: const Text('Share with User'),
                    subtitle: const Text('Send to a specific person'),
                    onTap: () {
                      Navigator.pop(context);
                      _shareWithUserDialog(file);
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _shareWithUserDialog(FileItem file) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add_rounded,
                      size: 32,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Share with User',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter email or username',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Email or Username',
                      prefixIcon: const Icon(Icons.alternate_email_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (controller.text.trim().isEmpty) return;
                            Navigator.pop(context);
                            await _shareFileWithUser(
                              file,
                              controller.text.trim(),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Share',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _shareWithGroupList(FileItem file) async {
    // Show loading dialog then fetch groups
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final authData = await AuthService().getAuthData();
      final token = authData['token'];
      if (token == null) throw Exception('Not authenticated');

      final groups = await ApiService().listGroups(token);
      if (mounted) Navigator.pop(context);

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (context) => DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              builder:
                  (_, controller) =>
                      _buildGroupSelectionSheet(controller, groups, file),
            ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load groups: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildGroupSelectionSheet(
    ScrollController controller,
    List<dynamic> groups,
    FileItem file,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 20),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Icon(
                  Icons.group_add_rounded,
                  color: Colors.purple,
                  size: 28,
                ),
                const SizedBox(width: 16),
                const Text(
                  'Select Group',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(height: 32),
          Expanded(
            child:
                groups.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.groups_3_outlined,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No groups found',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      controller: controller,
                      itemCount: groups.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.purple.withValues(
                              alpha: 0.1,
                            ),
                            child: Text(
                              (group['name'] as String)[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.purple,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            group['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('${group['member_count']} members'),
                          trailing: const Icon(
                            Icons.add_circle_outline_rounded,
                            color: Colors.blue,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _shareFileWithGroup(file, group['id']);
                          },
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareFileWithGroup(FileItem file, int groupId) async {
    if (file.id == null) return;
    try {
      final authData = await AuthService().getAuthData();
      final token = authData['token'];
      if (token == null) throw Exception('Not authenticated');

      await ApiService().shareFileWithGroup(token, groupId, file.id!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File shared with group successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareFileWithUser(FileItem file, String emailOrUsername) async {
    if (file.id == null) return;
    try {
      final authData = await AuthService().getAuthData();
      final token = authData['token'];
      if (token == null) throw Exception('Not authenticated');

      await ApiService().shareFileWithUser(token, file.id!, emailOrUsername);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shared with $emailOrUsername'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showFileDetails(FileItem file) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _getFileColor(file).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: _buildFileIcon(file, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              file.isFolder ? 'Folder' : file.mimeType,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  _buildDetailRow(
                    Icons.sd_storage_rounded,
                    'Size',
                    file.isFolder ? file.folderInfo : file.formattedSize,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    Icons.calendar_today_rounded,
                    'Modified',
                    _formatDetailDate(file.lastModified),
                  ),
                  if (file.isFavorite) ...[
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      Icons.favorite_rounded,
                      'Status',
                      'Favorited',
                      iconColor: Colors.red,
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    Color? iconColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: iconColor ?? Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDetailDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showFileOptions(FileItem file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _getFileColor(file).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: _buildFileIcon(file, size: 24),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  file.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  file.isFolder ? 'Folder' : file.mimeType,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        file.isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: file.isFavorite ? Colors.red : Colors.grey[700],
                      ),
                      title: Text(
                        file.isFavorite
                            ? 'Remove from Favorites'
                            : 'Add to Favorites',
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _toggleFavorite(file);
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.download_rounded,
                        color: Colors.grey[700],
                      ),
                      title: const Text('Download'),
                      onTap: () {
                        Navigator.pop(context);
                        if (file.isFolder) {
                          _downloadFolder(file);
                        } else {
                          // TODO: Implement file download
                        }
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.drive_file_rename_outline,
                        color: Colors.grey[700],
                      ),
                      title: const Text('Rename'),
                      onTap: () {
                        Navigator.pop(context);
                        _showRenameDialog(file);
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: Icon(
                        Icons.share_rounded,
                        color: Colors.blue[600],
                      ),
                      title: Text(
                        'Share',
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _showShareOptions(file);
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: Icon(
                        Icons.info_outline_rounded,
                        color: Colors.grey[700],
                      ),
                      title: const Text('Details'),
                      onTap: () {
                        Navigator.pop(context);
                        _showFileDetails(file);
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red,
                      ),
                      title: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Implement delete
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Color _getFileColor(FileItem file) {
    if (file.isFolder) return Colors.blue;
    if (file.mimeType.startsWith('image/')) return Colors.purple;
    if (file.mimeType.startsWith('video/')) return Colors.orange;
    if (file.mimeType.startsWith('audio/')) return Colors.red;
    if (file.mimeType.contains('pdf')) return Colors.red;
    if (file.mimeType.contains('word')) return Colors.blue;
    if (file.mimeType.contains('excel')) return Colors.green;
    return Colors.grey;
  }

  Widget _buildFileIcon(FileItem file, {double size = 24}) {
    IconData icon;
    Color color;

    if (file.isFolder) {
      icon = Icons.folder_rounded;
      color = Colors.blue;
    } else if (file.mimeType.startsWith('image/')) {
      icon = Icons.image_rounded;
      color = Colors.purple;
    } else if (file.mimeType.startsWith('video/')) {
      icon = Icons.videocam_rounded;
      color = Colors.orange;
    } else if (file.mimeType.startsWith('audio/')) {
      icon = Icons.audiotrack_rounded;
      color = Colors.red;
    } else if (file.mimeType.contains('pdf')) {
      icon = Icons.picture_as_pdf_rounded;
      color = Colors.red;
    } else if (file.mimeType.contains('document') ||
        file.mimeType.contains('word')) {
      icon = Icons.description_rounded;
      color = Colors.blue;
    } else if (file.mimeType.contains('spreadsheet') ||
        file.mimeType.contains('excel')) {
      icon = Icons.table_chart_rounded;
      color = Colors.green;
    } else if (file.mimeType.contains('presentation') ||
        file.mimeType.contains('powerpoint')) {
      icon = Icons.slideshow_rounded;
      color = Colors.orange;
    } else if (file.mimeType.contains('zip') ||
        file.mimeType.contains('archive') ||
        file.mimeType.contains('compressed')) {
      icon = Icons.folder_zip_rounded;
      color = Colors.grey[700]!;
    } else {
      icon = Icons.insert_drive_file_rounded;
      color = Colors.grey;
    }

    return Icon(icon, color: color, size: size);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else {
      return '${(difference.inDays / 365).floor()}y ago';
    }
  }
}
