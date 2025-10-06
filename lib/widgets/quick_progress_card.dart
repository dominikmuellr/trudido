import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/task_controller.dart';
import '../screens/home_screen.dart';
import '../services/theme_service.dart';

class QuickProgressCard extends ConsumerWidget {
  final TaskStatistics statistics;
  const QuickProgressCard({super.key, required this.statistics});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final appOpts =
        theme.extension<AppOptions>() ??
        const AppOptions(compact: false, highContrast: false);
    final completionRate = statistics.completionRate;
    final completedToday = statistics.completed;
    final totalToday = statistics.total;
    final hasCompletedTasksToday = completedToday > 0;
    final streakEmoji = hasCompletedTasksToday ? '🔥' : '📝';

    final pad = EdgeInsets.all(appOpts.compact ? 12 : 16);
    final boxSize = appOpts.compact ? 50.0 : 60.0;
    final gap = appOpts.compact ? 12.0 : 16.0;
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: appOpts.compact ? 13 : null,
    );
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontSize: appOpts.compact ? 12 : null,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => ref.read(currentTabProvider.notifier).setTab(2),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: pad,
          child: Row(
            children: [
              Container(
                height: boxSize,
                width: boxSize,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.3,
                  ),
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
                      fontSize: appOpts.compact ? 16 : null,
                    ),
                  ),
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Today's Progress", style: titleStyle),
                    SizedBox(height: appOpts.compact ? 2 : 4),
                    Text(
                      '$completedToday of $totalToday tasks completed',
                      style: bodyStyle,
                    ),
                    if (hasCompletedTasksToday) ...[
                      SizedBox(height: appOpts.compact ? 2 : 4),
                      Row(
                        children: [
                          Text(
                            streakEmoji,
                            style: TextStyle(
                              fontSize: appOpts.compact ? 14 : 16,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Great progress!',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w500,
                              fontSize: appOpts.compact ? 11 : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
                size: appOpts.compact ? 18 : 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
