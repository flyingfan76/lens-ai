import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/camera_preset.dart';
import '../services/preset_service.dart';
import '../core/theme/app_colors.dart';
import '../widgets/preset_card.dart';
import '../widgets/preset_creation_dialog.dart';

/// Screen for managing camera presets
class PresetManagementScreen extends StatefulWidget {
  const PresetManagementScreen({super.key});

  @override
  State<PresetManagementScreen> createState() => _PresetManagementScreenState();
}

class _PresetManagementScreenState extends State<PresetManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  List<CameraPreset> _filteredPresets = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _initializeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) {
      _updateFilteredPresets();
    }
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await PresetService.instance.initialize();
      _updateFilteredPresets();
    } catch (e) {
      debugPrint('Error initializing preset data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _updateFilteredPresets() {
    setState(() {
      switch (_tabController.index) {
        case 0: // All
          _filteredPresets = _searchQuery.isEmpty
              ? PresetService.instance.allPresets
              : PresetService.instance.searchPresets(_searchQuery);
          break;
        case 1: // Built-in
          var builtIn = PresetService.instance.builtInPresets;
          _filteredPresets = _searchQuery.isEmpty
              ? builtIn
              : builtIn.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
          break;
        case 2: // Custom
          var custom = PresetService.instance.userPresets;
          _filteredPresets = _searchQuery.isEmpty
              ? custom
              : custom.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
          break;
        case 3: // Favorites
          var favorites = PresetService.instance.favoritePresets;
          _filteredPresets = _searchQuery.isEmpty
              ? favorites
              : favorites.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
          break;
      }
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _isSearching = query.isNotEmpty;
    });
    _updateFilteredPresets();
  }

  Future<void> _showPresetOptions(CameraPreset preset) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildPresetOptionsSheet(preset),
    );

    if (result != null && mounted) {
      await _handlePresetAction(result, preset);
    }
  }

  Widget _buildPresetOptionsSheet(CameraPreset preset) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white54,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Preset info
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getIconData(preset.category.iconName),
                  color: AppColors.accent,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preset.description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Action buttons
          Column(
            children: [
              _buildActionButton(
                icon: Icons.play_arrow,
                label: 'Apply Preset',
                onTap: () => Navigator.pop(context, 'apply'),
              ),
              if (preset.source != PresetSource.builtin) ...[
                _buildActionButton(
                  icon: Icons.edit,
                  label: 'Edit Preset',
                  onTap: () => Navigator.pop(context, 'edit'),
                ),
                _buildActionButton(
                  icon: Icons.copy,
                  label: 'Duplicate',
                  onTap: () => Navigator.pop(context, 'duplicate'),
                ),
              ],
              _buildActionButton(
                icon: preset.isFavorite ? Icons.favorite : Icons.favorite_border,
                label: preset.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                onTap: () => Navigator.pop(context, 'favorite'),
              ),
              _buildActionButton(
                icon: Icons.share,
                label: 'Export Preset',
                onTap: () => Navigator.pop(context, 'export'),
              ),
              if (preset.source != PresetSource.builtin)
                _buildActionButton(
                  icon: Icons.delete,
                  label: 'Delete Preset',
                  onTap: () => Navigator.pop(context, 'delete'),
                  isDestructive: true,
                ),
            ],
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDestructive ? Colors.red : Colors.white70,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isDestructive ? Colors.red : Colors.white,
            fontSize: 16,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        tileColor: Colors.white12,
      ),
    );
  }

  Future<void> _handlePresetAction(String action, CameraPreset preset) async {
    try {
      switch (action) {
        case 'apply':
          await PresetService.instance.applyPreset(preset.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Applied preset: ${preset.name}'),
                backgroundColor: AppColors.accent,
              ),
            );
          }
          break;

        case 'edit':
          await _showEditPresetDialog(preset);
          break;

        case 'duplicate':
          final duplicated = await PresetService.instance.duplicatePreset(preset.id);
          _updateFilteredPresets();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Duplicated as: ${duplicated.name}'),
                backgroundColor: AppColors.accent,
              ),
            );
          }
          break;

        case 'favorite':
          await PresetService.instance.toggleFavorite(preset.id);
          _updateFilteredPresets();
          break;

        case 'export':
          await _exportPreset(preset);
          break;

        case 'delete':
          await _confirmDeletePreset(preset);
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEditPresetDialog(CameraPreset preset) async {
    final result = await showDialog<CameraPreset>(
      context: context,
      builder: (context) => PresetCreationDialog(
        currentSettings: preset.settings,
        editingPreset: preset,
      ),
    );

    if (result != null) {
      _updateFilteredPresets();
    }
  }

  Future<void> _exportPreset(CameraPreset preset) async {
    try {
      final jsonData = PresetService.instance.exportPresets(presetIds: [preset.id]);
      await Clipboard.setData(ClipboardData(text: jsonData));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preset copied to clipboard'),
            backgroundColor: AppColors.accent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export preset: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeletePreset(CameraPreset preset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
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
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await PresetService.instance.deletePreset(preset.id);
      _updateFilteredPresets();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted preset: ${preset.name}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Manage Presets',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _onSearchChanged('');
                }
              });
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_isSearching ? 120 : 48),
          child: Column(
            children: [
              if (_isSearching) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search presets...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white54),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Built-in'),
                  Tab(text: 'Custom'),
                  Tab(text: 'Favorites'),
                ],
                labelColor: AppColors.accent,
                unselectedLabelColor: Colors.white54,
                indicatorColor: AppColors.accent,
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPresetGrid(), // All
                _buildPresetGrid(), // Built-in
                _buildPresetGrid(), // Custom
                _buildPresetGrid(), // Favorites
              ],
            ),
    );
  }

  Widget _buildPresetGrid() {
    if (_filteredPresets.isEmpty) {
      return _buildEmptyState();
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _filteredPresets.length,
      itemBuilder: (context, index) {
        final preset = _filteredPresets[index];
        
        return PresetCard(
          preset: preset,
          showDetails: true,
          size: const Size(100, 120),
          onTap: () => _showPresetOptions(preset),
          onLongPress: () => _showPresetOptions(preset),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    String message;
    String actionText;
    VoidCallback? action;

    switch (_tabController.index) {
      case 1: // Built-in
        message = 'No built-in presets found';
        actionText = 'Refresh';
        action = _initializeData;
        break;
      case 2: // Custom
        message = 'No custom presets yet';
        actionText = 'Create Your First Preset';
        action = () => Navigator.pop(context);
        break;
      case 3: // Favorites
        message = 'No favorite presets';
        actionText = 'Explore Presets';
        action = () => _tabController.animateTo(0);
        break;
      default: // All
        message = _isSearching ? 'No presets match your search' : 'No presets available';
        actionText = _isSearching ? 'Clear Search' : 'Refresh';
        action = _isSearching
            ? () {
                _searchController.clear();
                _onSearchChanged('');
              }
            : _initializeData;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.camera_alt_outlined,
            size: 64,
            color: Colors.white54,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: action,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
            child: Text(actionText),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'person_outline':
        return Icons.person_outline;
      case 'landscape':
        return Icons.landscape;
      case 'sports':
        return Icons.sports;
      case 'nights_stay':
        return Icons.nights_stay;
      case 'center_focus_strong':
        return Icons.center_focus_strong;
      case 'location_city':
        return Icons.location_city;
      case 'event':
        return Icons.event;
      case 'studio':
        return Icons.camera_alt;
      case 'wb_sunny':
        return Icons.wb_sunny;
      case 'home':
        return Icons.home;
      case 'beach_access':
        return Icons.beach_access;
      case 'ac_unit':
        return Icons.ac_unit;
      case 'filter_b_and_w':
        return Icons.filter_b_and_w;
      case 'filter_vintage':
        return Icons.filter_vintage;
      case 'hdr_on':
        return Icons.hdr_on;
      case 'slow_motion_video':
        return Icons.slow_motion_video;
      case 'tune':
        return Icons.tune;
      default:
        return Icons.camera_alt;
    }
  }
}