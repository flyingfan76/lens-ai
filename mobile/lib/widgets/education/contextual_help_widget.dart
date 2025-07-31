import 'package:flutter/material.dart';
import '../../models/education.dart';
import '../../services/education_service.dart';

class ContextualHelpWidget extends StatefulWidget {
  final String? sceneType;
  final CameraSettings? cameraSettings;
  final String? userLevel;
  final List<String>? commonIssues;
  final EducationService educationService;

  const ContextualHelpWidget({
    Key? key,
    this.sceneType,
    this.cameraSettings,
    this.userLevel,
    this.commonIssues,
    required this.educationService,
  }) : super(key: key);

  @override
  State<ContextualHelpWidget> createState() => _ContextualHelpWidgetState();
}

class _ContextualHelpWidgetState extends State<ContextualHelpWidget> {
  List<HelpSuggestion> _suggestions = [];
  bool _isLoading = false;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _loadContextualHelp();
  }

  @override
  void didUpdateWidget(ContextualHelpWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Reload help if context has changed
    if (oldWidget.sceneType != widget.sceneType ||
        oldWidget.userLevel != widget.userLevel ||
        oldWidget.commonIssues != widget.commonIssues) {
      _loadContextualHelp();
    }
  }

  Future<void> _loadContextualHelp() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await widget.educationService.getContextualHelp(
        sceneType: widget.sceneType,
        cameraSettings: widget.cameraSettings,
        userLevel: widget.userLevel,
        commonIssues: widget.commonIssues,
      );
      
      final allSuggestions = response.tips.map((tip) => 
          HelpSuggestion(id: tip, suggestion: tip, title: tip)
      ).toList();
      
      // Sort by priority
      allSuggestions.sort((a, b) {
        const priorityOrder = {'high': 0, 'medium': 1, 'low': 2};
        return (priorityOrder[a.priority] ?? 2)
            .compareTo(priorityOrder[b.priority] ?? 2);
      });
      
      setState(() {
        _suggestions = allSuggestions.take(3).toList(); // Show top 3
        _isVisible = _suggestions.isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isVisible = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isVisible || _suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedSlide(
      offset: _isVisible ? Offset.zero : const Offset(0, 1),
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.all(16),
        child: Card(
          elevation: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      color: Colors.amber.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Photography Tips',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() => _isVisible = false);
                      },
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),
              
              // Suggestions
              Column(
                children: _suggestions.map((suggestion) {
                  return _buildSuggestionTile(suggestion);
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionTile(HelpSuggestion suggestion) {
    return ListTile(
      leading: _buildSuggestionIcon(suggestion.type),
      title: Text(
        suggestion.title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        suggestion.content,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _buildSuggestionAction(suggestion),
      onTap: () => _handleSuggestionTap(suggestion),
    );
  }

  Widget _buildSuggestionIcon(String type) {
    IconData iconData;
    Color color;

    switch (type) {
      case 'adjustment':
        iconData = Icons.tune;
        color = Colors.blue;
        break;
      case 'tutorial':
        iconData = Icons.school;
        color = Colors.green;
        break;
      case 'comparison':
        iconData = Icons.compare;
        color = Colors.purple;
        break;
      case 'glossary':
        iconData = Icons.book;
        color = Colors.orange;
        break;
      case 'tip':
        iconData = Icons.lightbulb;
        color = Colors.amber;
        break;
      default:
        iconData = Icons.help;
        color = Colors.grey;
    }

    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.1),
      child: Icon(iconData, color: color, size: 20),
    );
  }

  Widget _buildSuggestionAction(HelpSuggestion suggestion) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Text(
        suggestion.actionText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade700,
        ),
      ),
    );
  }

  void _handleSuggestionTap(HelpSuggestion suggestion) {
    switch (suggestion.type) {
      case 'tutorial':
        if (suggestion.actionTarget != null) {
          Navigator.pushNamed(
            context,
            '/tutorial-detail',
            arguments: suggestion.actionTarget,
          );
        }
        break;
      case 'comparison':
        if (suggestion.actionTarget != null) {
          Navigator.pushNamed(
            context,
            '/comparison-detail',
            arguments: suggestion.actionTarget,
          );
        }
        break;
      case 'adjustment':
        // Trigger camera parameter adjustment
        _showAdjustmentDialog(suggestion);
        break;
      case 'glossary':
        if (suggestion.actionTarget != null) {
          _showGlossaryTerm(suggestion.actionTarget!);
        }
        break;
      case 'tip':
        _showTipDialog(suggestion);
        break;
    }
  }

  void _showAdjustmentDialog(HelpSuggestion suggestion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(suggestion.title),
        content: Text(suggestion.content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement camera parameter adjustment
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Applied ${suggestion.title}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Text(suggestion.actionText),
          ),
        ],
      ),
    );
  }

  void _showTipDialog(HelpSuggestion suggestion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lightbulb, color: Colors.red.shade300),
            const SizedBox(width: 8),
            Expanded(child: Text(suggestion.title)),
          ],
        ),
        content: Text(suggestion.content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('GOT IT'),
          ),
        ],
      ),
    );
  }

  void _showGlossaryTerm(String term) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final glossaryTerm = await widget.educationService.getGlossaryTerm(term);
      
      Navigator.of(context).pop(); // Close loading dialog
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(glossaryTerm.term),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Simple Explanation:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(glossaryTerm.plainLanguageExplanation),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CLOSE'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/glossary', arguments: term);
              },
              child: const Text('LEARN MORE'),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading term: $e')),
      );
    }
  }
}