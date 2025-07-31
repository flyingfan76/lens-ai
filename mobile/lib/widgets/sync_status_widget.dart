import 'package:flutter/material.dart';
import '../models/cloud_sync.dart';
import '../services/cloud_sync_service.dart';

class SyncStatusWidget extends StatefulWidget {
  final bool showDetails;
  final VoidCallback? onTap;

  const SyncStatusWidget({
    super.key,
    this.showDetails = false,
    this.onTap,
  });

  @override
  State<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget> {
  final CloudSyncService _syncService = CloudSyncService();
  CloudSyncStatus? _syncStatus;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSyncStatus();
  }

  @override
  void dispose() {
    _syncService.dispose();
    super.dispose();
  }

  Future<void> _loadSyncStatus() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final status = await _syncService.getSyncStatus();
      
      if (mounted) {
        setState(() {
          _syncStatus = status;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
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

    if (_syncStatus == null) {
      return _buildUnavailableWidget();
    }

    return widget.showDetails 
        ? _buildDetailedView() 
        : _buildCompactView();
  }

  Widget _buildLoadingWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Loading sync status...'),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off,
            color: Theme.of(context).colorScheme.error,
            size: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Sync unavailable',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          IconButton(
            onPressed: _loadSyncStatus,
            icon: const Icon(Icons.refresh, size: 16),
            tooltip: 'Retry',
          ),
        ],
      ),
    );
  }

  Widget _buildUnavailableWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Row(
        children: [
          const Icon(Icons.cloud_off, color: Colors.grey, size: 16),
          SizedBox(width: 12),
          Text('Sync not available', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildCompactView() {
    final theme = Theme.of(context);
    final status = _syncStatus!;

    return InkWell(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildStatusIcon(status),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getStatusText(status),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (status.isSyncing) ...[
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: status.syncProgress / 100,
                      backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ],
                  if (status.hasConflicts) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${status.conflicts.length} conflict${status.conflicts.length == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (status.lastSyncAt != null) ...[
              const SizedBox(width: 8),
              Text(
                _formatLastSync(status.lastSyncAt!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedView() {
    final theme = Theme.of(context);
    final status = _syncStatus!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                _buildStatusIcon(status),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cloud Sync',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _getStatusText(status),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _loadSyncStatus,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),

            if (status.isSyncing) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: status.syncProgress / 100,
                backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 8),
              Text(
                '${status.syncProgress.toStringAsFixed(1)}% complete',
                style: theme.textTheme.bodySmall,
              ),
            ],

            const SizedBox(height: 16),

            // Data sync status
            _buildDataSyncSection(status),

            const SizedBox(height: 16),

            // Storage usage
            _buildStorageSection(status),

            if (status.hasConflicts) ...[
              const SizedBox(height: 16),
              _buildConflictsSection(status),
            ],

            const SizedBox(height: 16),

            // Actions
            _buildActionsSection(status),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(CloudSyncStatus status) {
    final theme = Theme.of(context);
    
    if (status.isSyncing) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: theme.colorScheme.primary,
        ),
      );
    }

    if (status.hasErrors) {
      return Icon(
        Icons.error,
        color: theme.colorScheme.error,
        size: 20,
      );
    }

    if (status.hasConflicts) {
      return const Icon(
        Icons.warning,
        color: Colors.orange,
        size: 20,
      );
    }

    return const Icon(
      Icons.cloud_done,
      color: Colors.green,
      size: 20,
    );
  }

  String _getStatusText(CloudSyncStatus status) {
    if (status.isSyncing) {
      return 'Syncing...';
    }

    if (status.hasErrors) {
      return 'Sync error';
    }

    if (status.hasConflicts) {
      return 'Conflicts need resolution';
    }

    if (status.lastSyncAt == null) {
      return 'Not synced yet';
    }

    return 'Up to date';
  }

  Widget _buildDataSyncSection(CloudSyncStatus status) {
    final theme = Theme.of(context);
    final dataStatus = status.dataSyncStatus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Data Sync Status',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _buildDataSyncItem('Photos', dataStatus.photos),
        _buildDataSyncItem('Presets', dataStatus.presets),
        _buildDataSyncItem('Settings', dataStatus.settings),
      ],
    );
  }

  Widget _buildDataSyncItem(String label, SyncItemStatus itemStatus) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: itemStatus.progress,
                    backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${itemStatus.syncedItems}/${itemStatus.totalItems}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageSection(CloudSyncStatus status) {
    final theme = Theme.of(context);
    final storage = status.storageUsage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Storage Usage',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: storage.usagePercent,
                backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.2),
                color: storage.isNearQuota 
                    ? (storage.isOverQuota ? theme.colorScheme.error : Colors.orange)
                    : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${storage.formattedSize} / ${storage.quotaFormatted}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        if (storage.isNearQuota) ...[
          const SizedBox(height: 4),
          Text(
            storage.isOverQuota 
                ? 'Storage quota exceeded' 
                : 'Storage nearly full',
            style: theme.textTheme.bodySmall?.copyWith(
              color: storage.isOverQuota 
                  ? theme.colorScheme.error 
                  : Colors.orange,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConflictsSection(CloudSyncStatus status) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.warning,
              color: Colors.orange,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'Sync Conflicts (${status.conflicts.length})',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Some items have conflicting changes that need manual resolution.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildActionsSection(CloudSyncStatus status) {
    return Row(
      children: [
        if (!status.isSyncing) ...[
          ElevatedButton.icon(
            onPressed: _triggerManualSync,
            icon: const Icon(Icons.sync, size: 16),
            label: const Text('Sync Now'),
          ),
          const SizedBox(width: 8),
        ],
        
        if (status.hasConflicts) ...[
          ElevatedButton.icon(
            onPressed: _showConflictResolution,
            icon: const Icon(Icons.build, size: 16),
            label: const Text('Resolve'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ],
    );
  }

  String _formatLastSync(DateTime lastSync) {
    final now = DateTime.now();
    final difference = now.difference(lastSync);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Future<void> _triggerManualSync() async {
    try {
      await _syncService.triggerSync();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync started successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Refresh status after a short delay
      await Future.delayed(const Duration(seconds: 2));
      _loadSyncStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showConflictResolution() {
    // Implementation would show conflict resolution dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Conflicts'),
        content: const Text('Conflict resolution interface coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}