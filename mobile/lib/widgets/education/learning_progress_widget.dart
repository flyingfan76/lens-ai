import 'package:flutter/material.dart';
import '../../models/education.dart';

class LearningProgressWidget extends StatelessWidget {
  final UserProgress userProgress;

  const LearningProgressWidget({
    Key? key,
    required this.userProgress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getLevelColor(userProgress.learningPath.currentLevel),
                  child: Text(
                    _getLevelInitial(userProgress.learningPath.currentLevel),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back!',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${userProgress.learningPath.currentLevel.toUpperCase()} Level',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _getLevelColor(userProgress.learningPath.currentLevel),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (userProgress.statistics.consistencyStreak > 0)
                  _buildStreakIndicator(context),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${userProgress.learningPath.completionPercentage.toInt()}%',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _getLevelColor(userProgress.learningPath.currentLevel),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: userProgress.learningPath.completionPercentage / 100,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getLevelColor(userProgress.learningPath.currentLevel),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Statistics Row
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    Icons.school,
                    userProgress.statistics.tutorialsCompleted.toString(),
                    'Tutorials\nCompleted',
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    Icons.access_time,
                    '${(userProgress.statistics.totalLearningTime / 60).toInt()}h',
                    'Learning\nTime',
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    Icons.emoji_events,
                    userProgress.achievements.length.toString(),
                    'Achievements\nEarned',
                  ),
                ),
              ],
            ),
            
            // Recent Achievement
            if (userProgress.achievements.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: Colors.amber.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Latest Achievement',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.amber.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            userProgress.achievements.last.name,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.grey.shade600,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.caption?.copyWith(
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStreakIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department,
            size: 16,
            color: Colors.orange.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            '${userProgress.statistics.consistencyStreak}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'beginner':
        return Colors.green;
      case 'intermediate':
        return Colors.orange;
      case 'advanced':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getLevelInitial(String level) {
    switch (level.toLowerCase()) {
      case 'beginner':
        return 'B';
      case 'intermediate':
        return 'I';
      case 'advanced':
        return 'A';
      default:
        return '?';
    }
  }
}