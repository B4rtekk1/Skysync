import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_page.dart';
import '../widgets/app_drawer.dart';

class SettingsPage extends StatefulWidget {
  final String username;
  final String email;

  const SettingsPage({super.key, required this.username, required this.email});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _emailNotifications = false;
  bool _twoFactorEnabled = false;
  String _selectedTheme = 'System';
  String _selectedLanguage = 'English';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black54),
      ),
      drawer: AppDrawer(
        username: widget.username,
        email: widget.email,
        currentPage: 'Settings',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Profile'),
          _buildCard([
            _buildListTile(
              icon: Icons.person_outline,
              title: 'Username',
              subtitle: widget.username,
              trailing: const Icon(Icons.edit, size: 20),
              onTap: () => _showEditDialog('Username', widget.username),
            ),
            const Divider(height: 1),
            _buildListTile(
              icon: Icons.email_outlined,
              title: 'Email',
              subtitle: widget.email,
              trailing: const Icon(Icons.edit, size: 20),
              onTap: () => _showEditDialog('Email', widget.email),
            ),
            const Divider(height: 1),
            _buildListTile(
              icon: Icons.camera_alt_outlined,
              title: 'Profile Picture',
              subtitle: 'Change your avatar',
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 24),

          _buildSectionHeader('Security'),
          _buildCard([
            _buildListTile(
              icon: Icons.lock_outline,
              title: 'Change Password',
              subtitle: 'Update your password',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showChangePasswordDialog(),
            ),
            const Divider(height: 1),
            _buildSwitchTile(
              icon: Icons.security,
              title: 'Two-Factor Authentication',
              subtitle: _twoFactorEnabled ? 'Enabled' : 'Disabled',
              value: _twoFactorEnabled,
              onChanged: (value) {
                setState(() {
                  _twoFactorEnabled = value;
                });
              },
            ),
            const Divider(height: 1),
            _buildListTile(
              icon: Icons.devices,
              title: 'Active Sessions',
              subtitle: 'Manage your devices',
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 24),

          _buildSectionHeader('Preferences'),
          _buildCard([
            _buildListTile(
              icon: Icons.palette_outlined,
              title: 'Theme',
              subtitle: _selectedTheme,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showThemeDialog(),
            ),
            const Divider(height: 1),
            _buildListTile(
              icon: Icons.language,
              title: 'Language',
              subtitle: _selectedLanguage,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLanguageDialog(),
            ),
          ]),
          const SizedBox(height: 24),

          _buildSectionHeader('Notifications'),
          _buildCard([
            _buildSwitchTile(
              icon: Icons.notifications_outlined,
              title: 'Push Notifications',
              subtitle: 'Receive push notifications',
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
              },
            ),
            const Divider(height: 1),
            _buildSwitchTile(
              icon: Icons.email_outlined,
              title: 'Email Notifications',
              subtitle: 'Receive email updates',
              value: _emailNotifications,
              onChanged: (value) {
                setState(() {
                  _emailNotifications = value;
                });
              },
            ),
          ]),
          const SizedBox(height: 24),

          _buildSectionHeader('Storage'),
          _buildCard([
            _buildListTile(
              icon: Icons.cloud_outlined,
              title: 'Storage Usage',
              subtitle: '6.75 GB of 15 GB used',
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            const Divider(height: 1),
            _buildListTile(
              icon: Icons.delete_outline,
              title: 'Clear Cache',
              subtitle: 'Free up space',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showClearCacheDialog(),
            ),
          ]),
          const SizedBox(height: 24),

          _buildSectionHeader('About'),
          _buildCard([
            _buildListTile(
              icon: Icons.info_outline,
              title: 'Version',
              subtitle: '1.0.0',
              onTap: () {},
            ),
            const Divider(height: 1),
            _buildListTile(
              icon: Icons.description_outlined,
              title: 'Terms of Service',
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            const Divider(height: 1),
            _buildListTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 24),

          _buildCard([
            _buildListTile(
              icon: Icons.logout,
              title: 'Sign Out',
              titleColor: Colors.red,
              iconColor: Colors.red,
              onTap: () => _showLogoutDialog(),
            ),
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      color: Colors.white,
      child: Column(children: children),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? titleColor,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Colors.blue, size: 24),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: titleColor ?? Colors.black87,
        ),
      ),
      subtitle:
          subtitle != null
              ? Text(
                subtitle,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              )
              : null,
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue, size: 24),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.blue,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  void _showEditDialog(String field, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit $field'),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: field,
                border: const OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  // TODO: Implement save logic
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$field updated successfully')),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Change Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  // TODO: Implement password change logic
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password changed successfully'),
                    ),
                  );
                },
                child: const Text('Change'),
              ),
            ],
          ),
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Choose Theme'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile(
                  title: const Text('Light'),
                  value: 'Light',
                  groupValue: _selectedTheme,
                  onChanged: (value) {
                    setState(() {
                      _selectedTheme = value!;
                    });
                    Navigator.pop(context);
                  },
                ),
                RadioListTile(
                  title: const Text('Dark'),
                  value: 'Dark',
                  groupValue: _selectedTheme,
                  onChanged: (value) {
                    setState(() {
                      _selectedTheme = value!;
                    });
                    Navigator.pop(context);
                  },
                ),
                RadioListTile(
                  title: const Text('System'),
                  value: 'System',
                  groupValue: _selectedTheme,
                  onChanged: (value) {
                    setState(() {
                      _selectedTheme = value!;
                    });
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Choose Language'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile(
                  title: const Text('English'),
                  value: 'English',
                  groupValue: _selectedLanguage,
                  onChanged: (value) {
                    setState(() {
                      _selectedLanguage = value!;
                    });
                    Navigator.pop(context);
                  },
                ),
                RadioListTile(
                  title: const Text('Polski'),
                  value: 'Polski',
                  groupValue: _selectedLanguage,
                  onChanged: (value) {
                    setState(() {
                      _selectedLanguage = value!;
                    });
                    Navigator.pop(context);
                  },
                ),
                RadioListTile(
                  title: const Text('Español'),
                  value: 'Español',
                  groupValue: _selectedLanguage,
                  onChanged: (value) {
                    setState(() {
                      _selectedLanguage = value!;
                    });
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear Cache'),
            content: const Text(
              'Are you sure you want to clear the cache? This will free up storage space.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cache cleared successfully')),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text('Clear'),
              ),
            ],
          ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Sign Out'),
            content: const Text('Are you sure you want to sign out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await AuthService().logout();
                  if (mounted) {
                    navigator.pop();
                    navigator.pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                      (route) => false,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Sign Out'),
              ),
            ],
          ),
    );
  }
}
