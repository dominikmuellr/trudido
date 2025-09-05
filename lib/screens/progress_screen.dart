import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// TODO: integrate category/priority stats after migration
import '../controllers/task_controller.dart';
import '../services/theme_service.dart'; // AppOptions extension

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskStats = ref.watch(taskStatisticsProvider);
  final statistics = taskStats;
    final appOptions = Theme.of(context).extension<AppOptions>() ?? const AppOptions(compact: false, highContrast: false);
    final compact = appOptions.compact;

    // Tokens
    final outerPadding = EdgeInsets.all(compact ? 12 : 16);
    final cardPadding = EdgeInsets.all(compact ? 14 : 20);
    final gapSection = SizedBox(height: compact ? 16 : 20);
    final gapTitleToContent = SizedBox(height: compact ? 12 : 16);
    final gapSmall = SizedBox(height: compact ? 6 : 8);
    final statsIconSize = compact ? 26.0 : 32.0;
    final statGap = SizedBox(height: compact ? 6 : 8);
    final completionPad = EdgeInsets.all(compact ? 18 : 24);
    final completionRadius = BorderRadius.circular(compact ? 12 : 16);
    final completionGap = SizedBox(height: compact ? 2 : 4);
    final statLabelStyle = Theme.of(context).textTheme.bodySmall;

    return SingleChildScrollView(
      padding: outerPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall Progress Card
          Card(
            child: Padding(
              padding: cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overall Progress',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  gapTitleToContent,
                  // Completion Rate Display
                  Center(
                    child: Container(
                      padding: completionPad,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: completionRadius,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(statistics.completionRate * 100).toInt()}%',
                            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          completionGap,
                          Text(
                            'Complete',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  gapSection,
                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        context,
                        'Total',
                        statistics.total.toString(),
                        Icons.assignment,
                        Colors.blue,
                        statsIconSize: statsIconSize,
                        gap: statGap,
                        labelStyle: statLabelStyle,
                      ),
                      _buildStatItem(
                        context,
                        'Done',
                        statistics.completed.toString(),
                        Icons.check_circle,
                        Colors.green,
                        statsIconSize: statsIconSize,
                        gap: statGap,
                        labelStyle: statLabelStyle,
                      ),
                      _buildStatItem(
                        context,
                        'Pending',
                        statistics.pending.toString(),
                        Icons.pending,
                        Colors.orange,
                        statsIconSize: statsIconSize,
                        gap: statGap,
                        labelStyle: statLabelStyle,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          gapSection,
          // Priority Breakdown
          Card(
            child: Padding(
              padding: cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tasks by Priority',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  gapTitleToContent,
                  _buildPriorityBar(context, 'High', statistics.byPriority['high'] ?? 0, Colors.red, compact: compact),
                  gapSmall,
                  _buildPriorityBar(context, 'Medium', statistics.byPriority['medium'] ?? 0, Colors.orange, compact: compact),
                  gapSmall,
                  _buildPriorityBar(context, 'Low', statistics.byPriority['low'] ?? 0, Colors.green, compact: compact),
                ],
              ),
            ),
          ),
          gapSection,
          // Category Breakdown
          Card(
            child: Padding(
              padding: cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tasks by Category',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  gapTitleToContent,
                  ...statistics.byCategory.entries.map((entry) => Padding(
                    padding: EdgeInsets.only(bottom: compact ? 6 : 8),
                    child: _buildCategoryEntry(context, entry.key, entry.value, compact: compact),
                  )),
                ],
              ),
            ),
          ),
          gapSection,
          // Additional Stats
          Card(
            child: Padding(
              padding: cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Productivity Insights',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  gapTitleToContent,
                  _buildInsightRow(context, 'Overdue Tasks', statistics.overdue.toString(), Icons.warning, Colors.red, compact: compact),
                  _buildInsightRow(context, 'Due Today', statistics.dueToday.toString(), Icons.today, Colors.orange, compact: compact),
                  _buildInsightRow(context, 'Due Soon', statistics.dueSoon.toString(), Icons.schedule, Colors.blue, compact: compact),
                  _buildInsightRow(context, 'Streak Days', statistics.streakDays.toString(), Icons.local_fire_department, Colors.green, compact: compact),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, IconData icon, Color color, {double statsIconSize = 32, Widget? gap, TextStyle? labelStyle}) {
    gap ??= const SizedBox(height: 8);
    labelStyle ??= Theme.of(context).textTheme.bodySmall;
    return Column(
      children: [
        Icon(icon, color: color, size: statsIconSize),
        gap,
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: labelStyle,
        ),
      ],
    );
  }

  Widget _buildPriorityBar(BuildContext context, String priority, int count, Color color, {bool compact = false}) {
    final labelWidth = compact ? 72.0 : 80.0;
    final barHeight = compact ? 6.0 : 8.0;
    return Row(
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            priority,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: barHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(barHeight / 2),
              child: LinearProgressIndicator(
                value: count > 0 ? count / 10 : 0, // Normalize to max 10 for demo
                backgroundColor: color.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ),
        SizedBox(width: compact ? 6 : 8),
        Text(
          count.toString(),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildInsightRow(BuildContext context, String label, String value, IconData icon, Color color, {bool compact = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 6 : 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: compact ? 22 : 24),
          SizedBox(width: compact ? 10 : 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryEntry(BuildContext context, String category, int count, {bool compact = false}) {
    final colors = [Colors.blue, Colors.purple, Colors.teal, Colors.pink, Colors.indigo];
    final color = colors[category.hashCode % colors.length];
    return Row(
      children: [
        Expanded(
          child: Text(
            category,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
        Container(
          height: compact ? 6 : 8,
          width: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: color.withValues(alpha: 0.2),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: count == 0 ? 0 : 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: color,
              ),
            ),
          ),
        ),
        SizedBox(width: compact ? 6 : 8),
        Text(count.toString(), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

}
