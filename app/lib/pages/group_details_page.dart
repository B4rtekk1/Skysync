import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class GroupDetailsPage extends StatefulWidget {
  final int groupId;
  final String groupName;
  final String username;

  const GroupDetailsPage({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.username,
  });

  @override
  State<GroupDetailsPage> createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  bool _isUploading = false;

  bool _isGridView = false;
  String _sortBy = 'name';
  bool _sortAscending = true;
  String _selectedFilter = 'All';
  String _searchQuery = '';
  String _includeFormats = '';
  String _excludeFormats = '';
  String _dateFilter = 'All Time';
  String _sizeFilter = 'Any Size';

  final List<String> _filters = [
    'All',
    'Folders',
    'Images',
    'Videos',
    'Documents',
    'Audio',
  ];

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

  List<Map<String, dynamic>> get _filteredFiles {
    List<Map<String, dynamic>> allItems = [];

    for (var folder in _folders) {
      allItems.add({
        'type': 'folder',
        'name': folder['folder_path'],
        'date': DateTime.parse(folder['shared_at']),
        'size': 0,
        'original': folder,
      });
    }

    for (var file in _files) {
      allItems.add({
        'type': 'file',
        'name': file['filename'],
        'date': DateTime.parse(file['uploaded_at'] ?? file['shared_at']),
        'size': file['file_size'],
        'mime_type': file['mime_type'],
        'original': file,
      });
    }

    var filtered = allItems;

    if (_selectedFilter != 'All') {
      filtered =
          filtered.where((item) {
            if (_selectedFilter == 'Folders') return item['type'] == 'folder';
            if (item['type'] == 'folder') return false;

            final mimeType = item['mime_type'] as String;
            if (_selectedFilter == 'Images') {
              return mimeType.startsWith('image/');
            }
            if (_selectedFilter == 'Videos') {
              return mimeType.startsWith('video/');
            }
            if (_selectedFilter == 'Audio') {
              return mimeType.startsWith('audio/');
            }
            if (_selectedFilter == 'Documents') {
              return mimeType.contains('pdf') ||
                  mimeType.contains('document') ||
                  mimeType.contains('word') ||
                  mimeType.contains('text') ||
                  mimeType.contains('spreadsheet') ||
                  mimeType.contains('presentation');
            }
            return false;
          }).toList();
    }

    final now = DateTime.now();
    if (_dateFilter == 'Today') {
      filtered =
          filtered.where((item) {
            final date = item['date'] as DateTime;
            return date.year == now.year &&
                date.month == now.month &&
                date.day == now.day;
          }).toList();
    } else if (_dateFilter == 'Last 7 Days') {
      final limit = now.subtract(const Duration(days: 7));
      filtered =
          filtered
              .where((item) => (item['date'] as DateTime).isAfter(limit))
              .toList();
    } else if (_dateFilter == 'Last 30 Days') {
      final limit = now.subtract(const Duration(days: 30));
      filtered =
          filtered
              .where((item) => (item['date'] as DateTime).isAfter(limit))
              .toList();
    }

    if (_sizeFilter == 'Small (<1MB)') {
      filtered =
          filtered
              .where((item) => (item['size'] as int) < 1024 * 1024)
              .toList();
    } else if (_sizeFilter == 'Medium (1-100MB)') {
      filtered =
          filtered.where((item) {
            final size = item['size'] as int;
            return size >= 1024 * 1024 && size < 100 * 1024 * 1024;
          }).toList();
    } else if (_sizeFilter == 'Large (>100MB)') {
      filtered =
          filtered
              .where((item) => (item['size'] as int) >= 100 * 1024 * 1024)
              .toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered
              .where(
                (item) => (item['name'] as String).toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
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
          filtered.where((item) {
            if (item['type'] == 'folder') return false;
            final ext = (item['name'] as String).split('.').last.toLowerCase();
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
          filtered.where((item) {
            if (item['type'] == 'folder') return true;
            final ext = (item['name'] as String).split('.').last.toLowerCase();
            return !formats.contains(ext);
          }).toList();
    }

    filtered.sort((a, b) {
      if (a['type'] == 'folder' && b['type'] != 'folder') return -1;
      if (a['type'] != 'folder' && b['type'] == 'folder') return 1;

      int comparison;
      switch (_sortBy) {
        case 'name':
          comparison = (a['name'] as String).toLowerCase().compareTo(
            (b['name'] as String).toLowerCase(),
          );
          break;
        case 'date':
          comparison = (a['date'] as DateTime).compareTo(b['date'] as DateTime);
          break;
        case 'size':
          comparison = (a['size'] as int).compareTo(b['size'] as int);
          break;
        default:
          comparison = 0;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  List<Map<String, dynamic>> _files = [];
  List<Map<String, dynamic>> _folders = [];
  List<Map<String, dynamic>> _members = [];
  bool _isAdmin = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _loadGroupData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authData = await AuthService().getAuthData();
      final token = authData['token'];

      if (token == null) throw Exception('Not authenticated');

      final apiService = ApiService();

      final details = await apiService.getGroupDetails(token, widget.groupId);

      final filesData = await apiService.getGroupFiles(token, widget.groupId);

      setState(() {
        _members = List<Map<String, dynamic>>.from(details['members']);
        _isAdmin = details['is_admin'] ?? false;

        _files = List<Map<String, dynamic>>.from(filesData['files'] ?? []);
        _folders = List<Map<String, dynamic>>.from(filesData['folders'] ?? []);

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _addMember() async {
    final controller = TextEditingController();
    bool isAdmin = false;

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => Dialog(
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
                            color: Colors.blue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_add_rounded,
                            size: 32,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Invite Member',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter their email or username to add them to the group',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: controller,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: 'Email or Username',
                            hintText: 'john@example.com',
                            prefixIcon: const Icon(
                              Icons.alternate_email_rounded,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.blue,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color:
                                isAdmin
                                    ? Colors.blue.withValues(alpha: 0.05)
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  isAdmin
                                      ? Colors.blue.withValues(alpha: 0.3)
                                      : Colors.grey[300]!,
                            ),
                          ),
                          child: SwitchListTile(
                            title: const Text(
                              'Admin Access',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: const Text(
                              'Can manage members and settings',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: isAdmin,
                            onChanged: (val) => setState(() => isAdmin = val),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (controller.text.trim().isEmpty) return;
                                  final scaffoldMessenger =
                                      ScaffoldMessenger.of(this.context);
                                  Navigator.pop(context);

                                  try {
                                    final authData =
                                        await AuthService().getAuthData();
                                    final token = authData['token'];
                                    if (token == null) {
                                      throw Exception('Not authenticated');
                                    }

                                    await ApiService().addMemberToGroup(
                                      token,
                                      widget.groupId,
                                      controller.text.trim(),
                                      isAdmin: isAdmin,
                                    );

                                    if (!mounted) return;
                                    scaffoldMessenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Invitation sent successfully',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    _loadGroupData();
                                  } catch (e) {
                                    if (!mounted) return;
                                    scaffoldMessenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          e.toString().replaceAll(
                                            'Exception: ',
                                            '',
                                          ),
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Invite',
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

  Future<void> _removeMember(int userId) async {
    try {
      final authData = await AuthService().getAuthData();
      final token = authData['token'];
      if (token == null) throw Exception('Not authenticated');

      await ApiService().removeMemberFromGroup(token, widget.groupId, userId);

      if (mounted) {
        _loadGroupData();
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

  Future<void> _showShareOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12),
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
                        const Text(
                          'Share File',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Choose how to add a file',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _ShareOptionCard(
                          icon: Icons.phone_android_rounded,
                          title: 'From Device',
                          subtitle: 'Upload from your device',
                          onTap: () {
                            Navigator.pop(context);
                            _uploadFromDevice();
                          },
                        ),
                        const SizedBox(height: 12),
                        _ShareOptionCard(
                          icon: Icons.cloud_outlined,
                          title: 'From Cloud',
                          subtitle: 'Your Skysync files',
                          onTap: () {
                            Navigator.pop(context);
                            _selectFromServer();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _uploadFromDevice() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) return;

      setState(() => _isUploading = true);

      final authData = await AuthService().getAuthData();
      final token = authData['token'];
      final username = authData['username'];

      if (token == null || username == null) {
        throw Exception('Not authenticated');
      }

      await ApiService().uploadFile(
        token,
        username,
        File(file.path!),
        folder: '/',
      );

      final files = await ApiService().listFiles(token, username);
      final uploadedFile = files.firstWhere(
        (f) => f['name'] == file.name,
        orElse: () => {},
      );

      if (uploadedFile.isNotEmpty && uploadedFile['id'] != null) {
        await ApiService().shareFileWithGroup(
          token,
          widget.groupId,
          uploadedFile['id'],
        );
      }

      if (mounted) {
        setState(() => _isUploading = false);
        _loadGroupData();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectFromServer() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder:
          (dialogContext) => _FileSelectionDialog(
            onFileSelected: (fileId) async {
              try {
                final authData = await AuthService().getAuthData();
                final token = authData['token'];
                if (token == null) throw Exception('Not authenticated');

                await ApiService().shareFileWithGroup(
                  token,
                  widget.groupId,
                  fileId,
                );

                if (mounted) {
                  _loadGroupData();
                }
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceAll('Exception: ', '')),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.groupName,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: 'Files & Folders', icon: Icon(Icons.folder_outlined)),
            Tab(text: 'Members', icon: Icon(Icons.people_outline)),
          ],
        ),
        actions: [
          if (_tabController.index == 0) ...[
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
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGroupData,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          if (_tabController.index == 0) _buildFilterBar(),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                    ? Center(child: Text(_errorMessage!))
                    : TabBarView(
                      controller: _tabController,
                      children: [_buildFilesTab(), _buildMembersTab()],
                    ),
          ),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildFab() {
    if (_tabController.index == 0) {
      return FloatingActionButton.extended(
        onPressed: _showShareOptions,
        icon:
            _isUploading
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                : const Icon(Icons.add),
        label: Text(_isUploading ? 'Uploading...' : 'Share File'),
      );
    } else if (_isAdmin) {
      return FloatingActionButton.extended(
        onPressed: _addMember,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Member'),
      );
    }
    return const SizedBox.shrink();
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

  Widget _buildFilesTab() {
    final filesToShow = _filteredFiles;

    if (filesToShow.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
                  ? 'No files shared yet'
                  : 'No $_selectedFilter found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share files to collaborate with the group',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_isGridView) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
        ),
        itemCount: filesToShow.length,
        itemBuilder: (context, index) {
          final item = filesToShow[index];
          if (item['type'] == 'folder') {
            return _buildGridFolderItem(item['original']);
          }
          return _buildGridFileItem(item['original']);
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filesToShow.length,
      itemBuilder: (context, index) {
        final item = filesToShow[index];
        if (item['type'] == 'folder') {
          return _buildFolderCard(item['original']);
        }
        return _buildFileCard(item['original']);
      },
    );
  }

  Widget _buildGridFolderItem(Map<String, dynamic> folder) {
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
                  // TODO: Navigate to folder if supported
                },
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_rounded, size: 48, color: Colors.blue),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        folder['folder_path'] ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isAdmin || folder['shared_by'] == widget.username)
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: Colors.red[400],
                  size: 20,
                ),
                onPressed: () => _unshareFolder(folder['folder_path']),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGridFileItem(Map<String, dynamic> file) {
    final mimeType = file['mime_type'] as String?;
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
                  // TODO: Open file preview
                },
                onLongPress: () => _showFileOptions(file),
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: _getFileColor(mimeType).withValues(alpha: 0.1),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        child: Center(child: _getFileIcon(mimeType, size: 48)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file['filename'] ?? 'Unknown',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_formatSize(file['file_size'])} • ${_formatDate(DateTime.parse(file['shared_at'] ?? DateTime.now().toIso8601String()))}',
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
            child: IconButton(
              icon: const Icon(Icons.more_vert_rounded, size: 20),
              color: Colors.grey[400],
              onPressed: () => _showFileOptions(file),
            ),
          ),
        ],
      ),
    );
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
                        'Date Shared',
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
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Date Shared',
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
                                    setState(() => _dateFilter = filter);
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
                                    setState(() => _sizeFilter = filter);
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
                                  showCheckmark: false,
                                );
                              }).toList(),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'File Formats',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: includeController,
                          decoration: InputDecoration(
                            labelText: 'Include extensions (e.g. jpg, pdf)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: excludeController,
                          decoration: InputDecoration(
                            labelText: 'Exclude extensions',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
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
                                ),
                                child: const Text(
                                  'Apply',
                                  style: TextStyle(color: Colors.white),
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

  void _showFileOptions(Map<String, dynamic> file) {
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
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _getFileColor(
                              file['mime_type'],
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: _getFileIcon(file['mime_type'], size: 24),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                file['filename'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                file['mime_type'] ?? 'Unknown',
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
                    leading: const Icon(
                      Icons.info_outline_rounded,
                      color: Colors.blue,
                    ),
                    title: const Text('File Details'),
                    onTap: () {
                      Navigator.pop(context);
                      _showFileDetails(file);
                    },
                  ),
                  if (_isAdmin || file['shared_by'] == widget.username)
                    ListTile(
                      leading: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.red,
                      ),
                      title: const Text(
                        'Unshare from Group',
                        style: TextStyle(color: Colors.red),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _unshareFile(file['id']);
                      },
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
    );
  }

  void _showFileDetails(Map<String, dynamic> file) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getFileColor(
                        file['mime_type'],
                      ).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: _getFileIcon(file['mime_type'], size: 40),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    file['filename'] ?? 'Unknown',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildDetailRow('Size', _formatSize(file['file_size'])),
                  const SizedBox(height: 12),
                  _buildDetailRow('Type', file['mime_type'] ?? 'Unknown'),
                  const SizedBox(height: 12),
                  _buildDetailRow('Shared by', file['shared_by'] ?? 'Unknown'),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'Shared at',
                    _formatDate(
                      DateTime.parse(
                        file['shared_at'] ?? DateTime.now().toIso8601String(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
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

  Widget _buildMembersTab() {
    if (_members.isEmpty) {
      return const Center(child: Text('No members yet'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _members.length,
      itemBuilder: (context, index) {
        return _buildMemberCard(_members[index]);
      },
    );
  }

  Widget _buildFolderCard(Map<String, dynamic> folder) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.folder_rounded, color: Colors.blue, size: 24),
            ),
          ),
          title: Text(
            folder['folder_path'] ?? 'Unknown',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                'Shared by ${folder['shared_by']}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
          trailing:
              _isAdmin || folder['shared_by'] == widget.username
                  ? IconButton(
                    icon: Icon(
                      Icons.remove_circle_outline_rounded,
                      color: Colors.red[400],
                    ),
                    onPressed: () => _unshareFolder(folder['folder_path']),
                  )
                  : null,
        ),
      ),
    );
  }

  Widget _buildFileCard(Map<String, dynamic> file) {
    final mimeType = file['mime_type'] as String?;
    final color = _getFileColor(mimeType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: _getFileIcon(mimeType, size: 24)),
          ),
          title: Text(
            file['filename'] ?? 'Unknown',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '${_formatSize(file['file_size'])} • ${_formatDate(DateTime.parse(file['shared_at'] ?? DateTime.now().toIso8601String()))}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
          trailing: IconButton(
            icon: Icon(Icons.more_vert_rounded, color: Colors.grey[400]),
            onPressed: () => _showFileOptions(file),
          ),
        ),
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final isMe = member['username'] == widget.username;
    final isAdminMember = member['is_admin'] == true;
    final initial = (member['username'] as String)[0].toUpperCase();

    // Generate a consistent color for the user based on their username
    final colors = [
      Colors.purple,
      Colors.blue,
      Colors.teal,
      Colors.orange,
      Colors.pink,
      Colors.indigo,
      Colors.red,
      Colors.cyan,
    ];
    final colorIndex =
        (member['username'] as String).codeUnits.fold(0, (a, b) => a + b) %
        colors.length;
    final userColor = colors[colorIndex];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          leading: Stack(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: userColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: userColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ),
              ),
              if (isAdminMember)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  member['username'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'You',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                member['email'] ?? 'No email',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
          trailing:
              _isAdmin && !isMe
                  ? PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: Colors.grey[400],
                    ),
                    onSelected: (value) {
                      if (value == 'remove') {
                        _removeMember(member['id']);
                      }
                    },
                    itemBuilder:
                        (context) => [
                          const PopupMenuItem(
                            value: 'remove',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.person_remove_rounded,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Remove',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                  )
                  : null,
        ),
      ),
    );
  }

  Color _getFileColor(String? mimeType) {
    if (mimeType == null) return Colors.grey;
    if (mimeType.startsWith('image/')) return Colors.purple;
    if (mimeType.startsWith('video/')) return Colors.orange;
    if (mimeType.startsWith('audio/')) return Colors.red;
    if (mimeType.contains('pdf')) return Colors.red;
    if (mimeType.contains('word') || mimeType.contains('document')) {
      return Colors.blue;
    }
    if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) {
      return Colors.green;
    }
    if (mimeType.contains('zip') || mimeType.contains('compressed')) {
      return Colors.grey;
    }
    return Colors.blue;
  }

  Icon _getFileIcon(String? mimeType, {double size = 32}) {
    IconData icon;
    Color color;

    if (mimeType == null) {
      icon = Icons.insert_drive_file_rounded;
      color = Colors.grey;
    } else if (mimeType.startsWith('image/')) {
      icon = Icons.image_rounded;
      color = Colors.purple;
    } else if (mimeType.startsWith('video/')) {
      icon = Icons.videocam_rounded;
      color = Colors.orange;
    } else if (mimeType.startsWith('audio/')) {
      icon = Icons.audiotrack_rounded;
      color = Colors.red;
    } else if (mimeType.contains('pdf')) {
      icon = Icons.picture_as_pdf_rounded;
      color = Colors.red;
    } else if (mimeType.contains('word') || mimeType.contains('document')) {
      icon = Icons.description_rounded;
      color = Colors.blue;
    } else if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) {
      icon = Icons.table_chart_rounded;
      color = Colors.green;
    } else if (mimeType.contains('zip') || mimeType.contains('compressed')) {
      icon = Icons.folder_zip_rounded;
      color = Colors.grey;
    } else {
      icon = Icons.insert_drive_file_rounded;
      color = Colors.blue;
    }

    return Icon(icon, color: color, size: size);
  }

  String _formatSize(int? bytes) {
    if (bytes == null) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size > 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  Future<void> _unshareFile(int fileId) async {
    try {
      final authData = await AuthService().getAuthData();
      final token = authData['token'];
      if (token == null) throw Exception('Not authenticated');

      await ApiService().unshareFileFromGroup(token, widget.groupId, fileId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File unshared successfully')),
        );
        _loadGroupData();
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

  Future<void> _unshareFolder(String folderPath) async {
    try {
      final authData = await AuthService().getAuthData();
      final token = authData['token'];
      if (token == null) throw Exception('Not authenticated');

      await ApiService().unshareFolderFromGroup(
        token,
        widget.groupId,
        folderPath,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Folder unshared successfully')),
        );
        _loadGroupData();
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
}

class _FileSelectionDialog extends StatefulWidget {
  final Function(int) onFileSelected;

  const _FileSelectionDialog({required this.onFileSelected});

  @override
  State<_FileSelectionDialog> createState() => _FileSelectionDialogState();
}

class _FileSelectionDialogState extends State<_FileSelectionDialog> {
  List<Map<String, dynamic>> _files = [];
  bool _isLoading = true;
  String _searchQuery = '';

  List<Map<String, dynamic>> get _filteredFiles {
    final filesOnly =
        _files.where((f) => f['is_folder'] != true && f['id'] != null).toList();
    if (_searchQuery.isEmpty) return filesOnly;
    return filesOnly.where((file) {
      final name = (file['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    try {
      final authData = await AuthService().getAuthData();
      final token = authData['token'];
      final username = authData['username'];

      if (token == null || username == null) return;

      final files = await ApiService().listFiles(token, username);

      if (mounted) {
        setState(() {
          _files = files;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  IconData _getFileIcon(String? mimeType) {
    if (mimeType == null) return Icons.insert_drive_file_rounded;
    if (mimeType.startsWith('image/')) return Icons.image_rounded;
    if (mimeType.startsWith('video/')) return Icons.video_file_rounded;
    if (mimeType.startsWith('audio/')) return Icons.audio_file_rounded;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (mimeType.contains('document') || mimeType.contains('word')) {
      return Icons.description_rounded;
    }
    if (mimeType.contains('spreadsheet') || mimeType.contains('excel')) {
      return Icons.table_chart_rounded;
    }
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) {
      return Icons.slideshow_rounded;
    }
    if (mimeType.contains('zip') ||
        mimeType.contains('archive') ||
        mimeType.contains('compressed')) {
      return Icons.folder_zip_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  Color _getFileIconColor(String? mimeType) {
    if (mimeType == null) return Colors.grey;
    if (mimeType.startsWith('image/')) return Colors.pink;
    if (mimeType.startsWith('video/')) return Colors.purple;
    if (mimeType.startsWith('audio/')) return Colors.orange;
    if (mimeType.contains('pdf')) return Colors.red;
    if (mimeType.contains('document') || mimeType.contains('word')) {
      return Colors.blue;
    }
    if (mimeType.contains('spreadsheet') || mimeType.contains('excel')) {
      return Colors.green;
    }
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) {
      return Colors.deepOrange;
    }
    if (mimeType.contains('zip') || mimeType.contains('archive')) {
      return Colors.amber;
    }
    return Colors.grey;
  }

  String _formatFileSize(dynamic size) {
    if (size == null) return '';
    final bytes = size is int ? size : int.tryParse(size.toString()) ?? 0;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_outlined,
                      size: 32,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select File to Share',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose a file from your Skysync storage',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search files...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Container(
                color: Colors.grey[50],
                child:
                    _isLoading
                        ? const Center(
                          child: CircularProgressIndicator(color: Colors.blue),
                        )
                        : _filteredFiles.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.folder_open_rounded,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No files matching "$_searchQuery"'
                                    : 'No files found',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _filteredFiles.length,
                          separatorBuilder:
                              (context, index) => const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final file = _filteredFiles[index];
                            final fileId = file['id'];
                            final mimeType = file['mime_type'] as String?;
                            final iconColor = _getFileIconColor(mimeType);

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.pop(context);
                                    widget.onFileSelected(fileId);
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.withValues(
                                          alpha: 0.1,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: iconColor.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Icon(
                                            _getFileIcon(mimeType),
                                            color: iconColor,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                file['name'] ?? 'Unknown file',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 14,
                                                  color: Colors.black87,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _formatFileSize(file['size']),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 16,
                                          color: Colors.grey[400],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ShareOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.blue, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
