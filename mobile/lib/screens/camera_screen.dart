import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/disposal_mixin.dart';
import '../widgets/white_balance_control.dart';
import '../services/ai/ai_coordinator.dart';
import '../services/ai/cloud_ai_service.dart';
import '../models/ai_suggestion.dart';
import '../models/ai_provider_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/external_camera.dart';
import '../core/state/camera_feature_provider.dart';
import '../core/providers/unified_camera_provider.dart';
import 'settings_screen.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../services/camera_settings_application_service.dart';

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
  late AICoordinator _aiCoordinator;
  List<AISuggestion> _currentSuggestions = [];
  Set<String> _selectedSuggestionIds = {}; // Track selected suggestions for bulk apply
  bool _showAISuggestionDialog = false;
  bool _isAIAnalyzing = false;
  bool _hasPendingSuggestions = false;
  DateTime? _lastAnalysisTime;

  // Camera settings application service
  final CameraSettingsApplicationService _settingsService = CameraSettingsApplicationService();

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
      debugPrint('🔧 Loading AI configuration from settings...');
      
      // Initialize with default configuration first
      _aiCoordinator = AICoordinator();
      
      // Load AI configuration from settings
      final aiConfig = await _loadAIConfigurationFromSettings();
      
      if (aiConfig != null) {
        // Configure AI coordinator based on user settings
        final coordinatorConfig = _buildCoordinatorConfiguration(aiConfig);
        
        debugPrint('🔧 Configuring AI Coordinator with provider: ${aiConfig.selectedProviderId}');
        
        // Force re-initialization to pick up new configuration
        debugPrint('🔄 Force re-initializing AI Coordinator...');
        AICoordinator.resetSingleton();
        _aiCoordinator = AICoordinator(configuration: coordinatorConfig);
        await _aiCoordinator.initialize();
        debugPrint('✅ AI Coordinator re-initialized with new settings');
      } else {
        debugPrint('⚠️ No AI configuration found, using local AI only');
        // Fallback to local-only configuration
        final coordinatorConfig = AICoordinatorConfiguration(
          enableCloudAI: false,
          selectionStrategy: ServiceSelectionStrategy.localOnly,
          allowFallbackToLocal: true,
        );
        
        _aiCoordinator.updateConfiguration(coordinatorConfig);
        await _aiCoordinator.initialize();
      }
    } catch (e) {
      debugPrint('❌ AI initialization error: $e');
      // Final fallback to local AI
      try {
        final coordinatorConfig = AICoordinatorConfiguration(
          enableCloudAI: false,
          selectionStrategy: ServiceSelectionStrategy.localOnly,
          allowFallbackToLocal: true,
        );
        _aiCoordinator.updateConfiguration(coordinatorConfig);
        await _aiCoordinator.initialize();
        debugPrint('✅ AI Coordinator initialized with local AI fallback');
      } catch (fallbackError) {
        debugPrint('❌ Even local AI initialization failed: $fallbackError');
      }
    }
  }

  /// Load AI configuration from SharedPreferences
  Future<AIConfiguration?> _loadAIConfigurationFromSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString('ai_configuration');
      
      if (configJson != null) {
        final configData = jsonDecode(configJson);
        final config = AIConfiguration.fromJson(configData);
        
        // Load API keys from SharedPreferences
        final updatedProviders = <AIProviderConfig>[];
        for (final provider in config.providers) {
          final savedKey = prefs.getString('ai_api_key_${provider.id}');
          if (savedKey != null && savedKey.isNotEmpty) {
            final updatedProvider = provider.copyWith(apiKey: savedKey);
            updatedProviders.add(updatedProvider);
          } else {
            updatedProviders.add(provider);
          }
        }
        
        return config.copyWith(providers: updatedProviders);
      }
    } catch (e) {
      debugPrint('❌ Failed to load AI configuration: $e');
    }
    return null;
  }
  
  /// Build AI coordinator configuration from user settings
  AICoordinatorConfiguration _buildCoordinatorConfiguration(AIConfiguration aiConfig) {
    // Find the selected provider
    final selectedProvider = aiConfig.providers.firstWhere(
      (p) => p.id == aiConfig.selectedProviderId,
      orElse: () => aiConfig.providers.first,
    );
    
    debugPrint('🎯 Selected AI provider: ${selectedProvider.name} (${selectedProvider.id})');
    
    // Debug provider details
    debugPrint('🔍 Provider details:');
    debugPrint('  - ID: ${selectedProvider.id}');
    debugPrint('  - Endpoint: ${selectedProvider.endpoint}');
    debugPrint('  - Has API key: ${selectedProvider.apiKey?.isNotEmpty ?? false}');
    debugPrint('  - API key length: ${selectedProvider.apiKey?.length ?? 0}');
    
    // Check if custom endpoint is configured and should be prioritized
    if (selectedProvider.id == 'custom' && 
        selectedProvider.endpoint != null && 
        selectedProvider.endpoint!.isNotEmpty) {
      
      // For testing purposes, provide a dummy key if missing
      String apiKey = selectedProvider.apiKey ?? '';
      if (apiKey.isEmpty) {
        debugPrint('⚠️ No API key found, using test key for cloud AI testing');
        apiKey = 'test-key-for-cloud-ai-testing';  // This will be used for testing only
      }
      
      debugPrint('✨ Using custom endpoint: ${selectedProvider.endpoint}');
      
      // Configure cloud AI with custom endpoint
      final cloudConfig = CloudAIConfiguration(
        provider: CloudAIProvider.custom,
        apiKey: apiKey,  // Use the test key if needed
        modelId: selectedProvider.selectedModel ?? 'gpt-4-vision-preview',
        customEndpoint: selectedProvider.endpoint!,
        customPrompt: aiConfig.customPromptTemplate,
      );
      
      debugPrint('🚀 Creating AICoordinator config with:');
      debugPrint('  - enableCloudAI: true');
      debugPrint('  - selectionStrategy: cloudFirst');
      debugPrint('  - cloudConfig endpoint: ${cloudConfig.customEndpoint}');
      debugPrint('  - cloudConfig apiKey length: ${cloudConfig.apiKey.length}');
      
      return AICoordinatorConfiguration(
        enableCloudAI: true,
        cloudConfiguration: cloudConfig,
        selectionStrategy: ServiceSelectionStrategy.cloudFirst, // Prioritize custom endpoint
        allowFallbackToLocal: true,
      );
    }
    
    // Handle other cloud providers (OpenAI, Anthropic, etc.)
    if (selectedProvider.isEnabled && 
        selectedProvider.apiKey != null && 
        selectedProvider.apiKey!.isNotEmpty) {
      
      CloudAIProvider cloudProvider;
      switch (selectedProvider.type) {
        case AIProviderType.openai:
          cloudProvider = CloudAIProvider.openai;
          break;
        case AIProviderType.anthropic:
          cloudProvider = CloudAIProvider.claude;
          break;
        case AIProviderType.google:
          cloudProvider = CloudAIProvider.gemini;
          break;
        case AIProviderType.custom:
        default:
          cloudProvider = CloudAIProvider.custom;
      }
      
      final cloudConfig = CloudAIConfiguration(
        provider: cloudProvider,
        apiKey: selectedProvider.apiKey!,
        modelId: selectedProvider.selectedModel ?? selectedProvider.availableModels.first,
        customEndpoint: selectedProvider.endpoint,
        customPrompt: aiConfig.customPromptTemplate,
      );
      
      return AICoordinatorConfiguration(
        enableCloudAI: true,
        cloudConfiguration: cloudConfig,
        selectionStrategy: ServiceSelectionStrategy.cloudFirst,
        allowFallbackToLocal: true,
      );
    }
    
    // Fallback to local AI if no valid cloud provider is configured
    debugPrint('⚠️ No valid cloud provider configured, falling back to local AI');
    return AICoordinatorConfiguration(
      enableCloudAI: false,
      selectionStrategy: ServiceSelectionStrategy.localOnly,
      allowFallbackToLocal: true,
    );
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
        debugPrint('🔥 CameraScreen: isLoading=${provider.isLoading}, hasAnyCameras=${provider.hasAnyCameras}, error=${provider.error}');
        debugPrint('🔥 CameraScreen: builtinCameras=${provider.builtinCameras.length}, externalCameras=${provider.externalCameras.length}');
        debugPrint('🔥 CameraScreen: External cameras: ${provider.externalCameras.map((c) => '${c.name} (connected: ${c.isConnected})').join(', ')}');
        if (provider.error != null) {
          debugPrint('🚨 ERROR SOURCE DETECTED: ${provider.error}');
        }
        
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          );
        }

        if (provider.error != null) {
          return _buildErrorState(provider.error!);
        }

        // TEMPORARY: Always show camera interface for AI testing, even without cameras
        // if (!provider.hasAnyCameras) {
        //   return _buildNoCamerasState();
        // }

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
      return Container(color: Colors.black);
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
              stream: liveViewStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint('📺 StreamBuilder ERROR: ${snapshot.error}');
                  return Container(
                    color: Colors.red.withOpacity(0.3),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, color: Colors.white, size: 48),
                          SizedBox(height: 8),
                          Text('Stream Error', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  );
                }
                
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  debugPrint('📺 StreamBuilder: Waiting for data... hasData=${snapshot.hasData}, connectionState=${snapshot.connectionState}');
                  return Container(
                    color: Colors.black,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 16),
                          Text(
                            snapshot.connectionState == ConnectionState.waiting 
                                ? 'Connecting to live view...'
                                : 'Starting live view...',
                            style: const TextStyle(color: Colors.white)
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Connection: ${snapshot.connectionState.toString()}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                final frameData = snapshot.data!;
                debugPrint('📺 StreamBuilder: Received frame ${frameData.length} bytes');
                
                if (_isValidJpegFrame(frameData)) {
                  _lastValidFrame = frameData;
                  return _buildOptimizedLiveViewDisplay(frameData, camera);
                } else {
                  debugPrint('📺 StreamBuilder: Invalid JPEG frame, showing loading...');
                  return Container(
                    color: Colors.black87,
                    child: const Center(
                      child: Text('Processing frame...', style: TextStyle(color: Colors.white70)),
                    ),
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
    if (data.length <= 10) {
      debugPrint('⚠️ JPEG Validation: Frame too short (${data.length} bytes)');
      return false;
    }
    
    // Check JPEG start marker (FF D8)
    bool hasValidStart = data[0] == 0xFF && data[1] == 0xD8;
    
    if (!hasValidStart) {
      debugPrint('⚠️ JPEG Validation: Missing JPEG start marker. First bytes: [${data[0]}, ${data[1]}]');
      return false;
    }
    
    // For live view frames, we'll be more lenient about the end marker
    // as some cameras send streaming JPEG data that might be truncated
    // Basic validation: must be reasonable size and have JPEG start
    if (data.length > 1000) { // Reasonable minimum size for a JPEG frame
      debugPrint('✅ JPEG Validation: Valid JPEG frame (${data.length} bytes)');
      return true;
    } else {
      debugPrint('⚠️ JPEG Validation: Frame too small for valid JPEG (${data.length} bytes)');
      return false;
    }
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
                fit: BoxFit.contain,  // Changed from cover to contain for better display
                gaplessPlayback: true,  // Smooth frame transitions
                filterQuality: FilterQuality.low,  // Better performance
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('❌ Image.memory DECODE ERROR: $error');
                  debugPrint('❌ Stack trace: $stackTrace');
                  debugPrint('❌ Frame info: ${imageData.length} bytes, starts with [${imageData[0]}, ${imageData[1]}]');
                  
                  // Show more detailed error info
                  if (kDebugMode) {
                    debugPrint('❌ Full error: $error');
                    debugPrint('❌ Problematic frame data (first 50 bytes): ${imageData.take(50).toList()}');
                    debugPrint('❌ Last 10 bytes: ${imageData.skip(imageData.length - 10).toList()}');
                  }
                  
                  return Container(
                    color: Colors.orange.withOpacity(0.3),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.warning_amber_outlined, color: Colors.white, size: 48),
                          const SizedBox(height: 8),
                          const Text(
                            'Frame Decode Error',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Error: ${error.toString().length > 50 ? '${error.toString().substring(0, 50)}...' : error.toString()}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70, fontSize: 10),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${imageData.length} bytes received',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
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
          // AI Analysis button with loading and badge
          Stack(
            children: [
              FloatingActionButton.small(
                onPressed: (_isAIAnalyzing || !_isAISuggestionsEnabled()) ? null : () => _showAISuggestions(),
                backgroundColor: (_isAIAnalyzing || !_isAISuggestionsEnabled())
                    ? AppColors.accent.withOpacity(0.6)
                    : AppColors.accent,
                heroTag: "ai_analysis",
                child: _isAIAnalyzing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        Icons.auto_awesome, 
                        color: _isAISuggestionsEnabled() ? Colors.white : Colors.grey,
                      ),
              ),
              // Suggestion badge
              if (_hasPendingSuggestions || (_currentSuggestions.isNotEmpty && !_showAISuggestionDialog))
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '${_currentSuggestions.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
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
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (camera.isConnected) ...[
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  final result = await provider.startLiveView();
                  debugPrint('🔥 startLiveView() returned: $result');
                  
                  if (!result && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Camera not found via AVFoundation.\n'
                          'Make sure your Nikon D90 is connected and recognized by macOS.',
                        ),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 6),
                      ),
                    );
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Live view started with AVFoundation!'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('🚨 Live view error: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Live view failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.videocam),
              label: const Text('Start Live View'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
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
            // AI button with loading state and disabled state
            Stack(
              children: [
                IconButton(
                  onPressed: (_isAIAnalyzing || !_isAISuggestionsEnabled()) ? null : _showAISuggestions,
                  icon: _isAIAnalyzing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                          ),
                        )
                      : Icon(
                          Icons.auto_awesome, 
                          color: _isAISuggestionsEnabled() ? AppColors.accent : Colors.grey,
                        ),
                ),
                // Suggestion badge
                if (_hasPendingSuggestions || (_currentSuggestions.isNotEmpty && !_showAISuggestionDialog))
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${_currentSuggestions.length > 9 ? '9+' : _currentSuggestions.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
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

  /// Build action button for main controls

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
                
                // Show analysis status with improved loading states
                if (_isAIAnalyzing)
                  _buildAnalysisLoadingState()
                else if (_currentSuggestions.isEmpty)
                  _buildNoSuggestionsState()
                else
                  _buildSuggestionsList(),
                
                const SizedBox(height: 16),
                
                // Bulk apply button
                if (_selectedSuggestionIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ElevatedButton.icon(
                      onPressed: _isAIAnalyzing ? null : () => _applySelectedSuggestions(),
                      icon: _isAIAnalyzing 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.check_circle, color: Colors.white),
                      label: Text(
                        _isAIAnalyzing 
                          ? 'Applying Settings...'
                          : 'Apply Selected (${_selectedSuggestionIds.length})',
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isAIAnalyzing 
                          ? AppColors.accent.withOpacity(0.7)
                          : AppColors.accent,
                        minimumSize: const Size(double.infinity, 40),
                      ),
                    ),
                  ),
                
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: _isAIAnalyzing ? null : () => _analyzeAgain(),
                      icon: _isAIAnalyzing 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                            ),
                          )
                        : const Icon(Icons.refresh, color: AppColors.accent),
                      label: Text(
                        _isAIAnalyzing ? 'Analyzing...' : 'Analyze Again',
                        style: TextStyle(
                          color: _isAIAnalyzing ? Colors.grey : AppColors.accent,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _showAISuggestionDialog = false;
                          _selectedSuggestionIds.clear(); // Clear selections when closing
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
    final analysisTime = _lastAnalysisTime != null 
        ? DateTime.now().difference(_lastAnalysisTime!).inSeconds
        : 0;
    
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
        if (analysisTime > 3)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'This may take a few more seconds...',
              style: TextStyle(
                color: Colors.orange.withValues(alpha: 0.8),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildNoSuggestionsState() {
    return Column(
      children: [
        Icon(
          Icons.lightbulb_outline,
          color: Colors.white.withValues(alpha: 0.5),
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          'No suggestions available',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Try analyzing the current view to get AI recommendations',
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
        
        // Categorized suggestions with scrolling
        _buildCategorizedSuggestions(),
        
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
      // Get current live view frame for real image analysis
      final frameData = _getCurrentLiveViewFrame();
      
      if (frameData != null) {
        debugPrint('🎯 Generating AI suggestions from live view frame (${frameData.length} bytes)');
        
        // First analyze the image to get scene analysis
        final sceneAnalysis = await _aiCoordinator.analyzeImage(frameData);
        debugPrint('📊 Scene analysis: ${sceneAnalysis.sceneType}, brightness: ${sceneAnalysis.brightness}, colors: ${sceneAnalysis.dominantColors}');
        
        // Then generate suggestions using both scene analysis and image data
        final result = await _aiCoordinator.generateSuggestions(
          sceneAnalysis: sceneAnalysis,
          imageBytes: frameData,
          cameraModel: _cameraProvider.activeExternalCamera?.name ?? 'Unknown Camera',
        );
        
        debugPrint('✅ AI Analysis complete: ${result.suggestions.length} suggestions (confidence: ${result.confidence})');
        
        setState(() {
          _currentSuggestions = result.suggestions;
        });
      } else {
        // Fallback to basic scene analysis if no frame available
        debugPrint('⚠️ No live view frame available, using basic scene analysis');
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
      }
    } catch (e) {
      debugPrint('❌ AI suggestion error: $e');
    }
  }

  /// Check if AI suggestions should be enabled
  bool _isAISuggestionsEnabled() {
    final provider = Provider.of<UnifiedCameraProvider>(context, listen: false);
    
    // Enable if we have a live view frame available
    if (provider.isLiveViewActive && _lastValidFrame != null) {
      return true;
    }
    
    // Enable if we have any camera active (builtin or external connected)
    if (provider.activeCameraType == CameraSourceType.builtin && 
        provider.builtinController != null) {
      return true;
    }
    
    if (provider.activeCameraType == CameraSourceType.external && 
        provider.activeExternalCamera != null && 
        provider.activeExternalCamera!.isConnected) {
      return true;
    }
    
    return false;
  }

  /// Show AI suggestion dialog (non-blocking)
  void _showAISuggestions() {
    // Check if AI suggestions should be enabled
    if (!_isAISuggestionsEnabled()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI suggestions require an active camera connection'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    if (_hasPendingSuggestions || _currentSuggestions.isNotEmpty) {
      // Show existing suggestions immediately
      setState(() {
        _showAISuggestionDialog = true;
        _hasPendingSuggestions = false;
      });
    } else {
      // Start new analysis in background
      _startBackgroundAIAnalysis();
      setState(() {
        _showAISuggestionDialog = true;
      });
    }
  }
  
  /// Start AI analysis in background (non-blocking)
  Future<void> _startBackgroundAIAnalysis() async {
    if (_isAIAnalyzing) {
      debugPrint('AI analysis already in progress, skipping');
      return;
    }

    // Check if AI suggestions are enabled
    if (!_isAISuggestionsEnabled()) {
      debugPrint('AI suggestions are disabled - no valid image source available');
      setState(() {
        _isAIAnalyzing = false;
        _currentSuggestions = [];
      });
      return;
    }

    // Get current frame immediately (fast, non-blocking)
    final frameData = _getCurrentLiveViewFrame();
    
    if (frameData == null) {
      debugPrint('No live view frame available, using fallback capture');
      await _fallbackAIAnalysis();
      return;
    }

    // Set analyzing state immediately
    setState(() {
      _isAIAnalyzing = true;
      _lastAnalysisTime = DateTime.now();
    });

    debugPrint('🤖 Starting background AI analysis with ${frameData.length} byte frame');
    
    // Process AI in background (slow, but non-blocking)
    _processAIInBackground(frameData);
  }

  /// Get current live view frame immediately (non-blocking)
  Uint8List? _getCurrentLiveViewFrame() {
    // Use existing live view frame buffer - instant access
    if (_lastValidFrame != null && _lastValidFrame!.isNotEmpty) {
      debugPrint('✅ Using current live view frame (${_lastValidFrame!.length} bytes)');
      return _lastValidFrame;
    }
    
    // No live view frame available
    debugPrint('⚠️ No live view frame available for AI analysis');
    return null;
  }


  /// Process AI analysis in background
  Future<void> _processAIInBackground(Uint8List frameData) async {
    try {
      debugPrint('🔄 Processing AI analysis in background...');
      
      // Phase 1: Quick local analysis (1-2 seconds)
      final sceneAnalysis = await _aiCoordinator.analyzeImage(frameData);
      debugPrint('✅ Scene analysis complete');
      
      // Phase 2: Generate suggestions (3-10 seconds)
      final result = await _aiCoordinator.generateSuggestions(
        sceneAnalysis: sceneAnalysis,
        cameraModel: _cameraProvider.getActiveCameraInfo()['model'],
        currentSettings: _getCurrentCameraSettings(),
        userRequest: 'Analyze this live view and provide photography suggestions',
        imageBytes: frameData,
      );
      
      // Update UI when complete
      if (mounted) {
        setState(() {
          _currentSuggestions = result.suggestions;
          _isAIAnalyzing = false;
          _hasPendingSuggestions = !_showAISuggestionDialog;
        });
        
        debugPrint('🎉 AI Analysis complete: ${result.suggestions.length} suggestions (confidence: ${result.confidence})');
        
        // Show notification if panel is not visible
        if (!_showAISuggestionDialog && result.suggestions.isNotEmpty) {
          _showSuggestionAvailableNotification(result.suggestions.length);
        }
      }
    } catch (e) {
      debugPrint('❌ Background AI analysis failed: $e');
      
      if (mounted) {
        setState(() {
          _isAIAnalyzing = false;
        });
        
        // Show error only if dialog is open
        if (_showAISuggestionDialog) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('AI analysis failed: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        
        // Try fallback analysis
        await _fallbackAIAnalysis();
      }
    }
  }

  /// Fallback AI analysis when no live view frame available
  Future<void> _fallbackAIAnalysis() async {
    try {
      final imageData = await _getCurrentFrameData();
      if (imageData != null) {
        await _processAIInBackground(imageData);
      } else {
        // No image available - disable AI suggestions
        debugPrint('⚠️ No image data available for AI analysis');
        setState(() {
          _isAIAnalyzing = false;
          _currentSuggestions = [];
        });
      }
    } catch (e) {
      debugPrint('Fallback AI analysis failed: $e');
      if (mounted) {
        setState(() {
          _isAIAnalyzing = false;
        });
      }
    }
  }

  /// Show notification when suggestions are ready
  void _showSuggestionAvailableNotification(int count) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('$count AI suggestions ready'),
          ],
        ),
        backgroundColor: AppColors.accent,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              _showAISuggestionDialog = true;
              _hasPendingSuggestions = false;
            });
          },
        ),
      ),
    );
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

  /// Build categorized suggestions with proper scrolling
  Widget _buildCategorizedSuggestions() {
    if (_currentSuggestions.isEmpty) return Container();
    
    // Categorize suggestions
    final cameraSettings = <AISuggestion>[];
    final composition = <AISuggestion>[];
    final technical = <AISuggestion>[];
    final creative = <AISuggestion>[];
    
    for (final suggestion in _currentSuggestions) {
      switch (suggestion.type) {
        case AISuggestionType.cameraSettings:
          cameraSettings.add(suggestion);
          break;
        case AISuggestionType.composition:
          composition.add(suggestion);
          break;
        case AISuggestionType.technique:
          technical.add(suggestion);
          break;
        case AISuggestionType.creative:
          creative.add(suggestion);
          break;
        case AISuggestionType.timing:
          technical.add(suggestion); // Timing suggestions go to technical
          break;
      }
    }
    
    return Container(
      height: 300, // Fixed height to ensure scrolling
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Camera Parameters Section
            if (cameraSettings.isNotEmpty) ...[
              _buildCategoryHeader('📷 Camera Parameters', cameraSettings.length),
              ...cameraSettings.map((s) => _buildSuggestionCard(s, showCameraIcon: true)),
              const SizedBox(height: 16),
            ],
            
            // Composition Section  
            if (composition.isNotEmpty) ...[
              _buildCategoryHeader('🎨 Composition & Framing', composition.length),
              ...composition.map((s) => _buildSuggestionCard(s, showCompositionIcon: true)),
              const SizedBox(height: 16),
            ],
            
            // Technical Section
            if (technical.isNotEmpty) ...[
              _buildCategoryHeader('⚙️ Technical Settings', technical.length),
              ...technical.map((s) => _buildSuggestionCard(s, showTechnicalIcon: true)),
              const SizedBox(height: 16),
            ],
            
            // Creative Section
            if (creative.isNotEmpty) ...[
              _buildCategoryHeader('💡 Creative Ideas', creative.length),
              ...creative.map((s) => _buildSuggestionCard(s, showCreativeIcon: true)),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
  
  /// Build category header with count
  Widget _buildCategoryHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(AISuggestion suggestion, {
    bool showCameraIcon = false,
    bool showCompositionIcon = false, 
    bool showTechnicalIcon = false,
    bool showCreativeIcon = false,
  }) {
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
                _getSuggestionIcon(showCameraIcon, showCompositionIcon, showTechnicalIcon, showCreativeIcon),
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
            Row(
              children: [
                Checkbox(
                  value: _selectedSuggestionIds.contains(suggestion.id),
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedSuggestionIds.add(suggestion.id);
                      } else {
                        _selectedSuggestionIds.remove(suggestion.id);
                      }
                    });
                  },
                  activeColor: AppColors.accent,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Select to apply this suggestion',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Get appropriate icon for suggestion category
  IconData _getSuggestionIcon(bool showCameraIcon, bool showCompositionIcon, bool showTechnicalIcon, bool showCreativeIcon) {
    if (showCameraIcon) return Icons.camera_alt;
    if (showCompositionIcon) return Icons.crop_free;
    if (showTechnicalIcon) return Icons.settings;
    if (showCreativeIcon) return Icons.lightbulb_outline;
    return Icons.info_outline; // Default fallback
  }


  /// Apply all selected suggestions in bulk
  Future<void> _applySelectedSuggestions() async {
    final selectedSuggestions = _currentSuggestions
        .where((suggestion) => _selectedSuggestionIds.contains(suggestion.id))
        .toList();
    
    if (selectedSuggestions.isEmpty) return;

    // Show loading state
    setState(() {
      _isAIAnalyzing = true; // Reuse loading state
    });

    try {
      debugPrint('🎯 Applying ${selectedSuggestions.length} AI suggestions to camera');
      
      final cameraProvider = Provider.of<UnifiedCameraProvider>(context, listen: false);
      final featureProvider = Provider.of<CameraFeatureProvider>(context, listen: false);

      // Apply suggestions using the service
      final appliedTitles = await _settingsService.applyMultipleSuggestions(
        suggestions: selectedSuggestions,
        cameraProvider: cameraProvider,
        featureProvider: featureProvider,
      );

      // Show result
      if (mounted) {
        if (appliedTitles.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('✅ Applied ${appliedTitles.length} suggestions:'),
                  const SizedBox(height: 4),
                  ...appliedTitles.take(3).map((title) => Text('• $title', 
                    style: const TextStyle(fontSize: 12, color: Colors.white70))),
                  if (appliedTitles.length > 3)
                    Text('• ... and ${appliedTitles.length - 3} more', 
                      style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );

          debugPrint('✅ Successfully applied suggestions: $appliedTitles');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ No camera settings could be applied. Check camera connection.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );

          debugPrint('⚠️ No suggestions were successfully applied');
        }
      }

    } catch (e) {
      debugPrint('❌ Error applying suggestions: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error applying suggestions: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      // Clear loading state and close dialog
      if (mounted) {
        setState(() {
          _isAIAnalyzing = false;
          _selectedSuggestionIds.clear();
          _showAISuggestionDialog = false;
        });
      }
    }
  }


  /// Trigger a new AI analysis
  void _analyzeAgain() {
    debugPrint('🔄 Analyze Again button pressed');
    
    // Clear current suggestions and selections
    setState(() {
      _currentSuggestions.clear();
      _selectedSuggestionIds.clear();
    });
    
    // Start new analysis
    _startBackgroundAIAnalysis();
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

  void _navigateToSettings() async {
    // Navigate to settings and wait for return
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
    
    // Re-initialize AI configuration when returning from settings
    debugPrint('🔄 Returned from settings, re-initializing AI configuration...');
    await _initializeAI();
    debugPrint('✅ AI configuration refreshed after settings change');
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

}