import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
// import 'package:app_links/app_links.dart';  // Tymczasowo wyłączone
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

  // void _initDeepLinks() {
  //   // Obsługa deep links gdy aplikacja jest już uruchomiona
  //   _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
  //     _handleDeepLink(uri);
  //   }, onError: (err) {
  //     print('Deep link error: $err');
  //   });

  //   // Obsługa deep links gdy aplikacja jest uruchamiana
  //   _appLinks.getInitialLink().then((String? link) {
  //     if (link != null) {
  //       final uri = Uri.parse(link);
  //       _handleDeepLink(uri);
  //     }
  //   });
  // }

  // void _handleDeepLink(Uri uri) {
  //   if (uri.host == 'reset-password') {
  //     final token = uri.queryParameters['token'];
  //     if (token != null) {
  //       Navigator.pushNamed(context, '/reset-password', arguments: token);
  //     }
  //   }
  // }

  // @override
  // void dispose() {
  //   _linkSubscription?.cancel();
  //   super.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appSettings,
      builder: (context, child) {
        return MaterialApp(
          title: 'ServApp',
          debugShowCheckedModeBanner: false,
          showSemanticsDebugger: false, // Włącz to na true aby zobaczyć debug widgetów
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
            '/home': (context) => const MyHomePage(title: 'Flutter Demo Home Page'),
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

// Widget sprawdzający czy użytkownik jest zalogowany
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
    // Krótkie opóźnienie dla lepszego UX
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

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
