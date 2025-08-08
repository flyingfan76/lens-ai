import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../services/ai/ai_coordinator.dart';
import '../core/utils/disposal_mixin.dart';

/// Simplified AI Settings Screen that works with current architecture
class AISettingsScreen extends StatefulWidget {
  const AISettingsScreen({super.key});

  @override
  State<AISettingsScreen> createState() => _AISettingsScreenState();
}

class _AISettingsScreenState extends State<AISettingsScreen>
    with SingleTickerProviderStateMixin, DisposalMixin {
  late TabController _tabController;
  final AICoordinator _aiService = AICoordinator();
  
  bool _isInitialized = false;
  bool _isServiceAvailable = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Register for cleanup using the mixin
    addCleanupFunction(() => _tabController.dispose());
    
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      await _aiService.initialize();
      setState(() {
        _isInitialized = true;
        _isServiceAvailable = _aiService.isServiceAvailable();
      });
    } catch (e) {
      setState(() {
        _isInitialized = true;
        _isServiceAvailable = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        title: const Text('AI Settings'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
          tabs: const [
            Tab(text: 'Service Status', icon: Icon(Icons.settings)),
            Tab(text: 'Preferences', icon: Icon(Icons.tune)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildServiceStatusTab(),
          _buildPreferencesTab(),
        ],
      ),
    );
  }

  Widget _buildServiceStatusTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusCard(),
          const SizedBox(height: 16),
          _buildCapabilitiesCard(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      color: AppColors.primaryLight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Service Status',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatusRow('Initialized', _isInitialized),
            _buildStatusRow('Service Available', _isServiceAvailable),
            if (_isServiceAvailable) ...[
              const SizedBox(height: 8),
              _buildInfoRow('Provider', _aiService.currentProvider),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: status ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            status ? 'Active' : 'Inactive',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCapabilitiesCard() {
    if (!_isServiceAvailable) {
      return Card(
        color: AppColors.primaryLight,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(
                Icons.warning_amber,
                color: Colors.orange,
                size: 48,
              ),
              const SizedBox(height: 8),
              Text(
                'AI Service Unavailable',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The AI service is currently not available. Please check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _aiService.getCapabilities(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            color: AppColors.primaryLight,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            ),
          );
        }

        final capabilities = snapshot.data ?? {};
        
        return Card(
          color: AppColors.primaryLight,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Capabilities',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...capabilities.entries.map((entry) => 
                  _buildCapabilityRow(entry.key, entry.value)
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCapabilityRow(String key, dynamic value) {
    String displayValue;
    if (value is bool) {
      displayValue = value ? 'Supported' : 'Not Supported';
    } else if (value is List) {
      displayValue = '${value.length} items';
    } else {
      displayValue = value.toString();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              key.replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}').trim(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            displayValue,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: AppColors.primaryLight,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Preferences',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Advanced AI settings will be available in a future update.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _testConnection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Test Connection'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testConnection() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Testing AI service connection...'),
        backgroundColor: AppColors.accent,
      ),
    );

    try {
      final result = await _aiService.testConnection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result 
              ? 'Connection test successful!' 
              : 'Connection test failed. Service may be offline.',
          ),
          backgroundColor: result ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection test error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    // The DisposalMixin will automatically handle cleanup functions
    super.dispose();
  }
}