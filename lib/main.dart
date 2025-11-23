// TODO: Main app improvements
// TODO: Add a proper splash screen and deep-link handling.
// TODO: Centralize authentication state (token expiry/refresh) and route updates.
// TODO: Add localization (i18n) support and RTL testing.
// TODO: Consider moving initialization and dependency wiring to a dedicated setup class.
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  final authService = AuthService();
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

  runApp(MyApp(initialScreen: initialScreen));
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;
  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skysync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: initialScreen,
    );
  }
}
