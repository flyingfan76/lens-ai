import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool _isConnected = false;
  bool _showAdvancedControls = false;
  double _isoValue = 400;
  double _apertureValue = 2.8;
  double _shutterSpeed = 60;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Main viewfinder area
            _buildViewfinder(),
            
            // Top status bar
            _buildTopBar(),
            
            // Bottom controls
            _buildBottomControls(),
            
            // Advanced controls panel (slides up from bottom)
            if (_showAdvancedControls) _buildAdvancedControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildViewfinder() {
    return Positioned.fill(
      child: Container(
        margin: const EdgeInsets.only(top: 60, bottom: 150),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isConnected ? AppColors.success : AppColors.textSecondaryDark,
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            // Viewfinder placeholder
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isConnected ? Icons.camera_alt : Icons.camera_alt_outlined,
                    size: 80,
                    color: _isConnected ? AppColors.success : AppColors.textSecondaryDark,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isConnected ? 'Live View' : 'Camera Disconnected',
                    style: TextStyle(
                      color: _isConnected ? AppColors.success : AppColors.textSecondaryDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (!_isConnected) ...[
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isConnected = !_isConnected;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Connect Camera'),
                    ),
                  ],
                ],
              ),
            ),
            
            // Rule of thirds grid overlay
            if (_isConnected) _buildGridOverlay(),
            
            // AI suggestions overlay
            if (_isConnected) _buildAISuggestions(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Connection status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isConnected ? AppColors.success : AppColors.error,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isConnected ? 'Canon EOS R5' : 'Disconnected',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            const Spacer(),
            
            // Battery indicator
            if (_isConnected) ...[
              const Icon(Icons.battery_full, color: Colors.white, size: 20),
              const SizedBox(width: 4),
              const Text('85%', style: TextStyle(color: Colors.white, fontSize: 12)),
              const SizedBox(width: 16),
            ],
            
            // Settings
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.settings, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.8),
              Colors.black,
            ],
          ),
        ),
        child: Column(
          children: [
            // Quick settings row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildQuickSetting('ISO', _isoValue.toInt().toString()),
                  _buildQuickSetting('f/', _apertureValue.toString()),
                  _buildQuickSetting('1/', _shutterSpeed.toInt().toString()),
                  _buildQuickSetting('WB', 'Auto'),
                ],
              ),
            ),
            
            // Main control row
            Expanded(
              child: Row(
                children: [
                  // Last photo thumbnail
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(Icons.photo, color: Colors.white54),
                      ),
                    ),
                  ),
                  
                  // Shutter button
                  Expanded(
                    child: Center(
                      child: GestureDetector(
                        onTap: _isConnected ? _capturePhoto : null,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isConnected ? Colors.white : Colors.grey[600],
                            border: Border.all(
                              color: _isConnected ? AppColors.primary : Colors.grey[500]!,
                              width: 4,
                            ),
                          ),
                          child: Icon(
                            Icons.circle,
                            size: 60,
                            color: _isConnected ? AppColors.primary : Colors.grey[500],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Mode selector
                  Expanded(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Text(
                          'AUTO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Advanced controls toggle
            GestureDetector(
              onTap: () {
                setState(() {
                  _showAdvancedControls = !_showAdvancedControls;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _showAdvancedControls 
                          ? Icons.keyboard_arrow_down 
                          : Icons.keyboard_arrow_up,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _showAdvancedControls ? 'Hide Controls' : 'Show Controls',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSetting(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white54,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              
              // Controls
              Expanded(
                child: Column(
                  children: [
                    _buildSliderControl('ISO', _isoValue, 100, 6400, (value) {
                      setState(() {
                        _isoValue = value;
                      });
                    }),
                    _buildSliderControl('Aperture', _apertureValue, 1.4, 11, (value) {
                      setState(() {
                        _apertureValue = value;
                      });
                    }),
                    _buildSliderControl('Shutter', _shutterSpeed, 1, 4000, (value) {
                      setState(() {
                        _shutterSpeed = value;
                      });
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliderControl(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              activeColor: AppColors.primary,
              inactiveColor: Colors.white24,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              value.toStringAsFixed(label == 'Aperture' ? 1 : 0),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridOverlay() {
    return CustomPaint(
      size: Size.infinite,
      painter: GridPainter(),
    );
  }

  Widget _buildAISuggestions() {
    return Positioned(
      top: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, color: AppColors.accent, size: 16),
                const SizedBox(width: 4),
                const Text(
                  'AI Suggestion',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Try moving closer\nto the subject',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _capturePhoto() {
    // Simulate photo capture
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Photo captured!'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 0.5;

    // Vertical lines
    canvas.drawLine(
      Offset(size.width / 3, 0),
      Offset(size.width / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 2 / 3, 0),
      Offset(size.width * 2 / 3, size.height),
      paint,
    );

    // Horizontal lines
    canvas.drawLine(
      Offset(0, size.height / 3),
      Offset(size.width, size.height / 3),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 2 / 3),
      Offset(size.width, size.height * 2 / 3),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}