import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class WhiteBalanceControl extends StatefulWidget {
  final WhiteBalanceSettings initialSettings;
  final Function(WhiteBalanceSettings) onChanged;
  final bool isAdvanced;

  const WhiteBalanceControl({
    super.key,
    required this.initialSettings,
    required this.onChanged,
    this.isAdvanced = false,
  });

  @override
  State<WhiteBalanceControl> createState() => _WhiteBalanceControlState();
}

class _WhiteBalanceControlState extends State<WhiteBalanceControl> {
  late WhiteBalanceSettings _settings;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings.copy();
    _showAdvanced = widget.isAdvanced;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: constraints.maxWidth,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildModeSelector(),
              if (_settings.mode == WBMode.custom) ...[
                const SizedBox(height: 16),
                _buildKelvinSlider(),
              ],
              if (_showAdvanced) ...[
                const SizedBox(height: 16),
                _buildShiftControls(),
                const SizedBox(height: 16),
                _buildAutoWBBias(),
                const SizedBox(height: 16),
                _buildPrioritySelector(),
              ],
              const SizedBox(height: 12),
              _buildToggleAdvanced(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(
          Icons.wb_sunny,
          color: AppColors.accent,
          size: 24,
        ),
        const SizedBox(width: 12),
        const Flexible(
          child: Text(
            'White Balance',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${_getEffectiveKelvin()}K',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mode',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: WBMode.values.map((mode) {
                final isSelected = _settings.mode == mode;
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.45, // Max 45% of available width
                  ),
                  child: GestureDetector(
                    onTap: () => _updateMode(mode),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.white30,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getModeIcon(mode),
                            color: isSelected ? Colors.white : Colors.white70,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _getModeLabel(mode),
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildKelvinSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Temperature',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              '${_settings.kelvin.round()}K',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _getKelvinColor(_settings.kelvin),
            inactiveTrackColor: Colors.white24,
            thumbColor: _getKelvinColor(_settings.kelvin),
            overlayColor: _getKelvinColor(_settings.kelvin).withValues(alpha: 0.2),
          ),
          child: Slider(
            value: _settings.kelvin,
            min: 2000,
            max: 10000,
            divisions: 80,
            onChanged: (value) {
              setState(() {
                _settings.kelvin = value;
              });
              widget.onChanged(_settings);
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '2000K',
              style: TextStyle(
                color: Colors.orange.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            Text(
              '10000K',
              style: TextStyle(
                color: Colors.blue.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShiftControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fine Tuning',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        _buildShiftSlider(
          'Magenta - Green',
          _settings.magentaGreenShift,
          -9,
          9,
          Colors.pink,
          Colors.green,
          (value) {
            setState(() {
              _settings.magentaGreenShift = value.round();
            });
            widget.onChanged(_settings);
          },
        ),
        const SizedBox(height: 16),
        _buildShiftSlider(
          'Blue - Amber',
          _settings.blueAmberShift,
          -9,
          9,
          Colors.blue,
          Colors.orange,
          (value) {
            setState(() {
              _settings.blueAmberShift = value.round();
            });
            widget.onChanged(_settings);
          },
        ),
      ],
    );
  }

  Widget _buildShiftSlider(
    String label,
    int value,
    int min,
    int max,
    Color negativeColor,
    Color positiveColor,
    Function(double) onChanged,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: value == 0
                    ? Colors.grey[700]
                    : (value > 0 ? positiveColor : negativeColor).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value == 0
                    ? '0'
                    : '${value > 0 ? '+' : ''}$value',
                style: TextStyle(
                  color: value == 0
                      ? Colors.white70
                      : (value > 0 ? positiveColor : negativeColor),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: value >= 0 ? positiveColor : negativeColor,
            inactiveTrackColor: Colors.white24,
            thumbColor: value == 0 ? Colors.white70 : 
                       (value > 0 ? positiveColor : negativeColor),
          ),
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: (max - min),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildAutoWBBias() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Auto WB Bias',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Switch(
              value: _settings.autoWBBiasEnabled,
              onChanged: (value) {
                setState(() {
                  _settings.autoWBBiasEnabled = value;
                });
                widget.onChanged(_settings);
              },
              activeColor: AppColors.primary,
            ),
          ],
        ),
        if (_settings.autoWBBiasEnabled) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildBiasControl('A', _settings.autoWBAmber, Colors.orange),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildBiasControl('M', _settings.autoWBMagenta, Colors.pink),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBiasControl(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(7, (index) {
            final biasValue = index - 3;
            final isActive = value == biasValue;
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (label == 'A') {
                    _settings.autoWBAmber = biasValue;
                  } else {
                    _settings.autoWBMagenta = biasValue;
                  }
                });
                widget.onChanged(_settings);
              },
              child: Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isActive ? color : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive ? color : color.withValues(alpha: 0.3),
                  ),
                ),
                child: Center(
                  child: Text(
                    biasValue == 0 ? '0' : '${biasValue > 0 ? '+' : ''}$biasValue',
                    style: TextStyle(
                      color: isActive ? Colors.white : color.withValues(alpha: 0.7),
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildPrioritySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Priority',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: WBPriority.values.map((priority) {
            final isSelected = _settings.priority == priority;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _settings.priority = priority;
                  });
                  widget.onChanged(_settings);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.white30,
                    ),
                  ),
                  child: Text(
                    _getPriorityLabel(priority),
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildToggleAdvanced() {
    return Center(
      child: TextButton.icon(
        onPressed: () {
          setState(() {
            _showAdvanced = !_showAdvanced;
          });
        },
        icon: Icon(
          _showAdvanced ? Icons.expand_less : Icons.expand_more,
          color: Colors.white60,
        ),
        label: Text(
          _showAdvanced ? 'Basic Controls' : 'Advanced Controls',
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  void _updateMode(WBMode mode) {
    setState(() {
      _settings.mode = mode;
      if (mode != WBMode.custom) {
        _settings.kelvin = _getModeKelvin(mode).toDouble();
      }
    });
    widget.onChanged(_settings);
  }

  int _getEffectiveKelvin() {
    if (_settings.mode == WBMode.custom) {
      return _settings.kelvin.round();
    }
    return _getModeKelvin(_settings.mode);
  }

  int _getModeKelvin(WBMode mode) {
    switch (mode) {
      case WBMode.tungsten:
        return 3200;
      case WBMode.fluorescent:
        return 4000;
      case WBMode.daylight:
        return 5500;
      case WBMode.flash:
        return 5500;
      case WBMode.cloudy:
        return 6500;
      case WBMode.shade:
        return 7500;
      default:
        return 5500;
    }
  }

  Color _getKelvinColor(double kelvin) {
    if (kelvin < 3000) return Colors.orange;
    if (kelvin < 4000) return Colors.orange.shade300;
    if (kelvin < 5000) return Colors.yellow.shade300;
    if (kelvin < 6000) return Colors.white;
    if (kelvin < 7000) return Colors.blue.shade100;
    return Colors.blue.shade300;
  }

  IconData _getModeIcon(WBMode mode) {
    switch (mode) {
      case WBMode.auto:
        return Icons.auto_awesome;
      case WBMode.tungsten:
        return Icons.lightbulb;
      case WBMode.fluorescent:
        return Icons.light;
      case WBMode.daylight:
        return Icons.wb_sunny;
      case WBMode.flash:
        return Icons.flash_on;
      case WBMode.cloudy:
        return Icons.cloud;
      case WBMode.shade:
        return Icons.nature;
      case WBMode.custom:
        return Icons.tune;
    }
  }

  String _getModeLabel(WBMode mode) {
    switch (mode) {
      case WBMode.auto:
        return 'Auto';
      case WBMode.tungsten:
        return 'Tungsten';
      case WBMode.fluorescent:
        return 'Fluorescent';
      case WBMode.daylight:
        return 'Daylight';
      case WBMode.flash:
        return 'Flash';
      case WBMode.cloudy:
        return 'Cloudy';
      case WBMode.shade:
        return 'Shade';
      case WBMode.custom:
        return 'Custom';
    }
  }

  String _getPriorityLabel(WBPriority priority) {
    switch (priority) {
      case WBPriority.standard:
        return 'Standard';
      case WBPriority.whitePriority:
        return 'White Priority';
      case WBPriority.atmospherePriority:
        return 'Atmosphere';
    }
  }
}

// Data Models
enum WBMode {
  auto,
  daylight,
  cloudy,
  tungsten,
  fluorescent,
  flash,
  shade,
  custom,
}

enum WBPriority {
  standard,
  whitePriority,
  atmospherePriority,
}

class WhiteBalanceSettings {
  WBMode mode;
  double kelvin;
  int magentaGreenShift;
  int blueAmberShift;
  bool autoWBBiasEnabled;
  int autoWBAmber;
  int autoWBMagenta;
  WBPriority priority;

  WhiteBalanceSettings({
    this.mode = WBMode.auto,
    this.kelvin = 5500,
    this.magentaGreenShift = 0,
    this.blueAmberShift = 0,
    this.autoWBBiasEnabled = false,
    this.autoWBAmber = 0,
    this.autoWBMagenta = 0,
    this.priority = WBPriority.standard,
  });

  WhiteBalanceSettings copy() {
    return WhiteBalanceSettings(
      mode: mode,
      kelvin: kelvin,
      magentaGreenShift: magentaGreenShift,
      blueAmberShift: blueAmberShift,
      autoWBBiasEnabled: autoWBBiasEnabled,
      autoWBAmber: autoWBAmber,
      autoWBMagenta: autoWBMagenta,
      priority: priority,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode.name,
      'kelvin': kelvin,
      'shift': {
        'magentaGreen': magentaGreenShift,
        'blueAmber': blueAmberShift,
      },
      'autoWBBias': {
        'enabled': autoWBBiasEnabled,
        'amber': autoWBAmber,
        'magenta': autoWBMagenta,
      },
      'priority': priority.name,
    };
  }

  static WhiteBalanceSettings fromJson(Map<String, dynamic> json) {
    return WhiteBalanceSettings(
      mode: WBMode.values.firstWhere(
        (mode) => mode.name == json['mode'],
        orElse: () => WBMode.auto,
      ),
      kelvin: (json['kelvin'] ?? 5500).toDouble(),
      magentaGreenShift: json['shift']?['magentaGreen'] ?? 0,
      blueAmberShift: json['shift']?['blueAmber'] ?? 0,
      autoWBBiasEnabled: json['autoWBBias']?['enabled'] ?? false,
      autoWBAmber: json['autoWBBias']?['amber'] ?? 0,
      autoWBMagenta: json['autoWBBias']?['magenta'] ?? 0,
      priority: WBPriority.values.firstWhere(
        (priority) => priority.name == json['priority'],
        orElse: () => WBPriority.standard,
      ),
    );
  }
}