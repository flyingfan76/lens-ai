import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/camera_preset.dart';

/// Service for managing camera presets with local storage
class PresetService {
  static const String _presetsKey = 'camera_presets';
  static const String _lastUsedPresetKey = 'last_used_preset';
  
  static PresetService? _instance;
  static PresetService get instance => _instance ??= PresetService._();
  
  PresetService._();

  List<CameraPreset> _presets = [];
  String? _lastUsedPresetId;
  bool _isInitialized = false;

  /// Initialize the service and load presets from storage
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _loadPresets();
      await _loadBuiltInPresets();
      _isInitialized = true;
      debugPrint('PresetService: Initialized with ${_presets.length} presets');
    } catch (e) {
      debugPrint('PresetService: Initialization error: $e');
      // Initialize with built-in presets only if loading fails
      await _loadBuiltInPresets();
      _isInitialized = true;
    }
  }

  /// Get all presets
  List<CameraPreset> get allPresets => List.unmodifiable(_presets);

  /// Get presets by category
  List<CameraPreset> getPresetsByCategory(PresetCategory category) {
    return _presets.where((preset) => preset.category == category).toList();
  }

  /// Get presets by source
  List<CameraPreset> getPresetsBySource(PresetSource source) {
    return _presets.where((preset) => preset.source == source).toList();
  }

  /// Get favorite presets
  List<CameraPreset> get favoritePresets {
    return _presets.where((preset) => preset.isFavorite).toList();
  }

  /// Get recently used presets
  List<CameraPreset> get recentPresets {
    var recent = List<CameraPreset>.from(_presets);
    recent.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
    return recent.take(10).toList();
  }

  /// Get most used presets
  List<CameraPreset> get popularPresets {
    var popular = List<CameraPreset>.from(_presets);
    popular.sort((a, b) => b.usageCount.compareTo(a.usageCount));
    return popular.take(10).toList();
  }

  /// Get built-in presets
  List<CameraPreset> get builtInPresets {
    return getPresetsBySource(PresetSource.builtin);
  }

  /// Get user-created presets
  List<CameraPreset> get userPresets {
    return getPresetsBySource(PresetSource.user);
  }

  /// Get preset by ID
  CameraPreset? getPresetById(String id) {
    try {
      return _presets.firstWhere((preset) => preset.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get last used preset
  CameraPreset? get lastUsedPreset {
    if (_lastUsedPresetId == null) return null;
    return getPresetById(_lastUsedPresetId!);
  }

  /// Create a new preset
  Future<CameraPreset> createPreset({
    required String name,
    required String description,
    required CameraSettings settings,
    PresetCategory category = PresetCategory.custom,
    String? iconName,
  }) async {
    final preset = CameraPreset(
      id: _generatePresetId(),
      name: name,
      description: description,
      category: category,
      source: PresetSource.user,
      createdAt: DateTime.now(),
      lastUsedAt: DateTime.now(),
      usageCount: 0,
      isFavorite: false,
      settings: settings,
      iconName: iconName,
    );

    _presets.add(preset);
    await _savePresets();
    
    debugPrint('PresetService: Created preset "${preset.name}"');
    return preset;
  }

  /// Update an existing preset
  Future<CameraPreset> updatePreset(CameraPreset preset) async {
    final index = _presets.indexWhere((p) => p.id == preset.id);
    if (index == -1) {
      throw Exception('Preset not found: ${preset.id}');
    }

    _presets[index] = preset;
    await _savePresets();
    
    debugPrint('PresetService: Updated preset "${preset.name}"');
    return preset;
  }

  /// Delete a preset
  Future<void> deletePreset(String presetId) async {
    final preset = getPresetById(presetId);
    if (preset == null) {
      throw Exception('Preset not found: $presetId');
    }

    // Don't allow deletion of built-in presets
    if (preset.source == PresetSource.builtin) {
      throw Exception('Cannot delete built-in preset');
    }

    _presets.removeWhere((p) => p.id == presetId);
    
    // Clear last used if it was this preset
    if (_lastUsedPresetId == presetId) {
      _lastUsedPresetId = null;
      await _saveLastUsedPreset();
    }

    await _savePresets();
    debugPrint('PresetService: Deleted preset "${preset.name}"');
  }

  /// Duplicate a preset
  Future<CameraPreset> duplicatePreset(String presetId, {String? newName}) async {
    final original = getPresetById(presetId);
    if (original == null) {
      throw Exception('Preset not found: $presetId');
    }

    final duplicatedName = newName ?? '${original.name} Copy';
    
    return await createPreset(
      name: duplicatedName,
      description: original.description,
      settings: original.settings,
      category: original.category,
      iconName: original.iconName,
    );
  }

  /// Apply a preset (increment usage count and update last used)
  Future<CameraPreset> applyPreset(String presetId) async {
    final preset = getPresetById(presetId);
    if (preset == null) {
      throw Exception('Preset not found: $presetId');
    }

    final updatedPreset = preset.copyWith(
      usageCount: preset.usageCount + 1,
      lastUsedAt: DateTime.now(),
    );

    await updatePreset(updatedPreset);
    
    _lastUsedPresetId = presetId;
    await _saveLastUsedPreset();

    debugPrint('PresetService: Applied preset "${preset.name}" (usage: ${updatedPreset.usageCount})');
    return updatedPreset;
  }

  /// Toggle favorite status
  Future<CameraPreset> toggleFavorite(String presetId) async {
    final preset = getPresetById(presetId);
    if (preset == null) {
      throw Exception('Preset not found: $presetId');
    }

    final updatedPreset = preset.copyWith(isFavorite: !preset.isFavorite);
    return await updatePreset(updatedPreset);
  }

  /// Search presets by name, description, or tags
  List<CameraPreset> searchPresets(String query) {
    if (query.isEmpty) return allPresets;
    
    final lowercaseQuery = query.toLowerCase();
    
    return _presets.where((preset) {
      return preset.name.toLowerCase().contains(lowercaseQuery) ||
             preset.description.toLowerCase().contains(lowercaseQuery) ||
             preset.category.displayName.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  /// Export presets to JSON
  String exportPresets({List<String>? presetIds}) {
    List<CameraPreset> presetsToExport;
    
    if (presetIds != null) {
      presetsToExport = presetIds
          .map((id) => getPresetById(id))
          .where((preset) => preset != null)
          .cast<CameraPreset>()
          .toList();
    } else {
      presetsToExport = userPresets; // Only export user presets
    }

    final exportData = {
      'version': '1.0',
      'exportDate': DateTime.now().toIso8601String(),
      'presets': presetsToExport.map((preset) => preset.toJson()).toList(),
    };

    return jsonEncode(exportData);
  }

  /// Import presets from JSON
  Future<List<CameraPreset>> importPresets(String jsonData) async {
    try {
      final data = jsonDecode(jsonData) as Map<String, dynamic>;
      final presetsList = data['presets'] as List;
      
      final importedPresets = <CameraPreset>[];
      
      for (final presetData in presetsList) {
        final preset = CameraPreset.fromJson(presetData as Map<String, dynamic>);
        
        // Generate new ID to avoid conflicts
        final importedPreset = preset.copyWith(
          id: _generatePresetId(),
          source: PresetSource.imported,
          createdAt: DateTime.now(),
          usageCount: 0,
        );
        
        _presets.add(importedPreset);
        importedPresets.add(importedPreset);
      }
      
      await _savePresets();
      debugPrint('PresetService: Imported ${importedPresets.length} presets');
      
      return importedPresets;
    } catch (e) {
      debugPrint('PresetService: Import error: $e');
      throw Exception('Failed to import presets: $e');
    }
  }

  /// Clear all user presets (keep built-in presets)
  Future<void> clearUserPresets() async {
    _presets.removeWhere((preset) => preset.source != PresetSource.builtin);
    await _savePresets();
    debugPrint('PresetService: Cleared all user presets');
  }

  // Private methods

  Future<void> _loadPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final presetsJson = prefs.getString(_presetsKey);
    _lastUsedPresetId = prefs.getString(_lastUsedPresetKey);
    
    if (presetsJson != null) {
      final presetsList = jsonDecode(presetsJson) as List;
      _presets = presetsList
          .map((json) => CameraPreset.fromJson(json as Map<String, dynamic>))
          .toList();
    }
  }

  Future<void> _savePresets() async {
    final prefs = await SharedPreferences.getInstance();
    final presetsJson = jsonEncode(_presets.map((preset) => preset.toJson()).toList());
    await prefs.setString(_presetsKey, presetsJson);
  }

  Future<void> _saveLastUsedPreset() async {
    final prefs = await SharedPreferences.getInstance();
    if (_lastUsedPresetId != null) {
      await prefs.setString(_lastUsedPresetKey, _lastUsedPresetId!);
    } else {
      await prefs.remove(_lastUsedPresetKey);
    }
  }

  Future<void> _loadBuiltInPresets() async {
    // Only add built-in presets if they don't already exist
    final existingBuiltInIds = builtInPresets.map((p) => p.id).toSet();
    
    for (final preset in _getBuiltInPresets()) {
      if (!existingBuiltInIds.contains(preset.id)) {
        _presets.add(preset);
      }
    }
    
    await _savePresets();
  }

  String _generatePresetId() {
    return 'preset_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }

  /// Built-in professional presets
  List<CameraPreset> _getBuiltInPresets() {
    final now = DateTime.now();
    
    return [
      // Portrait preset
      CameraPreset(
        id: 'builtin_portrait',
        name: 'Portrait',
        description: 'Perfect for people photography with beautiful bokeh',
        category: PresetCategory.portrait,
        source: PresetSource.builtin,
        createdAt: now,
        lastUsedAt: now,
        usageCount: 0,
        isFavorite: false,
        iconName: 'person_outline',
        settings: const CameraSettings(
          aperture: 2.8,
          iso: 200,
          shutterSpeed: '1/125',
          focusMode: FocusMode.single,
          meteringMode: MeteringMode.center,
          whiteBalanceMode: WhiteBalanceMode.auto,
          resolution: ResolutionPreset.high,
          imageFormat: ImageFormat.jpeg,
          enableHDR: false,
          flashMode: FlashMode.auto,
        ),
      ),
      
      // Landscape preset
      CameraPreset(
        id: 'builtin_landscape',
        name: 'Landscape',
        description: 'Sharp landscapes with great depth of field',
        category: PresetCategory.landscape,
        source: PresetSource.builtin,
        createdAt: now,
        lastUsedAt: now,
        usageCount: 0,
        isFavorite: false,
        iconName: 'landscape',
        settings: const CameraSettings(
          aperture: 8.0,
          iso: 100,
          shutterSpeed: '1/60',
          focusMode: FocusMode.auto,
          meteringMode: MeteringMode.matrix,
          whiteBalanceMode: WhiteBalanceMode.daylight,
          resolution: ResolutionPreset.veryHigh,
          imageFormat: ImageFormat.jpeg,
          enableHDR: true,
          flashMode: FlashMode.off,
          gridLines: true,
        ),
      ),
      
      // Sports preset
      CameraPreset(
        id: 'builtin_sports',
        name: 'Sports',
        description: 'Fast action with high shutter speeds',
        category: PresetCategory.sports,
        source: PresetSource.builtin,
        createdAt: now,
        lastUsedAt: now,
        usageCount: 0,
        isFavorite: false,
        iconName: 'sports',
        settings: const CameraSettings(
          aperture: 4.0,
          iso: 800,
          shutterSpeed: '1/500',
          focusMode: FocusMode.continuous,
          meteringMode: MeteringMode.matrix,
          whiteBalanceMode: WhiteBalanceMode.auto,
          resolution: ResolutionPreset.high,
          imageFormat: ImageFormat.jpeg,
          enableHDR: false,
          flashMode: FlashMode.off,
        ),
      ),
      
      // Low Light preset
      CameraPreset(
        id: 'builtin_lowlight',
        name: 'Low Light',
        description: 'Optimized for challenging lighting conditions',
        category: PresetCategory.lowLight,
        source: PresetSource.builtin,
        createdAt: now,
        lastUsedAt: now,
        usageCount: 0,
        isFavorite: false,
        iconName: 'nights_stay',
        settings: const CameraSettings(
          aperture: 1.8,
          iso: 1600,
          shutterSpeed: '1/30',
          focusMode: FocusMode.single,
          meteringMode: MeteringMode.center,
          whiteBalanceMode: WhiteBalanceMode.auto,
          resolution: ResolutionPreset.high,
          imageFormat: ImageFormat.jpeg,
          enableHDR: false,
          flashMode: FlashMode.auto,
        ),
      ),
      
      // Sunset preset
      CameraPreset(
        id: 'builtin_sunset',
        name: 'Sunset',
        description: 'Capture the golden hour magic',
        category: PresetCategory.sunset,
        source: PresetSource.builtin,
        createdAt: now,
        lastUsedAt: now,
        usageCount: 0,
        isFavorite: false,
        iconName: 'wb_sunny',
        settings: const CameraSettings(
          aperture: 5.6,
          iso: 100,
          shutterSpeed: '1/125',
          exposureCompensation: -0.5,
          focusMode: FocusMode.auto,
          meteringMode: MeteringMode.center,
          whiteBalanceMode: WhiteBalanceMode.daylight,
          colorTemperature: 3200,
          resolution: ResolutionPreset.high,
          imageFormat: ImageFormat.jpeg,
          enableHDR: true,
          flashMode: FlashMode.off,
          gridLines: true,
        ),
      ),
      
      // Macro preset
      CameraPreset(
        id: 'builtin_macro',
        name: 'Macro',
        description: 'Close-up photography with fine details',
        category: PresetCategory.macro,
        source: PresetSource.builtin,
        createdAt: now,
        lastUsedAt: now,
        usageCount: 0,
        isFavorite: false,
        iconName: 'center_focus_strong',
        settings: const CameraSettings(
          aperture: 4.0,
          iso: 400,
          shutterSpeed: '1/250',
          focusMode: FocusMode.manual,
          meteringMode: MeteringMode.spot,
          whiteBalanceMode: WhiteBalanceMode.auto,
          resolution: ResolutionPreset.veryHigh,
          imageFormat: ImageFormat.jpeg,
          enableHDR: false,
          flashMode: FlashMode.off,
        ),
      ),
    ];
  }
}