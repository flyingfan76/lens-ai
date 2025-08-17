import 'package:flutter/material.dart';
import 'camera_screen.dart';

/// Clean main dashboard - just shows the camera screen
class MainDashboard extends StatelessWidget {
  const MainDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const CameraScreen();
  }
}