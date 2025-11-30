// TODO: Main app improvements
// TODO: Add a proper splash screen and deep-link handling.
// TODO: Centralize authentication state (token expiry/refresh) and route updates.
// TODO: Add localization (i18n) support and RTL testing.
// TODO: Consider moving initialization and dependency wiring to a dedicated setup class.
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_sharing_intent/flutter_sharing_intent.dart';
import 'package:flutter_sharing_intent/model/sharing_file.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/my_files_page.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  final authService = AuthService();
  await authService.checkTokenValidity();
  final authData = await authService.getAuthData();

  Widget initialScreen;
  if (authData['token'] != null) {
    initialScreen = DashboardPage(
      username: authData['username'] ?? 'User',
      email: authData['email'] ?? '',
    );
  } else {
    initialScreen = const LoginPage();
  }

  runApp(MyApp(initialScreen: initialScreen, authData: authData));
}

class MyApp extends StatefulWidget {
  final Widget initialScreen;
  final Map<String, dynamic> authData;

  const MyApp({super.key, required this.initialScreen, required this.authData});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late StreamSubscription _mediaStreamSubscription;

  @override
  void initState() {
    super.initState();
    _initSharingIntent();
  }

  void _initSharingIntent() {
    _mediaStreamSubscription = FlutterSharingIntent.instance
        .getMediaStream()
        .listen(_handleSharedFiles);

    FlutterSharingIntent.instance.getInitialSharing().then(_handleSharedFiles);
  }

  Future<void> _handleSharedFiles(List<SharedFile> files) async {
    if (files.isEmpty) return;

    final context = _navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    final authService = AuthService();
    final authData = await authService.getAuthData();
    final token = authData['token'];
    final username = authData['username'];

    if (token == null || username == null) {
      _navigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      return;
    }

    final selectedFolder = await _showFolderSelectionDialog(context);
    if (selectedFolder == null || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Uploading ${files.length} file(s)...',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
    );

    final apiService = ApiService();
    int successCount = 0;
    final List<String> errors = [];

    for (final sharedFile in files) {
      try {
        final file = File(sharedFile.value ?? '');
        if (await file.exists()) {
          await apiService.uploadFile(
            token,
            username,
            file,
            folder: selectedFolder,
          );
          successCount++;
        }
      } catch (e) {
        errors.add(sharedFile.value?.split('/').last ?? 'Unknown file');
      }
    }

    if (!context.mounted) return;
    Navigator.of(context).pop();

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  successCount == files.length
                      ? Icons.check_circle
                      : Icons.warning,
                  color:
                      successCount == files.length
                          ? Colors.green
                          : Colors.orange,
                ),
                const SizedBox(width: 8),
                const Text('Upload Complete'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Successfully uploaded: $successCount/${files.length}'),
                if (errors.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Failed files:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...errors.map((e) => Text('• $e')),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _navigatorKey.currentState?.pushReplacement(
                    MaterialPageRoute(
                      builder:
                          (_) => MyFilesPage(
                            username: username,
                            email: authData['email'] ?? '',
                          ),
                    ),
                  );
                },
                child: const Text('View Files'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }

  Future<String?> _showFolderSelectionDialog(BuildContext context) async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Select Destination Folder'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Folder path (e.g., /Documents)',
                    labelText: 'Folder Path',
                    prefixIcon: const Icon(Icons.folder),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    helperText: 'Leave empty for root folder',
                  ),
                  onChanged: (value) {},
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final path =
                      controller.text.trim().isEmpty
                          ? '/'
                          : controller.text.trim();
                  Navigator.of(context).pop(path);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text(
                  'Upload',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _mediaStreamSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Skysync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          surface: Colors.grey[50],
        ),
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      home: widget.initialScreen,
    );
  }
}
