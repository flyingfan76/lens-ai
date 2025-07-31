import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class UserPresetsScreen extends StatefulWidget {
  const UserPresetsScreen({super.key});

  @override
  State<UserPresetsScreen> createState() => _UserPresetsScreenState();
}

class _UserPresetsScreenState extends State<UserPresetsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<UserPreset> _myPresets = [];
  List<UserPreset> _communityPresets = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPresets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPresets() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Replace with actual API calls
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() {
        _myPresets = _generateSamplePresets(isUserCreated: true);
        _communityPresets = _generateSamplePresets(isUserCreated: false);
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<UserPreset> _generateSamplePresets({required bool isUserCreated}) {
    if (isUserCreated) {
      return [
        UserPreset(
          id: '1',
          name: 'My Golden Hour',
          description: 'Perfect settings for sunset portraits',
          category: 'portrait',
          visibility: 'private',
          isUserCreated: true,
          createdByUsername: 'You',
          usageCount: 15,
          rating: 4.5,
        ),
        UserPreset(
          id: '2',
          name: 'Street Photography',
          description: 'Fast settings for street photography',
          category: 'street',
          visibility: 'public',
          isUserCreated: true,
          createdByUsername: 'You',
          usageCount: 8,
          rating: 4.2,
        ),
      ];
    } else {
      return [
        UserPreset(
          id: '3',
          name: 'Dreamy Landscapes',
          description: 'Ethereal landscape photography',
          category: 'landscape',
          visibility: 'public',
          isUserCreated: true,
          createdByUsername: 'ProPhotoGuy',
          usageCount: 245,
          rating: 4.8,
        ),
        UserPreset(
          id: '4',
          name: 'Wedding Magic',
          description: 'Perfect for wedding ceremonies',
          category: 'portrait',
          visibility: 'public',
          isUserCreated: true,
          createdByUsername: 'WeddingPro',
          usageCount: 189,
          rating: 4.6,
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Camera Presets',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'My Presets'),
            Tab(text: 'Community'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showCreatePresetDialog,
            icon: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyPresetsTab(),
          _buildCommunityTab(),
        ],
      ),
    );
  }

  Widget _buildMyPresetsTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (_myPresets.isEmpty) {
      return _buildEmptyState(
        icon: Icons.camera_alt_outlined,
        title: 'No Presets Yet',
        subtitle: 'Create your first preset to get started',
        actionText: 'Create Preset',
        onAction: _showCreatePresetDialog,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPresets,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myPresets.length,
        itemBuilder: (context, index) {
          return _buildPresetCard(_myPresets[index], showOwnership: false);
        },
      ),
    );
  }

  Widget _buildCommunityTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPresets,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _communityPresets.length,
        itemBuilder: (context, index) {
          return _buildPresetCard(_communityPresets[index], showOwnership: true);
        },
      ),
    );
  }

  Widget _buildPresetCard(UserPreset preset, {required bool showOwnership}) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showPresetDetails(preset),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preset.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          preset.description,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!showOwnership)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white54),
                      color: Colors.grey[800],
                      onSelected: (value) => _handlePresetAction(preset, value),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text('Edit', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'share',
                          child: Row(
                            children: [
                              const Icon(Icons.share, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text('Share', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'visibility',
                          child: Row(
                            children: [
                              const Icon(Icons.visibility, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text('Privacy', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(
                    icon: Icons.category,
                    label: preset.category.toUpperCase(),
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    icon: preset.visibility == 'private' 
                        ? Icons.lock 
                        : Icons.public,
                    label: preset.visibility.toUpperCase(),
                    color: preset.visibility == 'private' 
                        ? Colors.orange 
                        : Colors.green,
                  ),
                  const Spacer(),
                  if (showOwnership) ...[
                    const Icon(Icons.person, color: Colors.white54, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      preset.createdByUsername,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  const Icon(Icons.favorite, color: Colors.white54, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    preset.usageCount.toString(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionText,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(actionText),
          ),
        ],
      ),
    );
  }

  void _showCreatePresetDialog() {
    showDialog(
      context: context,
      builder: (context) => CreatePresetDialog(
        onPresetCreated: (preset) {
          setState(() {
            _myPresets.add(preset);
          });
        },
      ),
    );
  }

  void _showPresetDetails(UserPreset preset) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => PresetDetailsSheet(preset: preset),
    );
  }

  void _handlePresetAction(UserPreset preset, String action) {
    switch (action) {
      case 'edit':
        _editPreset(preset);
        break;
      case 'share':
        _sharePreset(preset);
        break;
      case 'visibility':
        _changeVisibility(preset);
        break;
      case 'delete':
        _deletePreset(preset);
        break;
    }
  }

  void _editPreset(UserPreset preset) {
    // TODO: Navigate to edit preset screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit preset feature coming soon')),
    );
  }

  void _sharePreset(UserPreset preset) {
    // TODO: Implement preset sharing
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sharing "${preset.name}"')),
    );
  }

  void _changeVisibility(UserPreset preset) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Change Privacy',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.lock, color: Colors.orange),
              title: const Text('Private', style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                'Only you can see this preset',
                style: TextStyle(color: Colors.white60),
              ),
              onTap: () {
                Navigator.pop(context);
                _updatePresetVisibility(preset, 'private');
              },
            ),
            ListTile(
              leading: const Icon(Icons.public, color: Colors.green),
              title: const Text('Public', style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                'Everyone can see and use this preset',
                style: TextStyle(color: Colors.white60),
              ),
              onTap: () {
                Navigator.pop(context);
                _updatePresetVisibility(preset, 'public');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _updatePresetVisibility(UserPreset preset, String visibility) {
    setState(() {
      preset.visibility = visibility;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Preset is now $visibility'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _deletePreset(UserPreset preset) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Preset',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${preset.name}"? This action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _myPresets.remove(preset);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Deleted "${preset.name}"'),
                  backgroundColor: AppColors.error,
                ),
              );
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class UserPreset {
  final String id;
  final String name;
  final String description;
  final String category;
  String visibility;
  final bool isUserCreated;
  final String createdByUsername;
  final int usageCount;
  final double rating;

  UserPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.visibility,
    required this.isUserCreated,
    required this.createdByUsername,
    required this.usageCount,
    required this.rating,
  });
}

class CreatePresetDialog extends StatefulWidget {
  final Function(UserPreset) onPresetCreated;

  const CreatePresetDialog({
    super.key,
    required this.onPresetCreated,
  });

  @override
  State<CreatePresetDialog> createState() => _CreatePresetDialogState();
}

class _CreatePresetDialogState extends State<CreatePresetDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'portrait';
  String _selectedVisibility = 'private';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text(
        'Create New Preset',
        style: TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Preset Name',
              labelStyle: TextStyle(color: Colors.white60),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white30),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Description',
              labelStyle: TextStyle(color: Colors.white60),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white30),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary),
              ),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            dropdownColor: Colors.grey[800],
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Category',
              labelStyle: TextStyle(color: Colors.white60),
            ),
            items: const [
              DropdownMenuItem(value: 'portrait', child: Text('Portrait')),
              DropdownMenuItem(value: 'landscape', child: Text('Landscape')),
              DropdownMenuItem(value: 'street', child: Text('Street')),
              DropdownMenuItem(value: 'macro', child: Text('Macro')),
              DropdownMenuItem(value: 'creative', child: Text('Creative')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedCategory = value!;
              });
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedVisibility,
            dropdownColor: Colors.grey[800],
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Privacy',
              labelStyle: TextStyle(color: Colors.white60),
            ),
            items: const [
              DropdownMenuItem(value: 'private', child: Text('Private')),
              DropdownMenuItem(value: 'public', child: Text('Public')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedVisibility = value!;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _createPreset,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: const Text('Create'),
        ),
      ],
    );
  }

  void _createPreset() {
    if (_nameController.text.isEmpty) return;

    final preset = UserPreset(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      description: _descriptionController.text,
      category: _selectedCategory,
      visibility: _selectedVisibility,
      isUserCreated: true,
      createdByUsername: 'You',
      usageCount: 0,
      rating: 0.0,
    );

    widget.onPresetCreated(preset);
    Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Created "${preset.name}"'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

class PresetDetailsSheet extends StatelessWidget {
  final UserPreset preset;

  const PresetDetailsSheet({
    super.key,
    required this.preset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  preset.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            preset.description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.person, color: Colors.white54, size: 20),
              const SizedBox(width: 8),
              Text(
                'Created by ${preset.createdByUsername}',
                style: const TextStyle(color: Colors.white60),
              ),
              const Spacer(),
              const Icon(Icons.favorite, color: Colors.white54, size: 20),
              const SizedBox(width: 4),
              Text(
                '${preset.usageCount} uses',
                style: const TextStyle(color: Colors.white60),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Applied "${preset.name}" preset'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Apply Preset'),
            ),
          ),
        ],
      ),
    );
  }
}