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

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/holiday_providers.dart';
import '../providers/app_providers.dart';
import '../controllers/task_controller.dart';
import '../utils/ics_parser.dart';
import '../utils/imported_calendar_colors.dart';
import '../widgets/common/common.dart';

/// Screen for managing holiday calendar imports and settings
class HolidayCalendarSettingsScreen extends ConsumerStatefulWidget {
  const HolidayCalendarSettingsScreen({super.key});

  @override
  ConsumerState<HolidayCalendarSettingsScreen> createState() =>
      _HolidayCalendarSettingsScreenState();
}

class _HolidayCalendarSettingsScreenState
    extends ConsumerState<HolidayCalendarSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final importedTasks = ref.watch(importedTasksProvider);
    final sources = ref.watch(importedCalendarSourcesProvider);
    final countBySource = ref.watch(importedTaskCountBySourceProvider);
    final showImported = ref.watch(showImportedEventsInCalendarProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Imported Calendars')),
      body: ListView(
        children: [
          // Show/Hide toggle (only if imported events exist)
          if (importedTasks.isNotEmpty) ...[
            SwitchListTile(
              secondary: Icon(Icons.visibility, color: colorScheme.primary),
              title: const Text('Show Imported Calendars'),
              subtitle: Text('${importedTasks.length} events imported'),
              value: showImported,
              onChanged: (value) {
                ref.read(showImportedEventsInCalendarProvider.notifier).state =
                    value;
              },
            ),

            // List of imported calendars with color indicators
            if (sources.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Imported Calendars',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...sources.map((source) {
                final color = ImportedCalendarColors.getColorForCalendarName(
                  source,
                );
                return ListTile(
                  leading: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Color(color),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  title: Text(source),
                  subtitle: Text('${countBySource[source] ?? 0} events'),
                  trailing: ExpressiveIconButton(
                    icon: Icon(Icons.delete_outline, color: colorScheme.error),
                    tooltip: 'Remove calendar',
                    onPressed: () => _confirmDeleteSource(context, source),
                  ),
                );
              }),
            ],
          ] else ...[
            // Empty state
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(
                    Icons.event_busy,
                    size: 64,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Calendars Imported',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Import an .ics file to see events in your calendar',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.8,
                      ),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],

          // Import button at bottom
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FilledButton.icon(
              onPressed: () => _importCalendar(context),
              icon: const Icon(Icons.add),
              label: const Text('Import Calendar'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _importCalendar(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Show loading indicator
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Text('Importing calendar...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      // Pick .ics file
      final fileResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ics'],
      );

      if (fileResult == null || fileResult.files.isEmpty) {
        scaffoldMessenger.hideCurrentSnackBar();
        return;
      }

      final file = fileResult.files.first;
      String content;

      if (file.bytes != null) {
        content = String.fromCharCodes(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Could not read file'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Use filename (without extension) as source calendar name
      final sourceName = file.name.replaceAll('.ics', '').replaceAll('_', ' ');

      // Parse ICS content as todos
      final parseResult = IcsParser.parseTodos(
        content,
        sourceCalendarName: sourceName,
      );

      if (parseResult.error != null) {
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(parseResult.error!),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (parseResult.success) {
        // Save all parsed todos using task controller
        final taskController = ref.read(taskControllerProvider.notifier);
        for (final todo in parseResult.todos) {
          await taskController.add(todo);
        }

        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Imported ${parseResult.todos.length} events${parseResult.calendarName != null ? ' from ${parseResult.calendarName}' : ''}',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Check for past imported tasks and offer to mark them complete
        if (mounted) {
          await _checkAndOfferMarkPastComplete(context);
        }
      } else {
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('No valid events found in the file'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _checkAndOfferMarkPastComplete(BuildContext context) async {
    // Wait a moment for providers to refresh
    await Future.delayed(const Duration(milliseconds: 300));

    final pastTasks = ref.read(pastImportedUncompletedTasksProvider);
    if (pastTasks.isEmpty) return;

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Past Tasks Complete?'),
        content: Text(
          'You imported ${pastTasks.length} task${pastTasks.length == 1 ? '' : 's'} '
          'with due dates in the past.\n\n'
          'Would you like to mark them as complete?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Mark Complete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final taskController = ref.read(taskControllerProvider.notifier);
      final ids = pastTasks.map((t) => t.id);
      await taskController.bulkComplete(ids);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Marked ${pastTasks.length} past task${pastTasks.length == 1 ? '' : 's'} as complete',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteSource(BuildContext context, String source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Calendar'),
        content: Text('Remove all events from "$source"?'),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ExpressiveTextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Remove',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Get all imported tasks from this source and delete them
        final allTasks = ref.read(tasksProvider);
        final toDelete = allTasks
            .where(
              (t) =>
                  t.sourceCalendarName == source &&
                  t.sourceCalendarColor != null,
            )
            .toList();

        final taskController = ref.read(taskControllerProvider.notifier);
        int deletedCount = 0;
        for (final task in toDelete) {
          await taskController.delete(task.id);
          deletedCount++;
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed $deletedCount events from $source'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove events: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
