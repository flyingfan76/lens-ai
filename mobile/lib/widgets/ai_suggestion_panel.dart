import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/ai_suggestion.dart';
import '../services/ai/ai_coordinator.dart';
import '../screens/ai_settings_screen.dart';
import '../core/utils/disposal_mixin.dart';
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
    with TickerProviderStateMixin, DisposalMixin {
  List<AISuggestion> _suggestions = [];
  bool _isLoading = false;
  bool _isAnalyzing = false;
  late AnimationController _panelController;
  late AnimationController _pulseController;
  late Animation<double> _panelAnimation;
  late Animation<double> _pulseAnimation;
  final AICoordinator _aiService = AICoordinator();

  @override
  void initState() {
    super.initState();
    
    // Initialize the unified AI service
    _aiService.initialize();
    
    _panelController = createAnimationController(
      duration: const Duration(milliseconds: 300),
    );
    
    _pulseController = createAnimationController(
      duration: const Duration(milliseconds: 1500),
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
    // DisposalMixin will handle animation controllers
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.65,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.75),
                      Colors.black.withValues(alpha: 0.80),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 32,
                      offset: const Offset(0, 16),
                      spreadRadius: -4,
                    ),
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      blurRadius: 48,
                      offset: const Offset(0, 0),
                      spreadRadius: -8,
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
        ),
      ),
    );
  }

  Widget _buildPanelHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent.withValues(alpha: 0.15),
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.accent.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.accent.withValues(alpha: 0.8),
                  AppColors.accent.withValues(alpha: 0.6),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Photography Assistant',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                if (_suggestions.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_suggestions.length} ${_suggestions.length == 1 ? 'suggestion' : 'suggestions'}',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else if (!_isLoading && !_isAnalyzing)
                  Text(
                    'Ready to analyze',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          _buildHeaderButton(
            icon: Icons.refresh_rounded,
            onPressed: _refreshSuggestions,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 4),
          _buildHeaderButton(
            icon: Icons.tune_rounded,
            onPressed: _openAISettings,
            tooltip: 'Settings',
          ),
          const SizedBox(width: 4),
          _buildHeaderButton(
            icon: Icons.close_rounded,
            onPressed: () => widget.onVisibilityChanged?.call(false),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accent.withValues(alpha: 0.1),
                      AppColors.primary.withValues(alpha: 0.1),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.accent.withValues(alpha: 0.8),
                  ),
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              Icon(
                Icons.auto_awesome,
                color: AppColors.accent.withValues(alpha: 0.7),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _isAnalyzing ? 'Analyzing scene composition...' : 'Loading AI suggestions...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isAnalyzing ? 'This may take a moment' : 'Please wait',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.accent.withValues(alpha: 0.15),
                  AppColors.primary.withValues(alpha: 0.1),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.psychology_rounded,
              color: AppColors.accent.withValues(alpha: 0.7),
              size: 36,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Ready for AI Analysis',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Get intelligent photography suggestions\nbased on your current scene',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.touch_app_rounded,
                  size: 16,
                  color: AppColors.accent.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
                Text(
                  'Tap AI button to start',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
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
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.accent.withValues(alpha: 0.95),
                      AppColors.accent.withValues(alpha: 0.85),
                      AppColors.primary.withValues(alpha: 0.8),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: -2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    if (_isAnalyzing)
                      Positioned.fill(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withValues(alpha: 0.9),
                          ),
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          widget.isVisible ? Icons.close_rounded : Icons.auto_awesome_rounded,
                          key: ValueKey(widget.isVisible),
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                    if (_suggestions.isNotEmpty && !widget.isVisible && !_isAnalyzing)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 18),
                          height: 18,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.error,
                                AppColors.error.withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: Colors.white,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.error.withValues(alpha: 0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _suggestions.length > 9 ? '9+' : '${_suggestions.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
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
        style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
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

      final result = await _aiService.generateSuggestions(sceneAnalysis: sceneAnalysis);
      
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

  void _openAISettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AISettingsScreen(),
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.9),
              size: 16,
            ),
          ),
        ),
      ),
    );
  }
}