import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../utils/custom_widgets.dart';
import '../utils/token_service.dart';
import '../utils/api_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  String _username = 'loading';
  String _email = 'loading@example.com';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final username = await TokenService.getUsername();
    final email = await TokenService.getEmail();
    setState(() {
      _username = username ?? 'unknown';
      _email = email ?? 'unknown';
    });
  }

  Future<void> _uploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );

      if (result == null) return;

      final file = result.files.first;
      if (file.path == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('main.could_not_access_file'.tr())));
        return;
      }

      final token = await TokenService.getToken();
      final username = await TokenService.getUsername();

      if (token == null || username == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('main.not_logged_in'.tr())),
        );
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
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
                  'main.uploading_file'.tr(),
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );

      final fileBytes = await File(file.path!).readAsBytes();

      final response = await ApiService.uploadFile(
        username: username,
        folderName: username,
        token: token,
        fileBytes: fileBytes,
        fileName: file.name,
      );

      // Zamknij dialog
      Navigator.of(context).pop();

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('main.file_uploaded'.tr(namedArgs: {'filename': file.name})),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('main.upload_failed'.tr(namedArgs: {'error': response.body})),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Zamknij dialog jeśli jest otwarty
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('main.upload_error'.tr(namedArgs: {'error': e.toString()})),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
              colors: [const Color(0xFF667eea), const Color(0xFF764ba2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          'main.app_title'.tr(),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
      drawer: CustomDrawer(
        username: _username,
        email: _email,
        currentRoute: '/main',
        onSignOut: () {
          Navigator.pushReplacementNamed(context, '/login');
        },
      ),
      backgroundColor: const Color(0xFFf8fafc),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF667eea), const Color(0xFF764ba2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667eea).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'main.welcome_back'.tr(namedArgs: {'username': _username}),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'main.manage_files'.tr(),
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'main.quick_actions'.tr(),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.upload_file,
                      title: 'main.upload_file'.tr(),
                      subtitle: 'main.upload_file_desc'.tr(),
                      color: Colors.blue,
                      onTap: _uploadFile,
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.03,
                  ), // Responsywny odstęp
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.folder_open,
                      title: 'main.my_files'.tr(),
                      subtitle: 'main.my_files_desc'.tr(),
                      color: Colors.green,
                      onTap: () {
                        Navigator.pushNamed(context, '/files');
                      },
                    ),
                  ),
                ],
              ),

              SizedBox(
                height: MediaQuery.of(context).size.height * 0.03,
              ), // Responsywny odstęp
              Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.star,
                      title: 'main.favorites'.tr(),
                      subtitle: 'main.favorites_desc'.tr(),
                      color: Colors.yellow,
                      onTap: () {
                        Navigator.pushNamed(context, '/favorites');
                      },
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.03,
                  ),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.people,
                      title: 'main.share'.tr(),
                      subtitle: 'main.share_desc'.tr(),
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pushNamed(context, '/shared-files');
                      },
                    ),
                  ),
                ],
              ),

                            SizedBox(
                height: MediaQuery.of(context).size.height * 0.03,
              ), // Responsywny odstęp
              Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.group,
                      title: 'main.groups'.tr(),
                      subtitle: 'main.groups_desc'.tr(),
                      color: Colors.teal,
                      onTap: () {
                        Navigator.pushNamed(context, '/groups');
                      },
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.03,
                  ),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.people,
                      title: 'main.my_shared'.tr(),
                      subtitle: 'main.my_shared_desc'.tr(),
                      color: Colors.indigo,
                      onTap: () {
                        Navigator.pushNamed(context, '/my-shared-files');
                      },
                    ),
                  ), // Responsywny odstęp
                ],
              ),

              SizedBox(
                height: MediaQuery.of(context).size.height * 0.03,
              ), // Responsywny odstęp
              Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.settings,
                      title: 'main.settings'.tr(),
                      subtitle: 'main.settings_desc'.tr(),
                      color: Colors.orangeAccent,
                      onTap: () {
                        Navigator.pushNamed(context, '/settings');
                      },
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.03,
                  ),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.help,
                      title: 'main.help'.tr(),
                      subtitle: 'main.help_desc'.tr(),
                      color: Colors.purple,
                      onTap: () async{
                        final url = Uri.parse('https://github.com/B4rtekk1/Skysync/issues');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        }else{
                          throw 'Could not launch $url';
                        }
                      },
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
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Responsywna wysokość karty
    final screenHeight = MediaQuery.of(context).size.height;
    final cardHeight = screenHeight * 0.2;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: cardHeight,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: color,
              size: cardHeight * 0.2, // Responsywny rozmiar ikony
            ),
            SizedBox(height: cardHeight * 0.08), // Responsywny odstęp
            Text(
              title,
              style: TextStyle(
                fontSize: cardHeight * 0.12, // Responsywny rozmiar tekstu
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: cardHeight * 0.03), // Responsywny odstęp
            Text(
              subtitle,
              style: TextStyle(
                fontSize: cardHeight * 0.09, // Responsywny rozmiar tekstu
                color: Colors.grey.shade600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
