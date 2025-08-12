import 'package:flutter/material.dart';
import '../models/camera_preset.dart';
import '../services/preset_service.dart';
import '../core/theme/app_colors.dart';
import 'preset_card.dart';

/// Horizontal scrollable carousel of camera presets
class PresetCarousel extends StatefulWidget {
  final String? selectedPresetId;
  final Function(CameraPreset)? onPresetSelected;
  final Function(CameraPreset)? onPresetLongPress;
  final VoidCallback? onNewPresetTap;
  final bool showNewPresetButton;
  final double height;
  final EdgeInsets padding;
  final List<CameraPreset>? customPresets;

  const PresetCarousel({
    super.key,
    this.selectedPresetId,
    this.onPresetSelected,
    this.onPresetLongPress,
    this.onNewPresetTap,
    this.showNewPresetButton = true,
    this.height = 120,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.customPresets,
  });

  @override
  State<PresetCarousel> createState() => _PresetCarouselState();
}

class _PresetCarouselState extends State<PresetCarousel> {
  final PageController _pageController = PageController();
  String? _loadingPresetId;
  List<CameraPreset> _presets = [];
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadPresets() async {
    if (!_isInitialized) {
      await PresetService.instance.initialize();
      _isInitialized = true;
    }

    setState(() {
      if (widget.customPresets != null) {
        _presets = widget.customPresets!;
      } else {
        // Show built-in presets first, then user favorites
        final builtIn = PresetService.instance.builtInPresets;
        final favorites = PresetService.instance.favoritePresets
            .where((p) => p.source != PresetSource.builtin)
            .toList();
        _presets = [...builtIn, ...favorites];
      }
    });
  }

  Future<void> _handlePresetTap(CameraPreset preset) async {
    if (_loadingPresetId == preset.id) return;

    setState(() {
      _loadingPresetId = preset.id;
    });

    try {
      // Apply the preset (updates usage count)
      final appliedPreset = await PresetService.instance.applyPreset(preset.id);
      
      // Notify parent
      widget.onPresetSelected?.call(appliedPreset);
    } catch (e) {
      debugPrint('Error applying preset: $e');
      // Show error snackbar if context is available
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply preset: ${preset.name}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingPresetId = null;
        });
      }
    }
  }

  void _handlePresetLongPress(CameraPreset preset) {
    widget.onPresetLongPress?.call(preset);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          if (_presets.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Presets',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.selectedPresetId != null)
                  Text(
                    _getSelectedPresetName(),
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Preset carousel
          Expanded(
            child: _presets.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.zero,
                    itemCount: _presets.length + (widget.showNewPresetButton ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _presets.length && widget.showNewPresetButton) {
                        return NewPresetCard(
                          onTap: widget.onNewPresetTap,
                          size: const Size(72, 96),
                        );
                      }

                      final preset = _presets[index];
                      final isSelected = preset.id == widget.selectedPresetId;
                      final isLoading = preset.id == _loadingPresetId;

                      return PresetCard(
                        preset: preset,
                        isSelected: isSelected,
                        isLoading: isLoading,
                        onTap: () => _handlePresetTap(preset),
                        onLongPress: () => _handlePresetLongPress(preset),
                        size: const Size(72, 96),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.camera_alt_outlined,
            size: 48,
            color: Colors.white54,
          ),
          const SizedBox(height: 8),
          const Text(
            'No presets available',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
          if (widget.showNewPresetButton) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: widget.onNewPresetTap,
              child: const Text(
                'Create your first preset',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getSelectedPresetName() {
    if (widget.selectedPresetId == null) return '';
    
    final selectedPreset = _presets.firstWhere(
      (preset) => preset.id == widget.selectedPresetId,
      orElse: () => _presets.first,
    );
    
    return selectedPreset.name;
  }
}

/// Compact version of preset carousel for bottom sheets
class CompactPresetCarousel extends StatelessWidget {
  final String? selectedPresetId;
  final Function(CameraPreset)? onPresetSelected;
  final Function(CameraPreset)? onPresetLongPress;
  final VoidCallback? onNewPresetTap;

  const CompactPresetCarousel({
    super.key,
    this.selectedPresetId,
    this.onPresetSelected,
    this.onPresetLongPress,
    this.onNewPresetTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: PresetService.instance.initialize(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 60,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
            ),
          );
        }

        final recentPresets = PresetService.instance.recentPresets.take(6).toList();
        
        return Container(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recentPresets.length + 1,
            itemBuilder: (context, index) {
              if (index == recentPresets.length) {
                return NewPresetCard(
                  onTap: onNewPresetTap,
                  size: const Size(50, 60),
                );
              }

              final preset = recentPresets[index];
              final isSelected = preset.id == selectedPresetId;

              return PresetCard(
                preset: preset,
                isSelected: isSelected,
                onTap: () => onPresetSelected?.call(preset),
                onLongPress: () => onPresetLongPress?.call(preset),
                size: const Size(50, 60),
              );
            },
          ),
        );
      },
    );
  }
}