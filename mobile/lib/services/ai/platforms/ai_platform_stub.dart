import 'package:flutter/foundation.dart';
import '../../../models/ai_suggestion.dart';

/// Abstract platform interface for local AI processing
abstract class LocalAIPlatform {
  /// Initialize platform-specific AI model
  Future<void> initializeModel();
  
  /// Run advanced analysis using platform-specific capabilities
  Future<List<AISuggestion>> runAdvancedAnalysis(SceneAnalysis sceneAnalysis, Uint8List imageBytes);
  
  /// Dispose platform resources
  void dispose();
}

/// Stub implementation for unsupported platforms
class StubLocalAIPlatform implements LocalAIPlatform {
  @override
  Future<void> initializeModel() async {
    debugPrint('StubLocalAIPlatform: Model initialization (no-op)');
  }
  
  @override
  Future<List<AISuggestion>> runAdvancedAnalysis(SceneAnalysis sceneAnalysis, Uint8List imageBytes) async {
    debugPrint('StubLocalAIPlatform: Advanced analysis not available');
    return [];
  }
  
  @override
  void dispose() {
    debugPrint('StubLocalAIPlatform: Disposed');
  }
}

LocalAIPlatform createLocalAIPlatform() => StubLocalAIPlatform();