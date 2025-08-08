import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../services/sync_configuration.dart';

class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SyncConfigurationService _syncService = SyncConfigurationService.instance;
  
  late SyncConfiguration _config;
  List<SyncTarget> _syncTargets = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadConfiguration();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadConfiguration() async {
    setState(() => _isLoading = true);
    
    try {
      await _syncService.initialize();
      _config = _syncService.configuration;
      _syncTargets = _syncService.syncTargets;
    } catch (e) {
      debugPrint('Failed to load sync configuration: $e');
      _config = const SyncConfiguration();
      _syncTargets = [];
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Photo Sync Settings',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accent,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppColors.accent,
          tabs: const [
            Tab(text: 'Targets'),
            Tab(text: 'Settings'),
            Tab(text: 'Status'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTargetsTab(),
                _buildSettingsTab(),
                _buildStatusTab(),
              ],
            ),
    );
  }

  Widget _buildTargetsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sync Targets',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Configure where your photos will be synced. Photos are always stored locally first.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          
          // Add new sync target button
          Card(
            color: AppColors.accent.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _showAddSyncTargetDialog,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      color: AppColors.accent,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Sync Target',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Connect to cloud storage or network drive',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Existing sync targets
          if (_syncTargets.isEmpty)
            _buildEmptyTargetsState()
          else
            ..._syncTargets.map((target) => _buildSyncTargetCard(target)),
        ],
      ),
    );
  }

  Widget _buildEmptyTargetsState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off,
            color: Colors.white.withValues(alpha: 0.5),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'No Sync Targets Configured',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Photos will be stored locally only until you add a sync target',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSyncTargetCard(SyncTarget target) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: target.isEnabled 
          ? Colors.green.withValues(alpha: 0.1)
          : Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: target.isEnabled 
            ? Colors.green.withValues(alpha: 0.3)
            : Colors.grey[700]!,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: target.isEnabled 
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.grey[800],
          child: Icon(
            _getSyncTargetIcon(target.type),
            color: target.isEnabled ? Colors.green : Colors.white70,
          ),
        ),
        title: Text(
          target.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _syncService.getSyncTargetDisplayName(target.type),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            if (target.lastSyncAt != null)
              Text(
                'Last sync: ${_formatDateTime(target.lastSyncAt!)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
            if (target.lastSyncError != null)
              Text(
                'Error: ${target.lastSyncError}',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 11,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: target.isEnabled,
              onChanged: (enabled) => _toggleSyncTarget(target, enabled),
              activeColor: Colors.green,
            ),
            PopupMenuButton<String>(
              color: Colors.grey[800],
              onSelected: (action) => _handleSyncTargetAction(target, action),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit, color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      const Text('Edit', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'test',
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_find, color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      const Text('Test Connection', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      const Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sync Preferences',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          // Auto sync settings
          _buildSettingsCard(
            'Automatic Sync',
            [
              SwitchListTile(
                title: const Text('Auto-Sync', style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  'Automatically sync photos after capture',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
                value: _config.autoSyncEnabled,
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(autoSyncEnabled: value);
                  });
                  _saveConfiguration();
                },
                activeColor: AppColors.accent,
              ),
              SwitchListTile(
                title: const Text('WiFi Only', style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  'Only sync when connected to WiFi',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
                value: _config.syncOnWiFiOnly,
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(syncOnWiFiOnly: value);
                  });
                  _saveConfiguration();
                },
                activeColor: AppColors.accent,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Content sync settings
          _buildSettingsCard(
            'Content to Sync',
            [
              SwitchListTile(
                title: const Text('Original Photos', style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  'Sync full resolution images',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
                value: _config.syncOriginalPhotos,
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(syncOriginalPhotos: value);
                  });
                  _saveConfiguration();
                },
                activeColor: AppColors.accent,
              ),
              SwitchListTile(
                title: const Text('Metadata & Settings', style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  'Include EXIF data and camera settings',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
                value: _config.syncMetadata,
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(syncMetadata: value);
                  });
                  _saveConfiguration();
                },
                activeColor: AppColors.accent,
              ),
              SwitchListTile(
                title: const Text('AI Analysis', style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  'Sync AI suggestions and analysis',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
                value: _config.syncAIAnalysis,
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(syncAIAnalysis: value);
                  });
                  _saveConfiguration();
                },
                activeColor: AppColors.accent,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Advanced settings
          _buildSettingsCard(
            'Advanced',
            [
              ListTile(
                title: const Text('Max File Size', style: TextStyle(color: Colors.white)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Maximum file size: ${_config.maxFileSize}MB',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: _config.maxFileSize.toDouble(),
                      min: 1,
                      max: 200,
                      divisions: 199,
                      activeColor: AppColors.accent,
                      onChanged: (value) {
                        setState(() {
                          _config = _config.copyWith(maxFileSize: value.toInt());
                        });
                      },
                      onChangeEnd: (value) => _saveConfiguration(),
                    ),
                  ],
                ),
              ),
              ListTile(
                title: const Text('Sync Interval', style: TextStyle(color: Colors.white)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Check for sync every ${_config.syncIntervalMinutes} minutes',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: _config.syncIntervalMinutes.toDouble(),
                      min: 15,
                      max: 1440, // 24 hours
                      divisions: 97,
                      activeColor: AppColors.accent,
                      onChanged: (value) {
                        setState(() {
                          _config = _config.copyWith(syncIntervalMinutes: value.toInt());
                        });
                      },
                      onChangeEnd: (value) => _saveConfiguration(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sync Status',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          // Current status
          _buildStatusCard(),
          
          const SizedBox(height: 16),
          
          // Quick actions
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final hasTargets = _syncTargets.isNotEmpty;
    final enabledTargets = _syncTargets.where((t) => t.isEnabled).length;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasTargets && enabledTargets > 0 
                  ? Icons.cloud_done 
                  : Icons.cloud_off,
                color: hasTargets && enabledTargets > 0 
                  ? Colors.green 
                  : Colors.orange,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasTargets && enabledTargets > 0 
                        ? 'Sync Enabled'
                        : 'Local Storage Only',
                      style: TextStyle(
                        color: hasTargets && enabledTargets > 0 
                          ? Colors.green 
                          : Colors.orange,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      hasTargets && enabledTargets > 0 
                        ? '$enabledTargets sync target${enabledTargets > 1 ? 's' : ''} active'
                        : 'Photos stored locally only',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          if (hasTargets && enabledTargets > 0) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 16),
            
            ...(_syncTargets.where((t) => t.isEnabled).map((target) => 
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      _getSyncTargetIcon(target.type),
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        target.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      target.lastSyncAt != null 
                        ? 'Last: ${_formatDateTime(target.lastSyncAt!)}'
                        : 'Never synced',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _manualSync,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('Sync Now'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _testAllConnections,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.accent),
                    foregroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.wifi_find, size: 18),
                  label: const Text('Test All'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  IconData _getSyncTargetIcon(SyncTargetType type) {
    switch (type) {
      case SyncTargetType.none:
        return Icons.block;
      case SyncTargetType.googleDrive:
        return Icons.folder;
      case SyncTargetType.icloud:
        return Icons.cloud;
      case SyncTargetType.dropbox:
        return Icons.cloud_queue;
      case SyncTargetType.onedrive:
        return Icons.cloud_circle;
      case SyncTargetType.customWebDAV:
        return Icons.web;
      case SyncTargetType.localNetwork:
        return Icons.router;
      case SyncTargetType.customAPI:
        return Icons.api;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showAddSyncTargetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Add Sync Target', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SyncTargetType.values.where((type) => type != SyncTargetType.none).map((type) {
            return ListTile(
              leading: Icon(_getSyncTargetIcon(type), color: AppColors.accent),
              title: Text(
                _syncService.getSyncTargetDisplayName(type),
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _addSyncTarget(type);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
          ),
        ],
      ),
    );
  }

  void _addSyncTarget(SyncTargetType type) {
    final target = _syncService.createDefaultSyncTarget(type);
    // TODO: Show configuration dialog for the new target
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('TODO: Configure ${_syncService.getSyncTargetDisplayName(type)}'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _toggleSyncTarget(SyncTarget target, bool enabled) async {
    final updatedTarget = target.copyWith(isEnabled: enabled);
    await _syncService.addOrUpdateSyncTarget(updatedTarget);
    
    setState(() {
      final index = _syncTargets.indexWhere((t) => t.id == target.id);
      if (index >= 0) {
        _syncTargets[index] = updatedTarget;
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${target.name} ${enabled ? 'enabled' : 'disabled'}'),
        backgroundColor: enabled ? Colors.green : Colors.orange,
      ),
    );
  }

  void _handleSyncTargetAction(SyncTarget target, String action) async {
    switch (action) {
      case 'edit':
        // TODO: Show edit dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('TODO: Edit ${target.name}'),
            backgroundColor: Colors.blue,
          ),
        );
        break;
      case 'test':
        _testConnection(target);
        break;
      case 'delete':
        _deleteSyncTarget(target);
        break;
    }
  }

  void _testConnection(SyncTarget target) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Testing connection to ${target.name}...'),
        backgroundColor: Colors.blue,
      ),
    );
    
    final success = await _syncService.testSyncTarget(target);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
              ? '✓ Connection to ${target.name} successful'
              : '✗ Connection to ${target.name} failed',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _deleteSyncTarget(SyncTarget target) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Delete Sync Target', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${target.name}"? This won\'t delete any photos, but will stop syncing to this target.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _syncService.removeSyncTarget(target.id);
              
              if (success) {
                setState(() {
                  _syncTargets.removeWhere((t) => t.id == target.id);
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Deleted ${target.name}'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _manualSync() {
    // TODO: Implement manual sync
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Manual sync started... (TODO: implement)'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _testAllConnections() async {
    final enabledTargets = _syncTargets.where((t) => t.isEnabled).toList();
    
    if (enabledTargets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No enabled sync targets to test'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Testing ${enabledTargets.length} connections...'),
        backgroundColor: Colors.blue,
      ),
    );
    
    int successful = 0;
    for (final target in enabledTargets) {
      final success = await _syncService.testSyncTarget(target);
      if (success) successful++;
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$successful of ${enabledTargets.length} connections successful'),
          backgroundColor: successful == enabledTargets.length 
            ? Colors.green 
            : successful > 0 
              ? Colors.orange 
              : Colors.red,
        ),
      );
    }
  }

  void _saveConfiguration() {
    _syncService.updateConfiguration(_config);
  }
}