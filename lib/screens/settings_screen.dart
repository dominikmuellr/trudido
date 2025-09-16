import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../providers/app_providers.dart';
import '../controllers/task_controller.dart';
import '../services/notification_service.dart';
import 'backup_settings_page.dart';
import 'display_theme_settings_page.dart';
import 'comprehensive_notification_settings.dart';
import 'template_management_screen.dart';
import 'default_tab_settings_screen.dart';
// removed unused imports (home_screen, greeting_header)

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Lazy ensure preferences initialized if user navigates directly before main init completes.
    final svc = ref.read(preferencesServiceProvider);
    if (!svc.isReady) {
      svc.ensureInitialized().then((_) {
        // Only update if still on settings screen.
        if (context.mounted) {
          ref.read(preferencesStateProvider.notifier).state = svc.snapshot;
        }
      });
    }
    final taskStats = ref.watch(taskStatisticsProvider);
    final statistics = taskStats; // adapt naming for existing UI
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Display & Theme Section
          _buildSectionHeader(context, 'Display & Theme'),
          ListTile(
            leading: Icon(PhosphorIcons.palette()),
            title: const Text('Display & Theme'),
            subtitle: const Text('Colors, layout, and visual preferences'),
            trailing: Icon(PhosphorIcons.caretRight()),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const DisplayThemeSettingsPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(PhosphorIcons.houseLine()),
            title: const Text('Default Starting Tab'),
            subtitle: const Text('Choose which tab opens when you start the app'),
            trailing: Icon(PhosphorIcons.caretRight()),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const DefaultTabSettingsScreen(),
                ),
              );
            },
          ),
          
          // Swipe Actions Section
          _buildSectionHeader(context, 'Note Actions'),
          _buildSwipeDirectionSetting(context, ref),
          
          const Divider(),
          
          // Templates & Workflows Section
          _buildSectionHeader(context, 'Templates & Workflows'),
          ListTile(
            leading: Icon(PhosphorIcons.squaresFour()),
            title: const Text('Folder Templates'),
            subtitle: const Text('Manage templates for smart folder creation'),
            trailing: Icon(PhosphorIcons.caretRight()),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const TemplateManagementScreen(),
                ),
              );
            },
          ),
          
          const Divider(),
          
          // Notifications Section
          _buildSectionHeader(context, 'Notifications'),
          ListTile(
            leading: Icon(PhosphorIcons.bell()),
            title: const Text('Notifications'),
            subtitle: const Text('Permissions, settings, and reliability'),
            trailing: Icon(PhosphorIcons.caretRight()),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ComprehensiveNotificationSettings(),
                ),
              );
            },
          ),
          
          const Divider(),
          
          // Data & Storage Section
          _buildSectionHeader(context, 'Data & Storage'),
          ListTile(
            leading: Icon(PhosphorIcons.downloadSimple()),
            title: const Text('Backup & Data'),
            subtitle: const Text('Export, import and automatic backups'),
            trailing: Icon(PhosphorIcons.caretRight()),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const BackupSettingsPage(),
                ),
              );
            },
          ),
          
          const Divider(),
          
          // About Section
          _buildSectionHeader(context, 'About'),
          ListTile(
            leading: Icon(PhosphorIcons.info()),
            title: const Text('App Version'),
            trailing: const Text('1.2.0'),
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
            subtitle: Text('Remove all completed tasks (${statistics.completed} tasks)'),
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

  Widget _buildSwipeDirectionSetting(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesStateProvider);
    final preferencesService = ref.read(preferencesServiceProvider);
    
    return ListTile(
      leading: const Icon(Icons.swipe),
      title: const Text('Swipe Actions'),
      subtitle: preferences.swipeLeftToDelete
          ? const Text('Left: Delete, Right: Pin')
          : const Text('Left: Pin, Right: Delete'),
      trailing: Switch(
        value: preferences.swipeLeftToDelete,
        onChanged: (value) async {
          final updatedPrefs = await preferencesService.update(
            swipeLeftToDelete: value,
          );
          ref.read(preferencesStateProvider.notifier).state = updatedPrefs;
        },
      ),
      onTap: () async {
        final updatedPrefs = await preferencesService.update(
          swipeLeftToDelete: !preferences.swipeLeftToDelete,
        );
        ref.read(preferencesStateProvider.notifier).state = updatedPrefs;
      },
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
              ref.read(taskControllerProvider.notifier).clearCompleted();
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
              // Bulk delete all tasks (categories handled later)
              ref.read(taskControllerProvider.notifier).clearAll();
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
