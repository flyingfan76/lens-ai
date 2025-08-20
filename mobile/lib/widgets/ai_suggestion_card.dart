import 'dart:ui';
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
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  gradient: _getGradientForType(widget.suggestion.type),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _getColorForType(widget.suggestion.type).withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                      spreadRadius: -2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: widget.isCompact ? _buildCompactCard() : _buildFullCard(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactCard() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildIcon(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.suggestion.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.suggestion.message,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (widget.suggestion.actionable) ...[
            _buildCompactApplyButton(),
            const SizedBox(width: 8),
          ],
          _buildDismissButton(),
        ],
      ),
    );
  }

  Widget _buildFullCard() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildIcon(),
              const SizedBox(width: 14),
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
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        _buildConfidenceBadge(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getColorForType(widget.suggestion.type).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getTypeLabel(widget.suggestion.type),
                        style: TextStyle(
                          color: _getColorForType(widget.suggestion.type),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildDismissButton(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.suggestion.message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w400,
            ),
          ),
          if (widget.suggestion.explanation != null) ...[
            const SizedBox(height: 12),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isExpanded ? 'Hide details' : 'Why this suggestion?',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (_isExpanded && widget.suggestion.explanation != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
              child: Text(
                widget.suggestion.explanation!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (widget.suggestion.actionable) ...[
                Expanded(child: _buildApplyButton()),
                const SizedBox(width: 12),
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
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getColorForType(widget.suggestion.type).withValues(alpha: 0.3),
            _getColorForType(widget.suggestion.type).withValues(alpha: 0.2),
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _getColorForType(widget.suggestion.type).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        _getIconForSuggestion(widget.suggestion),
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _buildConfidenceBadge() {
    final confidence = (widget.suggestion.confidence * 100).round();
    Color badgeColor = confidence >= 80 
        ? AppColors.success 
        : confidence >= 60 
            ? AppColors.warning 
            : AppColors.error;
            
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            badgeColor.withValues(alpha: 0.2),
            badgeColor.withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$confidence%',
            style: TextStyle(
              color: badgeColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactApplyButton() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onApply?.call(widget.suggestion),
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_fix_high_rounded,
                size: 14,
                color: _getColorForType(widget.suggestion.type),
              ),
              const SizedBox(width: 4),
              Text(
                'Apply',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _getColorForType(widget.suggestion.type),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApplyButton() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.white.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onApply?.call(widget.suggestion),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_fix_high_rounded,
                  size: 18,
                  color: _getColorForType(widget.suggestion.type),
                ),
                const SizedBox(width: 8),
                Text(
                  'Apply Settings',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _getColorForType(widget.suggestion.type),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShowOverlayButton() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _showCompositionOverlay();
          },
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.grid_on_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Show Guide',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDismissButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onDismiss?.call(widget.suggestion),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.close_rounded,
            color: Colors.white.withValues(alpha: 0.8),
            size: 16,
          ),
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
      stops: const [0.0, 0.5, 1.0],
      colors: [
        Colors.black.withValues(alpha: 0.7),
        primaryColor.withValues(alpha: 0.15),
        Colors.black.withValues(alpha: 0.8),
      ],
    );
  }

  Color _getColorForType(AISuggestionType type) {
    switch (type) {
      case AISuggestionType.cameraSettings:
        return AppColors.primary;
      case AISuggestionType.composition:
        return AppColors.purple;
      case AISuggestionType.technique:
        return AppColors.accent;
      case AISuggestionType.timing:
        return AppColors.teal;
      case AISuggestionType.creative:
        return AppColors.pink;
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