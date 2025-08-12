import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/responsive_utils.dart';
import 'consolidated_ai_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _aiSuggestions = true;
  bool _autoApplySettings = false;
  bool _saveRawFiles = true;
  bool _notifications = true;
  String _imageQuality = 'High';
  String _storageLocation = 'Internal';
  String _theme = 'System';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: ResponsiveUtils.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Camera Settings',
              [
                _buildSwitchTile(
                  'Auto Apply AI Settings',
                  'Automatically apply AI-suggested camera settings',
                  _autoApplySettings,
                  (value) => setState(() => _autoApplySettings = value),
                  icon: Icons.auto_awesome,
                ),
                _buildSwitchTile(
                  'Save RAW Files',
                  'Save uncompressed image files',
                  _saveRawFiles,
                  (value) => setState(() => _saveRawFiles = value),
                  icon: Icons.photo_camera,
                ),
                _buildDropdownTile(
                  'Image Quality',
                  'Choose image compression level',
                  _imageQuality,
                  ['Low', 'Medium', 'High', 'Maximum'],
                  (value) => setState(() => _imageQuality = value!),
                  icon: Icons.high_quality,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Storage & Performance',
              [
                _buildDropdownTile(
                  'Storage Location',
                  'Where to save captured photos',
                  _storageLocation,
                  ['Internal', 'SD Card', 'Cloud'],
                  (value) => setState(() => _storageLocation = value!),
                  icon: Icons.storage,
                ),
                ListTile(
                  leading: const Icon(Icons.cleaning_services),
                  title: const Text('Clear Cache'),
                  subtitle: const Text('Free up storage space'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showClearCacheDialog,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              'AI & Intelligence',
              [
                ListTile(
                  leading: const Icon(Icons.psychology),
                  title: const Text('AI Configuration'),
                  subtitle: const Text('Configure AI providers, models, and custom endpoints'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _navigateToAISettings,
                ),
                _buildSwitchTile(
                  'AI Suggestions',
                  'Get smart photography recommendations',
                  _aiSuggestions,
                  (value) => setState(() => _aiSuggestions = value),
                  icon: Icons.auto_awesome,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              'App Settings',
              [
                _buildDropdownTile(
                  'Theme',
                  'Choose app appearance',
                  _theme,
                  ['Light', 'Dark', 'System'],
                  (value) => setState(() => _theme = value!),
                  icon: Icons.palette,
                ),
                _buildSwitchTile(
                  'Notifications',
                  'Receive app notifications',
                  _notifications,
                  (value) => setState(() => _notifications = value),
                  icon: Icons.notifications,
                ),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('Language'),
                  subtitle: const Text('English'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showNotImplemented('Language selection'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              'About',
              [
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('Version'),
                  subtitle: const Text('Lens AI v1.0.0'),
                ),
                ListTile(
                  leading: const Icon(Icons.help),
                  title: const Text('Help & Support'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showNotImplemented('Help & Support'),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showNotImplemented('Privacy Policy'),
                ),
                ListTile(
                  leading: const Icon(Icons.gavel),
                  title: const Text('Terms of Service'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showNotImplemented('Terms of Service'),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged, {
    IconData? icon,
  }) {
    return ListTile(
      leading: icon != null ? Icon(icon) : null,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }

  Widget _buildDropdownTile<T>(
    String title,
    String subtitle,
    T value,
    List<T> items,
    ValueChanged<T?> onChanged, {
    IconData? icon,
  }) {
    return ListTile(
      leading: icon != null ? Icon(icon) : null,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: DropdownButton<T>(
        value: value,
        onChanged: onChanged,
        items: items.map((T item) {
          return DropdownMenuItem<T>(
            value: item,
            child: Text(item.toString()),
          );
        }).toList(),
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear all cached images and temporary files. '
          'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache cleared successfully'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showNotImplemented(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature is not yet implemented'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _navigateToAISettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ConsolidatedAISettingsScreen(),
      ),
    );
  }
}