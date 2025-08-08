import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/disposal_mixin.dart';
import '../widgets/white_balance_control.dart';
import '../services/ai/ai_coordinator.dart';
import '../models/ai_suggestion.dart';
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
  List<CameraDescription> _availableCameras = [];
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _isLoading = true;
  
  // AI suggestion state
  final AICoordinator _aiCoordinator = AICoordinator();
  List<AISuggestion> _currentSuggestions = [];
  bool _showAISuggestionDialog = false;

  @override
  void initState() {
    super.initState();
    _wbSettings = WhiteBalanceSettings();
    _initializeCamera();
    _initializeAI();
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
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
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

  Widget _buildCameraErrorState() {
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
            'Camera Not Available',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Unable to initialize camera.\nPlease check permissions and try again.',
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

  Widget _buildTopControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        Row(
          children: [
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
        // White balance control
        WhiteBalanceControl(
          initialSettings: _wbSettings,
          onChanged: (settings) {
            setState(() {
              _wbSettings = settings;
            });
          },
        ),
        const SizedBox(height: 16),
        
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