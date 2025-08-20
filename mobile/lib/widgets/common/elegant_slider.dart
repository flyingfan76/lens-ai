import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Elegant Apple-style slider component with refined appearance
class ElegantSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChanged;
  final String? label;
  final bool enabled;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? thumbColor;

  const ElegantSlider({
    super.key,
    required this.value,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.onChanged,
    this.label,
    this.enabled = true,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32, // Reduced height for elegance
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          // Track styling
          trackHeight: 3.0, // Thinner track
          activeTrackColor: activeColor ?? AppColors.accent,
          inactiveTrackColor: inactiveColor ?? Colors.white.withOpacity(0.15),
          
          // Thumb styling
          thumbColor: thumbColor ?? AppColors.accent,
          thumbShape: const RoundSliderThumbShape(
            enabledThumbRadius: 8.0, // Smaller thumb
            elevation: 2.0, // Subtle shadow
            pressedElevation: 4.0,
          ),
          
          // Overlay styling
          overlayColor: (activeColor ?? AppColors.accent).withOpacity(0.12),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
          
          // Tick marks (if divisions are used)
          tickMarkShape: const RoundSliderTickMarkShape(
            tickMarkRadius: 1.5,
          ),
          activeTickMarkColor: activeColor ?? AppColors.accent,
          inactiveTickMarkColor: Colors.white.withOpacity(0.3),
          
          // Value indicator
          valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
          valueIndicatorColor: activeColor ?? AppColors.accent,
          valueIndicatorTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          label: label,
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}

/// Settings row specifically designed for elegant sliders
class SettingsSliderRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChanged;
  final String Function(double)? valueFormatter;
  final bool enabled;
  final bool showDivider;
  final EdgeInsets? contentPadding;

  const SettingsSliderRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.value,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.onChanged,
    this.valueFormatter,
    this.enabled = true,
    this.showDivider = true,
    this.contentPadding,
  });

  String _formatValue(double value) {
    if (valueFormatter != null) {
      return valueFormatter!(value);
    }
    
    // Default formatting
    if (divisions != null) {
      return value.toInt().toString();
    } else {
      return '${(value * 100).toInt()}%';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with title and value
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (leading != null) ...[
                          leading!,
                          const SizedBox(width: 16),
                        ],
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: enabled ? Colors.white : Colors.white54,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Value display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formatValue(value),
                      style: TextStyle(
                        color: enabled ? AppColors.accent : Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              
              // Subtitle if provided
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: enabled ? Colors.white70 : Colors.white38,
                    fontSize: 14,
                  ),
                ),
              ],
              
              // Elegant slider
              const SizedBox(height: 8),
              ElegantSlider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                onChanged: enabled ? onChanged : null,
                enabled: enabled,
              ),
            ],
          ),
        ),
        
        // Divider
        if (showDivider)
          Divider(
            height: 1,
            color: Colors.white.withOpacity(0.08),
            indent: leading != null ? 56 : 20,
            endIndent: 20,
          ),
      ],
    );
  }
}