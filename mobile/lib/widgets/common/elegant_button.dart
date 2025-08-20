import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Apple-style elegant button with proper haptic feedback and states
class ElegantButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Widget? icon;
  final ElegantButtonStyle style;
  final ElegantButtonSize size;
  final bool isLoading;
  final bool isFullWidth;
  final EdgeInsetsGeometry? margin;

  const ElegantButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.style = ElegantButtonStyle.primary,
    this.size = ElegantButtonSize.medium,
    this.isLoading = false,
    this.isFullWidth = false,
    this.margin,
  });

  @override
  State<ElegantButton> createState() => _ElegantButtonState();
}

class _ElegantButtonState extends State<ElegantButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppAnimations.fast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: AppAnimations.spring,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _animationController.forward();
      HapticFeedback.lightImpact();
    }
  }

  void _onTapUp(TapUpDetails details) {
    _animationController.reverse();
  }

  void _onTapCancel() {
    _animationController.reverse();
  }

  void _onTap() {
    if (widget.onPressed != null && !widget.isLoading) {
      HapticFeedback.mediumImpact();
      widget.onPressed!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonStyle = _getButtonStyle();
    final buttonSize = _getButtonSize();

    return Container(
      margin: widget.margin,
      width: widget.isFullWidth ? double.infinity : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: GestureDetector(
              onTapDown: _onTapDown,
              onTapUp: _onTapUp,
              onTapCancel: _onTapCancel,
              onTap: _onTap,
              child: AnimatedContainer(
                duration: AppAnimations.fast,
                curve: AppAnimations.spring,
                height: buttonSize.height,
                padding: EdgeInsets.symmetric(
                  horizontal: buttonSize.horizontalPadding,
                ),
                decoration: BoxDecoration(
                  gradient: widget.onPressed == null || widget.isLoading
                      ? null
                      : buttonStyle.gradient,
                  color: widget.onPressed == null || widget.isLoading
                      ? buttonStyle.disabledColor
                      : (buttonStyle.gradient == null ? buttonStyle.backgroundColor : null),
                  borderRadius: BorderRadius.circular(buttonSize.borderRadius),
                  border: buttonStyle.borderColor != null
                      ? Border.all(color: buttonStyle.borderColor!)
                      : null,
                  boxShadow: widget.onPressed == null || widget.isLoading
                      ? null
                      : buttonStyle.boxShadow,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.isLoading) ...[
                      SizedBox(
                        width: buttonSize.iconSize,
                        height: buttonSize.iconSize,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            buttonStyle.textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ] else if (widget.icon != null) ...[
                      IconTheme(
                        data: IconThemeData(
                          color: buttonStyle.textColor,
                          size: buttonSize.iconSize,
                        ),
                        child: widget.icon!,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    Flexible(
                      child: Text(
                        widget.text,
                        style: buttonSize.textStyle.copyWith(
                          color: buttonStyle.textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
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

  _ButtonStyle _getButtonStyle() {
    switch (widget.style) {
      case ElegantButtonStyle.primary:
        return _ButtonStyle(
          backgroundColor: AppColors.primary,
          textColor: Colors.white,
          gradient: AppColors.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: AppSpacing.lightShadowBlur,
              offset: const Offset(0, 4),
            ),
          ],
          disabledColor: AppColors.disabled,
        );

      case ElegantButtonStyle.accent:
        return _ButtonStyle(
          backgroundColor: AppColors.accent,
          textColor: Colors.white,
          gradient: AppColors.accentGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withOpacity(0.3),
              blurRadius: AppSpacing.lightShadowBlur,
              offset: const Offset(0, 4),
            ),
          ],
          disabledColor: AppColors.disabled,
        );

      case ElegantButtonStyle.secondary:
        return _ButtonStyle(
          backgroundColor: AppColors.surfaceElevated,
          textColor: AppColors.textPrimaryDark,
          borderColor: AppColors.borderDark,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: AppSpacing.lightShadowBlur,
              offset: const Offset(0, 2),
            ),
          ],
          disabledColor: AppColors.disabled.withOpacity(0.3),
        );

      case ElegantButtonStyle.destructive:
        return _ButtonStyle(
          backgroundColor: AppColors.error,
          textColor: Colors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.error.withOpacity(0.3),
              blurRadius: AppSpacing.lightShadowBlur,
              offset: const Offset(0, 4),
            ),
          ],
          disabledColor: AppColors.disabled,
        );

      case ElegantButtonStyle.ghost:
        return _ButtonStyle(
          backgroundColor: Colors.transparent,
          textColor: AppColors.primary,
          borderColor: AppColors.primary.withOpacity(0.3),
          disabledColor: AppColors.disabled.withOpacity(0.1),
        );

      case ElegantButtonStyle.glass:
        return _ButtonStyle(
          backgroundColor: AppColors.glass,
          textColor: AppColors.textPrimaryDark,
          gradient: AppColors.glassGradient,
          borderColor: AppColors.borderDark,
          disabledColor: AppColors.disabled.withOpacity(0.1),
        );
    }
  }

  _ButtonSize _getButtonSize() {
    switch (widget.size) {
      case ElegantButtonSize.small:
        return _ButtonSize(
          height: AppSpacing.smallButtonHeight,
          horizontalPadding: AppSpacing.md,
          borderRadius: AppSpacing.smallRadius,
          textStyle: AppTypography.footnoteRegular,
          iconSize: 16,
        );

      case ElegantButtonSize.medium:
        return _ButtonSize(
          height: AppSpacing.buttonHeight,
          horizontalPadding: AppSpacing.lg,
          borderRadius: AppSpacing.buttonRadius,
          textStyle: AppTypography.bodyMedium,
          iconSize: 20,
        );

      case ElegantButtonSize.large:
        return _ButtonSize(
          height: AppSpacing.largeButtonHeight,
          horizontalPadding: AppSpacing.xl,
          borderRadius: AppSpacing.buttonRadius,
          textStyle: AppTypography.headlineBold,
          iconSize: 24,
        );
    }
  }
}

/// Floating Action Button with Apple-style design
class ElegantFloatingButton extends StatefulWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double size;
  final bool showShadow;

  const ElegantFloatingButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
    this.size = 56.0,
    this.showShadow = true,
  });

  @override
  State<ElegantFloatingButton> createState() => _ElegantFloatingButtonState();
}

class _ElegantFloatingButtonState extends State<ElegantFloatingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppAnimations.fast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: AppAnimations.spring,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed != null) {
      _animationController.forward();
      HapticFeedback.lightImpact();
    }
  }

  void _onTapUp(TapUpDetails details) {
    _animationController.reverse();
  }

  void _onTapCancel() {
    _animationController.reverse();
  }

  void _onTap() {
    if (widget.onPressed != null) {
      HapticFeedback.mediumImpact();
      widget.onPressed!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            onTap: _onTap,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.backgroundColor ?? AppColors.accent,
                shape: BoxShape.circle,
                boxShadow: widget.showShadow ? [
                  BoxShadow(
                    color: (widget.backgroundColor ?? AppColors.accent).withOpacity(0.3),
                    blurRadius: AppSpacing.shadowBlur,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: AppSpacing.lightShadowBlur,
                    offset: const Offset(0, 2),
                  ),
                ] : null,
              ),
              child: IconTheme(
                data: IconThemeData(
                  color: widget.foregroundColor ?? Colors.white,
                  size: widget.size * 0.4,
                ),
                child: widget.icon,
              ),
            ),
          ),
        );
      },
    );
  }
}

enum ElegantButtonStyle {
  primary,
  accent,
  secondary,
  destructive,
  ghost,
  glass,
}

enum ElegantButtonSize {
  small,
  medium,
  large,
}

class _ButtonStyle {
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final Gradient? gradient;
  final List<BoxShadow>? boxShadow;
  final Color disabledColor;

  _ButtonStyle({
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
    this.gradient,
    this.boxShadow,
    required this.disabledColor,
  });
}

class _ButtonSize {
  final double height;
  final double horizontalPadding;
  final double borderRadius;
  final TextStyle textStyle;
  final double iconSize;

  _ButtonSize({
    required this.height,
    required this.horizontalPadding,
    required this.borderRadius,
    required this.textStyle,
    required this.iconSize,
  });
}