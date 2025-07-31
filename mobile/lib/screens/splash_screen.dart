import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

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
    final size = MediaQuery.of(context).size;
    final lensSize = (size.width < size.height ? size.width : size.height) * 0.6;

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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Lens AI Logo with animation
                AnimatedBuilder(
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
                              // Main Lens AI image
                              Image.asset(
                                'assets/images/Lens-AI.jpg',
                                width: lensSize,
                                height: lensSize,
                                fit: BoxFit.cover,
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
                ),

                const SizedBox(height: 60),

                // App title
                AnimatedBuilder(
                  animation: _titleController,
                  builder: (context, child) {
                    return SlideTransition(
                      position: _titleSlide,
                      child: FadeTransition(
                        opacity: _titleOpacity,
                        child: Column(
                          children: [
                            Text(
                              'Lens AI',
                              style: TextStyle(
                                fontSize: 42,
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
                                fontSize: 16,
                                color: Colors.white.withValues(alpha: 0.8),
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
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
}

