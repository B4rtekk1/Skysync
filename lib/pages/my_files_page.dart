import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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
        folder: '/',
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
        folder: '/',
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
      print('Error refreshing files: $e');
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
          (context) => AlertDialog(
            title: const Text('New Folder'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Folder Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (controller.text.trim().isEmpty) return;
                  Navigator.pop(context);
                  await _createFolder(controller.text.trim());
                },
                child: const Text('Create'),
              ),
            ],
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
      await apiService.createFolder(token, widget.username, folderName);

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

      await apiService.toggleFavorite(token, file.name, "/");
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

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.sort_by_alpha),
                title: const Text('Name'),
                trailing:
                    _sortBy == 'name'
                        ? Icon(
                          _sortAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                        )
                        : null,
                onTap: () {
                  setState(() {
                    if (_sortBy == 'name') {
                      _sortAscending = !_sortAscending;
                    } else {
                      _sortBy = 'name';
                      _sortAscending = true;
                    }
                    _sortFiles();
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Date Modified'),
                trailing:
                    _sortBy == 'date'
                        ? Icon(
                          _sortAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                        )
                        : null,
                onTap: () {
                  setState(() {
                    if (_sortBy == 'date') {
                      _sortAscending = !_sortAscending;
                    } else {
                      _sortBy = 'date';
                      _sortAscending = false;
                    }
                    _sortFiles();
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.data_usage),
                title: const Text('Size'),
                trailing:
                    _sortBy == 'size'
                        ? Icon(
                          _sortAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                        )
                        : null,
                onTap: () {
                  setState(() {
                    if (_sortBy == 'size') {
                      _sortAscending = !_sortAscending;
                    } else {
                      _sortBy = 'size';
                      _sortAscending = false;
                    }
                    _sortFiles();
                  });
                  Navigator.pop(context);
                },
              ),
            ],
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
            );
          } catch (e) {
            errors.add('Failed to upload ${file.name}');
            print('Error uploading ${file.name}: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'My Files',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black54),
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
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
          IconButton(icon: const Icon(Icons.sort), onPressed: _showSortOptions),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'new_folder') {
                _showCreateFolderDialog();
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'new_folder',
                    child: Row(
                      children: [
                        Icon(Icons.create_new_folder, size: 20),
                        SizedBox(width: 12),
                        Text('New Folder'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      drawer: AppDrawer(
        username: widget.username,
        email: widget.email,
        currentPage: 'My Files',
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickAndUploadFiles,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.cloud_upload, color: Colors.white),
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

    if (_files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No files yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload files to get started',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFiles,
      child:
          _isGridView
              ? _buildGridBody()
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _files.length,
                itemBuilder: (context, index) {
                  final file = _files[index];
                  return _buildFileCard(file);
                },
              ),
    );
  }

  Widget _buildGridBody() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0,
      ),
      itemCount: _files.length,
      itemBuilder: (context, index) {
        return _buildGridItem(_files[index]);
      },
    );
  }

  Widget _buildGridItem(FileItem file) {
    return Stack(
      children: [
        InkWell(
          onTap: () {
            if (file.isFolder) {
              // TODO: Navigate into folder
            } else {
              // TODO: Open file preview
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(child: Center(child: _buildFileIcon(file, size: 48))),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Text(
                        file.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        file.isFolder
                            ? file.folderInfo
                            : '${file.formattedSize} • ${_formatDate(file.lastModified)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton(
            icon: Icon(
              file.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: file.isFavorite ? Colors.red : Colors.grey[400],
            ),
            onPressed: () => _toggleFavorite(file),
          ),
        ),
      ],
    );
  }

  Widget _buildFileCard(FileItem file) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _buildFileIcon(file, size: 24),
        ),
        title: Text(
          file.name,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          file.isFolder
              ? file.folderInfo
              : '${file.formattedSize} • ${_formatDate(file.lastModified)}',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
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
              tooltip:
                  file.isFavorite
                      ? 'Remove from favorites'
                      : 'Add to favorites',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(Icons.download, size: 20),
                          SizedBox(width: 12),
                          Text('Download'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(Icons.share, size: 20),
                          SizedBox(width: 12),
                          Text('Share'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 20),
                          SizedBox(width: 12),
                          Text('Details'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Colors.red,
                          ),
                          SizedBox(width: 12),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
            ),
          ],
        ),
        onTap: () {
          if (file.isFolder) {
            // TODO: Navigate into folder
          } else {
            // TODO: Open file preview
          }
        },
      ),
    );
  }

  Widget _buildFileIcon(FileItem file, {double size = 24}) {
    IconData icon;
    Color color;

    if (file.isFolder) {
      icon = Icons.folder;
      color = Colors.blue;
    } else if (file.mimeType.startsWith('image/')) {
      icon = Icons.image;
      color = Colors.green;
    } else if (file.mimeType.startsWith('video/')) {
      icon = Icons.videocam;
      color = Colors.purple;
    } else if (file.mimeType.startsWith('audio/')) {
      icon = Icons.audiotrack;
      color = Colors.orange;
    } else if (file.mimeType.contains('pdf')) {
      icon = Icons.picture_as_pdf;
      color = Colors.red;
    } else if (file.mimeType.contains('document') ||
        file.mimeType.contains('word')) {
      icon = Icons.description;
      color = Colors.blue[700]!;
    } else if (file.mimeType.contains('spreadsheet') ||
        file.mimeType.contains('excel')) {
      icon = Icons.table_chart;
      color = Colors.green[700]!;
    } else if (file.mimeType.contains('presentation') ||
        file.mimeType.contains('powerpoint')) {
      icon = Icons.slideshow;
      color = Colors.orange[700]!;
    } else if (file.mimeType.contains('zip') ||
        file.mimeType.contains('archive') ||
        file.mimeType.contains('compressed')) {
      icon = Icons.folder_zip;
      color = Colors.grey[700]!;
    } else {
      icon = Icons.insert_drive_file;
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
