import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Standard settings row component for consistent UI across all settings screens
class SettingsRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final bool showDivider;
  final EdgeInsets? contentPadding;

  const SettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.showDivider = true,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: Text(
            title,
            style: TextStyle(
              color: enabled ? Colors.white : Colors.white54,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle!,
                  style: TextStyle(
                    color: enabled ? Colors.white70 : Colors.white38,
                    fontSize: 14,
                  ),
                )
              : null,
          leading: leading,
          trailing: trailing != null 
              ? SizedBox(
                  width: 120, // Constrain trailing widget
                  child: trailing,
                )
              : null,
          onTap: enabled ? onTap : null,
          contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          enabled: enabled,
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: Colors.white12,
            indent: leading != null ? 72 : 20,
            endIndent: 20,
          ),
      ],
    );
  }
}

/// Settings row with a switch toggle
class SettingsSwitchRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;
  final bool showDivider;

  const SettingsSwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.value,
    this.onChanged,
    this.enabled = true,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsRow(
      title: title,
      subtitle: subtitle,
      leading: leading,
      trailing: Switch(
        value: value,
        onChanged: enabled ? onChanged : null,
        activeColor: AppColors.accent,
        inactiveThumbColor: Colors.white54,
        inactiveTrackColor: Colors.white24,
      ),
      enabled: enabled,
      showDivider: showDivider,
      onTap: enabled ? () => onChanged?.call(!value) : null,
    );
  }
}

/// Settings row with dropdown selection
class SettingsDropdownRow<T> extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool enabled;
  final bool showDivider;

  const SettingsDropdownRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.value,
    required this.items,
    this.onChanged,
    this.enabled = true,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsRow(
      title: title,
      subtitle: subtitle,
      leading: leading,
      trailing: SizedBox(
        width: 200, // Fixed width to prevent overflow
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: enabled ? onChanged : null,
          underline: const SizedBox(),
          dropdownColor: const Color(0xFF2A2A2A),
          style: const TextStyle(color: Colors.white),
          icon: Icon(
            Icons.arrow_drop_down,
            color: enabled ? Colors.white70 : Colors.white38,
          ),
          isExpanded: true, // Make dropdown take full width of container
        ),
      ),
      enabled: enabled,
      showDivider: showDivider,
    );
  }
}

/// Settings row with text input
class SettingsTextFieldRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final String? value;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final bool enabled;
  final bool showDivider;
  final TextInputType? keyboardType;
  final int? maxLines;

  const SettingsTextFieldRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.value,
    this.hintText,
    this.onChanged,
    this.obscureText = false,
    this.enabled = true,
    this.showDivider = true,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
              const SizedBox(height: 12),
              TextField(
                controller: TextEditingController(text: value),
                onChanged: enabled ? onChanged : null,
                enabled: enabled,
                obscureText: obscureText,
                keyboardType: keyboardType,
                maxLines: maxLines,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white12,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.accent),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: Colors.white12,
            indent: leading != null ? 56 : 20,
            endIndent: 20,
          ),
      ],
    );
  }
}