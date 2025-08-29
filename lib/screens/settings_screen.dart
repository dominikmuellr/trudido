import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/theme_service.dart';
import '../services/todo_provider.dart';
import 'notification_settings_screen.dart';
import '../services/notification_service.dart';
import 'unified_settings_page.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDarkMode = ref.watch(themeNotifierProvider) == ThemeMode.dark;
    final statistics = ref.watch(statisticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft()),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        children: [
          // Appearance Section
          _buildSectionHeader(context, 'Appearance'),
          ListTile(
            leading: Icon(PhosphorIcons.palette()),
            title: const Text('Dark Mode'),
            subtitle: const Text('Toggle between light and dark theme'),
            trailing: Switch(
              value: isDarkMode,
              onChanged: (value) {
                ref.read(themeNotifierProvider.notifier).toggleTheme();
              },
            ),
          ),
          
          const Divider(),
          
          // Notifications Section
          _buildSectionHeader(context, 'Notifications'),
          ListTile(
            leading: Icon(PhosphorIcons.bell()),
            title: const Text('Notification Settings'),
            subtitle: const Text('Manage task reminders and alerts'),
            trailing: Icon(PhosphorIcons.caretRight()),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const NotificationSettingsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(PhosphorIcons.timer()),
            title: const Text('Reminder Reliability'),
            subtitle: const Text('Exact alarms & battery optimization'),
            trailing: Icon(PhosphorIcons.caretRight()),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const UnifiedSettingsPage(),
                ),
              );
            },
          ),
          
          const Divider(),
          
          // Statistics Section
          _buildSectionHeader(context, 'Statistics'),
          ListTile(
            leading: Icon(PhosphorIcons.chartBar()),
            title: const Text('Total Tasks'),
            trailing: Text(
              '${statistics.totalTasks}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: Icon(PhosphorIcons.checkCircle()),
            title: const Text('Completed Tasks'),
            trailing: Text(
              '${statistics.completedTasks}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          ListTile(
            leading: Icon(PhosphorIcons.clock()),
            title: const Text('Pending Tasks'),
            trailing: Text(
              '${statistics.pendingTasks}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: Icon(PhosphorIcons.percent()),
            title: const Text('Completion Rate'),
            trailing: Text(
              '${(statistics.completionRate * 100).toInt()}%',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: statistics.completionRate > 0.7 
                    ? theme.colorScheme.primary 
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
          
          const Divider(),
          
          // About Section
          _buildSectionHeader(context, 'About'),
          ListTile(
            leading: Icon(PhosphorIcons.info()),
            title: const Text('App Version'),
            trailing: const Text('1.0.0'),
          ),
          ListTile(
            leading: Icon(PhosphorIcons.code()),
            title: const Text('Built with Flutter'),
            subtitle: const Text('Cross-platform todo app'),
          ),
          
          const Divider(),
          
          // Debug Section (only in debug mode)
          if (const bool.fromEnvironment('dart.vm.product') == false) ...[
            _buildSectionHeader(context, 'Debug'),
            ListTile(
              leading: Icon(PhosphorIcons.bug()),
              title: const Text('Test Notification (10s)'),
              subtitle: const Text('Schedules a native notification in 10 seconds'),
              onTap: () async {
                final dt = DateTime.now().add(const Duration(seconds: 10));
                final ok = await NotificationBridge.instance.scheduleTaskNotification(
                  taskId: 'settings_test',
                  title: 'Settings Test',
                  body: 'This fired after a 10s delay',
                  scheduledTime: dt,
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Scheduled for 10s from now' : 'Failed to schedule'),
                    duration: const Duration(seconds: 4),
                  ),
                );
              },
            ),
          ],
          
          const Divider(),
          
          // Data Management Section
          _buildSectionHeader(context, 'Data Management'),
          ListTile(
            leading: Icon(PhosphorIcons.trash(), color: theme.colorScheme.error),
            title: Text(
              'Clear Completed Tasks',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            subtitle: Text('Remove all completed tasks (${statistics.completedTasks} tasks)'),
            onTap: () => _showClearCompletedDialog(context, ref),
          ),
          ListTile(
            leading: Icon(PhosphorIcons.warning(), color: theme.colorScheme.error),
            title: Text(
              'Clear All Data',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            subtitle: const Text('Delete all tasks and categories'),
            onTap: () => _showClearAllDataDialog(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showClearCompletedDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Completed Tasks'),
        content: const Text(
          'Are you sure you want to delete all completed tasks? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(todosProvider.notifier).deleteCompleted();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Completed tasks cleared'),
                ),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showClearAllDataDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'Are you sure you want to delete ALL tasks and categories? This will permanently remove all your data and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              ref.read(todosProvider.notifier).clearAllData();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All data cleared'),
                ),
              );
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
