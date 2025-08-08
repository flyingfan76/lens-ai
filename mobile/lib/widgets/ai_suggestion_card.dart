import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/ai_suggestion.dart';
import '../core/utils/disposal_mixin.dart';

class AISuggestionCard extends StatefulWidget {
  final AISuggestion suggestion;
  final Function(AISuggestion)? onApply;
  final Function(AISuggestion)? onDismiss;
  final bool isCompact;

  const AISuggestionCard({
    super.key,
    required this.suggestion,
    this.onApply,
    this.onDismiss,
    this.isCompact = false,
  });

  @override
  State<AISuggestionCard> createState() => _AISuggestionCardState();
}

class _AISuggestionCardState extends State<AISuggestionCard>
    with SingleTickerProviderStateMixin, DisposalMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = createAnimationController(
      duration: const Duration(milliseconds: 300),
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    // DisposalMixin will handle animation controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            gradient: _getGradientForType(widget.suggestion.type),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _getColorForType(widget.suggestion.type).withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: widget.isCompact ? _buildCompactCard() : _buildFullCard(),
        ),
      ),
    );
  }

  Widget _buildCompactCard() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _buildIcon(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.suggestion.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.suggestion.message,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (widget.suggestion.actionable) _buildApplyButton(),
          _buildDismissButton(),
        ],
      ),
    );
  }

  Widget _buildFullCard() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.suggestion.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _buildConfidenceBadge(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getTypeLabel(widget.suggestion.type),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _buildDismissButton(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.suggestion.message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          if (widget.suggestion.explanation != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Row(
                children: [
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Why?',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_isExpanded && widget.suggestion.explanation != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.suggestion.explanation!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (widget.suggestion.actionable) ...[
                Expanded(child: _buildApplyButton()),
                const SizedBox(width: 8),
              ],
              if (widget.suggestion.type == AISuggestionType.composition)
                Expanded(child: _buildShowOverlayButton()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(
        _getIconForSuggestion(widget.suggestion),
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _buildConfidenceBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${(widget.suggestion.confidence * 100).round()}%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildApplyButton() {
    return ElevatedButton.icon(
      onPressed: () => widget.onApply?.call(widget.suggestion),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: _getColorForType(widget.suggestion.type),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
      ),
      icon: const Icon(Icons.tune, size: 16),
      label: Text(
        'Apply',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildShowOverlayButton() {
    return OutlinedButton.icon(
      onPressed: () {
        // Show composition overlay
        _showCompositionOverlay();
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      icon: const Icon(Icons.grid_on, size: 16),
      label: Text(
        'Show Guide',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDismissButton() {
    return GestureDetector(
      onTap: () => widget.onDismiss?.call(widget.suggestion),
      child: Container(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.close,
          color: Colors.white.withValues(alpha: 0.7),
          size: 16,
        ),
      ),
    );
  }

  void _showCompositionOverlay() {
    // Implementation to show composition guides
    // This would trigger overlay display in the camera view
  }

  LinearGradient _getGradientForType(AISuggestionType type) {
    Color primaryColor = _getColorForType(type);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        primaryColor.withValues(alpha: 0.8),
        primaryColor.withValues(alpha: 0.6),
        primaryColor.withValues(alpha: 0.4),
      ],
    );
  }

  Color _getColorForType(AISuggestionType type) {
    switch (type) {
      case AISuggestionType.cameraSettings:
        return AppColors.primary;
      case AISuggestionType.composition:
        return Colors.purple;
      case AISuggestionType.technique:
        return Colors.orange;
      case AISuggestionType.timing:
        return Colors.teal;
      case AISuggestionType.creative:
        return Colors.pink;
    }
  }

  String _getTypeLabel(AISuggestionType type) {
    switch (type) {
      case AISuggestionType.cameraSettings:
        return 'Camera Settings';
      case AISuggestionType.composition:
        return 'Composition';
      case AISuggestionType.technique:
        return 'Technique';
      case AISuggestionType.timing:
        return 'Timing';
      case AISuggestionType.creative:
        return 'Creative';
    }
  }

  IconData _getIconForSuggestion(AISuggestion suggestion) {
    if (suggestion.icon != null) {
      // Map string icons to IconData
      switch (suggestion.icon) {
        // Basic camera settings
        case 'iso':
          return Icons.iso;
        case 'aperture':
          return Icons.camera;
        case 'shutter_speed':
          return Icons.shutter_speed;
        case 'wb_sunny':
          return Icons.wb_sunny;
        case 'wb_shade':
          return Icons.wb_shade;
        
        // Advanced camera settings
        case 'flash_on':
          return Icons.flash_on;
        case 'flash_off':
          return Icons.flash_off;
        case 'center_focus_strong':
          return Icons.center_focus_strong;
        case 'zoom_in':
          return Icons.zoom_in;
        case 'zoom_out':
          return Icons.zoom_out;
        case 'videocam_off':
          return Icons.videocam_off;
        case 'exposure':
          return Icons.exposure;
        case 'hdr_on':
          return Icons.hdr_on;
        case 'hdr_off':
          return Icons.hdr_off;
        case 'portrait':
          return Icons.portrait;
        case 'landscape':
          return Icons.landscape;
        case 'auto_fix_high':
          return Icons.auto_fix_high;
        case 'settings_brightness':
          return Icons.settings_brightness;
        case 'contrast':
          return Icons.contrast;
        case 'palette':
          return Icons.palette;
        case 'photo_size_select_large':
          return Icons.photo_size_select_large;
        case 'aspect_ratio':
          return Icons.aspect_ratio;
        case 'timer':
          return Icons.timer;
        case 'burst_mode':
          return Icons.burst_mode;
        case 'lock':
          return Icons.lock;
        case 'lock_open':
          return Icons.lock_open;
        
        // Composition
        case 'grid_on':
          return Icons.grid_on;
        case 'crop':
          return Icons.crop;
        
        // Other
        case 'cloud':
          return Icons.cloud;
        case 'brightness_low':
          return Icons.brightness_low;
        case 'architecture':
          return Icons.architecture;
        default:
          return Icons.auto_awesome;
      }
    }
    
    // Fallback based on type
    switch (suggestion.type) {
      case AISuggestionType.cameraSettings:
        return Icons.tune;
      case AISuggestionType.composition:
        return Icons.crop;
      case AISuggestionType.technique:
        return Icons.photo_camera;
      case AISuggestionType.timing:
        return Icons.schedule;
      case AISuggestionType.creative:
        return Icons.palette;
    }
  }
}