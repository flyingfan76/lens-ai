import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/ai_suggestion.dart';
import '../services/ai_service.dart';
import 'ai_suggestion_card.dart';

class AISuggestionPanel extends StatefulWidget {
  final Function(Map<String, dynamic>)? onApplySettings;
  final bool isVisible;
  final Function(bool)? onVisibilityChanged;

  const AISuggestionPanel({
    super.key,
    this.onApplySettings,
    required this.isVisible,
    this.onVisibilityChanged,
  });

  @override
  State<AISuggestionPanel> createState() => _AISuggestionPanelState();
}

class _AISuggestionPanelState extends State<AISuggestionPanel>
    with TickerProviderStateMixin {
  List<AISuggestion> _suggestions = [];
  bool _isLoading = false;
  bool _isAnalyzing = false;
  late AnimationController _panelController;
  late AnimationController _pulseController;
  late Animation<double> _panelAnimation;
  late Animation<double> _pulseAnimation;
  final AIService _aiService = AIService();

  @override
  void initState() {
    super.initState();
    
    _panelController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _panelAnimation = CurvedAnimation(
      parent: _panelController,
      curve: Curves.easeInOut,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    if (widget.isVisible) {
      _panelController.forward();
    }
    
    // Start pulse animation for AI button
    _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(AISuggestionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _panelController.forward();
      } else {
        _panelController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _panelController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // AI Suggestion Panel
        if (widget.isVisible) _buildSuggestionPanel(),
        
        // Floating AI Button
        _buildFloatingAIButton(),
      ],
    );
  }

  Widget _buildSuggestionPanel() {
    return Positioned(
      top: 80,
      right: 16,
      left: 16,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(_panelAnimation),
        child: FadeTransition(
          opacity: _panelAnimation,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.accent.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPanelHeader(),
                if (_isLoading || _isAnalyzing) 
                  _buildLoadingIndicator()
                else if (_suggestions.isEmpty)
                  _buildEmptyState()
                else
                  _buildSuggestionsList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanelHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent.withOpacity(0.8),
            AppColors.accent.withOpacity(0.4),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Suggestions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_suggestions.isNotEmpty)
                  Text(
                    '${_suggestions.length} recommendations',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: _refreshSuggestions,
            icon: Icon(
              Icons.refresh,
              color: Colors.white,
              size: 20,
            ),
          ),
          IconButton(
            onPressed: () => widget.onVisibilityChanged?.call(false),
            icon: Icon(
              Icons.close,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isAnalyzing ? 'Analyzing scene...' : 'Loading suggestions...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: Colors.white.withOpacity(0.5),
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'No suggestions available',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the AI button to analyze the current scene',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return Flexible(
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        shrinkWrap: true,
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          return AISuggestionCard(
            suggestion: suggestion,
            onApply: _applySuggestion,
            onDismiss: _dismissSuggestion,
          );
        },
      ),
    );
  }

  Widget _buildFloatingAIButton() {
    return Positioned(
      top: 120,
      right: 20,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isVisible ? 1.0 : _pulseAnimation.value,
            child: GestureDetector(
              onTap: _togglePanel,
              onLongPress: _showAISettings,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.accent,
                      AppColors.accent.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        widget.isVisible ? Icons.close : Icons.auto_awesome,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    if (_isAnalyzing)
                      Positioned.fill(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    if (_suggestions.isNotEmpty && !widget.isVisible)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${_suggestions.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _togglePanel() {
    if (widget.isVisible) {
      widget.onVisibilityChanged?.call(false);
    } else {
      widget.onVisibilityChanged?.call(true);
      if (_suggestions.isEmpty) {
        _analyzeSuggestions();
      }
    }
  }

  void _showAISettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAISettingsSheet(),
    );
  }

  Widget _buildAISettingsSheet() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white54,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'AI Assistant Settings',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            _buildSettingTile(
              'Auto Analysis',
              'Automatically analyze scenes',
              true,
              (value) {},
            ),
            _buildSettingTile(
              'Smart Notifications',
              'Show suggestions proactively',
              false,
              (value) {},
            ),
            _buildSettingTile(
              'Learning Mode',
              'Improve suggestions based on usage',
              true,
              (value) {},
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.white.withOpacity(0.7)),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.accent,
      ),
    );
  }

  Future<void> _analyzeSuggestions() async {
    if (_isAnalyzing) return;
    
    setState(() {
      _isAnalyzing = true;
    });

    try {
      // Simulate scene analysis
      final sceneAnalysis = SceneAnalysis(
        sceneType: 'portrait',
        lightingCondition: 'normal',
        subjectDistance: 'medium',
        movementDetected: false,
        subjectPosition: 'center',
      );

      final result = await _aiService.analyzeSuggestions(sceneAnalysis);
      
      setState(() {
        _suggestions = result.suggestions;
        _isAnalyzing = false;
      });
    } catch (error) {
      setState(() {
        _isAnalyzing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to analyze scene: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _refreshSuggestions() {
    setState(() {
      _suggestions.clear();
    });
    _analyzeSuggestions();
  }

  void _applySuggestion(AISuggestion suggestion) {
    if (suggestion.action != null && widget.onApplySettings != null) {
      widget.onApplySettings!(suggestion.action!.settings);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Applied: ${suggestion.title}'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _dismissSuggestion(AISuggestion suggestion) {
    setState(() {
      _suggestions.removeWhere((s) => s.id == suggestion.id);
    });
  }
}