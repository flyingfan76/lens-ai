import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:camera/camera.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/disposal_mixin.dart';
import '../widgets/white_balance_control.dart';
import '../widgets/preset_carousel.dart';
import '../widgets/preset_creation_dialog.dart';
import '../services/ai/ai_coordinator.dart';
import '../services/preset_service.dart';
import '../models/ai_suggestion.dart';
import '../models/camera_preset.dart' as camera_preset;
import 'settings_screen.dart';
import 'preset_management_screen.dart';
import 'dart:async';

/// Simplified Camera Screen that works with current architecture
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with DisposalMixin {
  late WhiteBalanceSettings _wbSettings;
  List<CameraDescription> _availableCameras = [];
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _isLoading = true;
  
  // AI suggestion state
  final AICoordinator _aiCoordinator = AICoordinator();
  List<AISuggestion> _currentSuggestions = [];
  bool _showAISuggestionDialog = false;

  // Preset state
  camera_preset.CameraPreset? _currentPreset;
  bool _showPresetCarousel = false;
  camera_preset.CameraSettings _currentCameraSettings = const camera_preset.CameraSettings();
  
  // UI state
  bool _showAdvancedControls = false;

  @override
  void initState() {
    super.initState();
    _wbSettings = WhiteBalanceSettings();
    _initializeCamera();
    _initializeAI();
    _initializePresets();
  }

  Future<void> _initializeCamera() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isNotEmpty) {
        _cameraController = CameraController(
          _availableCameras.first,
          ResolutionPreset.high,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _isLoading = false;
          });
        }
      } else {
        debugPrint('No cameras available');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      // Check if this is a platform support issue
      if (e.toString().contains('MissingPluginException')) {
        if (defaultTargetPlatform == TargetPlatform.macOS) {
          debugPrint('Camera plugin not supported on macOS platform');
        } else if (defaultTargetPlatform == TargetPlatform.iOS && kDebugMode) {
          debugPrint('Camera not available in iOS Simulator - use physical device for testing');
        }
      } else if (defaultTargetPlatform == TargetPlatform.iOS && _availableCameras.isEmpty) {
        debugPrint('No cameras detected on iOS - likely running in simulator');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
      return 'Camera access is not yet supported on macOS desktop.\nPlease test on iOS or Android devices for full camera functionality.';
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

  // Preset-related methods
  Future<void> _initializePresets() async {
    try {
      await PresetService.instance.initialize();
      
      // Load last used preset
      final lastUsedPreset = PresetService.instance.lastUsedPreset;
      if (lastUsedPreset != null && mounted) {
        setState(() {
          _currentPreset = lastUsedPreset;
          _currentCameraSettings = lastUsedPreset.settings;
        });
      }
    } catch (e) {
      debugPrint('Error initializing presets: $e');
    }
  }

  Future<void> _applyPreset(camera_preset.CameraPreset preset) async {
    try {
      // Apply the preset through the service (updates usage count)
      final appliedPreset = await PresetService.instance.applyPreset(preset.id);
      
      if (mounted) {
        setState(() {
          _currentPreset = appliedPreset;
          _currentCameraSettings = appliedPreset.settings;
          _showPresetCarousel = false;
        });
      }

      // Apply settings to camera controller if available
      if (_isInitialized && _cameraController != null) {
        await _applyCameraSettings(appliedPreset.settings);
      }

      // Provide haptic feedback
      if (mounted) {
        // Show confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Applied preset: ${preset.name}'),
            backgroundColor: AppColors.accent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error applying preset: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply preset: ${preset.name}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _applyCameraSettings(camera_preset.CameraSettings settings) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      // Apply exposure settings (Note: Camera plugin has limited exposure control)
      if (settings.exposureCompensation != null) {
        final minExposure = await _cameraController!.getMinExposureOffset();
        final maxExposure = await _cameraController!.getMaxExposureOffset();
        final clampedExposure = settings.exposureCompensation!
            .clamp(minExposure, maxExposure);
        await _cameraController!.setExposureOffset(clampedExposure);
      }

      // Apply flash mode
      await _cameraController!.setFlashMode(_convertFlashMode(settings.flashMode));

      // Apply focus mode if supported
      // Note: Camera plugin has limited focus control on mobile devices
      
      debugPrint('Applied camera settings: ISO ${settings.iso}, f/${settings.aperture}');
    } catch (e) {
      debugPrint('Error applying camera settings: $e');
    }
  }

  FlashMode _convertFlashMode(camera_preset.FlashMode presetFlashMode) {
    switch (presetFlashMode) {
      case camera_preset.FlashMode.off:
        return FlashMode.off;
      case camera_preset.FlashMode.auto:
        return FlashMode.auto;
      case camera_preset.FlashMode.always:
        return FlashMode.always;
      case camera_preset.FlashMode.torch:
        return FlashMode.torch;
    }
  }

  void _togglePresetCarousel() {
    setState(() {
      _showPresetCarousel = !_showPresetCarousel;
    });
  }

  Future<void> _showCreatePresetDialog() async {
    final result = await showDialog<camera_preset.CameraPreset>(
      context: context,
      builder: (context) => PresetCreationDialog(
        currentSettings: _currentCameraSettings,
      ),
    );

    if (result != null) {
      // Apply the newly created preset
      await _applyPreset(result);
    }
  }

  void _showPresetManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PresetManagementScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              )
            : _buildCameraInterface(),
      ),
    );
  }

  Widget _buildCameraInterface() {
    if (!_isInitialized || _cameraController == null) {
      return _buildCameraErrorState();
    }

    return Stack(
      children: [
        // Camera preview
        Positioned.fill(
          child: CameraPreview(_cameraController!),
        ),
        
        // Top controls
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: _buildTopControls(),
        ),
        
        // Preset carousel (when camera unavailable, show presets anyway)
        Positioned(
          bottom: 140,
          left: 0,
          right: 0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _showPresetCarousel ? 120 : 0,
            child: _showPresetCarousel
                ? PresetCarousel(
                    selectedPresetId: _currentPreset?.id,
                    onPresetSelected: _applyPreset,
                    onNewPresetTap: _showCreatePresetDialog,
                  )
                : const SizedBox.shrink(),
          ),
        ),
        
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
  }

  // Also show presets in error state for testing
  Widget _buildCameraErrorState() {
    return Stack(
      children: [
        // Error message
        Center(
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
                'Camera Not Available',
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
              const Text(
                'You can still test presets and AI features:',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        
        // Top controls
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: _buildTopControls(),
        ),
        
        // Preset carousel for testing
        Positioned(
          bottom: 140,
          left: 0,
          right: 0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _showPresetCarousel ? 120 : 0,
            child: _showPresetCarousel
                ? PresetCarousel(
                    selectedPresetId: _currentPreset?.id,
                    onPresetSelected: _applyPreset,
                    onNewPresetTap: _showCreatePresetDialog,
                  )
                : const SizedBox.shrink(),
          ),
        ),
        
        // Bottom controls
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: _buildBottomControls(),
        ),
      ],
    );
  }

  Widget _buildTopControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        // Current preset indicator
        if (_currentPreset != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.camera_alt,
                  size: 16,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 6),
                Text(
                  _currentPreset!.name,
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            IconButton(
              onPressed: _togglePresetCarousel,
              icon: Icon(
                Icons.tune,
                color: _showPresetCarousel ? AppColors.accent : Colors.white,
              ),
            ),
            IconButton(
              onPressed: _showPresetManagement,
              icon: const Icon(Icons.dashboard, color: Colors.white),
            ),
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
        // Advanced controls (only show when enabled)
        if (_showAdvancedControls) ...[
          WhiteBalanceControl(
            initialSettings: _wbSettings,
            onChanged: (settings) {
              setState(() {
                _wbSettings = settings;
              });
            },
          ),
          const SizedBox(height: 16),
        ],
        
        // Main controls row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Advanced controls toggle
            IconButton(
              onPressed: () {
                setState(() {
                  _showAdvancedControls = !_showAdvancedControls;
                });
              },
              icon: Icon(
                _showAdvancedControls ? Icons.expand_less : Icons.expand_more,
                color: Colors.white,
                size: 30,
              ),
            ),
            
            // Capture button
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
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ),
              icon: const Icon(
                Icons.settings,
                color: Colors.white,
                size: 30,
              ),
            ),
          ],
        ),
      ],
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
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'AI Suggestions',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
                if (_currentSuggestions.isNotEmpty)
                  ...(_currentSuggestions.take(3).map((suggestion) => 
                    _buildSuggestionCard(suggestion)
                  ))
                else
                  Text(
                    'No AI suggestions available at the moment.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final XFile photo = await _cameraController!.takePicture();
      
      // Show a simple feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Photo captured: ${photo.path}'),
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
    _generateAISuggestions();
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

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }
}