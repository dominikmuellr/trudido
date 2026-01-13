// Trudido - A privacy-focused todo and notes app
// Copyright (C) 2025 Dominik Müller
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/task_controller.dart';
import '../utils/responsive_size.dart';
import 'calendar_sync_settings_screen.dart';
import 'holiday_calendar_settings_screen.dart';
import 'backup_settings_page.dart';

class DataManagementScreen extends ConsumerWidget {
  const DataManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final taskStats = ref.watch(taskStatisticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Management'),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
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
            leading: ScaledIcon(Icons.event),
            title: const Text('Import Calendar'),
            subtitle: const Text('Import from .ics files'),
            trailing: ScaledIcon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const HolidayCalendarSettingsScreen(),
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
              color: colorScheme.error,
            ),
            title: Text(
              'Danger Zone',
              style: TextStyle(color: colorScheme.error),
            ),
            subtitle: const Text('Clear tasks and reset data'),
            trailing: ScaledIcon(Icons.arrow_forward_ios),
            onTap: () => _showDangerZoneSheet(context, ref, taskStats),
          ),
          const SizedBox(height: 16),
        ],
      ),
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
              Navigator.of(context).pop();
              _showClearCompletedDialog(context, ref);
            },
          ),
          ListTile(
            leading: ScaledIcon(Icons.warning_amber_outlined, color: cs.error),
            title: Text('Clear All Data', style: TextStyle(color: cs.error)),
            subtitle: const Text('Delete all tasks and categories'),
            onTap: () {
              Navigator.of(context).pop();
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
