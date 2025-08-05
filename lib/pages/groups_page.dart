import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../utils/api_service.dart';
import '../utils/token_service.dart';
import '../utils/custom_widgets.dart';
import '../utils/error_handler.dart';
import 'dart:convert';

class GroupsPage extends StatefulWidget {
  const GroupsPage({Key? key}) : super(key: key);

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _username = 'loading';
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadGroups();
  }

  Future<void> _loadUserData() async {
    final username = await TokenService.getUsername();
    setState(() {
      _username = username ?? 'unknown';
    });
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await TokenService.getToken();
      if (token == null) {
        setState(() {
          _errorMessage = 'groups.not_logged_in'.tr();
          _isLoading = false;
        });
        return;
      }

      final response = await ApiService.listGroups(token: token);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _groups = List<Map<String, dynamic>>.from(data['groups']);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'groups.load_error'.tr();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'groups.network_error'.tr(args: [e.toString()]);
        _isLoading = false;
      });
    }
  }

  void _showCreateGroupDialog() {
    _groupNameController.clear();
    _descriptionController.clear();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('groups.create_group'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _groupNameController,
                decoration: InputDecoration(
                  labelText: 'groups.group_name'.tr(),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'groups.description'.tr(),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('groups.cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: _createGroup,
              child: Text('groups.create'.tr()),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();
    final description = _descriptionController.text.trim();

    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('groups.name_required'.tr())),
      );
      return;
    }

    try {
      final token = await TokenService.getToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('groups.not_logged_in'.tr())),
        );
        return;
      }

      final response = await ApiService.createGroup(
        name: groupName,
        description: description.isNotEmpty ? description : null,
        token: token,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('groups.created_successfully'.tr()),
            backgroundColor: Colors.green,
          ),
        );
        _loadGroups();
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['detail'] ?? 'groups.create_error'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('groups.network_error'.tr(args: [e.toString()])),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showGroupDetails(Map<String, dynamic> group) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GroupDetailsPage(group: group),
      ),
    );
  }

  void _showGroupMenu(BuildContext context, Map<String, dynamic> group) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.people, color: Color(0xFF667eea)),
                title: Text('groups.view_members'.tr()),
                onTap: () {
                  Navigator.of(context).pop();
                  _showGroupDetails(group);
                },
              ),
              if (group['is_admin'] == true) ...[
                ListTile(
                  leading: const Icon(Icons.person_add, color: Color(0xFF667eea)),
                  title: Text('groups.add_member'.tr()),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showAddMemberDialog(group);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit, color: Color(0xFF667eea)),
                  title: Text('groups.edit_group'.tr()),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showEditGroupDialog(group);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text('groups.delete_group'.tr()),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showDeleteGroupDialog(group);
                  },
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black87,
                  ),
                  child: Text('groups.cancel'.tr()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddMemberDialog(Map<String, dynamic> group) {
    final TextEditingController usernameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('groups.add_member'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                decoration: InputDecoration(
                  labelText: 'groups.username_or_email'.tr(),
                  hintText: 'groups.username_or_email_hint'.tr(),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('groups.cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () async {
                final username = usernameController.text.trim();
                if (username.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('groups.username_or_email_required'.tr())),
                  );
                  return;
                }

                try {
                  final token = await TokenService.getToken();
                  if (token == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('groups.not_logged_in'.tr())),
                    );
                    return;
                  }

                  final response = await ApiService.addGroupMember(
                    groupName: group['name'],
                    userIdentifier: username,
                    token: token,
                  );

                  if (!mounted) return;

                  if (response.statusCode == 200) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('groups.member_added'.tr()),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    final errorData = jsonDecode(response.body);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(errorData['detail'] ?? 'groups.add_member_error'.tr()),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('groups.network_error'.tr(args: [e.toString()])),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text('groups.add'.tr()),
            ),
          ],
        );
      },
    );
  }

  void _showEditGroupDialog(Map<String, dynamic> group) {
    // TODO: Implement edit group functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('groups.edit_not_implemented'.tr())),
    );
  }

  void _showDeleteGroupDialog(Map<String, dynamic> group) {
    // TODO: Implement delete group functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('groups.delete_not_implemented'.tr())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: CustomDrawer(
        username: _username,
        currentRoute: '/groups',
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
                Icons.group,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'groups.title'.tr(),
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
            onPressed: _loadGroups,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateGroupDialog,
        backgroundColor: const Color(0xFF667eea),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
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
                    'groups.loading_groups'.tr(),
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
                'Error loading groups',
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
                onPressed: _loadGroups,
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
                  'groups.retry'.tr(),
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

    if (_groups.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.group_outlined,
        title: 'No groups yet',
        subtitle: 'Create your first group to get started',
        onAction: _showCreateGroupDialog,
        actionText: 'groups.create_first'.tr(),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: _groups.length,
      itemBuilder: (context, index) {
        final group = _groups[index];
        
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
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF667eea).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  group['name'][0].toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF667eea),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
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
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.people,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${group['member_count']} ${'groups.members'.tr()}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    if (group['is_admin'] == true) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'groups.admin'.tr(),
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'details':
                    _showGroupDetails(group);
                    break;
                  case 'add_member':
                    if (group['is_admin'] == true) {
                      _showAddMemberDialog(group);
                    }
                    break;
                  case 'edit':
                    if (group['is_admin'] == true) {
                      _showEditGroupDialog(group);
                    }
                    break;
                  case 'delete':
                    if (group['is_admin'] == true) {
                      _showDeleteGroupDialog(group);
                    }
                    break;
                }
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 8,
              offset: const Offset(0, 8),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'details',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF667eea).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.info_outline, color: const Color(0xFF667eea), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'groups.view_details'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                if (group['is_admin'] == true) ...[
                  PopupMenuItem(
                    value: 'add_member',
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.person_add, color: Colors.green.shade600, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'groups.add_member'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.edit, color: Colors.blue.shade600, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'groups.edit_group'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.w500),
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
                          child: Icon(Icons.delete, color: Colors.red.shade600, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'groups.delete_group'.tr(),
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            onTap: () => _showGroupDetails(group),
          ),
        );
      },
    );
  }
}

class GroupDetailsPage extends StatefulWidget {
  final Map<String, dynamic> group;

  const GroupDetailsPage({
    Key? key,
    required this.group,
  }) : super(key: key);

  @override
  State<GroupDetailsPage> createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await TokenService.getToken();
      if (token == null) {
        setState(() {
          _errorMessage = 'groups.not_logged_in'.tr();
          _isLoading = false;
        });
        return;
      }

      final response = await ApiService.listGroupMembers(
        groupName: widget.group['name'],
        token: token,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _members = List<Map<String, dynamic>>.from(data['members']);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'groups.load_members_error'.tr();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'groups.network_error'.tr(args: [e.toString()]);
        _isLoading = false;
      });
    }
  }

  void _showAddMemberDialog() {
    _usernameController.clear();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('groups.add_member'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'groups.username_or_email'.tr(),
                  hintText: 'groups.username_or_email_hint'.tr(),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('groups.cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: _addMember,
              child: Text('groups.add'.tr()),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addMember() async {
    final username = _usernameController.text.trim();

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('groups.username_or_email_required'.tr())),
      );
      return;
    }

    try {
      final token = await TokenService.getToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('groups.not_logged_in'.tr())),
        );
        return;
      }

      final response = await ApiService.addGroupMember(
        groupName: widget.group['name'],
        userIdentifier: username,
        token: token,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('groups.member_added'.tr()),
            backgroundColor: Colors.green,
          ),
        );
        _loadMembers();
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['detail'] ?? 'groups.add_member_error'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('groups.network_error'.tr(args: [e.toString()])),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeMember(String username) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('groups.remove_member'.tr()),
          content: Text('groups.remove_member_confirm'.tr(args: [username])),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('groups.cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('groups.remove'.tr()),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final token = await TokenService.getToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('groups.not_logged_in'.tr())),
        );
        return;
      }

      final response = await ApiService.removeGroupMember(
        groupName: widget.group['name'],
        username: username,
        token: token,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('groups.member_removed'.tr()),
            backgroundColor: Colors.green,
          ),
        );
        _loadMembers();
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['detail'] ?? 'groups.remove_member_error'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('groups.network_error'.tr(args: [e.toString()])),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _promoteToAdmin(String username) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('groups.promote_to_admin'.tr()),
          content: Text('groups.promote_to_admin_confirm'.tr(args: [username])),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('groups.cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: Text('groups.promote'.tr()),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final token = await TokenService.getToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('groups.not_logged_in'.tr())),
        );
        return;
      }

      final response = await ApiService.addGroupMember(
        groupName: widget.group['name'],
        userIdentifier: username,
        isAdmin: true,
        token: token,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('groups.promoted_to_admin'.tr()),
            backgroundColor: Colors.green,
          ),
        );
        _loadMembers();
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['detail'] ?? 'groups.promote_error'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('groups.network_error'.tr(args: [e.toString()])),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _demoteFromAdmin(String username) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('groups.demote_from_admin'.tr()),
          content: Text('groups.demote_from_admin_confirm'.tr(args: [username])),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('groups.cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: Text('groups.demote'.tr()),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final token = await TokenService.getToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('groups.not_logged_in'.tr())),
        );
        return;
      }

      // Remove the user and add them back without admin privileges
      final removeResponse = await ApiService.removeGroupMember(
        groupName: widget.group['name'],
        username: username,
        token: token,
      );

      if (removeResponse.statusCode == 200) {
        final addResponse = await ApiService.addGroupMember(
          groupName: widget.group['name'],
          userIdentifier: username,
          isAdmin: false,
          token: token,
        );

        if (!mounted) return;

        if (addResponse.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('groups.demoted_from_admin'.tr()),
              backgroundColor: Colors.green,
            ),
          );
          _loadMembers();
        } else {
          final errorData = jsonDecode(addResponse.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData['detail'] ?? 'groups.demote_error'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        final errorData = jsonDecode(removeResponse.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['detail'] ?? 'groups.demote_error'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('groups.network_error'.tr(args: [e.toString()])),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showUserActionMenu(BuildContext context, Map<String, dynamic> member) {
    final isCurrentUserAdmin = widget.group['is_admin'] == true;
    final isMemberAdmin = member['is_admin'] == true;
    final isCurrentUser = member['username'] == 'admin'; // Assuming current user is 'admin'

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // User info header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF667eea),
                      child: Text(
                        member['username'][0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member['username'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            member['email'],
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isMemberAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'groups.admin'.tr(),
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Action buttons
              if (isCurrentUserAdmin && !isCurrentUser) ...[
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isMemberAdmin ? Icons.admin_panel_settings : Icons.admin_panel_settings_outlined,
                      color: Colors.orange.shade600,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    isMemberAdmin 
                      ? 'groups.demote_from_admin'.tr()
                      : 'groups.promote_to_admin'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    isMemberAdmin 
                      ? 'groups.demote_from_admin_desc'.tr()
                      : 'groups.promote_to_admin_desc'.tr(),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    if (isMemberAdmin) {
                      _demoteFromAdmin(member['username']);
                    } else {
                      _promoteToAdmin(member['username']);
                    }
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red.shade600,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'groups.remove_member'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'groups.remove_member_desc'.tr(),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _removeMember(member['username']);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.share,
                      color: Colors.blue.shade600,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'groups.grant_sharing'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'groups.grant_sharing_desc'.tr(),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showSharingPermissionsDialog(member);
                  },
                ),
              ],
              
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black87,
                  ),
                  child: Text('groups.cancel'.tr()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSharingPermissionsDialog(Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('groups.sharing_permissions'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'groups.sharing_permissions_desc'.tr(args: [member['username']]),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'groups.can_share_files'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'groups.can_share_folders'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'groups.can_share_with_groups'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('groups.ok'.tr()),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group['name']),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        actions: [
          if (widget.group['is_admin'] == true)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddMemberDialog,
            ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: widget.group['is_admin'] == true
          ? FloatingActionButton.extended(
              onPressed: _showAddMemberDialog,
              backgroundColor: const Color(0xFF667eea),
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: Text(
                'groups.add_member'.tr(),
                style: const TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMembers,
              child: Text('groups.retry'.tr()),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Group info card
        Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.group['name'],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.group['description'] != null && widget.group['description'].isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.group['description'],
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.people, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      '${_members.length} ${'groups.members'.tr()}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        // Members list
        Expanded(
          child: _members.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'groups.no_members'.tr(),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (widget.group['is_admin'] == true) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showAddMemberDialog,
                          icon: const Icon(Icons.person_add),
                          label: Text('groups.add_first_member'.tr()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF667eea),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF667eea),
                          child: Text(
                            member['username'][0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(member['username']),
                        subtitle: Text(member['email']),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (member['is_admin'] == true)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.orange.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'groups.admin'.tr(),
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (widget.group['is_admin'] == true && member['username'] != 'admin')
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  switch (value) {
                                    case 'promote':
                                      if (!member['is_admin']) {
                                        _promoteToAdmin(member['username']);
                                      }
                                      break;
                                    case 'demote':
                                      if (member['is_admin']) {
                                        _demoteFromAdmin(member['username']);
                                      }
                                      break;
                                    case 'remove':
                                      _removeMember(member['username']);
                                      break;
                                    case 'share':
                                      _showSharingPermissionsDialog(member);
                                      break;
                                  }
                                },
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 8,
                                offset: const Offset(0, 8),
                                itemBuilder: (context) => [
                                  if (!member['is_admin'])
                                    PopupMenuItem(
                                      value: 'promote',
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(Icons.admin_panel_settings, color: Colors.orange.shade600, size: 18),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'groups.promote_to_admin'.tr(),
                                            style: const TextStyle(fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (member['is_admin'])
                                    PopupMenuItem(
                                      value: 'demote',
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(Icons.admin_panel_settings_outlined, color: Colors.orange.shade600, size: 18),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'groups.demote_from_admin'.tr(),
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
                                            color: Colors.red.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(Icons.remove_circle_outline, color: Colors.red.shade600, size: 18),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'groups.remove_member'.tr(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Colors.red.shade600,
                                          ),
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
                                            color: Colors.blue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(Icons.share, color: Colors.blue.shade600, size: 18),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'groups.grant_sharing'.tr(),
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
                          if (widget.group['is_admin'] == true && member['username'] != 'admin') {
                            _showUserActionMenu(context, member);
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
} 