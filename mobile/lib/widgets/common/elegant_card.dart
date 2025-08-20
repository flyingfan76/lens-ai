import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Elegant Apple-style card with refined shadows and minimal styling
class ElegantCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> children;
  final EdgeInsets margin;
  final EdgeInsets padding;
  final Color? backgroundColor;
  final bool showBorder;
  final bool showShadow;
  final VoidCallback? onTap;
  final double borderRadius;

  const ElegantCard({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    required this.children,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6), // Reduced vertical margin
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.showBorder = false, // Disabled by default for cleaner look
    this.showShadow = true,
    this.onTap,
    this.borderRadius = 16, // Increased border radius for modern look
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: showShadow ? [
          // Subtle shadow for depth
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          // Additional soft shadow for iOS-like effect
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ] : null,
      ),
      child: Card(
        elevation: 0, // Remove default elevation, use custom shadow
        color: backgroundColor ?? const Color(0xFF1C1C1E), // Slightly lighter than pure black
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: showBorder
              ? BorderSide(color: Colors.white.withOpacity(0.06))
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null || leading != null) ...[
                  Row(
                    children: [
                      if (leading != null) ...[
                        leading!,
                        const SizedBox(width: 12),
                      ],
                      if (title != null)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17, // iOS-standard font size
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.4, // Tighter letter spacing
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subtitle!,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (children.isNotEmpty) const SizedBox(height: 12), // Reduced spacing
                ],
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Elegant status card with refined indicators
class ElegantStatusCard extends StatelessWidget {
  final String title;
  final String status;
  final StatusType statusType;
  final String? description;
  final Widget? action;
  final VoidCallback? onTap;

  const ElegantStatusCard({
    super.key,
    required this.title,
    required this.status,
    required this.statusType,
    this.description,
    this.action,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElegantCard(
      onTap: onTap,
      children: [
        Row(
          children: [
            Container(
              width: 8, // Smaller indicator
              height: 8,
              decoration: BoxDecoration(
                color: _getStatusColor(),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _getStatusColor().withOpacity(0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status,
                    style: TextStyle(
                      color: _getStatusColor(),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      description!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (action != null) action!,
          ],
        ),
      ],
    );
  }

  Color _getStatusColor() {
    switch (statusType) {
      case StatusType.success:
        return const Color(0xFF34C759); // iOS green
      case StatusType.warning:
        return const Color(0xFFFF9F0A); // iOS orange
      case StatusType.error:
        return const Color(0xFFFF3B30); // iOS red
      case StatusType.info:
        return AppColors.accent;
    }
  }
}

/// Elegant connection test card with refined button styling
class ElegantConnectionTestCard extends StatefulWidget {
  final String title;
  final String endpoint;
  final Future<bool> Function() onTest;
  final VoidCallback? onConfigure;

  const ElegantConnectionTestCard({
    super.key,
    required this.title,
    required this.endpoint,
    required this.onTest,
    this.onConfigure,
  });

  @override
  State<ElegantConnectionTestCard> createState() => _ElegantConnectionTestCardState();
}

class _ElegantConnectionTestCardState extends State<ElegantConnectionTestCard> {
  bool _isLoading = false;
  bool? _lastResult;
  String? _lastError;

  Future<void> _runTest() async {
    setState(() {
      _isLoading = true;
      _lastError = null;
    });

    try {
      final result = await widget.onTest();
      setState(() {
        _lastResult = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _lastResult = false;
        _lastError = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElegantCard(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.endpoint,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_lastError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _lastError!,
                      style: const TextStyle(
                        color: Color(0xFFFF3B30), // iOS red
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (_lastResult != null && !_isLoading)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (_lastResult! ? const Color(0xFF34C759) : const Color(0xFFFF3B30)).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _lastResult! ? Icons.check : Icons.close,
                  color: _lastResult! ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
                  size: 16,
                ),
              ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  colors: [
                    AppColors.accent,
                    AppColors.accent.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _runTest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Test',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
        if (widget.onConfigure != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: widget.onConfigure,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withOpacity(0.2)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Configure',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

enum StatusType { success, warning, error, info }