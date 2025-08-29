import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/statistics.dart';
import '../screens/home_screen.dart';

class QuickProgressCard extends ConsumerWidget {
  final TodoStatistics statistics;

  const QuickProgressCard({
    super.key,
    required this.statistics,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final completionRate = statistics.completionRate;
    final completedToday = statistics.completedTasks;
    final totalToday = statistics.totalTasks;
    
    // Calculate today's streak (simplified - you might want to implement proper streak logic)
    final hasCompletedTasksToday = completedToday > 0;
    final streakEmoji = hasCompletedTasksToday ? "🔥" : "📝";
    
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () {
          // Navigate to Progress tab
          ref.read(currentTabProvider.notifier).state = 2;
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Progress display (without circle)
              Container(
                height: 60,
                width: 60,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${(completionRate * 100).toInt()}%',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Progress details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Progress',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$completedToday of $totalToday tasks completed',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (hasCompletedTasksToday) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            streakEmoji,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Great progress!',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              // Navigate icon
              Icon(
                PhosphorIcons.caretRight(),
                color: theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
