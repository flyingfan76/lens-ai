import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/disposal_mixin.dart';
import '../widgets/white_balance_control.dart';
import '../services/ai/ai_coordinator.dart';
import '../models/ai_suggestion.dart';
import '../models/external_camera.dart';
import '../core/state/camera_feature_provider.dart';
import '../core/providers/unified_camera_provider.dart';
import 'settings_screen.dart';
import 'dart:async';

/// Simplified Camera Screen that works with current architecture
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with DisposalMixin {
  late WhiteBalanceSettings _wbSettings;
  late UnifiedCameraProvider _cameraProvider;
  
  // AI suggestion state
  final AICoordinator _aiCoordinator = AICoordinator();
  List<AISuggestion> _currentSuggestions = [];
  bool _showAISuggestionDialog = false;

  // Control panel state
  bool _showControlPanel = false;
  bool _showCameraSelector = false;
  
  // UI state

  @override
  void initState() {
    super.initState();
    _wbSettings = WhiteBalanceSettings();
    _cameraProvider = UnifiedCameraProvider();
    _initializeAI();
    
    // Note: External cameras work on macOS via USB/WiFi connections
  }
  
  Future<void> _clearCameraCacheOnMacOS() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('discovered_cameras');
      await prefs.remove('connected_camera');
      debugPrint('CameraScreen: Cleared camera cache for macOS');
    } catch (e) {
      debugPrint('CameraScreen: Failed to clear camera cache: $e');
    }
  }

  Future<void> _switchToBuiltinCamera(CameraDescription camera) async {
    final success = await _cameraProvider.switchToBuiltinCamera(camera);
    if (success) {
      setState(() {
        _showCameraSelector = false;
      });
    }
  }

  Future<void> _switchToExternalCamera(ExternalCamera camera) async {
    final success = await _cameraProvider.switchToExternalCamera(camera);
    if (success) {
      setState(() {
        _showCameraSelector = false;
      });
    }
  }

  Future<void> _initializeAI() async {
    try {
      await _aiCoordinator.initialize();
    } catch (e) {
      debugPrint('AI initialization error: $e');
    }
  }

  String _getPlatformSpecificErrorMessage() {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return 'Built-in camera not supported on macOS desktop.\n\nExternal cameras (DSLR, mirrorless) are supported via USB or WiFi.\nConnect a camera and tap "Scan for Cameras" to detect it.';
    }
    
    // Check if running on iOS Simulator
    if (defaultTargetPlatform == TargetPlatform.iOS && !kIsWeb) {
      // iOS Simulator typically doesn't have camera access
      try {
        if (kDebugMode) {
          return 'Camera not available in iOS Simulator.\nTo test camera features, please use a physical iOS device.\n\nAll other app features work normally in simulator.';
        }
      } catch (e) {
        // Fallback for any platform detection issues
      }
    }
    
    return 'Unable to initialize camera.\nPlease check permissions and try again.';
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _buildCameraInterface(),
      ),
    );
  }

  Widget _buildCameraInterface() {
    return Consumer<UnifiedCameraProvider>(
      builder: (context, provider, child) {
        // Debug logging for macOS camera issue
        debugPrint('CameraScreen: isLoading=${provider.isLoading}, hasAnyCameras=${provider.hasAnyCameras}, error=${provider.error}');
        debugPrint('CameraScreen: builtinCameras=${provider.builtinCameras.length}, externalCameras=${provider.externalCameras.length}');
        debugPrint('CameraScreen: External cameras: ${provider.externalCameras.map((c) => '${c.name} (connected: ${c.isConnected})').join(', ')}');
        
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          );
        }

        if (provider.error != null) {
          return _buildErrorState(provider.error!);
        }

        if (!provider.hasAnyCameras) {
          return _buildNoCamerasState();
        }

        return Stack(
          children: [
            // Camera preview
            Positioned.fill(
              child: _buildCameraPreview(provider),
            ),
            
            // Top controls
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _buildTopControls(provider),
            ),
            
            // Camera selector overlay
            if (_showCameraSelector) 
              _buildCameraSelectorOverlay(provider),
            
            // Bottom controls
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _buildBottomControls(),
            ),
            
            // AI suggestion overlay
            if (_showAISuggestionDialog) _buildAISuggestionOverlay(),
          ],
        );
      },
    );
  }

  Widget _buildCameraPreview(UnifiedCameraProvider provider) {
    if (provider.activeCameraType == CameraSourceType.builtin && 
        provider.builtinController != null) {
      return CameraPreview(provider.builtinController!);
    } else if (provider.activeCameraType == CameraSourceType.external) {
      return _buildExternalCameraPreview(provider.activeExternalCamera!);
    } else {
      return const Center(
        child: Text(
          'Select a camera to begin',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      );
    }
  }

  Widget _buildExternalCameraPreview(ExternalCamera camera) {
    return Consumer<UnifiedCameraProvider>(
      builder: (context, provider, child) {
        // If live view is active, show the live stream
        if (provider.isLiveViewActive && provider.liveViewStream != null) {
          return _buildLiveViewStream(provider.liveViewStream!, camera);
        }
        
        // Otherwise show camera info with live view controls
        return _buildCameraInfoWithControls(camera, provider);
      },
    );
  }

  // Cached overlay widgets to prevent rebuilds
  Widget? _cachedLiveViewOverlays;
  Widget? _cachedControlsOverlay;
  Uint8List? _lastValidFrame;
  
  Widget _buildLiveViewStream(Stream<Uint8List> liveViewStream, ExternalCamera camera) {
    // Build cached overlays once
    _cachedLiveViewOverlays ??= _buildLiveViewOverlays(camera);
    _cachedControlsOverlay ??= _buildLiveViewControls();
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: AppColors.accent, width: 2),
      ),
      child: Stack(
        children: [
          // Optimized live view stream
          Positioned.fill(
            child: StreamBuilder<Uint8List>(
              stream: liveViewStream.distinct(),  // Remove duplicate frames
              builder: (context, snapshot) {
                // Use previous valid frame if current is corrupted/empty
                final currentFrame = snapshot.hasData && snapshot.data!.isNotEmpty 
                    ? snapshot.data! 
                    : _lastValidFrame;
                    
                if (currentFrame != null && _isValidJpegFrame(currentFrame)) {
                  // Cache the valid frame
                  _lastValidFrame = currentFrame;
                  
                  return _buildOptimizedLiveViewDisplay(currentFrame, camera);
                } else {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.green),
                  );
                }
              },
            ),
          ),
          
          // Static cached overlays
          _cachedLiveViewOverlays!,
          _cachedControlsOverlay!,
        ],
      ),
    );
  }
  
  /// Check if frame is valid JPEG to prevent rendering corrupted frames
  bool _isValidJpegFrame(Uint8List data) {
    return data.length > 10 && 
           data[0] == 0xFF && 
           data[1] == 0xD8 && 
           data[data.length - 2] == 0xFF && 
           data[data.length - 1] == 0xD9;
  }
  
  /// Build optimized live view display with minimal rebuilds
  Widget _buildOptimizedLiveViewDisplay(Uint8List imageData, ExternalCamera camera) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.green, width: 2),
            borderRadius: BorderRadius.circular(8),
            color: Colors.black87,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: RepaintBoundary(  // Isolate image painting
              child: Image.memory(
                imageData,
                fit: BoxFit.cover,
                gaplessPlayback: true,  // Smooth frame transitions
                filterQuality: FilterQuality.low,  // Better performance
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Live view image error: $error');
                  return _buildMockCameraPreview();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  /// Build static overlay widgets (cached to prevent rebuilds)
  Widget _buildLiveViewOverlays(ExternalCamera camera) {
    return Stack(
      children: [
        // LIVE indicator
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Camera model
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              camera.model,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
              ),
            ),
          ),
        ),
        
        // Status text
        Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.videocam,
                    color: Colors.green,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Live view streaming from ${camera.name}',
                    style: TextStyle(
                      color: Colors.green.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  /// Build static control overlay (cached to prevent rebuilds)
  Widget _buildLiveViewControls() {
    return Positioned(
      bottom: 16,
      right: 16,
      child: Column(
        children: [
          // AI Analysis button
          FloatingActionButton.small(
            onPressed: () => _showAISuggestions(),
            backgroundColor: AppColors.accent,
            heroTag: "ai_analysis",
            child: const Icon(Icons.auto_awesome, color: Colors.white),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            onPressed: () async {
              final provider = Provider.of<UnifiedCameraProvider>(context, listen: false);
              await provider.stopLiveView();
              // Clear cached overlays when stopping
              _cachedLiveViewOverlays = null;
              _cachedControlsOverlay = null;
              _lastValidFrame = null;
            },
            backgroundColor: Colors.red,
            heroTag: "stop_live_view",
            child: const Icon(Icons.stop, color: Colors.white),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            onPressed: () async {
              final provider = Provider.of<UnifiedCameraProvider>(context, listen: false);
              await provider.capturePhoto();
            },
            backgroundColor: Colors.green,
            heroTag: "capture_photo",
            child: const Icon(Icons.camera_alt, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraInfoWithControls(ExternalCamera camera, UnifiedCameraProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        border: Border.all(color: AppColors.accent, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getCameraIcon(camera.brand),
            size: 80,
            color: AppColors.accent,
          ),
          const SizedBox(height: 16),
          Text(
            camera.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            camera.model,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: camera.isConnected ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              camera.isConnected ? 'Connected' : 'Connecting...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Live view control button
          if (camera.isConnected) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                await provider.startLiveView();
              },
              icon: const Icon(Icons.videocam),
              label: const Text('Start Live View'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
          
          // Debug info
          if (defaultTargetPlatform == TargetPlatform.macOS)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Debug: isConnected=${camera.isConnected}',
                style: const TextStyle(
                  color: Colors.yellow,
                  fontSize: 10,
                ),
              ),
            ),
          if (camera.connectionType == CameraConnectionType.wifi && camera.ipAddress != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'IP: ${camera.ipAddress}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build real live view image from camera JPEG data
  Widget _buildRealLiveViewImage(Uint8List imageData) {
    try {
      // Check if we have JPEG data (starts with FF D8)
      if (imageData.length > 2 && imageData[0] == 0xFF && imageData[1] == 0xD8) {
        // Real JPEG image from camera
        return Image.memory(
          imageData,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Error displaying live view image: $error');
            return _buildMockCameraPreview();
          },
        );
      } else {
        // Not JPEG data, fall back to mock preview
        return _buildMockCameraPreview();
      }
    } catch (e) {
      debugPrint('Error processing live view image data: $e');
      return _buildMockCameraPreview();
    }
  }

  /// Build mock camera preview background (fallback)
  Widget _buildMockCameraPreview() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[900]!,
            Colors.grey[800]!,
            Colors.grey[700]!,
            Colors.grey[600]!,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Simulated depth with circles (like bokeh effect)
          Positioned(
            top: 50,
            right: 80,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange.withValues(alpha: 0.3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: 60,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withValues(alpha: 0.4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.2),
                    blurRadius: 15,
                    spreadRadius: 8,
                  ),
                ],
              ),
            ),
          ),
          
          // Center focus area
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.green.withValues(alpha: 0.6),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  Icons.center_focus_strong,
                  color: Colors.green.withValues(alpha: 0.7),
                  size: 48,
                ),
              ),
            ),
          ),
          
          // Mock scene elements
          Positioned(
            top: 30,
            left: 30,
            child: Container(
              width: 80,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.brown.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCameraIcon(CameraBrand brand) {
    switch (brand) {
      case CameraBrand.nikon:
        return Icons.camera_alt;
      case CameraBrand.canon:
        return Icons.camera;
      case CameraBrand.sony:
        return Icons.camera_enhance;
      default:
        return Icons.camera_alt_outlined;
    }
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          const Text(
            'Camera Error',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoCamerasState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.camera_alt_outlined,
            size: 64,
            color: Colors.white54,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Cameras Found',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getPlatformSpecificErrorMessage(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  _cameraProvider.refreshExternalCameras();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Scan for Cameras'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {}); // Force UI rebuild
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh UI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopControls(UnifiedCameraProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            // Camera selector button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    provider.activeCameraType == CameraSourceType.external 
                        ? Icons.camera_alt 
                        : Icons.camera,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    provider.getActiveCameraName(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showCameraSelector = !_showCameraSelector;
                      });
                    },
                    icon: Icon(
                      _showCameraSelector ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Row(
          children: [
            // Camera count indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: provider.hasExternalCameras ? AppColors.accent : Colors.grey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${provider.totalCameraCount} cameras',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _showAISuggestions,
              icon: const Icon(Icons.auto_awesome, color: AppColors.accent),
            ),
            IconButton(
              onPressed: () => _navigateToSettings(),
              icon: const Icon(Icons.settings, color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Control panel (show when triggered)
        if (_showControlPanel) ...[
          _buildComprehensiveControlPanel(),
          const SizedBox(height: 16),
        ],
        
        // Main control row with trigger
        _buildMainControlRow(),
      ],
    );
  }

  /// Build main control row with capture button and trigger
  Widget _buildMainControlRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Control panel trigger
        IconButton(
          onPressed: () {
            setState(() {
              _showControlPanel = !_showControlPanel;
            });
          },
          icon: Icon(
            _showControlPanel ? Icons.expand_less : Icons.expand_more,
            color: Colors.white,
            size: 30,
          ),
        ),
        
        // Capture button - center and prominent
        GestureDetector(
          onTap: _capturePhoto,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: AppColors.accent, width: 3),
            ),
            child: const Icon(
              Icons.camera_alt,
              color: AppColors.accent,
              size: 30,
            ),
          ),
        ),
        
        // Settings button
        IconButton(
          onPressed: () => _navigateToSettings(),
          icon: const Icon(
            Icons.settings,
            color: Colors.white,
            size: 30,
          ),
        ),
      ],
    );
  }

  /// Build comprehensive control panel with all functional camera settings
  Widget _buildComprehensiveControlPanel() {
    return Consumer<CameraFeatureProvider>(
      builder: (context, cameraProvider, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // White Balance Controls (direct, no nested expand)
              _buildWhiteBalanceControls(),
              const SizedBox(height: 20),
              
              // Camera Settings Row 1: ISO and Aperture
              Row(
                children: [
                  Expanded(
                    child: _buildFunctionalSlider(
                      'ISO',
                      cameraProvider.iso,
                      100.0,
                      3200.0,
                      (value) {
                        // Update ISO in provider
                        cameraProvider.updateCameraSettings({'iso': value});
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFunctionalSlider(
                      'f/',
                      cameraProvider.aperture,
                      1.4,
                      16.0,
                      (value) {
                        // Update aperture in provider
                        cameraProvider.updateCameraSettings({'aperture': value});
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Camera Settings Row 2: Shutter Speed and Zoom
              Row(
                children: [
                  Expanded(
                    child: _buildFunctionalSlider(
                      '1/',
                      cameraProvider.shutterSpeed,
                      1.0,
                      1000.0,
                      (value) {
                        // Update shutter speed in provider
                        cameraProvider.updateCameraSettings({'shutterSpeed': value});
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFunctionalSlider(
                      'Zoom',
                      cameraProvider.zoomLevel,
                      cameraProvider.minZoomLevel,
                      cameraProvider.maxZoomLevel,
                      (value) {
                        // Update zoom in provider
                        cameraProvider.updateCameraSettings({'zoomLevel': value});
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Flash Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.flash_off,
                    color: !cameraProvider.isFlashEnabled 
                        ? AppColors.accent 
                        : Colors.white.withValues(alpha: 0.5),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: cameraProvider.isFlashEnabled,
                    onChanged: (value) {
                      // Update flash in provider
                      cameraProvider.updateCameraSettings({'flashMode': value});
                    },
                    activeColor: AppColors.accent,
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.flash_on,
                    color: cameraProvider.isFlashEnabled 
                        ? AppColors.accent 
                        : Colors.white.withValues(alpha: 0.5),
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build direct white balance controls without nested expand
  Widget _buildWhiteBalanceControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // WB Header
        Row(
          children: [
            const Icon(Icons.wb_sunny, color: AppColors.accent, size: 18),
            const SizedBox(width: 8),
            const Text(
              'White Balance',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_getWBKelvin()}K',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // WB Mode Selection (compact)
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildWBModeChip('Auto', _wbSettings.mode == WBMode.auto, () {
              setState(() {
                _wbSettings.mode = WBMode.auto;
              });
            }),
            _buildWBModeChip('Day', _wbSettings.mode == WBMode.daylight, () {
              setState(() {
                _wbSettings.mode = WBMode.daylight;
              });
            }),
            _buildWBModeChip('Cloudy', _wbSettings.mode == WBMode.cloudy, () {
              setState(() {
                _wbSettings.mode = WBMode.cloudy;
              });
            }),
            _buildWBModeChip('Tungsten', _wbSettings.mode == WBMode.tungsten, () {
              setState(() {
                _wbSettings.mode = WBMode.tungsten;
              });
            }),
            _buildWBModeChip('Custom', _wbSettings.mode == WBMode.custom, () {
              setState(() {
                _wbSettings.mode = WBMode.custom;
              });
            }),
          ],
        ),
        
        // Custom temperature slider (only when custom mode)
        if (_wbSettings.mode == WBMode.custom) ...[
          const SizedBox(height: 12),
          _buildFunctionalSlider(
            'Temp',
            _wbSettings.kelvin,
            2000.0,
            10000.0,
            (value) {
              setState(() {
                _wbSettings.kelvin = value;
              });
            },
          ),
        ],
        
        const SizedBox(height: 16),
        
        // Fine Tuning Controls (from original advanced controls)
        const Text(
          'Fine Tuning',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        
        // Magenta-Green shift
        _buildWBShiftSlider(
          'Magenta - Green',
          _wbSettings.magentaGreenShift.toDouble(),
          -9.0,
          9.0,
          Colors.pink,
          Colors.green,
          (value) {
            setState(() {
              _wbSettings.magentaGreenShift = value.round();
            });
          },
        ),
        const SizedBox(height: 12),
        
        // Blue-Amber shift  
        _buildWBShiftSlider(
          'Blue - Amber',
          _wbSettings.blueAmberShift.toDouble(),
          -9.0,
          9.0,
          Colors.blue,
          Colors.orange,
          (value) {
            setState(() {
              _wbSettings.blueAmberShift = value.round();
            });
          },
        ),
        const SizedBox(height: 16),
        
        // Auto WB Bias
        Row(
          children: [
            const Text(
              'Auto WB Bias',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Switch(
              value: _wbSettings.autoWBBiasEnabled,
              onChanged: (value) {
                setState(() {
                  _wbSettings.autoWBBiasEnabled = value;
                });
              },
              activeColor: AppColors.accent,
            ),
          ],
        ),
        
        // WB Priority selection
        if (_wbSettings.autoWBBiasEnabled) ...[
          const SizedBox(height: 12),
          const Text(
            'Priority',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              _buildWBModeChip('Standard', _wbSettings.priority == WBPriority.standard, () {
                setState(() {
                  _wbSettings.priority = WBPriority.standard;
                });
              }),
              _buildWBModeChip('White Priority', _wbSettings.priority == WBPriority.whitePriority, () {
                setState(() {
                  _wbSettings.priority = WBPriority.whitePriority;
                });
              }),
              _buildWBModeChip('Atmosphere', _wbSettings.priority == WBPriority.atmospherePriority, () {
                setState(() {
                  _wbSettings.priority = WBPriority.atmospherePriority;
                });
              }),
            ],
          ),
        ],
      ],
    );
  }

  /// Build WB mode chip
  Widget _buildWBModeChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accent : Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.8),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// Get current WB kelvin value
  int _getWBKelvin() {
    switch (_wbSettings.mode) {
      case WBMode.tungsten:
        return 3200;
      case WBMode.daylight:
        return 5500;
      case WBMode.cloudy:
        return 6500;
      case WBMode.custom:
        return _wbSettings.kelvin.round();
      default:
        return 5500;
    }
  }

  /// Build WB shift slider for fine tuning
  Widget _buildWBShiftSlider(
    String label,
    double value,
    double min,  
    double max,
    Color negativeColor,
    Color positiveColor,
    Function(double) onChanged,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: value == 0
                    ? Colors.grey[700]
                    : (value > 0 ? positiveColor : negativeColor).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                value == 0
                    ? '0'
                    : '${value > 0 ? '+' : ''}${value.round()}',
                style: TextStyle(
                  color: value == 0
                      ? Colors.white70
                      : (value > 0 ? positiveColor : negativeColor),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: value >= 0 ? positiveColor : negativeColor,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
            thumbColor: value == 0 ? Colors.white70 : 
                       (value > 0 ? positiveColor : negativeColor),
            overlayColor: (value >= 0 ? positiveColor : negativeColor).withValues(alpha: 0.2),
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).round(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  /// Build quick control button for frequently used settings
  Widget _buildQuickControl(IconData icon, String label, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            Text(
              value,
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build functional slider for camera settings with real provider integration
  Widget _buildFunctionalSlider(String label, double value, double min, double max, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${_formatSliderValue(label, value)}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.accent,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
            thumbColor: AppColors.accent,
            overlayColor: AppColors.accent.withValues(alpha: 0.2),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  /// Build compact slider for camera settings
  Widget _buildCompactSlider(String label, double value, double min, double max, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label${_formatSliderValue(label, value)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.accent,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
            thumbColor: AppColors.accent,
            overlayColor: AppColors.accent.withValues(alpha: 0.2),
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  /// Build action button for main controls
  Widget _buildActionButton(IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildAISuggestionOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: AppColors.accent,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'AI Analysis',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _showAISuggestionDialog = false;
                        });
                      },
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Show analysis status
                if (_currentSuggestions.isEmpty)
                  _buildAnalysisLoadingState()
                else
                  _buildSuggestionsList(),
                
                const SizedBox(height: 16),
                
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: () => _analyzeCurrentFrame(),
                      icon: const Icon(Icons.refresh, color: AppColors.accent),
                      label: const Text(
                        'Analyze Again',
                        style: TextStyle(color: AppColors.accent),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _showAISuggestionDialog = false;
                        });
                      },
                      icon: const Icon(Icons.close, color: Colors.white70),
                      label: const Text(
                        'Close',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildAnalysisLoadingState() {
    return Column(
      children: [
        const CircularProgressIndicator(
          color: AppColors.accent,
          strokeWidth: 3,
        ),
        const SizedBox(height: 16),
        Text(
          'Analyzing current view...',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'AI is examining your composition, lighting, and settings',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  Widget _buildSuggestionsList() {
    return Column(
      children: [
        // Header with analysis info
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Analysis complete • ${_currentSuggestions.length} suggestions',
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        
        // Suggestions list
        ...(_currentSuggestions.take(4).map((suggestion) => 
          _buildSuggestionCard(suggestion)
        )),
        
        if (_currentSuggestions.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Colors.orange,
                  size: 24,
                ),
                const SizedBox(height: 8),
                const Text(
                  'No specific suggestions',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your current setup looks good! Try changing your composition or lighting for more suggestions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _capturePhoto() async {
    try {
      final success = await _cameraProvider.capturePhoto();
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to capture photo'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Show a simple feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo captured successfully'),
          backgroundColor: AppColors.accent,
        ),
      );
      
      // Generate AI suggestions for the captured photo
      _generateAISuggestions();
      
    } catch (e) {
      debugPrint('Capture error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to capture photo'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _generateAISuggestions() async {
    try {
      final result = await _aiCoordinator.generateSuggestions(
        sceneAnalysis: SceneAnalysis(
          sceneType: 'general',
          lightingCondition: 'normal',
          subjectDistance: 'medium',
          movementDetected: false,
        ),
      );
      
      setState(() {
        _currentSuggestions = result.suggestions;
      });
    } catch (e) {
      debugPrint('AI suggestion error: $e');
    }
  }

  void _showAISuggestions() {
    setState(() {
      _showAISuggestionDialog = true;
    });
    _analyzeCurrentFrame();
  }
  
  /// Analyze current live view frame with AI
  Future<void> _analyzeCurrentFrame() async {
    try {
      // Get current frame from live view or capture a photo
      Uint8List? imageData = await _getCurrentFrameData();
      
      if (imageData != null) {
        // Show loading state
        setState(() {
          _currentSuggestions = []; // Clear previous suggestions
        });
        
        // Analyze image with AI
        final sceneAnalysis = await _aiCoordinator.analyzeImage(imageData);
        
        // Generate suggestions based on analysis
        final result = await _aiCoordinator.generateSuggestions(
          sceneAnalysis: sceneAnalysis,
          cameraModel: _cameraProvider.getActiveCameraInfo()['model'],
          currentSettings: _getCurrentCameraSettings(),
          userRequest: 'Analyze this live view and provide photography suggestions',
          imageBytes: imageData,
        );
        
        setState(() {
          _currentSuggestions = result.suggestions;
        });
        
        debugPrint('AI Analysis: Found ${result.suggestions.length} suggestions with confidence ${result.confidence}');
      } else {
        // No frame available, generate general suggestions
        await _generateAISuggestions();
      }
    } catch (e) {
      debugPrint('AI analysis error: $e');
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI analysis failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      // Fallback to general suggestions
      await _generateAISuggestions();
    }
  }
  
  /// Get current frame data from live view or capture
  Future<Uint8List?> _getCurrentFrameData() async {
    final provider = Provider.of<UnifiedCameraProvider>(context, listen: false);
    
    // If live view is active, get the current frame
    if (provider.isLiveViewActive && _lastValidFrame != null) {
      debugPrint('Using current live view frame for AI analysis (${_lastValidFrame!.length} bytes)');
      return _lastValidFrame;
    }
    
    // If builtin camera is active, capture a frame
    if (provider.activeCameraType == CameraSourceType.builtin && 
        provider.builtinController != null) {
      try {
        debugPrint('Capturing frame from builtin camera for AI analysis');
        final image = await provider.builtinController!.takePicture();
        final bytes = await File(image.path).readAsBytes();
        return bytes;
      } catch (e) {
        debugPrint('Failed to capture builtin camera frame: $e');
      }
    }
    
    // If external camera is active, try to capture
    if (provider.activeCameraType == CameraSourceType.external && 
        provider.activeExternalCamera != null) {
      // For now, we'll use the last valid frame if available
      // In a real implementation, you might trigger a photo capture
      if (_lastValidFrame != null) {
        debugPrint('Using last valid external camera frame for AI analysis');
        return _lastValidFrame;
      }
    }
    
    debugPrint('No frame data available for AI analysis');
    return null;
  }
  
  /// Get current camera settings for AI context
  Map<String, dynamic> _getCurrentCameraSettings() {
    return {
      'iso': Provider.of<CameraFeatureProvider>(context, listen: false).iso,
      'aperture': Provider.of<CameraFeatureProvider>(context, listen: false).aperture,
      'shutterSpeed': Provider.of<CameraFeatureProvider>(context, listen: false).shutterSpeed,
      'whiteBalance': _wbSettings.mode.name,
      'whiteBalanceKelvin': _getWBKelvin(),
      'flashEnabled': Provider.of<CameraFeatureProvider>(context, listen: false).isFlashEnabled,
      'zoomLevel': Provider.of<CameraFeatureProvider>(context, listen: false).zoomLevel,
    };
  }

  Widget _buildSuggestionCard(AISuggestion suggestion) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: AppColors.accent,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  suggestion.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            suggestion.message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
          if (suggestion.actionable) ...[
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _applySuggestion(suggestion),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                minimumSize: const Size(double.infinity, 32),
              ),
              child: const Text(
                'Apply',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _applySuggestion(AISuggestion suggestion) {
    // Apply the suggestion to camera settings
    if (suggestion.action != null) {
      final settings = suggestion.action!.settings;
      // Here you would apply the settings to the camera
      debugPrint('Applying suggestion: ${settings.toString()}');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Applied: ${suggestion.title}'),
          backgroundColor: AppColors.accent,
        ),
      );
    }
    
    setState(() {
      _showAISuggestionDialog = false;
    });
  }

  /// Build comprehensive camera control panel with all settings
  Widget _buildCameraControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // White Balance Control
          WhiteBalanceControl(
            initialSettings: _wbSettings,
            onChanged: (settings) {
              setState(() {
                _wbSettings = settings;
              });
            },
          ),
          const SizedBox(height: 16),
          
          // Camera Settings Row 1: ISO and Aperture
          Row(
            children: [
              Expanded(
                child: _buildSliderControl(
                  'ISO',
                  400.0, // Current value - would get from provider
                  100.0,
                  3200.0,
                  (value) {
                    // Update ISO
                    debugPrint('ISO: $value');
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSliderControl(
                  'f/',
                  2.8, // Current value - would get from provider
                  1.4,
                  16.0,
                  (value) {
                    // Update aperture
                    debugPrint('Aperture: f/$value');
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Camera Settings Row 2: Shutter Speed and Flash
          Row(
            children: [
              Expanded(
                child: _buildSliderControl(
                  'Shutter',
                  60.0, // Current value - would get from provider
                  1.0,
                  1000.0,
                  (value) {
                    // Update shutter speed
                    debugPrint('Shutter: 1/${value.round()}');
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Flash',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.flash_off,
                          color: Colors.white.withValues(alpha: 0.6),
                          size: 16,
                        ),
                        Expanded(
                          child: Switch(
                            value: false, // Would get from provider
                            onChanged: (value) {
                              debugPrint('Flash: $value');
                            },
                            activeColor: AppColors.accent,
                          ),
                        ),
                        Icon(
                          Icons.flash_on,
                          color: AppColors.accent,
                          size: 16,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build slider control widget
  Widget _buildSliderControl(String label, double value, double min, double max, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${_formatSliderValue(label, value)}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.accent,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
            thumbColor: AppColors.accent,
            overlayColor: AppColors.accent.withValues(alpha: 0.2),
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  /// Format slider values for display
  String _formatSliderValue(String label, double value) {
    switch (label) {
      case 'ISO':
        return value.round().toString();
      case 'f/':
        return value.toStringAsFixed(1);
      case 'Shutter':
        return '1/${value.round()}';
      default:
        return value.toStringAsFixed(1);
    }
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  Widget _buildCameraSelectorOverlay(UnifiedCameraProvider provider) {
    return Positioned(
      top: 80,
      left: 16,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Camera',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => provider.refreshExternalCameras(),
                    icon: const Icon(Icons.refresh, color: AppColors.accent),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24),
            
            // Built-in cameras
            if (provider.hasBuiltinCameras) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Built-in Cameras',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              ...provider.builtinCameras.map((camera) => ListTile(
                    leading: Icon(
                      camera.lensDirection == CameraLensDirection.front
                          ? Icons.camera_front
                          : Icons.camera_rear,
                      color: Colors.white,
                    ),
                    title: Text(
                      camera.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      camera.lensDirection.name,
                      style: const TextStyle(color: Colors.white54),
                    ),
                    trailing: provider.activeCameraType == CameraSourceType.builtin &&
                            provider.builtinController?.description.name == camera.name
                        ? const Icon(Icons.check_circle, color: AppColors.accent)
                        : null,
                    onTap: () => _switchToBuiltinCamera(camera),
                  )),
            ],
            
            // External cameras
            if (provider.hasExternalCameras) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'External Cameras',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              ...provider.externalCameras.map((camera) => ListTile(
                    leading: Icon(
                      _getCameraIcon(camera.brand),
                      color: camera.isConnected ? AppColors.accent : Colors.white54,
                    ),
                    title: Text(
                      camera.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${camera.brand.name.toUpperCase()} • ${camera.connectionType.name.toUpperCase()}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        if (camera.ipAddress != null)
                          Text(
                            camera.ipAddress!,
                            style: const TextStyle(color: Colors.white38, fontSize: 10),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: camera.isConnected ? Colors.green : Colors.orange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            camera.isConnected ? 'Connected' : 'Available',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (provider.activeExternalCamera?.id == camera.id)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.check_circle, color: AppColors.accent),
                          ),
                      ],
                    ),
                    onTap: () => _switchToExternalCamera(camera),
                  )),
            ],
            
            // No cameras found
            if (!provider.hasAnyCameras)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No cameras detected. Make sure external cameras are connected and powered on.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}