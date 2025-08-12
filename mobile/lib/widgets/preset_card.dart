import 'package:flutter/material.dart';
import '../models/camera_preset.dart';
import '../core/theme/app_colors.dart';

/// A card widget representing a camera preset
class PresetCard extends StatelessWidget {
  final CameraPreset preset;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showDetails;
  final Size size;

  const PresetCard({
    super.key,
    required this.preset,
    this.isSelected = false,
    this.isLoading = false,
    this.onTap,
    this.onLongPress,
    this.showDetails = false,
    this.size = const Size(72, 96),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      onLongPress: isLoading ? null : onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size.width,
        height: size.height,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: AppColors.accent, width: 2)
              : Border.all(color: Colors.white24, width: 1),
          color: isSelected 
              ? AppColors.accent.withValues(alpha: 0.2)
              : Colors.black54,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            // Main content
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon or thumbnail
                  _buildIcon(),
                  
                  const SizedBox(height: 8),
                  
                  // Preset name
                  Text(
                    preset.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: showDetails ? 14 : 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  if (showDetails) ...[
                    const SizedBox(height: 4),
                    _buildSettingsPreview(),
                  ],
                ],
              ),
            ),
            
            // Loading overlay
            if (isLoading)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black54,
                ),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                    ),
                  ),
                ),
              ),
            
            // Favorite indicator
            if (preset.isFavorite)
              Positioned(
                top: 4,
                right: 4,
                child: Icon(
                  Icons.favorite,
                  size: 12,
                  color: AppColors.accent,
                ),
              ),
            
            // Built-in indicator
            if (preset.source == PresetSource.builtin)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    // Use category icon if available
    final iconName = preset.iconName ?? preset.category.iconName;
    
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isSelected 
            ? AppColors.accent.withValues(alpha: 0.3)
            : Colors.white12,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(
        _getIconData(iconName),
        color: isSelected ? AppColors.accent : Colors.white70,
        size: 24,
      ),
    );
  }

  Widget _buildSettingsPreview() {
    final settings = preset.settings;
    final previewItems = <String>[];
    
    if (settings.iso != null) {
      previewItems.add('ISO ${settings.iso!.toInt()}');
    }
    if (settings.aperture != null) {
      previewItems.add('f/${settings.aperture}');
    }
    if (settings.shutterSpeed != null) {
      previewItems.add(settings.shutterSpeed!);
    }
    
    return Text(
      previewItems.take(2).join('\n'),
      style: TextStyle(
        color: Colors.white70,
        fontSize: 10,
      ),
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
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

/// A special card for creating new presets
class NewPresetCard extends StatelessWidget {
  final VoidCallback? onTap;
  final Size size;

  const NewPresetCard({
    super.key,
    this.onTap,
    this.size = const Size(72, 96),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size.width,
        height: size.height,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24, width: 1),
          color: Colors.transparent,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white70,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'New',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}