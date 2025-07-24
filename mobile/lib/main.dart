import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/main_dashboard.dart';

void main() {
  runApp(const LensAIApp());
}

class LensAIApp extends StatelessWidget {
  const LensAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lens AI',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/main': (context) => const MainDashboard(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}