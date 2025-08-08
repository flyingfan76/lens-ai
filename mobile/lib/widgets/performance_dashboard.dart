import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/utils/performance_monitor.dart';
import '../core/utils/metrics_collector.dart';

/// Real-Time Performance Dashboard Widget
/// 
/// Features:
/// - Live performance metrics visualization
/// - Interactive charts and graphs
/// - System resource monitoring
/// - Alert notifications
/// - Performance recommendations
/// - Export capabilities
class PerformanceDashboard extends StatefulWidget {
  final PerformanceMonitor performanceMonitor;
  final MetricsCollector metricsCollector;
  final bool showAdvancedMetrics;
  final Duration refreshInterval;
  final VoidCallback? onExport;
  
  const PerformanceDashboard({
    super.key,
    required this.performanceMonitor,
    required this.metricsCollector,
    this.showAdvancedMetrics = false,
    this.refreshInterval = const Duration(seconds: 2),
    this.onExport,
  });
  
  @override
  State<PerformanceDashboard> createState() => _PerformanceDashboardState();
}

class _PerformanceDashboardState extends State<PerformanceDashboard>
    with TickerProviderStateMixin {
  
  late Timer _refreshTimer;
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  
  ComprehensivePerformanceDashboard? _dashboardData;
  CollectionStatistics? _collectionStats;
  List<PerformanceAlert> _currentAlerts = [];
  
  // Chart data
  final List<ChartDataPoint> _cpuData = [];
  final List<ChartDataPoint> _memoryData = [];
  final List<ChartDataPoint> _frameRateData = [];
  
  // UI state
  bool _isLoading = true;
  int _selectedTabIndex = 0;
  bool _showAlerts = true;
  
  int get selectedTabIndex => _selectedTabIndex;
  
  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _startRefreshTimer();
    _loadInitialData();
    
    // Listen to performance events
    widget.performanceMonitor.eventStream.listen(_handlePerformanceEvent);
    widget.performanceMonitor.alertStream.listen(_handleAlert);
  }
  
  @override
  void dispose() {
    _refreshTimer.cancel();
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
  
  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(widget.refreshInterval, (_) {
      _refreshData();
    });
  }
  
  Future<void> _loadInitialData() async {
    await _refreshData();
    _fadeController.forward();
  }
  
  Future<void> _refreshData() async {
    try {
      final dashboardData = widget.performanceMonitor.getDashboard();
      final collectionStats = widget.metricsCollector.getStatistics();
      
      setState(() {
        _dashboardData = dashboardData;
        _collectionStats = collectionStats;
        _currentAlerts = dashboardData.currentAlerts;
        _isLoading = false;
      });
      
      _updateChartData(dashboardData);
      
    } catch (e) {
      debugPrint('PerformanceDashboard: Error refreshing data - $e');
    }
  }
  
  void _updateChartData(ComprehensivePerformanceDashboard data) {
    final now = DateTime.now();
    
    // Update CPU data
    _cpuData.add(ChartDataPoint(
      time: now,
      value: data.systemResources.cpuUsage,
    ));
    
    // Update memory data
    _memoryData.add(ChartDataPoint(
      time: now,
      value: data.systemResources.memoryUsage.toDouble(),
    ));
    
    // Update frame rate data (average from all screens)
    final averageFrameRate = data.screenPerformance.values.isEmpty
        ? 60.0
        : data.screenPerformance.values
            .map((screen) => screen.averageFrameRate)
            .reduce((a, b) => a + b) / data.screenPerformance.values.length;
    
    _frameRateData.add(ChartDataPoint(
      time: now,
      value: averageFrameRate,
    ));
    
    // Keep only last 60 data points (2 minutes at 2-second intervals)
    const maxDataPoints = 60;
    if (_cpuData.length > maxDataPoints) {
      _cpuData.removeRange(0, _cpuData.length - maxDataPoints);
    }
    if (_memoryData.length > maxDataPoints) {
      _memoryData.removeRange(0, _memoryData.length - maxDataPoints);
    }
    if (_frameRateData.length > maxDataPoints) {
      _frameRateData.removeRange(0, _frameRateData.length - maxDataPoints);
    }
  }
  
  void _handlePerformanceEvent(PerformanceEvent event) {
    if (event.severity.index >= EventSeverity.warning.index) {
      HapticFeedback.lightImpact();
    }
  }
  
  void _handleAlert(PerformanceAlert alert) {
    if (alert.severity.index >= EventSeverity.error.index) {
      HapticFeedback.mediumImpact();
    }
    
    setState(() {
      _currentAlerts.add(alert);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Dashboard'),
        actions: [
          if (widget.onExport != null)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: widget.onExport,
              tooltip: 'Export Data',
            ),
          IconButton(
            icon: Icon(_showAlerts ? Icons.notifications : Icons.notifications_off),
            onPressed: () => setState(() => _showAlerts = !_showAlerts),
            tooltip: 'Toggle Alerts',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeController,
              child: _buildDashboardContent(),
            ),
    );
  }
  
  Widget _buildDashboardContent() {
    return Column(
      children: [
        if (_showAlerts && _currentAlerts.isNotEmpty)
          _buildAlertsSection(),
        
        _buildTabBar(),
        
        Expanded(
          child: TabBarView(
            children: [
              _buildOverviewTab(),
              _buildSystemTab(),
              _buildPerformanceTab(),
              if (widget.showAdvancedMetrics) _buildAdvancedTab(),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildAlertsSection() {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          ListTile(
            leading: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Icon(
                  Icons.warning,
                  color: Colors.red.withOpacity(0.7 + 0.3 * _pulseController.value),
                );
              },
            ),
            title: Text('Performance Alerts (${_currentAlerts.length})'),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _currentAlerts.clear()),
            ),
          ),
          ..._currentAlerts.take(3).map((alert) => _buildAlertTile(alert)),
        ],
      ),
    );
  }
  
  Widget _buildAlertTile(PerformanceAlert alert) {
    return ListTile(
      dense: true,
      leading: Icon(
        _getAlertIcon(alert.severity),
        color: _getAlertColor(alert.severity),
        size: 16,
      ),
      title: Text(
        alert.message,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        alert.timestamp.toString(),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
  
  Widget _buildTabBar() {
    return DefaultTabController(
      length: widget.showAdvancedMetrics ? 4 : 3,
      child: TabBar(
        onTap: (index) => setState(() => _selectedTabIndex = index),
        tabs: [
          const Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
          const Tab(text: 'System', icon: Icon(Icons.memory)),
          const Tab(text: 'Performance', icon: Icon(Icons.speed)),
          if (widget.showAdvancedMetrics)
            const Tab(text: 'Advanced', icon: Icon(Icons.analytics)),
        ],
      ),
    );
  }
  
  Widget _buildOverviewTab() {
    if (_dashboardData == null) return const SizedBox();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildOverviewCards(),
          const SizedBox(height: 16),
          _buildQuickMetrics(),
          const SizedBox(height: 16),
          _buildRecommendations(),
        ],
      ),
    );
  }
  
  Widget _buildOverviewCards() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: 'Performance Score',
            value: _dashboardData?.summary.totalOptimizations.toString() ?? '0',
            subtitle: 'Optimizations',
            icon: Icons.trending_up,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            title: 'Response Time',
            value: '${_dashboardData?.userExperience.averageResponseTime.toInt() ?? 0}ms',
            subtitle: 'Average',
            icon: Icons.timer,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }
  
  Widget _buildQuickMetrics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Real-Time Metrics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildMetricRow('CPU Usage', 
              '${_dashboardData?.systemResources.cpuUsage.toStringAsFixed(1) ?? '0'}%',
              _dashboardData?.systemResources.cpuUsage ?? 0.0,
              100.0,
            ),
            _buildMetricRow('Memory Usage', 
              '${_dashboardData?.systemResources.memoryUsage ?? 0}MB',
              _dashboardData?.systemResources.memoryUsage.toDouble() ?? 0.0,
              1000.0,
            ),
            _buildMetricRow('Battery Level', 
              '${_dashboardData?.batteryStatus.level.toStringAsFixed(0) ?? '100'}%',
              _dashboardData?.batteryStatus.level ?? 100.0,
              100.0,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMetricRow(String label, String value, double current, double max) {
    final percentage = (current / max).clamp(0.0, 1.0);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation(
              _getProgressColor(percentage),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSystemTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSystemResourceChart(),
          const SizedBox(height: 16),
          _buildSystemInfo(),
          const SizedBox(height: 16),
          _buildCollectionStats(),
        ],
      ),
    );
  }
  
  Widget _buildSystemResourceChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Resources',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _buildChart(_cpuData, 'CPU Usage', Colors.blue),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _buildChart(_memoryData, 'Memory Usage', Colors.green),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSystemInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Device Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Platform', _dashboardData?.deviceCapabilities.toString() ?? 'Unknown'),
            _buildInfoRow('Target FPS', '${_dashboardData?.deviceCapabilities.targetFrameRate ?? 60}'),
            _buildInfoRow('GPU Acceleration', 
              _dashboardData?.deviceCapabilities.supportsGPUAcceleration == true ? 'Yes' : 'No'),
            _buildInfoRow('Background Processing', 
              _dashboardData?.deviceCapabilities.supportsBackgroundProcessing == true ? 'Yes' : 'No'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCollectionStats() {
    if (_collectionStats == null) return const SizedBox();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Collection Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Metrics Collected', _collectionStats!.totalMetricsCollected.toString()),
            _buildInfoRow('Metrics Dropped', _collectionStats!.metricsDropped.toString()),
            _buildInfoRow('Collection Efficiency', 
              '${(_collectionStats!.collectionEfficiency * 100).toStringAsFixed(1)}%'),
            _buildInfoRow('Collection Overhead', 
              '${_collectionStats!.collectionOverhead.toStringAsFixed(1)}μs'),
            _buildInfoRow('Collection Mode', _collectionStats!.activeMode.name),
            _buildInfoRow('High Priority', _collectionStats!.isHighPriority ? 'Yes' : 'No'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPerformanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildFrameRateChart(),
          const SizedBox(height: 16),
          _buildScreenPerformance(),
          const SizedBox(height: 16),
          _buildCachePerformance(),
        ],
      ),
    );
  }
  
  Widget _buildFrameRateChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Frame Rate',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _buildChart(_frameRateData, 'Frame Rate', Colors.orange),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildScreenPerformance() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Screen Performance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._dashboardData?.screenPerformance.entries.map((entry) {
              return _buildScreenTile(entry.key, entry.value);
            }) ?? [],
          ],
        ),
      ),
    );
  }
  
  Widget _buildScreenTile(String screenName, ScreenPerformanceData data) {
    return ListTile(
      title: Text(screenName),
      subtitle: Text(
        'Load: ${data.averageLoadTime.toInt()}ms, '
        'Transition: ${data.averageTransitionTime.toInt()}ms, '
        'FPS: ${data.averageFrameRate.toStringAsFixed(1)}',
      ),
      trailing: _buildPerformanceIndicator(data.averageLoadTime, 500),
    );
  }
  
  Widget _buildCachePerformance() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cache Performance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Overall Hit Rate', 
              '${((_dashboardData?.cacheIntegration.overallHitRate ?? 0) * 100).toStringAsFixed(1)}%'),
            ..._dashboardData?.cacheIntegration.cacheTypes.entries.map((entry) {
              return _buildInfoRow(entry.key, 
                '${(entry.value.hitRate * 100).toStringAsFixed(1)}% (${entry.value.hits}/${entry.value.hits + entry.value.misses})');
            }) ?? [],
          ],
        ),
      ),
    );
  }
  
  Widget _buildAdvancedTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildAdvancedMetrics(),
          const SizedBox(height: 16),
          _buildRecommendations(),
        ],
      ),
    );
  }
  
  Widget _buildAdvancedMetrics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Advanced Metrics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Memory Pressure', 
              _dashboardData?.memoryPressure.pressure ?? 'Unknown'),
            _buildInfoRow('Network Operations', 
              _dashboardData?.networkPerformance.totalOperations.toString() ?? '0'),
            _buildInfoRow('Network Success Rate', 
              '${((_dashboardData?.networkPerformance.successRate ?? 0) * 100).toStringAsFixed(1)}%'),
            _buildInfoRow('Slow Interactions', 
              _dashboardData?.userExperience.slowInteractionCount.toString() ?? '0'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRecommendations() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Optimization Recommendations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._dashboardData?.optimizationRecommendations.map((rec) {
              return _buildRecommendationTile(rec);
            }) ?? [const Text('No recommendations available')],
          ],
        ),
      ),
    );
  }
  
  Widget _buildRecommendationTile(OptimizationRecommendation recommendation) {
    return ListTile(
      leading: Icon(
        _getRecommendationIcon(recommendation.priority),
        color: _getRecommendationColor(recommendation.priority),
      ),
      title: Text(recommendation.title),
      subtitle: Text(recommendation.description),
      trailing: Text('${recommendation.estimatedImprovement.toStringAsFixed(1)}%'),
    );
  }
  
  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
  
  Widget _buildChart(List<ChartDataPoint> data, String title, Color color) {
    if (data.isEmpty) {
      return const Center(child: Text('No data available'));
    }
    
    return CustomPaint(
      painter: LineChartPainter(data: data, color: color),
      child: Container(),
    );
  }
  
  Widget _buildPerformanceIndicator(double value, double threshold) {
    final isGood = value < threshold;
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isGood ? Colors.green : Colors.red,
      ),
    );
  }
  
  // Helper methods
  
  IconData _getAlertIcon(EventSeverity severity) {
    switch (severity) {
      case EventSeverity.critical:
        return Icons.error;
      case EventSeverity.error:
        return Icons.warning;
      case EventSeverity.warning:
        return Icons.info;
      case EventSeverity.info:
        return Icons.info_outline;
    }
  }
  
  Color _getAlertColor(EventSeverity severity) {
    switch (severity) {
      case EventSeverity.critical:
        return Colors.red;
      case EventSeverity.error:
        return Colors.orange;
      case EventSeverity.warning:
        return Colors.yellow;
      case EventSeverity.info:
        return Colors.blue;
    }
  }
  
  IconData _getRecommendationIcon(RecommendationPriority priority) {
    switch (priority) {
      case RecommendationPriority.critical:
        return Icons.priority_high;
      case RecommendationPriority.high:
        return Icons.arrow_upward;
      case RecommendationPriority.medium:
        return Icons.remove;
      case RecommendationPriority.low:
        return Icons.arrow_downward;
    }
  }
  
  Color _getRecommendationColor(RecommendationPriority priority) {
    switch (priority) {
      case RecommendationPriority.critical:
        return Colors.red;
      case RecommendationPriority.high:
        return Colors.orange;
      case RecommendationPriority.medium:
        return Colors.yellow;
      case RecommendationPriority.low:
        return Colors.green;
    }
  }
  
  Color _getProgressColor(double percentage) {
    if (percentage < 0.5) return Colors.green;
    if (percentage < 0.8) return Colors.yellow;
    return Colors.red;
  }
}

/// Chart data point for visualizations
class ChartDataPoint {
  final DateTime time;
  final double value;
  
  ChartDataPoint({required this.time, required this.value});
}

/// Custom painter for line charts
class LineChartPainter extends CustomPainter {
  final List<ChartDataPoint> data;
  final Color color;
  
  LineChartPainter({required this.data, required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    
    // Find min and max values for scaling
    double minValue = data.map((d) => d.value).reduce(math.min);
    double maxValue = data.map((d) => d.value).reduce(math.max);
    
    // Add some padding
    final range = maxValue - minValue;
    minValue -= range * 0.1;
    maxValue += range * 0.1;
    
    if (minValue == maxValue) {
      minValue -= 1;
      maxValue += 1;
    }
    
    // Draw the line
    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i].value - minValue) / (maxValue - minValue)) * size.height;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paint);
    
    // Draw gradient fill
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.3),
          color.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();
    
    canvas.drawPath(fillPath, gradientPaint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}