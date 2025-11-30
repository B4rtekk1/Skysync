import 'package:flutter/material.dart';
import '../pages/dashboard_page.dart';
import '../pages/my_files_page.dart';
import '../pages/groups_page.dart';
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(0),
          bottomRight: Radius.circular(0),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              children: [
                _buildDrawerItem(
                  context,
                  Icons.dashboard_outlined,
                  'Dashboard',
                  currentPage == 'Dashboard',
                  () => _navigateTo(context, 'Dashboard'),
                ),
                _buildDrawerItem(
                  context,
                  Icons.folder_outlined,
                  'My Files',
                  currentPage == 'My Files',
                  () => _navigateTo(context, 'My Files'),
                ),
                _buildDrawerItem(
                  context,
                  Icons.people_outline,
                  'Groups',
                  currentPage == 'Groups',
                  () => _navigateTo(context, 'Groups'),
                ),
                _buildDrawerItem(
                  context,
                  Icons.share_outlined,
                  'Shared with me',
                  currentPage == 'Shared with me',
                  () {
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, thickness: 0.5, color: Colors.black12),
                const SizedBox(height: 16),
                _buildDrawerItem(
                  context,
                  Icons.delete_outline,
                  'Trash',
                  currentPage == 'Trash',
                  () {
                    Navigator.pop(context);
                  },
                ),
                _buildDrawerItem(
                  context,
                  Icons.settings_outlined,
                  'Settings',
                  currentPage == 'Settings',
                  () => _navigateTo(context, 'Settings'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5, color: Colors.black12),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildDrawerItem(
              context,
              Icons.logout,
              'Sign Out',
              false,
              () async {
                await AuthService().logout();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                }
              },
              isDestructive: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.blue.shade50,
            child: Text(
              username.isNotEmpty ? username[0].toUpperCase() : 'U',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  email,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    final color =
        isDestructive
            ? Colors.red.shade400
            : (isSelected ? Colors.blue.shade700 : Colors.grey.shade700);
    final bgColor = isSelected ? Colors.blue.shade50 : Colors.transparent;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: color, size: 22),
        title: Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        onTap: onTap,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
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
      case 'Groups':
        page = GroupsPage(username: username, email: email);
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
