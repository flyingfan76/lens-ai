import 'package:flutter/material.dart';
import '../models/auto_adjustment.dart';
import '../services/auto_adjustment_service.dart';

class AutoAdjustmentWidget extends StatefulWidget {
  final CameraSettings currentSettings;
  final String sceneType;
  final String lightingCondition;
  final String? cameraBrand;
  final String? userId;
  final Function(CameraSettings)? onSettingsAccepted;
  final Function(CameraSettings)? onSettingsModified;
  final VoidCallback? onSettingsRejected;

  const AutoAdjustmentWidget({
    Key? key,
    required this.currentSettings,
    required this.sceneType,
    required this.lightingCondition,
    this.cameraBrand,
    this.userId,
    this.onSettingsAccepted,
    this.onSettingsModified,
    this.onSettingsRejected,
  }) : super(key: key);

  @override
  State<AutoAdjustmentWidget> createState() => _AutoAdjustmentWidgetState();
}

class _AutoAdjustmentWidgetState extends State<AutoAdjustmentWidget> {
  final AutoAdjustmentService _service = AutoAdjustmentService();
  
  AutoAdjustmentResult? _result;
  bool _isLoading = false;
  String? _error;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _getRecommendations();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _getRecommendations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _service.getRecommendations(
        sceneType: widget.sceneType,
        currentSettings: widget.currentSettings,
        lightiningCondition: widget.lightingCondition,
        cameraBrand: widget.cameraBrand,
      );

      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _recordFeedback(String action, [CameraSettings? modifiedSettings]) async {
    if (widget.userId != null && _result != null) {
      try {
        await _service.recordUserFeedback(
          userId: widget.userId!,
          sceneType: widget.sceneType,
          lightingCondition: widget.lightingCondition,
          originalSettings: _result!.originalSettings,
          suggestedSettings: _result!.optimizedSettings,
          finalSettings: modifiedSettings ?? _result!.optimizedSettings,
          userAction: action,
          confidence: _result!.confidence,
          processingTime: _result!.processingTime,
        );
      } catch (e) {
        debugPrint('Failed to record feedback: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingWidget();
    }

    if (_error != null) {
      return _buildErrorWidget();
    }

    if (_result == null) {
      return const SizedBox.shrink();
    }

    return _buildRecommendationWidget();
  }

  Widget _buildLoadingWidget() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            const Text('Analyzing settings...'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Auto-adjustment unavailable',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    'Check your connection and try again',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _getRecommendations,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationWidget() {
    final theme = Theme.of(context);
    final hasChanges = _hasSignificantChanges();
    
    if (!hasChanges) {
      return _buildOptimalSettingsWidget();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildSettingsComparison(),
            if (_showDetails) ...[
              const SizedBox(height: 16),
              _buildAnalysisDetails(),
            ],
            const SizedBox(height: 16),
            _buildActions(),
            if (_result!.recommendations.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildRecommendations(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptimalSettingsWidget() {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings Optimized',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Your current settings are already optimal for ${widget.sceneType} photography',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.green.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Icon(
          Icons.auto_fix_high,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Auto-Adjustment Suggestions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Optimized for ${_result!.analysis.displaySceneType}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _showDetails = !_showDetails;
            });
          },
          icon: Icon(
            _showDetails ? Icons.expand_less : Icons.expand_more,
          ),
          tooltip: _showDetails ? 'Hide details' : 'Show details',
        ),
      ],
    );
  }

  Widget _buildSettingsComparison() {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Current',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.arrow_forward,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Suggested',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSettingRow(
            'ISO',
            _result!.originalSettings.displayISO,
            _result!.optimizedSettings.displayISO,
            _result!.originalSettings.iso != _result!.optimizedSettings.iso,
          ),
          _buildSettingRow(
            'Aperture',
            _result!.originalSettings.displayAperture,
            _result!.optimizedSettings.displayAperture,
            _result!.originalSettings.aperture != _result!.optimizedSettings.aperture,
          ),
          _buildSettingRow(
            'Shutter',
            _result!.originalSettings.displayShutterSpeed,
            _result!.optimizedSettings.displayShutterSpeed,
            _result!.originalSettings.shutterSpeed != _result!.optimizedSettings.shutterSpeed,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(String label, String current, String suggested, bool hasChanged) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              current,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 16),
          Icon(
            hasChanged ? Icons.arrow_forward : Icons.check,
            color: hasChanged ? theme.colorScheme.primary : Colors.green,
            size: 16,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              suggested,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: hasChanged ? theme.colorScheme.primary : null,
                fontWeight: hasChanged ? FontWeight.w600 : null,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisDetails() {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analysis Details',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _buildAnalysisItem('Scene Type', _result!.analysis.displaySceneType),
          _buildAnalysisItem('Lighting', _result!.analysis.displayLightingCondition),
          _buildAnalysisItem('Confidence', '${(_result!.confidence * 100).toStringAsFixed(0)}%'),
          _buildAnalysisItem('Processing Time', '${_result!.processingTime}ms'),
          if (_result!.analysis.exposureAnalysis != null)
            _buildAnalysisItem('Exposure Quality', _result!.analysis.exposureAnalysis!.exposureQuality),
          if (_result!.analysis.focusAnalysis != null)
            _buildAnalysisItem('Focus Quality', _result!.analysis.focusAnalysis!.focusQuality),
        ],
      ),
    );
  }

  Widget _buildAnalysisItem(String label, String value) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall,
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              _recordFeedback('rejected');
              widget.onSettingsRejected?.call();
            },
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Dismiss'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: () {
              _recordFeedback('accepted');
              widget.onSettingsAccepted?.call(_result!.optimizedSettings);
            },
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Apply Settings'),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendations() {
    final theme = Theme.of(context);
    final highPriorityRecs = _result!.recommendations.where((r) => r.isHighPriority).toList();
    
    if (highPriorityRecs.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.orange.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tips_and_updates,
                color: Colors.orange.shade700,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Recommendations',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...highPriorityRecs.map((rec) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• ${rec.message}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.orange.shade700,
              ),
            ),
          )),
        ],
      ),
    );
  }

  bool _hasSignificantChanges() {
    if (_result == null) return false;
    
    final original = _result!.originalSettings;
    final optimized = _result!.optimizedSettings;
    
    // Check for significant ISO changes (>20%)
    final isoChange = (original.iso - optimized.iso).abs() / original.iso;
    if (isoChange > 0.2) return true;
    
    // Check for aperture changes
    if (original.aperture != optimized.aperture) return true;
    
    // Check for shutter speed changes
    if (original.shutterSpeed != optimized.shutterSpeed) return true;
    
    return false;
  }
}