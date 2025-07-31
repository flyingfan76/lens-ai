import 'package:flutter/material.dart';
import '../models/style_preset.dart';

class StylePresetCard extends StatelessWidget {
  final StylePreset preset;
  final VoidCallback? onTap;
  final VoidCallback? onApply;
  final VoidCallback? onFavorite;
  final bool isSelected;
  final bool showApplyButton;
  final bool showRating;
  final bool isFavorite;

  const StylePresetCard({
    super.key,
    required this.preset,
    this.onTap,
    this.onApply,
    this.onFavorite,
    this.isSelected = false,
    this.showApplyButton = true,
    this.showRating = true,
    this.isFavorite = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: isSelected ? 8 : 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 12),
              _buildDescription(context),
              const SizedBox(height: 12),
              _buildSettingsPreview(context),
              const SizedBox(height: 12),
              _buildTags(context),
              if (showRating || showApplyButton) ...[
                const SizedBox(height: 12),
                _buildFooter(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        // Thumbnail
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: theme.colorScheme.surface,
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
          ),
          child: preset.thumbnail.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    preset.thumbnail,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildThumbnailPlaceholder(context);
                    },
                  ),
                )
              : _buildThumbnailPlaceholder(context),
        ),
        const SizedBox(width: 12),
        
        // Title and category
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      preset.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (preset.metadata.featured)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      child: const Icon(
                        Icons.star,
                        size: 16,
                        color: Colors.amber,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _buildCategoryChip(context),
                  const SizedBox(width: 8),
                  _buildDifficultyChip(context),
                ],
              ),
            ],
          ),
        ),
        
        // Favorite button
        if (onFavorite != null)
          IconButton(
            onPressed: onFavorite,
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? Colors.red : theme.colorScheme.outline,
            ),
            tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
          ),
      ],
    );
  }

  Widget _buildThumbnailPlaceholder(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.1),
            theme.colorScheme.secondary.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Icon(
        _getCategoryIcon(),
        size: 24,
        color: theme.colorScheme.primary,
      ),
    );
  }

  IconData _getCategoryIcon() {
    switch (preset.category) {
      case 'portrait':
        return Icons.person;
      case 'landscape':
        return Icons.landscape;
      case 'street':
        return Icons.location_city;
      case 'macro':
        return Icons.center_focus_strong;
      case 'creative':
        return Icons.palette;
      case 'low_light':
        return Icons.nights_stay;
      default:
        return Icons.camera_alt;
    }
  }

  Widget _buildDescription(BuildContext context) {
    final theme = Theme.of(context);
    
    return Text(
      preset.description,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSettingsPreview(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSettingItem(
            context,
            'ISO',
            preset.settings.displayISO,
            Icons.iso,
          ),
          _buildSettingItem(
            context,
            'Aperture',
            preset.settings.displayAperture,
            Icons.camera,
          ),
          _buildSettingItem(
            context,
            'Shutter',
            preset.settings.displayShutterSpeed,
            Icons.shutter_speed,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTags(BuildContext context) {
    final theme = Theme.of(context);
    
    if (preset.tags.isEmpty) return const SizedBox.shrink();
    
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: preset.tags.take(3).map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            tag,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      children: [
        if (showRating && preset.metadata.rating.hasRatings) ...[
          const Icon(
            Icons.star,
            size: 16,
            color: Colors.amber,
          ),
          const SizedBox(width: 4),
          Text(
            preset.metadata.rating.displayRating,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        
        const Spacer(),
        
        if (showApplyButton && onApply != null)
          ElevatedButton.icon(
            onPressed: onApply,
            icon: const Icon(Icons.camera_alt, size: 16),
            label: const Text('Apply'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryChip(BuildContext context) {
    final theme = Theme.of(context);
    final category = PresetCategory.fromString(preset.category);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        category.displayName,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.secondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDifficultyChip(BuildContext context) {
    final theme = Theme.of(context);
    final difficulty = preset.metadata.difficulty;
    
    Color chipColor;
    switch (difficulty) {
      case 'beginner':
        chipColor = Colors.green;
        break;
      case 'intermediate':
        chipColor = Colors.orange;
        break;
      case 'advanced':
        chipColor = Colors.red;
        break;
      default:
        chipColor = theme.colorScheme.outline;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        difficulty.toUpperCase(),
        style: theme.textTheme.bodySmall?.copyWith(
          color: chipColor,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}