import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/responsive_utils.dart';
import '../core/providers/unified_camera_provider.dart';
import '../models/external_camera.dart';
import '../services/external_camera_service.dart';
import 'consolidated_ai_settings_screen.dart';
import 'dart:async';

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
  
  // Camera management state
  bool _isScanningCameras = false;
  ExternalCamera? _connectedCamera;
  List<ExternalCamera> _discoveredCameras = [];
  StreamSubscription<List<ExternalCamera>>? _cameraStreamSubscription;
  
  @override
  void initState() {
    super.initState();
    _initializeCameraState();
  }
  
  @override
  void dispose() {
    _cameraStreamSubscription?.cancel();
    super.dispose();
  }
  
  void _initializeCameraState() {
    final cameraService = ExternalCameraService();
    
    // Subscribe to camera discoveries
    _cameraStreamSubscription = cameraService.cameraStream.listen((cameras) {
      setState(() {
        _discoveredCameras = cameras;
        // Check if any camera is connected
        final connectedCameras = cameras.where((c) => c.isConnected);
        _connectedCamera = connectedCameras.isNotEmpty ? connectedCameras.first : null;
      });
    });
    
    // Get initial camera state
    _discoveredCameras = cameraService.discoveredCameras;
    final connectedCameras = _discoveredCameras.where((c) => c.isConnected);
    _connectedCamera = connectedCameras.isNotEmpty ? connectedCameras.first : null;
  }

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
              'Camera Management',
              [
                ListTile(
                  leading: Icon(
                    Icons.camera_alt,
                    color: _connectedCamera != null ? Colors.green : Colors.grey,
                  ),
                  title: Text(_connectedCamera != null 
                      ? 'Connected Camera' 
                      : 'No Camera Connected'),
                  subtitle: Text(_connectedCamera != null 
                      ? '${_connectedCamera!.name} (${_connectedCamera!.brand.name.toUpperCase()})'
                      : 'Scan for external cameras'),
                  trailing: _connectedCamera != null 
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Connected',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                ),
                ListTile(
                  leading: Icon(
                    Icons.search,
                    color: _isScanningCameras ? AppColors.primary : null,
                  ),
                  title: const Text('Scan for Cameras'),
                  subtitle: Text(_isScanningCameras 
                      ? 'Scanning for external cameras...' 
                      : 'Search for USB and WiFi cameras'),
                  trailing: _isScanningCameras 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _isScanningCameras ? null : _scanForCameras,
                ),
                if (_discoveredCameras.isNotEmpty) ...[
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Discovered Cameras',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  ..._discoveredCameras.map((camera) => _buildCameraListTile(camera)),
                ],
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
  
  Future<void> _scanForCameras() async {
    if (_isScanningCameras) return;
    
    setState(() {
      _isScanningCameras = true;
    });
    
    try {
      final cameraService = ExternalCameraService();
      
      // Stop and restart discovery to ensure fresh scan
      await cameraService.stopDiscovery();
      await cameraService.startDiscovery();
      
      // Show scanning feedback for minimum time
      await Future.delayed(const Duration(seconds: 2));
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _discoveredCameras.isEmpty 
                ? 'No external cameras found. Make sure cameras are connected and powered on.'
                : 'Found ${_discoveredCameras.length} camera(s)',
          ),
          backgroundColor: _discoveredCameras.isEmpty ? Colors.orange : AppColors.primary,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error scanning for cameras: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isScanningCameras = false;
      });
    }
  }
  
  Widget _buildCameraListTile(ExternalCamera camera) {
    return ListTile(
      leading: Icon(
        _getCameraIcon(camera.brand),
        color: camera.isConnected ? Colors.green : Colors.grey,
      ),
      title: Text(camera.name),
      subtitle: Text('${camera.brand.name.toUpperCase()} • ${camera.connectionType.name.toUpperCase()}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: camera.isConnected ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              camera.isConnected ? 'Connected' : 'Available',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (!camera.isConnected) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.link, size: 20),
              onPressed: () => _connectToCamera(camera),
              tooltip: 'Connect to camera',
            ),
          ],
        ],
      ),
    );
  }
  
  IconData _getCameraIcon(CameraBrand brand) {
    switch (brand) {
      case CameraBrand.nikon:
        return Icons.camera_alt;
      case CameraBrand.canon:
        return Icons.camera;
      case CameraBrand.sony:
        return Icons.camera_enhance;
      default:
        return Icons.camera_alt_outlined;
    }
  }
  
  Future<void> _connectToCamera(ExternalCamera camera) async {
    try {
      final cameraProvider = Provider.of<UnifiedCameraProvider>(context, listen: false);
      final success = await cameraProvider.switchToExternalCamera(camera);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${camera.name}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect to ${camera.name}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}