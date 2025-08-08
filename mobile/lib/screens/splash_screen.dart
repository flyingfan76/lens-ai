import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/responsive_utils.dart';

/// Splash screen that displays the Lens AI logo with smooth animations
/// Features the uploaded Lens-AI.jpg image with elegant transitions
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _lensController;
  late AnimationController _worldController;
  late AnimationController _titleController;
  late Animation<double> _lensScale;
  late Animation<double> _worldOpacity;
  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;

  @override
  void initState() {
    super.initState();

    // Lens animation controller
    _lensController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // World animation controller
    _worldController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Title animation controller
    _titleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Lens scale animation
    _lensScale = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _lensController,
      curve: Curves.elasticOut,
    ));

    // World opacity animation
    _worldOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _worldController,
      curve: Curves.easeInOut,
    ));

    // Title animations
    _titleOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _titleController,
      curve: Curves.easeIn,
    ));

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _titleController,
      curve: Curves.easeOut,
    ));

    // Start animations sequence
    _startAnimations();
  }

  void _startAnimations() async {
    // Start lens animation
    _lensController.forward();

    // Wait a bit, then start world animation
    await Future.delayed(const Duration(milliseconds: 800));
    _worldController.forward();

    // Wait a bit more, then start title animation
    await Future.delayed(const Duration(milliseconds: 1000));
    _titleController.forward();

    // Navigate to main screen after splash
    await Future.delayed(const Duration(milliseconds: 2000));
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/main');
    }
  }

  @override
  void dispose() {
    _lensController.dispose();
    _worldController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = ResponsiveUtils.isLandscape(context);
    final lensSize = ResponsiveUtils.getMinDimension(context) * (isLandscape ? 0.4 : 0.6);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [
                  Color(0xFF1a1a1a),
                  Colors.black,
                ],
              ),
            ),
          ),

          // Main content
          Center(
            child: isLandscape
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLogo(lensSize),
                      SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context)),
                      _buildTitleSection(),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLogo(lensSize),
                      const SizedBox(height: 60),
                      _buildTitleSection(),
                    ],
                  ),
          ),

          // Loading indicator at bottom
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _titleController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _titleOpacity,
                  child: Column(
                    children: [
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading...',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(double lensSize) {
    return AnimatedBuilder(
      animation: _lensScale,
      builder: (context, child) {
        return Transform.scale(
          scale: _lensScale.value,
          child: Container(
            width: lensSize,
            height: lensSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // Main Lens AI image - Try multiple loading methods
                  FutureBuilder<bool>(
                    future: _checkImageExists(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data == true) {
                        return Image.asset(
                          'assets/images/Lens-AI.jpg',
                          width: lensSize,
                          height: lensSize,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('Image.asset failed: $error');
                            return _buildFallbackLogo(lensSize);
                          },
                        );
                      } else {
                        // If asset doesn't exist, show fallback immediately
                        return _buildFallbackLogo(lensSize);
                      }
                    },
                  ),
                  
                  // Overlay for better text visibility
                  AnimatedBuilder(
                    animation: _worldOpacity,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _worldOpacity.value * 0.3,
                        child: Container(
                          width: lensSize,
                          height: lensSize,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Subtle highlight effect
                  Positioned(
                    top: lensSize * 0.1,
                    left: lensSize * 0.1,
                    child: Container(
                      width: lensSize * 0.3,
                      height: lensSize * 0.2,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.2),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTitleSection() {
    return AnimatedBuilder(
      animation: _titleController,
      builder: (context, child) {
        return SlideTransition(
          position: _titleSlide,
          child: FadeTransition(
            opacity: _titleOpacity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Lens AI',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveFontSize(context, 42),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        color: AppColors.primary.withValues(alpha: 0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Capture the World Through AI',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveFontSize(context, 16),
                    color: Colors.white.withValues(alpha: 0.8),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Check if the image asset exists
  Future<bool> _checkImageExists() async {
    try {
      await rootBundle.load('assets/images/Lens-AI.jpg');
      return true;
    } catch (e) {
      debugPrint('Lens-AI.jpg not found in assets: $e');
      return false;
    }
  }

  /// Build fallback logo when image fails to load
  Widget _buildFallbackLogo(double lensSize) {
    return Container(
      width: lensSize,
      height: lensSize,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.8,
          colors: [
            AppColors.primary.withValues(alpha: 0.8),
            AppColors.accent.withValues(alpha: 0.6),
            Colors.black.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt,
              size: lensSize * 0.3,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 8),
            Text(
              'LENS AI',
              style: TextStyle(
                color: Colors.white,
                fontSize: lensSize * 0.08,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

