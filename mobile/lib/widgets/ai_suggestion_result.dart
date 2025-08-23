import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../services/ai_response_parser.dart';

/// Widget to display AI analysis results with camera settings and composition suggestions
class AISuggestionResult extends StatefulWidget {
  final ParsedAIResponse response;
  final Function(Map<String, dynamic>)? onApplyCameraSettings;
  final bool isCompact;

  const AISuggestionResult({
    super.key,
    required this.response,
    this.onApplyCameraSettings,
    this.isCompact = false,
  });

  @override
  State<AISuggestionResult> createState() => _AISuggestionResultState();
}

class _AISuggestionResultState extends State<AISuggestionResult> {
  bool _isApplying = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isCompact) {
      return _buildCompactView();
    } else {
      return _buildFullView();
    }
  }

  Widget _buildCompactView() {
    return Card(
      color: Colors.black.withValues(alpha: 0.8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: AppColors.accent,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI Recommendations',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.response.cameraSettings.isNotEmpty)
                  _buildApplyButton(),
              ],
            ),
            if (widget.response.displaySuggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildCompositionSuggestionsCompact(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFullView() {
    return Card(
      color: Colors.black.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            
            // Camera Settings Section
            if (widget.response.cameraSettings.isNotEmpty) ...[
              _buildCameraSettingsSection(),
              const SizedBox(height: 16),
            ],
            
            // Composition Suggestions Section  
            if (widget.response.displaySuggestions.isNotEmpty) ...[
              _buildCompositionSuggestionsSection(),
              const SizedBox(height: 12),
            ],
            
            // Apply Settings Button
            if (widget.response.cameraSettings.isNotEmpty)
              _buildApplyButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.accent, AppColors.accent.withValues(alpha: 0.7)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.auto_awesome,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI Analysis Complete',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${widget.response.provider} • ${(widget.response.confidence * 100).round()}% confidence',
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

  Widget _buildCameraSettingsSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune,
                color: AppColors.primary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Camera Settings',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatCameraSettings(widget.response.cameraSettings),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompositionSuggestionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.grid_on,
              color: Colors.purple,
              size: 16,
            ),
            const SizedBox(width: 8),
            const Text(
              'Composition Tips',
              style: TextStyle(
                color: Colors.purple,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildCompositionSuggestionsList(), 
      ],
    );
  }

  Widget _buildCompositionSuggestionsCompact() {
    if (widget.response.displaySuggestions.isEmpty) return const SizedBox.shrink();
    
    return Column(
      children: widget.response.displaySuggestions.take(2).map((suggestion) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Icon(
                _getIconData(suggestion.icon),
                color: Colors.purple,
                size: 12,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  suggestion.title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCompositionSuggestionsList() {
    return Column(
      children: widget.response.displaySuggestions.map((suggestion) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.purple.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _getIconData(suggestion.icon),
                color: Colors.purple,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (suggestion.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        suggestion.description,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildApplyButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isApplying ? null : _applyCameraSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        icon: _isApplying 
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.tune, size: 16),
        label: Text(
          _isApplying ? 'Applying...' : 'Apply Camera Settings',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _formatCameraSettings(Map<String, dynamic> settings) {
    final parts = <String>[];
    
    if (settings['iso'] != null) {
      parts.add('ISO ${settings['iso']?.toInt()}');
    }
    
    if (settings['aperture'] != null) {
      parts.add('f/${settings['aperture']?.toStringAsFixed(1)}');
    }
    
    if (settings['shutterSpeed'] != null) {
      final shutter = settings['shutterSpeed'] as double;
      if (shutter < 1) {
        parts.add('1/${(1/shutter).round()}s');
      } else {
        parts.add('${shutter.toStringAsFixed(1)}s');
      }
    }
    
    if (settings['whiteBalance'] != null) {
      parts.add('WB: ${settings['whiteBalance']}');
    }
    
    return parts.join(' • ');
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'zoom_in':
        return Icons.zoom_in;
      case 'zoom_out':
        return Icons.zoom_out;
      case 'grid_on':
        return Icons.grid_on;
      case 'landscape':
        return Icons.landscape;
      case 'portrait':
        return Icons.portrait;
      case 'architecture':
        return Icons.architecture;
      case 'hdr_on':
        return Icons.hdr_on;
      case 'wb_sunny':
        return Icons.wb_sunny;
      default:
        return Icons.auto_awesome;
    }
  }

  Future<void> _applyCameraSettings() async {
    if (widget.onApplyCameraSettings == null || _isApplying) return;

    setState(() {
      _isApplying = true;
    });

    try {
      // Apply camera settings directly through the callback
      widget.onApplyCameraSettings!(widget.response.cameraSettings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Camera settings applied'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply settings: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isApplying = false;
        });
      }
    }
  }
}