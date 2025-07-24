import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../core/theme/app_colors.dart';

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
    final lensSize = math.min(size.width, size.height) * 0.6;

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
                // Lens with world inside
                AnimatedBuilder(
                  animation: _lensScale,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _lensScale.value,
                      child: Container(
                        width: lensSize,
                        height: lensSize,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Lens outer ring
                            Container(
                              width: lensSize,
                              height: lensSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF4a4a4a),
                                    Color(0xFF2a2a2a),
                                    Color(0xFF1a1a1a),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                            ),

                            // Lens inner glass
                            Container(
                              width: lensSize * 0.85,
                              height: lensSize * 0.85,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  center: const Alignment(-0.3, -0.3),
                                  radius: 1.2,
                                  colors: [
                                    Colors.white.withOpacity(0.1),
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.2),
                                  ],
                                ),
                              ),
                            ),

                            // World inside lens
                            AnimatedBuilder(
                              animation: _worldOpacity,
                              builder: (context, child) {
                                return Opacity(
                                  opacity: _worldOpacity.value,
                                  child: ClipOval(
                                    child: Container(
                                      width: lensSize * 0.75,
                                      height: lensSize * 0.75,
                                      child: const WorldView(),
                                    ),
                                  ),
                                );
                              },
                            ),

                            // Lens highlight
                            Positioned(
                              top: lensSize * 0.15,
                              left: lensSize * 0.25,
                              child: Container(
                                width: lensSize * 0.2,
                                height: lensSize * 0.15,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withOpacity(0.4),
                                      Colors.white.withOpacity(0.1),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
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
                                    color: AppColors.primary.withOpacity(0.5),
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
                                color: Colors.white.withOpacity(0.8),
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
                            AppColors.primary.withOpacity(0.7),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
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

class WorldView extends StatefulWidget {
  const WorldView({super.key});

  @override
  State<WorldView> createState() => _WorldViewState();
}

class _WorldViewState extends State<WorldView>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationController.value * 2 * math.pi,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF4FC3F7), // Sky blue
                  Color(0xFF29B6F6), // Deeper blue
                  Color(0xFF4CAF50), // Green
                  Color(0xFF8BC34A), // Light green
                  Color(0xFF66BB6A), // Medium green
                  Color(0xFF2E7D32), // Dark green
                ],
                stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
              ),
            ),
            child: Stack(
              children: [
                // Continent shapes
                Positioned(
                  top: 20,
                  left: 10,
                  child: _buildContinent(40, 25, const Color(0xFF4CAF50)),
                ),
                Positioned(
                  top: 60,
                  right: 15,
                  child: _buildContinent(35, 20, const Color(0xFF66BB6A)),
                ),
                Positioned(
                  bottom: 30,
                  left: 20,
                  child: _buildContinent(50, 30, const Color(0xFF8BC34A)),
                ),
                Positioned(
                  bottom: 15,
                  right: 25,
                  child: _buildContinent(30, 20, const Color(0xFF4CAF50)),
                ),
                
                // Clouds
                Positioned(
                  top: 15,
                  right: 30,
                  child: _buildCloud(25, Colors.white.withOpacity(0.6)),
                ),
                Positioned(
                  top: 45,
                  left: 25,
                  child: _buildCloud(20, Colors.white.withOpacity(0.4)),
                ),
                Positioned(
                  bottom: 50,
                  right: 10,
                  child: _buildCloud(22, Colors.white.withOpacity(0.5)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContinent(double width, double height, Color color) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 3,
            offset: const Offset(1, 1),
          ),
        ],
      ),
    );
  }

  Widget _buildCloud(double size, Color color) {
    return Container(
      width: size,
      height: size * 0.6,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size / 2),
      ),
    );
  }
}