import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../controllers/task_controller.dart';
import '../utils/responsive_size.dart';
import 'backup_settings_page.dart';
import 'about_screen.dart';
import 'display_theme_settings_page.dart';
import 'comprehensive_notification_settings.dart';
import 'template_management_screen.dart';
import 'font_size_settings_screen.dart';
import 'calendar_sync_settings_screen.dart';
import '../controllers/preferences_controller.dart';

// Moved _SwipeActionSheet and _getSwipeActionName outside the class
String _getSwipeActionName(String action) {
  switch (action) {
    case 'delete':
      return 'Delete';
    case 'pin':
      return 'Pin';
    case 'none':
      return 'None';
    default:
      return 'Unknown';
  }
}

class _SwipeActionSheet extends ConsumerWidget {
  const _SwipeActionSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesStateProvider);
    final controller = ref.read(preferencesControllerProvider);
    final cs = Theme.of(context).colorScheme;

    Widget buildActionOption(
      String action,
      String label,
      IconData icon,
      bool isSelected,
      VoidCallback onTap,
    ) {
      return ListTile(
        leading: ScaledIcon(
          icon,
          color: isSelected ? cs.primary : cs.onSurfaceVariant,
        ),
        title: Text(
          label,
          style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : null),
        ),
        trailing: isSelected
            ? ScaledIcon(Icons.check, color: cs.primary)
            : null,
        onTap: onTap,
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Configure Swipe Actions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          ListTile(
            title: const Text('Left Swipe Action'),
            subtitle: Text(_getSwipeActionName(preferences.swipeLeftAction)),
          ),
          buildActionOption(
            'delete',
            'Delete',
            Icons.delete_outline,
            preferences.swipeLeftAction == 'delete',
            () {
              controller.setSwipeLeftAction('delete');
            },
          ),
          buildActionOption(
            'pin',
            'Pin',
            Icons.push_pin_outlined,
            preferences.swipeLeftAction == 'pin',
            () {
              controller.setSwipeLeftAction('pin');
            },
          ),
          buildActionOption(
            'none',
            'None',
            Icons.do_not_disturb_alt_outlined,
            preferences.swipeLeftAction == 'none',
            () {
              controller.setSwipeLeftAction('none');
            },
          ),
          ListTile(
            title: const Text('Right Swipe Action'),
            subtitle: Text(_getSwipeActionName(preferences.swipeRightAction)),
          ),
          buildActionOption(
            'delete',
            'Delete',
            Icons.delete_outline,
            preferences.swipeRightAction == 'delete',
            () {
              controller.setSwipeRightAction('delete');
            },
          ),
          buildActionOption(
            'pin',
            'Pin',
            Icons.push_pin_outlined,
            preferences.swipeRightAction == 'pin',
            () {
              controller.setSwipeRightAction('pin');
            },
          ),
          buildActionOption(
            'none',
            'None',
            Icons.do_not_disturb_alt_outlined,
            preferences.swipeRightAction == 'none',
            () {
              controller.setSwipeRightAction('none');
            },
          ),
          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'Made with ❤️ in Europe',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DangerZoneSheet extends ConsumerWidget {
  final dynamic statistics;
  const _DangerZoneSheet({required this.statistics});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Danger Zone',
              style: theme.textTheme.titleLarge?.copyWith(
                color: cs.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'These actions cannot be undone. Please proceed with caution.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: ScaledIcon(Icons.delete_outline, color: cs.error),
            title: Text(
              'Clear Completed Tasks',
              style: TextStyle(color: cs.error),
            ),
            subtitle: Text(
              'Remove all completed tasks (${statistics.completed} tasks)',
            ),
            onTap: () {
              Navigator.of(context).pop(); // Close the sheet first
              _showClearCompletedDialog(context, ref);
            },
          ),
          ListTile(
            leading: ScaledIcon(Icons.warning_amber_outlined, color: cs.error),
            title: Text('Clear All Data', style: TextStyle(color: cs.error)),
            subtitle: const Text('Delete all tasks and categories'),
            onTap: () {
              Navigator.of(context).pop(); // Close the sheet first
              _showClearAllDataDialog(context, ref);
            },
          ),
          const SizedBox(height: 16),
        ],
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
              ref.read(taskControllerProvider.notifier).clearCompleted();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Completed tasks cleared')),
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
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('All data cleared')));
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

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
    final statistics = taskStats;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Display & Theme Section
          _buildSectionHeader(context, 'Display & Theme'),
          ListTile(
            leading: ScaledIcon(Icons.palette_outlined),
            title: const Text('Display & Theme'),
            subtitle: const Text('Colors, layout, and visual preferences'),
            trailing: ScaledIcon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const DisplayThemeSettingsPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: ScaledIcon(Icons.text_fields),
            title: const Text('Font Size'),
            subtitle: const Text('Adjust text size for the entire app'),
            trailing: ScaledIcon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const FontSizeSettingsScreen(),
                ),
              );
            },
          ),

          // Templates & Workflows Section
          _buildSectionHeader(context, 'Templates & Workflows'),
          ListTile(
            leading: ScaledIcon(Icons.widgets_outlined),
            title: const Text('Folder Templates'),
            subtitle: const Text('Manage templates for smart folder creation'),
            trailing: ScaledIcon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const TemplateManagementScreen(),
                ),
              );
            },
          ),

          _buildSwipeDirectionSetting(context, ref),

          // Notifications Section
          _buildSectionHeader(context, 'Notifications'),
          ListTile(
            leading: ScaledIcon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            subtitle: const Text('Permissions, settings, and reliability'),
            trailing: ScaledIcon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      const ComprehensiveNotificationSettings(),
                ),
              );
            },
          ),

          // Data & Storage Section
          _buildSectionHeader(context, 'Data & Storage'),
          ListTile(
            leading: ScaledIcon(Icons.calendar_month_outlined),
            title: const Text('Calendar Sync'),
            subtitle: const Text('Sync tasks with Android/DAVx5 calendar'),
            trailing: ScaledIcon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CalendarSyncSettingsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: ScaledIcon(Icons.save_alt),
            title: const Text('Backup & Data'),
            subtitle: const Text('Export, import and automatic backups'),
            trailing: ScaledIcon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const BackupSettingsPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: ScaledIcon(
              Icons.warning_amber_outlined,
              color: theme.colorScheme.error,
            ),
            title: Text(
              'Danger Zone',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            subtitle: const Text('Clear tasks and reset data'),
            trailing: ScaledIcon(Icons.arrow_forward_ios),
            onTap: () => _showDangerZoneSheet(context, ref, statistics),
          ),

          // About Section
          _buildSectionHeader(context, 'About'),
          ListTile(
            leading: ScaledIcon(Icons.info_outline),
            title: const Text('About & Licenses'),
            subtitle: const Text(
              'App license, package licenses and repository',
            ),
            trailing: ScaledIcon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AboutScreen()),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'Made with ❤️ in Europe',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSwipeDirectionSetting(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesStateProvider);

    return ListTile(
      leading: const ScaledIcon(Icons.swipe),
      title: const Text('Swipe Actions'),
      subtitle: Text(
        'Left: ${_getSwipeActionName(preferences.swipeLeftAction)}, Right: ${_getSwipeActionName(preferences.swipeRightAction)}',
      ),
      trailing: ScaledIcon(Icons.arrow_forward_ios),
      onTap: () async {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (ctx) => _SwipeActionSheet(),
        );
      },
    );
  }

  void _showDangerZoneSheet(BuildContext context, WidgetRef ref, statistics) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _DangerZoneSheet(statistics: statistics),
    );
  }
}
