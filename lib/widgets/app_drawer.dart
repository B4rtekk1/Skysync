import 'package:flutter/material.dart';
import '../pages/dashboard_page.dart';
import '../pages/my_files_page.dart';
import '../pages/settings_page.dart';
import '../pages/login_page.dart';
import '../services/auth_service.dart';
import '../utils/page_transitions.dart';

class AppDrawer extends StatelessWidget {
  final String username;
  final String email;
  final String currentPage;

  const AppDrawer({
    super.key,
    required this.username,
    required this.email,
    required this.currentPage,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Colors.blue),
            accountName: Text(username),
            accountEmail: Text(email),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : 'U',
                style: const TextStyle(fontSize: 24, color: Colors.blue),
              ),
            ),
          ),
          _buildDrawerItem(
            context,
            Icons.dashboard,
            'Dashboard',
            currentPage == 'Dashboard',
            () => _navigateTo(context, 'Dashboard'),
          ),
          _buildDrawerItem(
            context,
            Icons.folder,
            'My Files',
            currentPage == 'My Files',
            () => _navigateTo(context, 'My Files'),
          ),
          _buildDrawerItem(
            context,
            Icons.people,
            'User Groups',
            currentPage == 'User Groups',
            () {
              // TODO: Navigate to User Groups
              Navigator.pop(context);
            },
          ),
          _buildDrawerItem(
            context,
            Icons.share,
            'Shared with me',
            currentPage == 'Shared with me',
            () {
              // TODO: Navigate to Shared with me
              Navigator.pop(context);
            },
          ),
          const Divider(),
          _buildDrawerItem(
            context,
            Icons.delete,
            'Trash',
            currentPage == 'Trash',
            () {
              // TODO: Navigate to Trash
              Navigator.pop(context);
            },
          ),
          const Divider(),
          _buildDrawerItem(
            context,
            Icons.settings,
            'Settings',
            currentPage == 'Settings',
            () => _navigateTo(context, 'Settings'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await AuthService().logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context,
    IconData icon,
    String title,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.blue : Colors.grey[600]),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.blue : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Colors.blue.withValues(alpha: 0.1),
      onTap: onTap,
    );
  }

  void _navigateTo(BuildContext context, String targetPage) {
    if (currentPage == targetPage) {
      Navigator.pop(context);
      return;
    }

    Navigator.pop(context);

    Widget page;
    switch (targetPage) {
      case 'Dashboard':
        page = DashboardPage(username: username, email: email);
        break;
      case 'My Files':
        page = MyFilesPage(username: username, email: email);
        break;
      case 'Settings':
        page = SettingsPage(username: username, email: email);
        break;
      default:
        return;
    }

    if (targetPage == 'Dashboard') {
      Navigator.pushAndRemoveUntil(
        context,
        PageTransitions.slideTransition(page),
        (route) => false,
      );
    } else if (currentPage == 'Dashboard') {
      Navigator.push(context, PageTransitions.slideTransition(page));
    } else {
      Navigator.pushReplacement(context, PageTransitions.slideTransition(page));
    }
  }
}
