import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/verification_page.dart';
import 'pages/main_page.dart';
import 'pages/files_page.dart';
import 'pages/favorites_page.dart';
import 'pages/shared_files_page.dart';
import 'pages/my_shared_files_page.dart';
import 'pages/groups_page.dart';
import 'pages/forgot_password_page.dart';
import 'pages/reset_password_page.dart';
import 'pages/settings_page.dart';
import 'utils/notification_service.dart';
import 'utils/app_settings.dart';
import 'utils/token_service.dart';
import 'utils/cache_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  await EasyLocalization.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('pl')],
      path: 'assets/lang',
      fallbackLocale: const Locale('en'),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // StreamSubscription? _linkSubscription;
  // final _appLinks = AppLinks();
  late AppSettings _appSettings;

  @override
  void initState() {
    super.initState();
    _appSettings = AppSettings();
    _appSettings.initialize();
    _initializeCache();
    // _initDeepLinks();
  }

  Future<void> _initializeCache() async {
    await CacheService().initialize();
  }

  

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appSettings,
      builder: (context, child) {
        return MaterialApp(
          title: 'Skysync',
          debugShowCheckedModeBanner: false,
          showSemanticsDebugger: false,
          navigatorKey: NotificationService.navigatorKey,
          theme: _appSettings.getThemeData(),
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          initialRoute: '/splash',
          routes: {
            '/splash': (context) => const SplashScreen(),
            '/login': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              final isVerified = args == 'verified';
              return LoginPage(showVerificationSuccess: isVerified);
            },
            '/register': (context) => const RegisterPage(),
            '/verification': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              final email = args is String ? args : '';
              return VerificationPage(email: email);
            },
            '/main': (context) => const MainPage(),
            '/files': (context) => const FilesPage(),
            '/favorites': (context) => const FavoritesPage(),
            '/shared-files': (context) => const SharedFilesPage(),
            '/my-shared-files': (context) => const MySharedFilesPage(),
            '/groups': (context) => const GroupsPage(),
            '/forgot-password': (context) => const ForgotPasswordPage(),
            '/reset-password': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              final token = args is String ? args : '';
              return ResetPasswordPage(token: token);
            },
            '/settings': (context) => const SettingsPage(),
          },
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    try {
      final isLoggedIn = await TokenService.isLoggedIn();
      
      if (!mounted) return;
      
      if (isLoggedIn) {
        Navigator.pushReplacementNamed(context, '/main');
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf8fafc),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF667eea).withValues(alpha: 0.1),
              const Color(0xFF764ba2).withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 200,
                  maxHeight: 200,
                ),
                child: Image.asset(
                  'assets/Logo-name.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 30),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
