import 'package:flutter/material.dart';
import '../models/auto_adjustment.dart';
import '../services/auto_adjustment_service.dart';

class AutoAdjustmentPreferencesScreen extends StatefulWidget {
  final String? userId;

  const AutoAdjustmentPreferencesScreen({
    super.key,
    this.userId,
  });

  @override
  State<AutoAdjustmentPreferencesScreen> createState() => _AutoAdjustmentPreferencesScreenState();
}

class _AutoAdjustmentPreferencesScreenState extends State<AutoAdjustmentPreferencesScreen> {
  final AutoAdjustmentService _service = AutoAdjustmentService();
  
  UserPreferences? _preferences;
  List<LearningInsight> _insights = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPreferencesAndInsights();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _loadPreferencesAndInsights() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final preferences = await _service.getUserPreferences(widget.userId);
      List<LearningInsight> insights = [];
      
      if (widget.userId != null) {
        try {
          insights = await _service.getLearningInsights(widget.userId!);
        } catch (e) {
          debugPrint('Failed to load insights: $e');
        }
      }

      setState(() {
        _preferences = preferences;
        _insights = insights;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _savePreferences() async {
    if (_preferences == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _service.updateUserPreferences(_preferences!, widget.userId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save preferences: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto-Adjustment Preferences'),
        elevation: 0,
        actions: [
          if (_preferences != null)
            TextButton(
              onPressed: _isSaving ? null : _savePreferences,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : _buildPreferencesContent(),
    );
  }

  Widget _buildErrorWidget() {
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
            'Failed to load preferences',
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
            onPressed: _loadPreferencesAndInsights,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_insights.isNotEmpty) ...[
            _buildInsightsSection(),
            const SizedBox(height: 24),
          ],
          _buildGeneralPreferences(),
          const SizedBox(height: 24),
          _buildISOPreferences(),
          const SizedBox(height: 24),
          _buildAperturePreferences(),
          const SizedBox(height: 24),
          _buildShutterPreferences(),
          const SizedBox(height: 24),
          _buildAdvancedPreferences(),
        ],
      ),
    );
  }

  Widget _buildInsightsSection() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Learning Insights',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ..._insights.map((insight) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight.displayType,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          insight.message,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralPreferences() {
    return _buildPreferenceSection(
      'General Preferences',
      [
        _buildSwitchTile(
          'Auto Focus',
          'Automatically adjust focus settings',
          _preferences!.autoFocus,
          (value) {
            setState(() {
              _preferences = _preferences!.copyWith(autoFocus: value);
            });
          },
        ),
        _buildDropdownTile(
          'Priority Mode',
          'How to balance exposure triangle adjustments',
          _preferences!.priorityMode,
          [
            'balanced',
            'exposure_priority',
            'aperture_priority',
            'iso_priority',
          ],
          (value) {
            setState(() {
              _preferences = _preferences!.copyWith(priorityMode: value);
            });
          },
        ),
        _buildDropdownTile(
          'Portrait Mode Style',
          'Preferred look for portrait photography',
          _preferences!.portraitMode,
          [
            'natural',
            'creamy',
            'sharp',
          ],
          (value) {
            setState(() {
              _preferences = _preferences!.copyWith(portraitMode: value);
            });
          },
        ),
      ],
    );
  }

  Widget _buildISOPreferences() {
    return _buildPreferenceSection(
      'ISO Preferences',
      [
        _buildSwitchTile(
          'Prefer Low ISO',
          'Prioritize image quality over convenience',
          _preferences!.preferLowISO,
          (value) {
            setState(() {
              _preferences = _preferences!.copyWith(preferLowISO: value);
            });
          },
        ),
        _buildSliderTile(
          'Maximum Preferred ISO',
          'Highest ISO you\'re comfortable with',
          _preferences!.maxPreferredISO.toDouble(),
          100,
          3200,
          [100, 200, 400, 800, 1600, 3200],
          (value) {
            setState(() {
              _preferences = _preferences!.copyWith(maxPreferredISO: value.round());
            });
          },
        ),
        _buildSliderTile(
          'Low Light Maximum ISO',
          'Highest ISO for challenging conditions',
          _preferences!.maxLowLightISO.toDouble(),
          400,
          6400,
          [400, 800, 1600, 3200, 6400],
          (value) {
            setState(() {
              _preferences = _preferences!.copyWith(maxLowLightISO: value.round());
            });
          },
        ),
        _buildSwitchTile(
          'Allow High ISO',
          'Use high ISO when necessary',
          _preferences!.allowHighISO,
          (value) {
            setState(() {
              _preferences = _preferences!.copyWith(allowHighISO: value);
            });
          },
        ),
      ],
    );
  }

  Widget _buildAperturePreferences() {
    return _buildPreferenceSection(
      'Aperture Preferences',
      [
        _buildSwitchTile(
          'Prefer Wide Aperture',
          'Favor shallow depth of field',
          _preferences!.preferWideAperture,
          (value) {
            setState(() {
              _preferences = _preferences!.copyWith(preferWideAperture: value);
            });
          },
        ),
        _buildSwitchTile(
          'Preserve Aperture',
          'Avoid changing aperture when possible',
          _preferences!.preserveAperture,
          (value) {
            setState(() {
              _preferences = _preferences!.copyWith(preserveAperture: value);
            });
          },
        ),
      ],
    );
  }

  Widget _buildShutterPreferences() {
    return _buildPreferenceSection(
      'Shutter Speed Preferences',
      [
        _buildSliderTile(
          'Sports Minimum Shutter',
          'Fastest shutter speed for sports (1/x seconds)',
          1 / _preferences!.minSportsShutter,
          250,
          1000,
          [250, 500, 1000],
          (value) {
            setState(() {
              _preferences = _preferences!.copyWith(minSportsShutter: 1 / value);
            });
          },
          valueFormatter: (value) => '1/${value.round()}',
        ),
      ],
    );
  }

  Widget _buildAdvancedPreferences() {
    return _buildPreferenceSection(
      'Advanced Settings',
      [
        ListTile(
          title: const Text('Reset to Defaults'),
          subtitle: const Text('Restore original preference settings'),
          trailing: OutlinedButton(
            onPressed: () {
              _showResetDialog();
            },
            child: const Text('Reset'),
          ),
        ),
      ],
    );
  }

  Widget _buildPreferenceSection(String title, List<Widget> children) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildDropdownTile(
    String title,
    String subtitle,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: DropdownButton<String>(
        value: value,
        items: options.map((option) => DropdownMenuItem(
          value: option,
          child: Text(option.replaceAll('_', ' ').toUpperCase()),
        )).toList(),
        onChanged: onChanged,
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildSliderTile(
    String title,
    String subtitle,
    double value,
    double min,
    double max,
    List<double> divisions,
    ValueChanged<double> onChanged, {
    String Function(double)? valueFormatter,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: Text(
            valueFormatter?.call(value) ?? value.round().toString(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions.length - 1,
          onChanged: onChanged,
        ),
      ],
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Preferences'),
        content: const Text(
          'This will restore all auto-adjustment preferences to their default values. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _preferences = UserPreferences();
              });
              Navigator.pop(context);
              _savePreferences();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}