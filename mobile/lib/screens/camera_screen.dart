import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../widgets/white_balance_control.dart';
import '../widgets/ai_suggestion_panel.dart';
import '../services/ai_service.dart';
import '../core/providers/camera_provider.dart';
import '../core/services/camera_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'dart:typed_data';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool _isConnected = false;
  bool _showAdvancedControls = false;
  bool _showAISuggestions = false;
  double _isoValue = 400;
  double _apertureValue = 2.8;
  double _shutterSpeed = 60;
  String _cameraName = 'Unknown Camera';
  late WhiteBalanceSettings _wbSettings;
  final AIService _aiService = AIService();
  
  // Add camera provider and available cameras list
  final CameraProvider _cameraProvider = CameraProvider();
  List<Map<String, dynamic>> _availableCameras = [];
  bool _isDiscovering = false;
  
  // Live view WebSocket
  WebSocketChannel? _liveViewChannel;
  bool _isLiveViewActive = false;
  Uint8List? _currentFrame;

  @override
  void initState() {
    super.initState();
    _wbSettings = WhiteBalanceSettings();
    _discoverCameras(); // Discover cameras on startup
  }
  
  Future<void> _discoverCameras() async {
    setState(() {
      _isDiscovering = true;
    });
    
    try {
      await _cameraProvider.discoverExternalCameras();
      setState(() {
        _availableCameras = _cameraProvider.availableCameras;
        if (_availableCameras.isNotEmpty) {
          _cameraName = _availableCameras.first['model'] ?? 'Unknown Camera';
          print('DEBUG: Camera name set to: $_cameraName');
          print('DEBUG: Full camera data: ${_availableCameras.first}');
        }
      });
    } catch (e) {
      print('Camera discovery failed: $e');
    } finally {
      setState(() {
        _isDiscovering = false;
      });
    }
  }
  
  Future<void> _connectToCamera() async {
    if (_availableCameras.isEmpty) return;
    
    final cameraId = _availableCameras.first['id'];
    final cameraModel = _availableCameras.first['model'];
    
    print('DEBUG: Connecting to camera: $cameraId ($cameraModel)');
    
    try {
      await _cameraProvider.connectToExternalCamera(cameraId: cameraId);
      setState(() {
        if (_cameraProvider.isConnected) {
          _cameraName = cameraModel; // Use the actual detected model
        }
      });
      print('DEBUG: Successfully connected to: $cameraModel');
    } catch (e) {
      print('Connection failed: $e');
    }
  }
  
  Future<void> _startLiveView() async {
    try {
      final result = await _cameraProvider.startLiveView();
      final streamUrl = result['streamUrl'] as String;
      
      print('Live view started: $streamUrl');
      
      // Connect to WebSocket for live view frames
      _connectToLiveViewStream(streamUrl);
      
      setState(() {
        _isLiveViewActive = true;
      });
    } catch (e) {
      print('Failed to start live view: $e');
    }
  }
  
  void _connectToLiveViewStream(String streamUrl) {
    try {
      _liveViewChannel = WebSocketChannel.connect(Uri.parse(streamUrl));
      
      _liveViewChannel!.stream.listen(
        (data) {
          if (data is String) {
            // Handle JSON message (e.g., status updates)
            try {
              final message = json.decode(data);
              print('WebSocket message: $message');
            } catch (e) {
              print('Failed to parse WebSocket message: $e');
            }
          } else if (data is List<int>) {
            // Handle binary frame data
            setState(() {
              _currentFrame = Uint8List.fromList(data);
            });
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
          setState(() {
            _isLiveViewActive = false;
          });
        },
        onDone: () {
          print('WebSocket connection closed');
          setState(() {
            _isLiveViewActive = false;
          });
        },
      );
    } catch (e) {
      print('Failed to connect to live view stream: $e');
    }
  }
  
  Future<void> _stopLiveView() async {
    try {
      await _cameraProvider.stopLiveView();
      _liveViewChannel?.sink.close();
      setState(() {
        _isLiveViewActive = false;
        _currentFrame = null;
      });
      print('Live view stopped');
    } catch (e) {
      print('Failed to stop live view: $e');
    }
  }

  @override
  void dispose() {
    _liveViewChannel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top status bar
            _buildTopBar(),
            
            // Main viewfinder area (takes remaining space)
            Expanded(
              child: Stack(
                children: [
                  _buildViewfinder(),
                  // AI Suggestion Panel
                  AISuggestionPanel(
                    isVisible: _showAISuggestions,
                    onVisibilityChanged: (visible) {
                      setState(() {
                        _showAISuggestions = visible;
                      });
                    },
                    onApplySettings: _applyAISettings,
                  ),
                  // Advanced controls panel (slides up from bottom)
                  if (_showAdvancedControls) _buildAdvancedControls(),
                ],
              ),
            ),
            
            // Bottom controls (fixed at bottom)
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildViewfinder() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _cameraProvider.isConnected ? AppColors.success : AppColors.textSecondaryDark,
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          // Live view stream or placeholder
          if (_isLiveViewActive && _currentFrame != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.memory(
                  _currentFrame!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
            )
          else
            // Viewfinder placeholder
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _cameraProvider.isConnected ? Icons.camera_alt : Icons.camera_alt_outlined,
                    size: 80,
                    color: _cameraProvider.isConnected ? AppColors.success : AppColors.textSecondaryDark,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _cameraProvider.isConnected
                        ? (_isLiveViewActive ? 'Starting Live View...' : 'Tap Live View to Start')
                        : 'Camera Disconnected',
                    style: TextStyle(
                      color: _cameraProvider.isConnected ? AppColors.success : AppColors.textSecondaryDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (!_cameraProvider.isConnected && _availableCameras.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _connectToCamera(),
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
          if (_cameraProvider.isConnected && _isLiveViewActive) _buildGridOverlay(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
          children: [
            // Connection status with real camera info
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _availableCameras.isNotEmpty ? AppColors.success : AppColors.error,
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
                    Expanded(
                      child: Text(
                        _availableCameras.isNotEmpty 
                            ? '${_availableCameras.length} Camera(s): ${_cameraName}'
                            : _isDiscovering ? 'Discovering...' : 'No Cameras',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            
            // Live view button
            if (_cameraProvider.isConnected)
              IconButton(
                onPressed: _isLiveViewActive ? _stopLiveView : _startLiveView,
                icon: Icon(
                  _isLiveViewActive ? Icons.videocam_off : Icons.videocam,
                  color: _isLiveViewActive ? Colors.red : Colors.blue,
                  size: 20,
                ),
                tooltip: _isLiveViewActive ? 'Stop Live View' : 'Start Live View',
              ),
            
            // Refresh button to discover cameras
            IconButton(
              onPressed: _isDiscovering ? null : _discoverCameras,
              icon: _isDiscovering 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                    )
                  : const Icon(Icons.refresh, color: Colors.white, size: 20),
            ),
            
            // Settings
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.settings, color: Colors.white, size: 20),
            ),
          ],
        ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick settings row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildQuickSetting('ISO', _isoValue.toInt().toString()),
                  _buildQuickSetting('f/', _apertureValue.toString()),
                  _buildQuickSetting('1/', _shutterSpeed.toInt().toString()),
                  _buildQuickSetting('WB', _getWBDisplayText()),
                ],
              ),
            ),
            
            // Main control row
            Container(
              height: 90,
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
                padding: const EdgeInsets.symmetric(vertical: 12),
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
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.4,
        ),
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
                child: SingleChildScrollView(
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
                      const SizedBox(height: 16),
                      WhiteBalanceControl(
                        initialSettings: _wbSettings,
                        onChanged: (settings) {
                          setState(() {
                            _wbSettings = settings;
                          });
                        },
                        isAdvanced: true,
                      ),
                    ],
                  ),
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


  void _capturePhoto() async {
    if (_isConnected) {
      try {
        // Apply current settings to camera before capture
        await _applyCurrentSettingsToCamera();
        
        // Capture photo via SDK
        final result = await _aiService.capturePhoto();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result != null ? 'Photo captured!' : 'Capture failed'),
            backgroundColor: result != null ? AppColors.success : AppColors.error,
            duration: const Duration(seconds: 1),
          ),
        );
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Capture error: $error'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      // Simulate photo capture when not connected
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Photo captured! (Simulated)'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _applyCurrentSettingsToCamera() async {
    final settings = {
      'iso': _isoValue.round(),
      'aperture': 'f/${_apertureValue.toStringAsFixed(1)}',
      'shutterSpeed': '1/${_shutterSpeed.round()}',
      'whiteBalance': _wbSettings.toJson(),
    };
    
    await _aiService.applyCameraSettings(settings);
  }

  void _applyAISettings(Map<String, dynamic> settings) {
    setState(() {
      if (settings.containsKey('iso')) {
        _isoValue = (settings['iso'] as num).toDouble();
      }
      
      if (settings.containsKey('aperture')) {
        final apertureStr = settings['aperture'] as String;
        if (apertureStr.startsWith('f/')) {
          _apertureValue = double.tryParse(apertureStr.substring(2)) ?? _apertureValue;
        }
      }
      
      if (settings.containsKey('shutterSpeed')) {
        final shutterStr = settings['shutterSpeed'] as String;
        if (shutterStr.startsWith('1/')) {
          _shutterSpeed = double.tryParse(shutterStr.substring(2)) ?? _shutterSpeed;
        }
      }
      
      if (settings.containsKey('whiteBalance')) {
        final wbData = settings['whiteBalance'] as Map<String, dynamic>;
        _wbSettings = WhiteBalanceSettings.fromJson(wbData);
      }
    });
    
    // Apply settings to camera if connected
    if (_isConnected) {
      _applyCurrentSettingsToCamera();
    }
  }


  String _getWBDisplayText() {
    switch (_wbSettings.mode) {
      case WBMode.auto:
        return 'Auto';
      case WBMode.daylight:
        return 'Day';
      case WBMode.tungsten:
        return 'Tung';
      case WBMode.fluorescent:
        return 'Fluo';
      case WBMode.cloudy:
        return 'Cloud';
      case WBMode.shade:
        return 'Shade';
      case WBMode.flash:
        return 'Flash';
      case WBMode.custom:
        return '${(_wbSettings.kelvin / 1000).toStringAsFixed(1)}K';
    }
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