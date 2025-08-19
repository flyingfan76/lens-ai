import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'base_state_provider.dart';
import '../../models/ai_suggestion.dart';
import '../../services/ai/ai_coordinator.dart';

/// AI feature state provider
/// 
/// Manages AI-related functionality including:
/// - AI suggestions and recommendations
/// - AI service configuration and status
/// - AI analysis results
/// - User preferences for AI features
class AIFeatureProvider extends BaseStateProvider 
    with StatePersistenceMixin, PeriodicStateMixin {
  static const String _storageKey = 'lens_ai_ai_feature_state';
  
  // AI service dependencies
  AICoordinator? _aiCoordinator;
  
  // AI service state
  bool _aiServiceAvailable = false;
  String _aiServiceStatus = 'Disconnected';
  String _currentAIProvider = 'local';
  Map<String, dynamic> _aiCapabilities = {};
  
  // AI suggestions state
  List<AISuggestion> _currentSuggestions = [];
  AISuggestion? _selectedSuggestion;
  bool _suggestionsLoading = false;
  DateTime? _lastSuggestionsUpdate;
  String _suggestionContext = 'general'; // general, portrait, landscape, etc.
  
  // AI analysis state
  Map<String, dynamic> _lastAnalysisResult = {};
  bool _analysisInProgress = false;
  DateTime? _lastAnalysisTime;
  String _analysisType = 'scene'; // scene, composition, lighting, etc.
  
  // AI preferences and settings
  bool _enableAISuggestions = true;
  bool _enableRealTimeAnalysis = true;
  bool _enableAutoApplySettings = false;
  bool _enableAdvancedAI = false;
  double _suggestionConfidenceThreshold = 0.7;
  String _preferredAIStyle = 'balanced'; // conservative, balanced, creative
  bool _enableLearningFromFeedback = true;
  
  // AI feedback and learning
  Map<String, int> _suggestionFeedback = {}; // suggestion_id -> rating (1-5)
  List<Map<String, dynamic>> _userPreferenceHistory = [];
  Map<String, dynamic> _learnedPreferences = {};
  
  // AI performance metrics
  Map<String, dynamic> _performanceMetrics = {
    'totalSuggestions': 0,
    'appliedSuggestions': 0,
    'averageResponseTime': 0.0,
    'successRate': 0.0,
  };
  
  SharedPreferences? _prefs;
  Timer? _analysisTimer;
  
  // Getters - AI service state
  bool get aiServiceAvailable => _aiServiceAvailable;
  String get aiServiceStatus => _aiServiceStatus;
  String get currentAIProvider => _currentAIProvider;
  Map<String, dynamic> get aiCapabilities => Map.from(_aiCapabilities);
  
  // Getters - Suggestions state
  List<AISuggestion> get currentSuggestions => List.unmodifiable(_currentSuggestions);
  AISuggestion? get selectedSuggestion => _selectedSuggestion;
  bool get suggestionsLoading => _suggestionsLoading;
  DateTime? get lastSuggestionsUpdate => _lastSuggestionsUpdate;
  String get suggestionContext => _suggestionContext;
  
  // Getters - Analysis state
  Map<String, dynamic> get lastAnalysisResult => Map.from(_lastAnalysisResult);
  bool get analysisInProgress => _analysisInProgress;
  DateTime? get lastAnalysisTime => _lastAnalysisTime;
  String get analysisType => _analysisType;
  
  // Getters - Preferences
  bool get enableAISuggestions => _enableAISuggestions;
  bool get enableRealTimeAnalysis => _enableRealTimeAnalysis;
  bool get enableAutoApplySettings => _enableAutoApplySettings;
  bool get enableAdvancedAI => _enableAdvancedAI;
  double get suggestionConfidenceThreshold => _suggestionConfidenceThreshold;
  String get preferredAIStyle => _preferredAIStyle;
  bool get enableLearningFromFeedback => _enableLearningFromFeedback;
  
  // Getters - Feedback and learning
  Map<String, int> get suggestionFeedback => Map.from(_suggestionFeedback);
  List<Map<String, dynamic>> get userPreferenceHistory => List.from(_userPreferenceHistory);
  Map<String, dynamic> get learnedPreferences => Map.from(_learnedPreferences);
  
  // Getters - Performance metrics
  Map<String, dynamic> get performanceMetrics => Map.from(_performanceMetrics);
  
  @override
  String get persistenceKey => _storageKey;
  
  /// Set AI coordinator dependency
  void setAICoordinator(AICoordinator coordinator) {
    if (_aiCoordinator != coordinator) {
      _aiCoordinator = coordinator;
      _syncWithAICoordinator();
    }
  }
  
  @override
  Future<void> initializeState() async {
    _prefs = await SharedPreferences.getInstance();
    await loadState();
    
    // Initialize AI service if available
    if (_aiCoordinator != null) {
      await _initializeAIService();
    }
    
    // Start periodic updates if real-time analysis is enabled
    if (_enableRealTimeAnalysis) {
      startPeriodicUpdates(interval: const Duration(seconds: 5));
    }
  }
  
  /// Initialize AI service
  Future<void> _initializeAIService() async {
    await executeWithErrorHandling(() async {
      if (_aiCoordinator != null) {
        _aiServiceAvailable = _aiCoordinator!.isServiceAvailable();
        _aiServiceStatus = _aiServiceAvailable ? 'Available' : 'Unavailable';
        _currentAIProvider = _aiCoordinator!.currentProvider;
        
        // Get AI capabilities
        _aiCapabilities = await _aiCoordinator!.getCapabilities();
        
        _syncWithAICoordinator();
      }
    }, operationName: 'initialize AI service');
  }
  
  /// Sync state with AI coordinator
  void _syncWithAICoordinator() {
    if (_aiCoordinator == null) return;
    
    batchStateUpdates(() {
      _aiServiceAvailable = _aiCoordinator!.isServiceAvailable();
      _aiServiceStatus = _aiServiceAvailable ? 'Available' : 'Unavailable';
      _currentAIProvider = _aiCoordinator!.currentProvider;
    });
  }
  
  @override
  Future<void> performPeriodicUpdate() async {
    if (_aiCoordinator != null && _enableRealTimeAnalysis) {
      await _performBackgroundAnalysis();
    }
  }
  
  /// Perform background analysis for real-time suggestions
  Future<void> _performBackgroundAnalysis() async {
    if (_analysisInProgress || !_aiServiceAvailable) return;
    
    await executeWithErrorHandling(() async {
      // Only perform analysis if enough time has passed
      final now = DateTime.now();
      if (_lastAnalysisTime != null && 
          now.difference(_lastAnalysisTime!).inSeconds < 10) {
        return;
      }
      
      _analysisInProgress = true;
      _lastAnalysisTime = now;
      
      // Perform lightweight analysis for real-time feedback
      // This would integrate with the AI service for actual analysis
      _lastAnalysisResult = {
        'timestamp': now.toIso8601String(),
        'type': 'background',
        'quality': 'good',
        'suggestions': [],
      };
      
      _analysisInProgress = false;
    }, operationName: 'background analysis');
  }
  
  // AI suggestion methods
  
  /// Generate AI suggestions for current scene
  Future<void> generateSuggestions({
    String? imagePath,
    Map<String, dynamic>? sceneContext,
    String context = 'general',
  }) async {
    if (!validateState() || !_enableAISuggestions) return;
    
    await executeWithErrorHandling(() async {
      _suggestionsLoading = true;
      _suggestionContext = context;
      notifyListeners();
      
      final startTime = DateTime.now();
      
      if (_aiCoordinator != null && _aiServiceAvailable) {
        // Generate suggestions using AI coordinator
        final analysisResult = await _aiCoordinator!.generateSuggestions(
          sceneAnalysis: SceneAnalysis(
            sceneType: sceneContext?['sceneType'] ?? 'general',
            lightingCondition: sceneContext?['lightingCondition'] ?? 'normal',
            subjectDistance: sceneContext?['subjectDistance'] ?? 'medium',
            movementDetected: sceneContext?['movementDetected'] ?? false,
          ),
        );
        
        _currentSuggestions = analysisResult.suggestions
            .where((s) => s.confidence >= _suggestionConfidenceThreshold)
            .toList();
        
        _lastSuggestionsUpdate = DateTime.now();
        
        // Update performance metrics
        _updatePerformanceMetrics(startTime);
        
        // Learn from context if learning is enabled
        if (_enableLearningFromFeedback && sceneContext != null) {
          _learnFromContext(sceneContext);
        }
      } else {
        // No AI coordinator available - create empty suggestions
        _currentSuggestions = [];
        _lastSuggestionsUpdate = DateTime.now();
        debugPrint('AIFeatureProvider: No AI coordinator available for suggestion generation');
      }
      
      _suggestionsLoading = false;
      
      // Auto-save state
      await saveState();
    }, 
    operationName: 'generate AI suggestions',
    showLoadingState: true,
    loadingMessage: 'Generating AI suggestions...',
    );
  }
  
  
  /// Select a suggestion
  void selectSuggestion(AISuggestion suggestion) {
    if (_selectedSuggestion != suggestion) {
      _selectedSuggestion = suggestion;
      notifyListeners();
    }
  }
  
  /// Clear selected suggestion
  void clearSelectedSuggestion() {
    if (_selectedSuggestion != null) {
      _selectedSuggestion = null;
      notifyListeners();
    }
  }
  
  /// Apply selected suggestion
  Future<bool> applySelectedSuggestion() async {
    if (_selectedSuggestion == null) return false;
    
    final result = await executeWithErrorHandling<bool>(() async {
      // This would integrate with camera provider to apply settings
      // For now, track that suggestion was applied
      _performanceMetrics['appliedSuggestions'] = 
          (_performanceMetrics['appliedSuggestions'] ?? 0) + 1;
      
      await saveState();
      
      return true;
    }, 
    operationName: 'apply AI suggestion',
    fallbackValue: false,
    );
    
    return result ?? false;
  }
  
  /// Provide feedback on suggestion
  Future<void> provideSuggestionFeedback(String suggestionId, int rating) async {
    if (rating < 1 || rating > 5) {
      throw ArgumentError('Rating must be between 1 and 5');
    }
    
    await executeWithErrorHandling(() async {
      _suggestionFeedback[suggestionId] = rating;
      
      if (_enableLearningFromFeedback) {
        _updateLearningFromFeedback(suggestionId, rating);
      }
      
      await saveState();
      notifyListeners();
    }, operationName: 'provide suggestion feedback');
  }
  
  /// Update learned preferences from feedback
  void _updateLearningFromFeedback(String suggestionId, int rating) {
    // Find the suggestion and learn from the feedback
    final suggestion = _currentSuggestions
        .where((s) => s.id == suggestionId)
        .firstOrNull;
    
    if (suggestion != null) {
      final preferenceKey = '${suggestion.type.name}_${suggestion.title}';
      final currentScore = _learnedPreferences[preferenceKey] ?? 0.0;
      
      // Update preference score based on feedback
      const feedbackWeight = 0.1; // How much feedback affects learned preferences
      final newScore = currentScore + (rating - 3) * feedbackWeight; // 3 is neutral
      
      _learnedPreferences[preferenceKey] = newScore.clamp(-1.0, 1.0);
    }
  }
  
  /// Learn from scene context
  void _learnFromContext(Map<String, dynamic> context) {
    _userPreferenceHistory.add({
      'timestamp': DateTime.now().toIso8601String(),
      'context': context,
      'suggestions': _currentSuggestions.map((s) => s.toMap()).toList(),
    });
    
    // Keep only last 100 entries for memory efficiency
    if (_userPreferenceHistory.length > 100) {
      _userPreferenceHistory.removeAt(0);
    }
  }
  
  /// Update performance metrics
  void _updatePerformanceMetrics(DateTime startTime) {
    _performanceMetrics['totalSuggestions'] = 
        (_performanceMetrics['totalSuggestions'] ?? 0) + 1;
    
    final responseTime = DateTime.now().difference(startTime).inMilliseconds;
    final currentAvg = _performanceMetrics['averageResponseTime'] ?? 0.0;
    final total = _performanceMetrics['totalSuggestions'] ?? 1;
    
    _performanceMetrics['averageResponseTime'] = 
        (currentAvg * (total - 1) + responseTime) / total;
    
    final appliedCount = _performanceMetrics['appliedSuggestions'] ?? 0;
    _performanceMetrics['successRate'] = appliedCount / total;
  }
  
  // AI analysis methods
  
  /// Analyze image or scene
  Future<Map<String, dynamic>> analyzeScene({
    String? imagePath,
    Map<String, dynamic>? sceneData,
    String analysisType = 'scene',
  }) async {
    if (!validateState()) return {};
    
    final result = await executeWithErrorHandling<Map<String, dynamic>>(() async {
      _analysisInProgress = true;
      _analysisType = analysisType;
      notifyListeners();
      
      Map<String, dynamic> analysisResult = {};
      
      if (_aiCoordinator != null && _aiServiceAvailable) {
        // Perform actual AI analysis
        analysisResult = await _aiCoordinator!.analyzeImageFromPath(
          imagePath: imagePath,
          analysisType: analysisType,
        );
      } else {
        // No AI coordinator available - create empty analysis
        analysisResult = {};
        debugPrint('AIFeatureProvider: No AI coordinator available for scene analysis');
      }
      
      _lastAnalysisResult = analysisResult;
      _lastAnalysisTime = DateTime.now();
      _analysisInProgress = false;
      
      await saveState();
      
      return analysisResult;
    }, 
    operationName: 'analyze scene',
    showLoadingState: true,
    loadingMessage: 'Analyzing scene...',
    fallbackValue: <String, dynamic>{},
    );
    
    return result ?? {};
  }
  
  
  // Preference management methods
  
  /// Set AI suggestions enabled
  Future<void> setAISuggestionsEnabled(bool enabled) async {
    if (_enableAISuggestions != enabled) {
      await executeWithErrorHandling(() async {
        _enableAISuggestions = enabled;
        
        if (!enabled) {
          _currentSuggestions.clear();
          _selectedSuggestion = null;
        }
        
        await saveState();
        notifyListeners();
      }, operationName: 'set AI suggestions enabled');
    }
  }
  
  /// Set real-time analysis enabled
  Future<void> setRealTimeAnalysisEnabled(bool enabled) async {
    if (_enableRealTimeAnalysis != enabled) {
      await executeWithErrorHandling(() async {
        _enableRealTimeAnalysis = enabled;
        
        if (enabled) {
          startPeriodicUpdates(interval: const Duration(seconds: 5));
        } else {
          stopPeriodicUpdates();
        }
        
        await saveState();
        notifyListeners();
      }, operationName: 'set real-time analysis enabled');
    }
  }
  
  /// Set auto-apply settings enabled
  Future<void> setAutoApplySettingsEnabled(bool enabled) async {
    if (_enableAutoApplySettings != enabled) {
      await executeWithErrorHandling(() async {
        _enableAutoApplySettings = enabled;
        await saveState();
        notifyListeners();
      }, operationName: 'set auto-apply settings enabled');
    }
  }
  
  /// Set advanced AI enabled
  Future<void> setAdvancedAIEnabled(bool enabled) async {
    if (_enableAdvancedAI != enabled) {
      await executeWithErrorHandling(() async {
        _enableAdvancedAI = enabled;
        await saveState();
        notifyListeners();
      }, operationName: 'set advanced AI enabled');
    }
  }
  
  /// Set suggestion confidence threshold
  Future<void> setSuggestionConfidenceThreshold(double threshold) async {
    final clampedThreshold = threshold.clamp(0.1, 1.0);
    if (_suggestionConfidenceThreshold != clampedThreshold) {
      await executeWithErrorHandling(() async {
        _suggestionConfidenceThreshold = clampedThreshold;
        
        // Filter current suggestions based on new threshold
        _currentSuggestions = _currentSuggestions
            .where((s) => s.confidence >= clampedThreshold)
            .toList();
        
        await saveState();
        notifyListeners();
      }, operationName: 'set suggestion confidence threshold');
    }
  }
  
  /// Set preferred AI style
  Future<void> setPreferredAIStyle(String style) async {
    if (_preferredAIStyle != style) {
      await executeWithErrorHandling(() async {
        _preferredAIStyle = style;
        await saveState();
        notifyListeners();
      }, operationName: 'set preferred AI style');
    }
  }
  
  /// Set learning from feedback enabled
  Future<void> setLearningFromFeedbackEnabled(bool enabled) async {
    if (_enableLearningFromFeedback != enabled) {
      await executeWithErrorHandling(() async {
        _enableLearningFromFeedback = enabled;
        
        if (!enabled) {
          _suggestionFeedback.clear();
          _userPreferenceHistory.clear();
          _learnedPreferences.clear();
        }
        
        await saveState();
        notifyListeners();
      }, operationName: 'set learning from feedback enabled');
    }
  }
  
  // State persistence implementation
  
  @override
  Map<String, dynamic> getPersistedState() {
    return {
      'aiService': {
        'currentAIProvider': _currentAIProvider,
        'aiCapabilities': _aiCapabilities,
      },
      'suggestions': {
        'suggestionContext': _suggestionContext,
        'lastSuggestionsUpdate': _lastSuggestionsUpdate?.toIso8601String(),
      },
      'analysis': {
        'lastAnalysisResult': _lastAnalysisResult,
        'lastAnalysisTime': _lastAnalysisTime?.toIso8601String(),
        'analysisType': _analysisType,
      },
      'preferences': {
        'enableAISuggestions': _enableAISuggestions,
        'enableRealTimeAnalysis': _enableRealTimeAnalysis,
        'enableAutoApplySettings': _enableAutoApplySettings,
        'enableAdvancedAI': _enableAdvancedAI,
        'suggestionConfidenceThreshold': _suggestionConfidenceThreshold,
        'preferredAIStyle': _preferredAIStyle,
        'enableLearningFromFeedback': _enableLearningFromFeedback,
      },
      'feedback': {
        'suggestionFeedback': _suggestionFeedback,
        'userPreferenceHistory': _userPreferenceHistory,
        'learnedPreferences': _learnedPreferences,
      },
      'performanceMetrics': _performanceMetrics,
      'savedAt': DateTime.now().toIso8601String(),
    };
  }
  
  @override
  Future<void> restorePersistedState(Map<String, dynamic> state) async {
    batchStateUpdates(() {
      // Restore AI service state
      final aiService = state['aiService'] as Map<String, dynamic>? ?? {};
      _currentAIProvider = aiService['currentAIProvider'] ?? 'local';
      _aiCapabilities = Map<String, dynamic>.from(aiService['aiCapabilities'] ?? {});
      
      // Restore suggestions state
      final suggestions = state['suggestions'] as Map<String, dynamic>? ?? {};
      _suggestionContext = suggestions['suggestionContext'] ?? 'general';
      final lastUpdateStr = suggestions['lastSuggestionsUpdate'] as String?;
      if (lastUpdateStr != null) {
        _lastSuggestionsUpdate = DateTime.tryParse(lastUpdateStr);
      }
      
      // Restore analysis state
      final analysis = state['analysis'] as Map<String, dynamic>? ?? {};
      _lastAnalysisResult = Map<String, dynamic>.from(analysis['lastAnalysisResult'] ?? {});
      _analysisType = analysis['analysisType'] ?? 'scene';
      final lastAnalysisStr = analysis['lastAnalysisTime'] as String?;
      if (lastAnalysisStr != null) {
        _lastAnalysisTime = DateTime.tryParse(lastAnalysisStr);
      }
      
      // Restore preferences
      final preferences = state['preferences'] as Map<String, dynamic>? ?? {};
      _enableAISuggestions = preferences['enableAISuggestions'] ?? true;
      _enableRealTimeAnalysis = preferences['enableRealTimeAnalysis'] ?? true;
      _enableAutoApplySettings = preferences['enableAutoApplySettings'] ?? false;
      _enableAdvancedAI = preferences['enableAdvancedAI'] ?? false;
      _suggestionConfidenceThreshold = preferences['suggestionConfidenceThreshold'] ?? 0.7;
      _preferredAIStyle = preferences['preferredAIStyle'] ?? 'balanced';
      _enableLearningFromFeedback = preferences['enableLearningFromFeedback'] ?? true;
      
      // Restore feedback data
      final feedback = state['feedback'] as Map<String, dynamic>? ?? {};
      _suggestionFeedback = Map<String, int>.from(feedback['suggestionFeedback'] ?? {});
      _userPreferenceHistory = List<Map<String, dynamic>>.from(
        (feedback['userPreferenceHistory'] as List?)?.cast<Map<String, dynamic>>() ?? []
      );
      _learnedPreferences = Map<String, dynamic>.from(feedback['learnedPreferences'] ?? {});
      
      // Restore performance metrics
      _performanceMetrics = Map<String, dynamic>.from(state['performanceMetrics'] ?? {
        'totalSuggestions': 0,
        'appliedSuggestions': 0,
        'averageResponseTime': 0.0,
        'successRate': 0.0,
      });
    });
  }
  
  @override
  Future<void> saveState() async {
    if (_prefs == null) return;
    
    try {
      final state = getPersistedState();
      await _prefs!.setString(_storageKey, jsonEncode(state));
    } catch (e) {
      debugPrint('Failed to save AI feature state: $e');
    }
  }
  
  @override
  Future<void> loadState() async {
    if (_prefs == null) return;
    
    try {
      final stateJson = _prefs!.getString(_storageKey);
      if (stateJson != null) {
        final state = jsonDecode(stateJson) as Map<String, dynamic>;
        await restorePersistedState(state);
      }
    } catch (e) {
      debugPrint('Failed to load AI feature state: $e');
    }
  }
  
  @override
  void dispose() {
    _analysisTimer?.cancel();
    stopPeriodicUpdates();
    super.dispose();
  }
}