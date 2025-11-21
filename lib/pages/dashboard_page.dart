import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_page.dart';

class DashboardPage extends StatelessWidget {
  final String username;
  final String email;

  const DashboardPage({super.key, required this.username, required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Row(
          children: [
            Icon(Icons.cloud_queue, color: Colors.blue, size: 28),
            SizedBox(width: 12),
            Text(
              'Skysync Console',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.black54),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.blue,
            radius: 16,
            child: Text(
              username.isNotEmpty ? username[0].toUpperCase() : 'U',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      drawer: Drawer(
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
            _buildDrawerItem(context, Icons.dashboard, 'Dashboard', true),
            _buildDrawerItem(context, Icons.folder, 'My Files', false),
            _buildDrawerItem(context, Icons.people, 'User Groups', false),
            _buildDrawerItem(context, Icons.share, 'Shared with me', false),
            const Divider(),
            _buildDrawerItem(context, Icons.delete, 'Trash', false),
            const Divider(),
            _buildDrawerItem(context, Icons.settings, 'Settings', false),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.red),
              ),
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w300,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount =
                    constraints.maxWidth > 900
                        ? 3
                        : (constraints.maxWidth > 600 ? 2 : 1);
                double childAspectRatio = 1.5;

                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: childAspectRatio,
                  children: [
                    _buildSummaryCard(
                      'Storage Usage',
                      Icons.cloud,
                      Colors.blue,
                      [
                        const LinearProgressIndicator(value: 0.45),
                        const SizedBox(height: 8),
                        _buildResourceRow('Used', '6.75 GB'),
                        _buildResourceRow('Total', '15 GB'),
                        _buildResourceRow('Free', '8.25 GB'),
                      ],
                    ),
                    _buildSummaryCard(
                      'Recent Activity',
                      Icons.history,
                      Colors.orange,
                      [
                        _buildResourceRow(
                          'project_docs.pdf',
                          'Modified 2h ago',
                        ),
                        _buildResourceRow('vacation_photos', 'Uploaded 5h ago'),
                        _buildResourceRow(
                          'team_meeting.txt',
                          'Shared yesterday',
                        ),
                      ],
                    ),
                    _buildSummaryCard('My Groups', Icons.group, Colors.green, [
                      _buildResourceRow('Developers', '5 members'),
                      _buildResourceRow('Marketing', '12 members'),
                      _buildResourceRow('Family', '4 members'),
                    ]),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w400,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildActionButton(Icons.cloud_upload, 'Upload File'),
                _buildActionButton(Icons.create_new_folder, 'New Folder'),
                _buildActionButton(Icons.group_add, 'Create Group'),
                _buildActionButton(Icons.person_add, 'Invite User'),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'Recent Files',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w400,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              color: Colors.white,
              child: Column(
                children: [
                  _buildFileItem(
                    Icons.picture_as_pdf,
                    'project_proposal.pdf',
                    '2.4 MB',
                    '2 hours ago',
                  ),
                  const Divider(height: 1),
                  _buildFileItem(
                    Icons.image,
                    'screenshot.png',
                    '1.2 MB',
                    '5 hours ago',
                  ),
                  const Divider(height: 1),
                  _buildFileItem(
                    Icons.description,
                    'notes.txt',
                    '24 KB',
                    'Yesterday',
                  ),
                  const Divider(height: 1),
                  _buildFileItem(
                    Icons.folder,
                    'vacation_photos',
                    '450 MB',
                    '2 days ago',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context,
    IconData icon,
    String title,
    bool isSelected,
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
      onTap: () {},
    );
  }

  Widget _buildFileItem(IconData icon, String name, String size, String time) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue, size: 32),
      title: Text(name),
      subtitle: Text('$size • $time'),
      trailing: IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
    );
  }

  Widget _buildSummaryCard(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600])),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return ElevatedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.blue[700],
        backgroundColor: Colors.white,
        elevation: 0,
        side: BorderSide(color: Colors.grey[300]!),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
