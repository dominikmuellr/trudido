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
import '../providers/holiday_providers.dart';

/// Screen for managing holiday calendar imports and settings
class HolidayCalendarSettingsScreen extends ConsumerWidget {
  const HolidayCalendarSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final holidays = ref.watch(holidaysProvider);
    final sources = ref.watch(holidaySourcesProvider);
    final countBySource = ref.watch(holidayCountBySourceProvider);
    final showHolidays = ref.watch(showHolidaysInCalendarProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Imported Calendars')),
      body: ListView(
        children: [
          // Show/Hide holidays toggle (only if holidays exist)
          if (holidays.isNotEmpty) ...[
            SwitchListTile(
              secondary: Icon(Icons.visibility, color: colorScheme.primary),
              title: const Text('Show Imported Calendars'),
              subtitle: Text('${holidays.length} events imported'),
              value: showHolidays,
              onChanged: (value) {
                ref.read(showHolidaysInCalendarProvider.notifier).state = value;
              },
            ),

            // List of imported calendars
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
              ...sources.map(
                (source) => ListTile(
                  leading: Icon(Icons.event_note, color: colorScheme.secondary),
                  title: Text(source),
                  subtitle: Text('${countBySource[source] ?? 0} events'),
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline, color: colorScheme.error),
                    tooltip: 'Remove calendar',
                    onPressed: () => _confirmDeleteSource(context, ref, source),
                  ),
                ),
              ),
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
              onPressed: () => _importHolidayCalendar(context, ref),
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

  Future<void> _importHolidayCalendar(
    BuildContext context,
    WidgetRef ref,
  ) async {
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
      final result = await ref.read(holidaysProvider.notifier).importFromFile();

      scaffoldMessenger.hideCurrentSnackBar();

      if (result.error != null) {
        if (result.error != 'No file selected') {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text(result.error!), backgroundColor: Colors.red),
          );
        }
        return;
      }

      if (result.success) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Imported ${result.holidays.length} events${result.calendarName != null ? ' from ${result.calendarName}' : ''}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
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

  Future<void> _confirmDeleteSource(
    BuildContext context,
    WidgetRef ref,
    String source,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Calendar'),
        content: Text('Remove all events from "$source"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
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
      final count = await ref
          .read(holidaysProvider.notifier)
          .deleteSource(source);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed $count events from $source'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
