import 'dart:async';
import '../state/base_state_provider.dart';

/// UI State management for camera screens
/// 
/// This provider manages all UI-related state for camera functionality.
/// It's separate from hardware control and focused solely on UI state.
class CameraStateProvider extends BaseStateProvider {
  // UI Control States
  bool _showAdvancedControls = false;
  bool _showAISuggestions = false;
  bool _showCameraControls = false;
  bool _isLiveViewActive = false;
  bool _isCapturing = false;
  bool _isDiscovering = false;
  
  // UI Settings (user preferences for display)
  double _uiISOValue = 400;
  double _uiApertureValue = 2.8;
  double _uiShutterSpeed = 60;
  String _uiWhiteBalance = 'auto';
  String _selectedCameraName = 'Mobile Camera';
  String _advancedMode = 'Basic';
  
  // Preview and display states
  bool _showCompositionGrid = false;
  bool _showHistogram = false;
  double _previewBrightness = 1.0;
  
  // Capture states
  String _captureMode = 'photo'; // photo, video, burst
  int _captureCount = 0;
  Timer? _captureTimer;
  
  // Loading and status states
  bool _isLoading = false;
  String _statusMessage = '';
  bool _hasStatusMessage = false;
  
  // Getters for UI control states
  bool get showAdvancedControls => _showAdvancedControls;
  bool get showAISuggestions => _showAISuggestions;
  bool get showCameraControls => _showCameraControls;
  bool get isLiveViewActive => _isLiveViewActive;
  bool get isCapturing => _isCapturing;
  bool get isDiscovering => _isDiscovering;
  
  // Getters for UI settings
  double get uiISOValue => _uiISOValue;
  double get uiApertureValue => _uiApertureValue;
  double get uiShutterSpeed => _uiShutterSpeed;
  String get uiWhiteBalance => _uiWhiteBalance;
  String get selectedCameraName => _selectedCameraName;
  String get advancedMode => _advancedMode;
  
  // Getters for preview states
  bool get showCompositionGrid => _showCompositionGrid;
  bool get showHistogram => _showHistogram;
  double get previewBrightness => _previewBrightness;
  
  // Getters for capture states
  String get captureMode => _captureMode;
  int get captureCount => _captureCount;
  
  // Getters for loading states
  @override
  bool get isLoading => _isLoading;
  String get statusMessage => _statusMessage;
  bool get hasStatusMessage => _hasStatusMessage;
  
  /// Toggle advanced controls visibility
  void toggleAdvancedControls() {
    _showAdvancedControls = !_showAdvancedControls;
    notifyListeners();
  }
  
  /// Set advanced controls visibility
  void setAdvancedControlsVisible(bool visible) {
    if (_showAdvancedControls != visible) {
      _showAdvancedControls = visible;
      notifyListeners();
    }
  }
  
  /// Toggle AI suggestions visibility
  void toggleAISuggestions() {
    _showAISuggestions = !_showAISuggestions;
    notifyListeners();
  }
  
  /// Set AI suggestions visibility
  void setAISuggestionsVisible(bool visible) {
    if (_showAISuggestions != visible) {
      _showAISuggestions = visible;
      notifyListeners();
    }
  }
  
  /// Toggle camera controls visibility
  void toggleCameraControls() {
    _showCameraControls = !_showCameraControls;
    notifyListeners();
  }
  
  /// Set camera controls visibility
  void setCameraControlsVisible(bool visible) {
    if (_showCameraControls != visible) {
      _showCameraControls = visible;
      notifyListeners();
    }
  }
  
  /// Set live view state
  void setLiveViewActive(bool active) {
    if (_isLiveViewActive != active) {
      _isLiveViewActive = active;
      notifyListeners();
    }
  }
  
  /// Set capturing state
  void setCapturing(bool capturing) {
    if (_isCapturing != capturing) {
      _isCapturing = capturing;
      notifyListeners();
    }
  }
  
  /// Set discovering state
  void setDiscovering(bool discovering) {
    if (_isDiscovering != discovering) {
      _isDiscovering = discovering;
      notifyListeners();
    }
  }
  
  /// Update UI camera settings (for display purposes)
  void updateUISettings({
    double? iso,
    double? aperture,
    double? shutterSpeed,
    String? whiteBalance,
  }) {
    bool changed = false;
    
    if (iso != null && _uiISOValue != iso) {
      _uiISOValue = iso;
      changed = true;
    }
    
    if (aperture != null && _uiApertureValue != aperture) {
      _uiApertureValue = aperture;
      changed = true;
    }
    
    if (shutterSpeed != null && _uiShutterSpeed != shutterSpeed) {
      _uiShutterSpeed = shutterSpeed;
      changed = true;
    }
    
    if (whiteBalance != null && _uiWhiteBalance != whiteBalance) {
      _uiWhiteBalance = whiteBalance;
      changed = true;
    }
    
    if (changed) {
      notifyListeners();
    }
  }
  
  /// Set selected camera name
  void setSelectedCameraName(String name) {
    if (_selectedCameraName != name) {
      _selectedCameraName = name;
      notifyListeners();
    }
  }
  
  /// Set advanced mode
  void setAdvancedMode(String mode) {
    if (_advancedMode != mode) {
      _advancedMode = mode;
      notifyListeners();
    }
  }
  
  /// Toggle composition grid
  void toggleCompositionGrid() {
    _showCompositionGrid = !_showCompositionGrid;
    notifyListeners();
  }
  
  /// Set composition grid visibility
  void setCompositionGridVisible(bool visible) {
    if (_showCompositionGrid != visible) {
      _showCompositionGrid = visible;
      notifyListeners();
    }
  }
  
  /// Toggle histogram
  void toggleHistogram() {
    _showHistogram = !_showHistogram;
    notifyListeners();
  }
  
  /// Set histogram visibility
  void setHistogramVisible(bool visible) {
    if (_showHistogram != visible) {
      _showHistogram = visible;
      notifyListeners();
    }
  }
  
  /// Set preview brightness
  void setPreviewBrightness(double brightness) {
    brightness = brightness.clamp(0.0, 2.0);
    if (_previewBrightness != brightness) {
      _previewBrightness = brightness;
      notifyListeners();
    }
  }
  
  /// Set capture mode
  void setCaptureMode(String mode) {
    if (_captureMode != mode) {
      _captureMode = mode;
      notifyListeners();
    }
  }
  
  /// Increment capture count
  void incrementCaptureCount() {
    _captureCount++;
    notifyListeners();
  }
  
  /// Reset capture count
  void resetCaptureCount() {
    _captureCount = 0;
    notifyListeners();
  }
  
  /// Set loading state
  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }
  
  /// Set status message
  void setStatusMessage(String message) {
    _statusMessage = message;
    _hasStatusMessage = message.isNotEmpty;
    notifyListeners();
  }
  
  /// Clear status message
  void clearStatusMessage() {
    _statusMessage = '';
    _hasStatusMessage = false;
    notifyListeners();
  }
  
  /// Show temporary status message
  void showTemporaryStatus(String message, {Duration duration = const Duration(seconds: 3)}) {
    setStatusMessage(message);
    
    // Cancel existing timer
    _captureTimer?.cancel();
    
    // Set new timer to clear message
    _captureTimer = Timer(duration, () {
      clearStatusMessage();
    });
    
    // Register cleanup for timer
    addCleanupFunction(() => _captureTimer?.cancel());
  }
  
  /// Reset all UI state to defaults
  void resetToDefaults() {
    _showAdvancedControls = false;
    _showAISuggestions = false;
    _showCameraControls = false;
    _isLiveViewActive = false;
    _isCapturing = false;
    _isDiscovering = false;
    
    _uiISOValue = 400;
    _uiApertureValue = 2.8;
    _uiShutterSpeed = 60;
    _uiWhiteBalance = 'auto';
    _selectedCameraName = 'Mobile Camera';
    _advancedMode = 'Basic';
    
    _showCompositionGrid = false;
    _showHistogram = false;
    _previewBrightness = 1.0;
    
    _captureMode = 'photo';
    _captureCount = 0;
    
    _isLoading = false;
    clearStatusMessage();
    
    notifyListeners();
  }
  
  /// Get all UI state as a map (for debugging/persistence)
  Map<String, dynamic> getUIState() {
    return {
      'showAdvancedControls': _showAdvancedControls,
      'showAISuggestions': _showAISuggestions,
      'showCameraControls': _showCameraControls,
      'isLiveViewActive': _isLiveViewActive,
      'isCapturing': _isCapturing,
      'isDiscovering': _isDiscovering,
      'uiSettings': {
        'iso': _uiISOValue,
        'aperture': _uiApertureValue,
        'shutterSpeed': _uiShutterSpeed,
        'whiteBalance': _uiWhiteBalance,
        'selectedCameraName': _selectedCameraName,
        'advancedMode': _advancedMode,
      },
      'previewSettings': {
        'showCompositionGrid': _showCompositionGrid,
        'showHistogram': _showHistogram,
        'previewBrightness': _previewBrightness,
      },
      'captureSettings': {
        'captureMode': _captureMode,
        'captureCount': _captureCount,
      },
      'loadingState': {
        'isLoading': _isLoading,
        'statusMessage': _statusMessage,
        'hasStatusMessage': _hasStatusMessage,
      },
    };
  }
  
  @override
  void dispose() {
    _captureTimer?.cancel();
    // ServiceDisposalMixin handles other cleanup
    super.dispose();
  }
}