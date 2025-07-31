import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isDarkMode = false;
  bool _autoConnect = true;
  bool _aiSuggestions = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // User Profile Section
            _buildProfileHeader(),
            
            const SizedBox(height: 24),
            
            // Statistics Cards
            _buildStatsSection(),
            
            const SizedBox(height: 24),
            
            // Settings Sections
            _buildSettingsSection('Camera Settings', [
              _buildSettingsTile(
                icon: Icons.camera_alt,
                title: 'Connected Cameras',
                subtitle: '2 cameras paired',
                onTap: () => _showConnectedCameras(),
              ),
              _buildSwitchTile(
                icon: Icons.bluetooth,
                title: 'Auto-connect',
                subtitle: 'Automatically connect to nearby cameras',
                value: _autoConnect,
                onChanged: (value) {
                  setState(() {
                    _autoConnect = value;
                  });
                },
              ),
            ]),
            
            const SizedBox(height: 16),
            
            _buildSettingsSection('AI & Assistance', [
              _buildSwitchTile(
                icon: Icons.auto_awesome,
                title: 'AI Suggestions',
                subtitle: 'Get real-time photography tips',
                value: _aiSuggestions,
                onChanged: (value) {
                  setState(() {
                    _aiSuggestions = value;
                  });
                },
              ),
              _buildSettingsTile(
                icon: Icons.school,
                title: 'Learning Center',
                subtitle: 'Photography tutorials and tips',
                onTap: () {},
              ),
            ]),
            
            const SizedBox(height: 16),
            
            _buildSettingsSection('App Preferences', [
              _buildSwitchTile(
                icon: Icons.dark_mode,
                title: 'Dark Mode',
                subtitle: 'Use dark theme',
                value: _isDarkMode,
                onChanged: (value) {
                  setState(() {
                    _isDarkMode = value;
                  });
                },
              ),
              _buildSettingsTile(
                icon: Icons.notifications,
                title: 'Notifications',
                subtitle: 'Manage app notifications',
                onTap: () {},
              ),
              _buildSettingsTile(
                icon: Icons.cloud_sync,
                title: 'Cloud Sync',
                subtitle: 'Backup and sync photos',
                onTap: () {},
              ),
            ]),
            
            const SizedBox(height: 16),
            
            _buildSettingsSection('Support', [
              _buildSettingsTile(
                icon: Icons.help_outline,
                title: 'Help & FAQ',
                subtitle: 'Get help with Lens AI',
                onTap: () {},
              ),
              _buildSettingsTile(
                icon: Icons.feedback,
                title: 'Send Feedback',
                subtitle: 'Help us improve the app',
                onTap: () {},
              ),
              _buildSettingsTile(
                icon: Icons.info_outline,
                title: 'About',
                subtitle: 'Version 1.0.0',
                onTap: () => _showAboutDialog(),
              ),
            ]),
            
            const SizedBox(height: 32),
            
            // Sign Out Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Sign Out',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        // Avatar
        Stack(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              child: const Icon(
                Icons.person,
                size: 50,
                color: AppColors.primary,
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Name and title
        Text(
          'John Photographer',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 4),
        
        Text(
          'Amateur Photographer',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).brightness == Brightness.light
                ? AppColors.textSecondaryLight
                : AppColors.textSecondaryDark,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Achievement badges
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildBadge('🏆', 'Pro'),
            const SizedBox(width: 16),
            _buildBadge('⭐', 'Expert'),
            const SizedBox(width: 16),
            _buildBadge('🎯', 'Sharp'),
          ],
        ),
      ],
    );
  }

  Widget _buildBadge(String emoji, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Photos Taken', '1,247', Icons.photo_camera)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('AI Improvements', '342', Icons.auto_awesome)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Presets Used', '28', Icons.palette)),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              icon,
              color: AppColors.primary,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }

  void _showConnectedCameras() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connected Cameras'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt, color: AppColors.success),
              ),
              title: const Text('Canon EOS R5'),
              subtitle: const Text('Connected • Battery: 85%'),
              trailing: const Icon(Icons.check_circle, color: AppColors.success),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt, color: Colors.grey),
              ),
              title: const Text('Nikon D850'),
              subtitle: const Text('Last seen: 2 hours ago'),
              trailing: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.bluetooth_searching),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Add camera pairing logic
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Add Camera', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Lens AI',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.camera_alt,
          color: Colors.white,
          size: 32,
        ),
      ),
      children: [
        const Text('AI-powered mobile camera control and photography assistant.'),
        const SizedBox(height: 16),
        const Text('Made with ❤️ for photographers everywhere.'),
      ],
    );
  }
}