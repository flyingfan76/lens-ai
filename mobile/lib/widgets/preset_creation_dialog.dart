import 'package:flutter/material.dart';
import '../models/camera_preset.dart';
import '../services/preset_service.dart';
import '../core/theme/app_colors.dart';

/// Dialog for creating or editing camera presets
class PresetCreationDialog extends StatefulWidget {
  final CameraSettings currentSettings;
  final CameraPreset? editingPreset;
  final Function(CameraPreset)? onPresetCreated;

  const PresetCreationDialog({
    super.key,
    required this.currentSettings,
    this.editingPreset,
    this.onPresetCreated,
  });

  @override
  State<PresetCreationDialog> createState() => _PresetCreationDialogState();
}

class _PresetCreationDialogState extends State<PresetCreationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  PresetCategory _selectedCategory = PresetCategory.custom;
  bool _isLoading = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    
    if (widget.editingPreset != null) {
      _nameController.text = widget.editingPreset!.name;
      _descriptionController.text = widget.editingPreset!.description;
      _selectedCategory = widget.editingPreset!.category;
    } else {
      // Auto-suggest name based on settings
      _nameController.text = _generateSuggestedName();
      _descriptionController.text = _generateSuggestedDescription();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _generateSuggestedName() {
    final settings = widget.currentSettings;
    final timeOfDay = DateTime.now().hour;
    
    // Generate name based on current settings and time
    if (timeOfDay >= 17 || timeOfDay <= 6) {
      if (settings.iso != null && settings.iso! > 800) {
        return 'Night Portrait';
      }
      return 'Evening Setup';
    } else if (timeOfDay >= 12 && timeOfDay < 17) {
      return 'Afternoon Light';
    } else {
      return 'Morning Light';
    }
  }

  String _generateSuggestedDescription() {
    final settings = widget.currentSettings;
    final parts = <String>[];
    
    if (settings.aperture != null) {
      if (settings.aperture! <= 2.8) {
        parts.add('shallow depth of field');
      } else if (settings.aperture! >= 8) {
        parts.add('sharp throughout');
      }
    }
    
    if (settings.iso != null) {
      if (settings.iso! <= 200) {
        parts.add('minimal noise');
      } else if (settings.iso! >= 800) {
        parts.add('good for low light');
      }
    }

    if (parts.isEmpty) {
      return 'Custom camera settings for your photography needs';
    }
    
    return 'Perfect for ${parts.join(' and ')}';
  }

  Future<void> _validateName() async {
    final name = _nameController.text.trim();
    
    if (name.isEmpty) {
      setState(() {
        _nameError = 'Preset name is required';
      });
      return;
    }
    
    // Check for duplicate names (except when editing the same preset)
    final existingPresets = PresetService.instance.allPresets;
    final duplicateExists = existingPresets.any((preset) =>
        preset.name.toLowerCase() == name.toLowerCase() &&
        preset.id != widget.editingPreset?.id);
    
    if (duplicateExists) {
      setState(() {
        _nameError = 'A preset with this name already exists';
      });
      return;
    }
    
    setState(() {
      _nameError = null;
    });
  }

  Future<void> _savePreset() async {
    await _validateName();
    
    if (_nameError != null) return;
    
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      CameraPreset savedPreset;
      
      if (widget.editingPreset != null) {
        // Update existing preset
        savedPreset = widget.editingPreset!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _selectedCategory,
          settings: widget.currentSettings,
        );
        savedPreset = await PresetService.instance.updatePreset(savedPreset);
      } else {
        // Create new preset
        savedPreset = await PresetService.instance.createPreset(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          settings: widget.currentSettings,
          category: _selectedCategory,
          iconName: _selectedCategory.iconName,
        );
      }

      widget.onPresetCreated?.call(savedPreset);
      
      if (mounted) {
        Navigator.of(context).pop(savedPreset);
      }
    } catch (e) {
      debugPrint('Error saving preset: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save preset: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.editingPreset != null ? Icons.edit : Icons.add,
                    color: AppColors.accent,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.editingPreset != null ? 'Edit Preset' : 'Save Preset',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Preset name
                      _buildTextField(
                        controller: _nameController,
                        label: 'Preset Name',
                        hint: 'e.g., Golden Hour Portrait',
                        errorText: _nameError,
                        onChanged: (_) => _validateName(),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a preset name';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Description
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        hint: 'Describe when to use this preset',
                        maxLines: 3,
                      ),

                      const SizedBox(height: 16),

                      // Category selection
                      _buildCategorySelection(),

                      const SizedBox(height: 24),

                      // Current settings preview
                      _buildSettingsPreview(),
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _savePreset,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(widget.editingPreset != null ? 'Update' : 'Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    String? errorText,
    Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          validator: validator,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white54),
            errorText: errorText,
            filled: true,
            fillColor: Colors.white12,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.accent),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<PresetCategory>(
              value: _selectedCategory,
              dropdownColor: const Color(0xFF2A2A2A),
              style: const TextStyle(color: Colors.white),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
              onChanged: (PresetCategory? value) {
                if (value != null) {
                  setState(() {
                    _selectedCategory = value;
                  });
                }
              },
              items: PresetCategory.values.map((category) {
                return DropdownMenuItem<PresetCategory>(
                  value: category,
                  child: Row(
                    children: [
                      Icon(
                        _getIconData(category.iconName),
                        color: Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(category.displayName),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsPreview() {
    final settings = widget.currentSettings;
    final settingsList = <String>[];

    if (settings.iso != null) {
      settingsList.add('ISO ${settings.iso!.toInt()}');
    }
    if (settings.aperture != null) {
      settingsList.add('f/${settings.aperture}');
    }
    if (settings.shutterSpeed != null) {
      settingsList.add(settings.shutterSpeed!);
    }
    if (settings.whiteBalanceMode != WhiteBalanceMode.auto) {
      settingsList.add('WB: ${settings.whiteBalanceMode.name}');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Current Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(12),
          ),
          child: settingsList.isEmpty
              ? const Text(
                  'No specific settings configured',
                  style: TextStyle(color: Colors.white54),
                )
              : Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: settingsList.map((setting) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        setting,
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
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