import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'user_presets_screen.dart';

class PresetsScreen extends StatefulWidget {
  const PresetsScreen({super.key});

  @override
  State<PresetsScreen> createState() => _PresetsScreenState();
}

class _PresetsScreenState extends State<PresetsScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _presets = [
    {
      'name': 'Golden Hour',
      'description': 'Warm, soft lighting perfect for portraits',
      'creator': 'AI Recommended',
      'settings': 'ISO 200 • f/2.8 • Auto WB',
      'downloads': 1250,
      'isAI': true,
    },
    {
      'name': 'Street Photography',
      'description': 'High contrast for urban scenes',
      'creator': 'Pro Photographer',
      'settings': 'ISO 800 • f/8 • Daylight WB',
      'downloads': 890,
      'isAI': false,
    },
    {
      'name': 'Nature Macro',
      'description': 'Detailed close-up shots of flora',
      'creator': 'Nature Expert',
      'settings': 'ISO 100 • f/11 • Flash',
      'downloads': 445,
      'isAI': false,
    },
    {
      'name': 'Night Sky',
      'description': 'Capture stars and night landscapes',
      'creator': 'Astro Photographer',
      'settings': 'ISO 3200 • f/2.8 • Manual Focus',
      'downloads': 2100,
      'isAI': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Style Presets'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserPresetsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.person),
            tooltip: 'My Presets',
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Theme.of(context).brightness == Brightness.light
              ? AppColors.textSecondaryLight
              : AppColors.textSecondaryDark,
          tabs: const [
            Tab(text: 'My Presets'),
            Tab(text: 'AI Picks'),
            Tab(text: 'Popular'),
            Tab(text: 'Professional'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPresetsList('my'),
          _buildPresetsList('ai'),
          _buildPresetsList('popular'),
          _buildPresetsList('professional'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePresetDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildPresetsList(String category) {
    List<Map<String, dynamic>> filteredPresets = _presets;
    
    if (category == 'ai') {
      filteredPresets = _presets.where((preset) => preset['isAI'] == true).toList();
    } else if (category == 'popular') {
      filteredPresets = _presets..sort((a, b) => b['downloads'].compareTo(a['downloads']));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredPresets.length,
      itemBuilder: (context, index) {
        final preset = filteredPresets[index];
        return _buildPresetCard(preset);
      },
    );
  }

  Widget _buildPresetCard(Map<String, dynamic> preset) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview image
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.7),
                  AppColors.accent.withOpacity(0.7),
                ],
              ),
            ),
            child: Stack(
              children: [
                const Center(
                  child: Icon(
                    Icons.photo_camera,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                if (preset['isAI'])
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'AI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Content
          Padding(
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
                            preset['name'],
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            preset['description'],
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.favorite_border),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Settings preview
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.grey[100]
                        : Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.settings, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        preset['settings'],
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Footer
                Row(
                  children: [
                    Text(
                      'by ${preset['creator']}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
                    Icon(Icons.download, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${preset['downloads']}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () => _applyPreset(preset),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                      ),
                      child: const Text(
                        'Apply',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _applyPreset(Map<String, dynamic> preset) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Apply ${preset['name']}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will change your camera settings to:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                preset['settings'],
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ],
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
                SnackBar(
                  content: Text('${preset['name']} preset applied!'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Apply', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCreatePresetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Preset'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Preset Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
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
                  content: Text('Preset created successfully!'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}