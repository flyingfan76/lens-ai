import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Configuration card component for grouping related settings
class ConfigurationCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> children;
  final EdgeInsets margin;
  final EdgeInsets padding;
  final Color? backgroundColor;
  final bool showBorder;
  final VoidCallback? onTap;

  const ConfigurationCard({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    required this.children,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.showBorder = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Card(
        color: backgroundColor ?? const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: showBorder
              ? const BorderSide(color: Colors.white12)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  subtitle!,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (children.isNotEmpty) const SizedBox(height: 16),
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

/// Status indicator card for showing service status
class StatusCard extends StatelessWidget {
  final String title;
  final String status;
  final StatusType statusType;
  final String? description;
  final Widget? action;
  final VoidCallback? onTap;

  const StatusCard({
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
    return ConfigurationCard(
      onTap: onTap,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _getStatusColor(),
                shape: BoxShape.circle,
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
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: TextStyle(
                      color: _getStatusColor(),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      description!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
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
        return Colors.green;
      case StatusType.warning:
        return Colors.orange;
      case StatusType.error:
        return Colors.red;
      case StatusType.info:
        return AppColors.accent;
    }
  }
}

/// Connection test card for testing endpoint connectivity
class ConnectionTestCard extends StatefulWidget {
  final String title;
  final String endpoint;
  final Future<bool> Function() onTest;
  final VoidCallback? onConfigure;

  const ConnectionTestCard({
    super.key,
    required this.title,
    required this.endpoint,
    required this.onTest,
    this.onConfigure,
  });

  @override
  State<ConnectionTestCard> createState() => _ConnectionTestCardState();
}

class _ConnectionTestCardState extends State<ConnectionTestCard> {
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
    return ConfigurationCard(
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
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.endpoint,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_lastError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _lastError!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (_lastResult != null && !_isLoading)
              Icon(
                _lastResult! ? Icons.check_circle : Icons.error,
                color: _lastResult! ? Colors.green : Colors.red,
                size: 20,
              ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _runTest,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  : const Text('Test'),
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
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Configure',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

enum StatusType { success, warning, error, info }