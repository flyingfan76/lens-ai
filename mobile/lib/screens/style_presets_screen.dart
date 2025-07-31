import 'package:flutter/material.dart';
import '../models/style_preset.dart';
import '../services/style_preset_service.dart';
import '../widgets/style_preset_card.dart';

class StylePresetsScreen extends StatefulWidget {
  const StylePresetsScreen({super.key});

  @override
  State<StylePresetsScreen> createState() => _StylePresetsScreenState();
}

class _StylePresetsScreenState extends State<StylePresetsScreen>
    with TickerProviderStateMixin {
  final StylePresetService _presetService = StylePresetService();
  final TextEditingController _searchController = TextEditingController();
  
  List<StylePreset> _allPresets = [];
  List<StylePreset> _filteredPresets = [];
  List<StylePreset> _featuredPresets = [];
  bool _isLoading = true;
  String? _error;
  String _selectedCategory = 'all';
  String _selectedDifficulty = 'all';
  String _sortBy = 'popularity';
  Set<String> _favoritePresets = {};

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPresets();
    _loadFeaturedPresets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _presetService.dispose();
    super.dispose();
  }

  Future<void> _loadPresets() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final presets = await _presetService.getAllPresets(
        sortBy: _sortBy,
        category: _selectedCategory == 'all' ? null : _selectedCategory,
        difficulty: _selectedDifficulty == 'all' ? null : _selectedDifficulty,
      );

      setState(() {
        _allPresets = presets;
        _filteredPresets = presets;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFeaturedPresets() async {
    try {
      final featured = await _presetService.getFeaturedPresets(limit: 10);
      setState(() {
        _featuredPresets = featured;
      });
    } catch (e) {
      // Non-critical error, just log it
      debugPrint('Failed to load featured presets: $e');
    }
  }

  void _filterPresets() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredPresets = _allPresets.where((preset) {
        final matchesSearch = query.isEmpty ||
            preset.name.toLowerCase().contains(query) ||
            preset.description.toLowerCase().contains(query) ||
            preset.tags.any((tag) => tag.toLowerCase().contains(query));
        
        final matchesCategory = _selectedCategory == 'all' ||
            preset.category == _selectedCategory;
        
        final matchesDifficulty = _selectedDifficulty == 'all' ||
            preset.metadata.difficulty == _selectedDifficulty;
        
        return matchesSearch && matchesCategory && matchesDifficulty;
      }).toList();
    });
  }

  void _applyPreset(StylePreset preset) async {
    try {
      // Record usage
      await _presetService.recordPresetUsage(preset.id);
      
      // Apply settings to camera (implement camera integration)
      // For now, show a success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Applied "${preset.name}" preset'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply preset: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleFavorite(StylePreset preset) {
    setState(() {
      if (_favoritePresets.contains(preset.id)) {
        _favoritePresets.remove(preset.id);
      } else {
        _favoritePresets.add(preset.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Style Presets'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Featured'),
            Tab(text: 'All Presets'),
            Tab(text: 'My Presets'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showFilterBottomSheet,
            icon: const Icon(Icons.tune),
            tooltip: 'Filters',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFeaturedTab(),
                _buildAllPresetsTab(),
                _buildMyPresetsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePresetDialog,
        tooltip: 'Create Preset',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search presets...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    _filterPresets();
                  },
                  icon: const Icon(Icons.clear),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: (_) => _filterPresets(),
      ),
    );
  }

  Widget _buildFeaturedTab() {
    if (_featuredPresets.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _featuredPresets.length,
      itemBuilder: (context, index) {
        final preset = _featuredPresets[index];
        return StylePresetCard(
          preset: preset,
          onApply: () => _applyPreset(preset),
          onFavorite: () => _toggleFavorite(preset),
          isFavorite: _favoritePresets.contains(preset.id),
          onTap: () => _showPresetDetails(preset),
        );
      },
    );
  }

  Widget _buildAllPresetsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load presets',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPresets,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredPresets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No presets found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPresets,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _filteredPresets.length,
        itemBuilder: (context, index) {
          final preset = _filteredPresets[index];
          return StylePresetCard(
            preset: preset,
            onApply: () => _applyPreset(preset),
            onFavorite: () => _toggleFavorite(preset),
            isFavorite: _favoritePresets.contains(preset.id),
            onTap: () => _showPresetDetails(preset),
          );
        },
      ),
    );
  }

  Widget _buildMyPresetsTab() {
    final userPresets = _allPresets
        .where((preset) => preset.type == 'user_created')
        .toList();

    if (userPresets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No custom presets yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first custom preset',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showCreatePresetDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Preset'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: userPresets.length,
      itemBuilder: (context, index) {
        final preset = userPresets[index];
        return StylePresetCard(
          preset: preset,
          onApply: () => _applyPreset(preset),
          onFavorite: () => _toggleFavorite(preset),
          isFavorite: _favoritePresets.contains(preset.id),
          onTap: () => _showPresetDetails(preset),
        );
      },
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildFilterBottomSheet(),
    );
  }

  Widget _buildFilterBottomSheet() {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filters & Sort',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              
              // Category filter
              Text(
                'Category',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['all', ...PresetCategory.values.map((c) => c.value)]
                    .map((category) {
                  final isSelected = _selectedCategory == category;
                  return FilterChip(
                    label: Text(category == 'all' 
                        ? 'All' 
                        : PresetCategory.fromString(category).displayName),
                    selected: isSelected,
                    onSelected: (selected) {
                      setModalState(() {
                        _selectedCategory = category;
                      });
                    },
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 24),
              
              // Difficulty filter
              Text(
                'Difficulty',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['all', 'beginner', 'intermediate', 'advanced']
                    .map((difficulty) {
                  final isSelected = _selectedDifficulty == difficulty;
                  return FilterChip(
                    label: Text(difficulty == 'all' ? 'All' : difficulty.capitalize()),
                    selected: isSelected,
                    onSelected: (selected) {
                      setModalState(() {
                        _selectedDifficulty = difficulty;
                      });
                    },
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 24),
              
              // Sort options
              Text(
                'Sort By',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _sortBy,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'popularity', child: Text('Popularity')),
                  DropdownMenuItem(value: 'rating', child: Text('Rating')),
                  DropdownMenuItem(value: 'newest', child: Text('Newest')),
                ],
                onChanged: (value) {
                  setModalState(() {
                    _sortBy = value ?? 'popularity';
                  });
                },
              ),
              
              const SizedBox(height: 24),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setModalState(() {
                          _selectedCategory = 'all';
                          _selectedDifficulty = 'all';
                          _sortBy = 'popularity';
                        });
                      },
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _loadPresets();
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPresetDetails(StylePreset preset) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preset.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  preset.description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                
                // Settings details
                Text(
                  'Camera Settings',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                // Add detailed settings display here
                
                const Spacer(),
                
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _applyPreset(preset);
                        },
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCreatePresetDialog() {
    // Implement create preset dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Preset'),
        content: const Text('Preset creation feature coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}