import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'camera_screen.dart';
import 'gallery_screen.dart';
import 'presets_screen.dart';
import 'profile_screen.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const CameraScreen(),
    const GalleryScreen(),
    const PresetsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.black.withOpacity(0.1)
                  : Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Theme.of(context).brightness == Brightness.light
              ? AppColors.textSecondaryLight
              : AppColors.textSecondaryDark,
          backgroundColor: Theme.of(context).brightness == Brightness.light
              ? AppColors.surfaceLight
              : AppColors.surfaceDark,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: Icon(_currentIndex == 0 ? Icons.camera_alt : Icons.camera_alt_outlined),
              label: 'Camera',
            ),
            BottomNavigationBarItem(
              icon: Icon(_currentIndex == 1 ? Icons.photo_library : Icons.photo_library_outlined),
              label: 'Gallery',
            ),
            BottomNavigationBarItem(
              icon: Icon(_currentIndex == 2 ? Icons.palette : Icons.palette_outlined),
              label: 'Presets',
            ),
            BottomNavigationBarItem(
              icon: Icon(_currentIndex == 3 ? Icons.person : Icons.person_outline),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}