import 'package:flutter/material.dart';
import '../controllers/task_controller.dart';

class StatsCard extends StatelessWidget {
  final TaskStatistics statistics;

  const StatsCard({super.key, required this.statistics});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Progress',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: statistics.completionRate,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(statistics.completionRate * 100).toStringAsFixed(1)}% Complete',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        value: statistics.completionRate,
                        strokeWidth: 6,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    Text(
                      '${statistics.completed}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  context,
                  icon: Icons.checklist,
                  label: 'Total',
                  value: '${statistics.total}',
                ),
                _buildStatItem(
                  context,
                  icon: Icons.schedule,
                  label: 'Pending',
                  value: '${statistics.pending}',
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                if (statistics.overdue > 0)
                  _buildStatItem(
                    context,
                    icon: Icons.warning,
                    label: 'Overdue',
                    value: '${statistics.overdue}',
                    color: Theme.of(context).colorScheme.error,
                  ),
                if (statistics.dueToday > 0)
                  _buildStatItem(
                    context,
                    icon: Icons.event,
                    label: 'Due Today',
                    value: '${statistics.dueToday}',
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
              ],
            ),

            if (statistics.motivationalMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statistics.motivationalMessage,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final statColor = color ?? theme.colorScheme.outline;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: statColor, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: statColor,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}
