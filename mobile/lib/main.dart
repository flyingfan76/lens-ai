import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera_companion/core/providers/app_provider.dart';
import 'package:camera_companion/core/providers/camera_provider.dart';
import 'package:camera_companion/core/providers/ai_provider.dart';
import 'package:camera_companion/core/theme/app_theme.dart';
import 'package:camera_companion/features/home/screens/home_screen.dart';
import 'package:camera_companion/features/auth/screens/login_screen.dart';
import 'package:camera_companion/core/services/auth_service.dart';

void main() {
  runApp(const CameraCompanionApp());
}

class CameraCompanionApp extends StatelessWidget {
  const CameraCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => CameraProvider()),
        ChangeNotifierProvider(create: (_) => AIProvider()),
      ],
      child: MaterialApp(
        title: 'Camera Companion',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const AuthWrapper(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService().isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.data == true) {
          return const HomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}