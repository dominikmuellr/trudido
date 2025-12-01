import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/calendar_sync_service.dart';
import '../providers/app_providers.dart';
import '../controllers/task_controller.dart';
import '../utils/responsive_size.dart';

/// Provider for calendar sync service
final calendarSyncServiceProvider = Provider<CalendarSyncService>((ref) {
  return CalendarSyncService();
});

/// Provider for calendar sync status
final calendarSyncStatusProvider = FutureProvider<CalendarSyncStatus>((
  ref,
) async {
  final service = ref.watch(calendarSyncServiceProvider);
  await service.ensureInitialized();
  return service.getSyncStatus();
});

/// Settings screen for calendar sync configuration
class CalendarSyncSettingsScreen extends ConsumerStatefulWidget {
  const CalendarSyncSettingsScreen({super.key});

  @override
  ConsumerState<CalendarSyncSettingsScreen> createState() =>
      _CalendarSyncSettingsScreenState();
}

class _CalendarSyncSettingsScreenState
    extends ConsumerState<CalendarSyncSettingsScreen> {
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(calendarSyncStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar Sync')),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildErrorState(context, error.toString()),
        data: (status) => _buildContent(context, status),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaledIcon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading calendar settings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => ref.invalidate(calendarSyncStatusProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, CalendarSyncStatus status) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final service = ref.read(calendarSyncServiceProvider);

    return ListView(
      children: [
        // Info card about DAVx5
        _buildInfoCard(context),

        // Enable/Disable sync
        SwitchListTile(
          secondary: ScaledIcon(Icons.sync, color: cs.primary),
          title: const Text('Enable Calendar Sync'),
          subtitle: const Text('Sync tasks with device calendar'),
          value: status.isEnabled,
          onChanged: _isLoading
              ? null
              : (value) async {
                  setState(() => _isLoading = true);
                  if (value && !status.hasPermissions) {
                    final granted = await service.requestPermissions();
                    if (!granted) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Calendar permission required'),
                          ),
                        );
                      }
                      setState(() => _isLoading = false);
                      return;
                    }
                  }
                  await service.setEnabled(value);
                  ref.invalidate(calendarSyncStatusProvider);
                  setState(() => _isLoading = false);
                },
        ),

        if (status.isEnabled) ...[
          const Divider(),

          // Permission status
          if (!status.hasPermissions)
            ListTile(
              leading: ScaledIcon(Icons.warning_amber, color: cs.error),
              title: const Text('Calendar Permission Required'),
              subtitle: const Text('Tap to grant permission'),
              trailing: FilledButton(
                onPressed: () async {
                  final granted = await service.requestPermissions();
                  ref.invalidate(calendarSyncStatusProvider);
                  if (!granted && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please enable calendar permission in settings',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Grant'),
              ),
            ),

          // Calendar selection
          if (status.hasPermissions) ...[
            _buildSectionHeader(context, 'Calendars'),
            ListTile(
              leading: ScaledIcon(Icons.add_circle_outline, color: cs.primary),
              title: const Text('Add Calendar'),
              subtitle: Text(
                status.selectedCalendars.isEmpty
                    ? 'No calendars selected'
                    : '${status.selectedCalendars.length} calendar(s) configured',
              ),
              trailing: const ScaledIcon(Icons.arrow_forward_ios),
              onTap: () => _showAddCalendarPicker(context, status),
            ),

            // List of selected calendars
            if (status.selectedCalendars.isNotEmpty) ...[
              ...status.selectedCalendars.map(
                (cal) => _buildSelectedCalendarTile(
                  context,
                  cal,
                  status.primaryExportCalendarId == cal.id,
                ),
              ),
            ],

            if (status.availableCalendars.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  color: cs.tertiaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        ScaledIcon(
                          Icons.info_outline,
                          color: cs.onTertiaryContainer,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'No writable calendars found. If using DAVx5, make sure to sync your calendars first.',
                            style: TextStyle(color: cs.onTertiaryContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Sync options
            _buildSectionHeader(context, 'Sync Options'),
            SwitchListTile(
              secondary: ScaledIcon(Icons.play_circle_outline),
              title: const Text('Auto-Sync on Startup'),
              subtitle: const Text('Sync calendars when app opens'),
              value: status.autoSyncOnStartup,
              onChanged: (value) async {
                await service.setAutoSyncOnStartup(value);
                ref.invalidate(calendarSyncStatusProvider);
              },
            ),
            SwitchListTile(
              secondary: ScaledIcon(Icons.check_circle_outline),
              title: const Text('Sync Completed Tasks'),
              subtitle: const Text('Include completed tasks in calendar'),
              value: status.syncCompletedTasks,
              onChanged: (value) async {
                await service.setSyncCompletedTasks(value);
                ref.invalidate(calendarSyncStatusProvider);
              },
            ),
            SwitchListTile(
              secondary: ScaledIcon(Icons.swap_vert),
              title: const Text('Two-Way Sync'),
              subtitle: const Text('Import calendar events as tasks'),
              value: status.twoWaySyncEnabled,
              onChanged: (value) async {
                await service.setTwoWaySyncEnabled(value);
                ref.invalidate(calendarSyncStatusProvider);
              },
            ),

            // Manual sync button
            if (status.isConfigured) ...[
              _buildSectionHeader(context, 'Actions'),
              ListTile(
                leading: _isSyncing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : ScaledIcon(Icons.upload, color: cs.primary),
                title: const Text('Export Tasks to Calendar'),
                subtitle: const Text('Push all tasks to primary calendar'),
                enabled: !_isSyncing && !_isImporting,
                onTap: () => _syncAllTasks(context),
              ),
              ListTile(
                leading: _isImporting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : ScaledIcon(Icons.download, color: cs.primary),
                title: const Text('Import Events from Calendars'),
                subtitle: const Text('Pull events from all import calendars'),
                enabled: !_isSyncing && !_isImporting,
                onTap: () => _showImportDialog(context, status),
              ),
              if (status.twoWaySyncEnabled)
                ListTile(
                  leading: (_isSyncing || _isImporting)
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : ScaledIcon(Icons.sync, color: cs.tertiary),
                  title: const Text('Full Two-Way Sync'),
                  subtitle: const Text('Export tasks & import events'),
                  enabled: !_isSyncing && !_isImporting,
                  onTap: () => _performTwoWaySync(context),
                ),

              _buildSectionHeader(context, 'Maintenance'),
              ListTile(
                leading: ScaledIcon(
                  Icons.cleaning_services,
                  color: cs.secondary,
                ),
                title: const Text('Remove Duplicate Events'),
                subtitle: const Text('Clean up duplicate Trudido events'),
                enabled: !_isSyncing && !_isImporting,
                onTap: () => _showCleanupDuplicatesDialog(context, status),
              ),
              ListTile(
                leading: ScaledIcon(Icons.delete_forever, color: cs.error),
                title: Text(
                  'Delete All Trudido Events',
                  style: TextStyle(color: cs.error),
                ),
                subtitle: const Text(
                  'Remove all exported events from calendar',
                ),
                enabled: !_isSyncing && !_isImporting,
                onTap: () => _showDeleteAllEventsDialog(context, status),
              ),

              if (status.lastSyncTime != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    'Last sync: ${_formatDateTime(status.lastSyncTime!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              const Divider(),
              ListTile(
                leading: ScaledIcon(Icons.delete_sweep, color: cs.error),
                title: Text(
                  'Remove All Calendars',
                  style: TextStyle(color: cs.error),
                ),
                subtitle: const Text('Disconnect all calendars'),
                onTap: () => _showDisconnectAllDialog(context),
              ),
            ],
          ],
        ],

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        color: cs.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ScaledIcon(
                    Icons.calendar_today,
                    color: cs.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'DAVx5 Integration',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'For CalDAV sync (Nextcloud, etc.):\n'
                '1. Install DAVx5 from F-Droid or Play Store\n'
                '2. Add your CalDAV account in DAVx5\n'
                '3. Sync your calendars in DAVx5\n'
                '4. Select the synced calendar below\n\n'
                'Your tasks will sync to the Android calendar, and DAVx5 handles the CalDAV sync.',
                style: TextStyle(color: cs.onPrimaryContainer),
              ),
            ],
          ),
        ),
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

  Widget _buildSelectedCalendarTile(
    BuildContext context,
    SelectedCalendar cal,
    bool isPrimary,
  ) {
    final cs = Theme.of(context).colorScheme;
    final service = ref.read(calendarSyncServiceProvider);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Color(cal.color),
        radius: 16,
        child: const Icon(Icons.calendar_today, size: 16, color: Colors.white),
      ),
      title: Row(
        children: [
          Expanded(child: Text(cal.name)),
          if (isPrimary)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Primary',
                style: TextStyle(fontSize: 10, color: cs.onPrimaryContainer),
              ),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          if (cal.isForExport)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: const Text('Export'),
                labelStyle: const TextStyle(fontSize: 10),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (cal.isForImport)
            Chip(
              label: const Text('Import'),
              labelStyle: const TextStyle(fontSize: 10),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          switch (value) {
            case 'primary':
              await service.setPrimaryExportCalendar(cal.id);
              ref.invalidate(calendarSyncStatusProvider);
              break;
            case 'toggle_export':
              await service.updateSelectedCalendar(
                cal.copyWith(isForExport: !cal.isForExport),
              );
              ref.invalidate(calendarSyncStatusProvider);
              break;
            case 'toggle_import':
              await service.updateSelectedCalendar(
                cal.copyWith(isForImport: !cal.isForImport),
              );
              ref.invalidate(calendarSyncStatusProvider);
              break;
            case 'remove':
              await service.removeSelectedCalendar(cal.id);
              ref.invalidate(calendarSyncStatusProvider);
              break;
          }
        },
        itemBuilder: (context) => [
          if (!isPrimary && cal.isForExport)
            const PopupMenuItem(
              value: 'primary',
              child: ListTile(
                leading: Icon(Icons.star),
                title: Text('Set as Primary'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          PopupMenuItem(
            value: 'toggle_export',
            child: ListTile(
              leading: Icon(
                cal.isForExport ? Icons.cloud_off : Icons.cloud_upload,
              ),
              title: Text(cal.isForExport ? 'Disable Export' : 'Enable Export'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'toggle_import',
            child: ListTile(
              leading: Icon(
                cal.isForImport ? Icons.cloud_off : Icons.cloud_download,
              ),
              title: Text(cal.isForImport ? 'Disable Import' : 'Enable Import'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'remove',
            child: ListTile(
              leading: Icon(Icons.delete, color: cs.error),
              title: Text('Remove', style: TextStyle(color: cs.error)),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCalendarPicker(BuildContext context, CalendarSyncStatus status) {
    // Filter out already selected calendars
    final availableCalendars = status.availableCalendars
        .where((c) => !status.selectedCalendars.any((s) => s.id == c.id))
        .toList();

    if (availableCalendars.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status.availableCalendars.isEmpty
                ? 'No writable calendars available'
                : 'All available calendars are already added',
          ),
        ),
      );
      return;
    }

    final service = ref.read(calendarSyncServiceProvider);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  'Add Calendar',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Select calendars for syncing. You can add work, personal, shared calendars, etc.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: availableCalendars.length,
                  itemBuilder: (context, index) {
                    final calendar = availableCalendars[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Color(calendar.color ?? 0xFF2196F3),
                        radius: 16,
                        child: const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(calendar.name ?? 'Unknown'),
                      subtitle: Text(calendar.accountName ?? ''),
                      onTap: () async {
                        await service.addSelectedCalendar(
                          SelectedCalendar(
                            id: calendar.id!,
                            name: calendar.name ?? 'Calendar',
                            color: calendar.color ?? 0xFF2196F3,
                            isForExport: true,
                            isForImport: true,
                          ),
                        );
                        ref.invalidate(calendarSyncStatusProvider);
                        if (context.mounted) Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _syncAllTasks(BuildContext context) async {
    setState(() => _isSyncing = true);

    try {
      final service = ref.read(calendarSyncServiceProvider);
      final tasks = ref.read(tasksProvider);

      // Perform full two-way sync
      final now = DateTime.now();
      final result = await service.performTwoWaySync(
        existingTasks: tasks,
        syncStartDate: now.subtract(const Duration(days: 30)),
        syncEndDate: now.add(const Duration(days: 90)),
      );

      // Add imported tasks
      if (result.imported.isNotEmpty) {
        final taskController = ref.read(taskControllerProvider.notifier);
        for (final todo in result.imported) {
          await taskController.add(todo);
        }
      }

      ref.invalidate(calendarSyncStatusProvider);

      if (mounted) {
        String message = 'Synced ${result.exported} tasks to calendar';
        if (result.imported.isNotEmpty) {
          message += ', imported ${result.imported.length} events';
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  void _showDisconnectAllDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove All Calendars'),
        content: const Text(
          'This will stop syncing tasks with all calendars. '
          'Existing calendar events will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final service = ref.read(calendarSyncServiceProvider);
              await service.clearSelectedCalendars();
              await service.setEnabled(false);
              ref.invalidate(calendarSyncStatusProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Remove All'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else {
      return DateFormat('MMM d, yyyy HH:mm').format(dt);
    }
  }

  void _showImportDialog(BuildContext context, CalendarSyncStatus status) {
    bool importEverything = true;
    bool skipAlreadyImported = true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Import Calendar Events'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Import events from your selected calendars as tasks. '
                'Events exported by Trudido will be skipped.',
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Import all events'),
                subtitle: const Text('Past year and next 2 years'),
                value: importEverything,
                onChanged: (value) {
                  setDialogState(() => importEverything = value ?? true);
                },
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Skip previously imported'),
                subtitle: const Text('Uncheck to re-import all events'),
                value: skipAlreadyImported,
                onChanged: (value) {
                  setDialogState(() => skipAlreadyImported = value ?? true);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                final now = DateTime.now();
                final startDate = importEverything
                    ? now.subtract(const Duration(days: 365))
                    : now.subtract(const Duration(days: 30));
                final endDate = importEverything
                    ? now.add(const Duration(days: 730))
                    : now.add(const Duration(days: 90));
                _importEvents(startDate, endDate, skipAlreadyImported);
              },
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importEvents(
    DateTime startDate,
    DateTime endDate, [
    bool skipAlreadyImported = true,
  ]) async {
    setState(() => _isImporting = true);

    try {
      final service = ref.read(calendarSyncServiceProvider);
      final calendarsToImport = service.selectedCalendars
          .where((c) => c.isForImport)
          .toList();

      if (calendarsToImport.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No calendars selected for import')),
          );
        }
        return;
      }

      int totalAdded = 0;
      final taskController = ref.read(taskControllerProvider.notifier);

      for (final calendar in calendarsToImport) {
        final importedTodos = await service.importEventsFromCalendar(
          calendarId: calendar.id,
          startDate: startDate,
          endDate: endDate,
          skipAlreadyImported: skipAlreadyImported,
        );

        for (final todo in importedTodos) {
          await taskController.add(todo);
          totalAdded++;
        }
      }

      if (totalAdded == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No new events to import')),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported $totalAdded events as tasks')),
        );
      }

      ref.invalidate(calendarSyncStatusProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    } finally {
      setState(() => _isImporting = false);
    }
  }

  Future<void> _performTwoWaySync(BuildContext context) async {
    setState(() {
      _isSyncing = true;
      _isImporting = true;
    });

    try {
      final service = ref.read(calendarSyncServiceProvider);
      final tasks = ref.read(tasksProvider);
      final now = DateTime.now();

      final result = await service.performTwoWaySync(
        existingTasks: tasks,
        syncStartDate: now.subtract(const Duration(days: 30)),
        syncEndDate: now.add(const Duration(days: 90)),
      );

      // Add imported todos
      if (result.imported.isNotEmpty) {
        final taskController = ref.read(taskControllerProvider.notifier);
        for (final todo in result.imported) {
          await taskController.add(todo);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Exported ${result.exported} tasks, imported ${result.imported.length} events',
            ),
          ),
        );
      }

      ref.invalidate(calendarSyncStatusProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
      }
    } finally {
      setState(() {
        _isSyncing = false;
        _isImporting = false;
      });
    }
  }

  void _showCleanupDuplicatesDialog(
    BuildContext context,
    CalendarSyncStatus status,
  ) {
    final primaryCal = status.primaryExportCalendar;
    if (primaryCal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No primary export calendar set')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Duplicate Events'),
        content: Text(
          'This will search for duplicate events created by Trudido in "${primaryCal.name}" '
          'and remove them, keeping only one event per task.\n\n'
          'This is useful if you accidentally synced the same tasks multiple times.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _cleanupDuplicates(primaryCal.id);
            },
            child: const Text('Clean Up'),
          ),
        ],
      ),
    );
  }

  Future<void> _cleanupDuplicates(String calendarId) async {
    setState(() => _isSyncing = true);

    try {
      final service = ref.read(calendarSyncServiceProvider);
      final now = DateTime.now();

      final deleted = await service.deleteDuplicateTrudidoEvents(
        calendarId: calendarId,
        startDate: now.subtract(const Duration(days: 365)),
        endDate: now.add(const Duration(days: 730)),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              deleted > 0
                  ? 'Removed $deleted duplicate events'
                  : 'No duplicates found',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Cleanup failed: $e')));
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  void _showDeleteAllEventsDialog(
    BuildContext context,
    CalendarSyncStatus status,
  ) {
    final primaryCal = status.primaryExportCalendar;
    if (primaryCal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No primary export calendar set')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Trudido Events'),
        icon: Icon(Icons.warning, color: Theme.of(context).colorScheme.error),
        content: Text(
          'This will permanently delete ALL events created by Trudido from "${primaryCal.name}".\n\n'
          'This cannot be undone. Your tasks in Trudido will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAllTrudidoEvents(primaryCal.id);
            },
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAllTrudidoEvents(String calendarId) async {
    setState(() => _isSyncing = true);

    try {
      final service = ref.read(calendarSyncServiceProvider);
      final now = DateTime.now();

      final deleted = await service.deleteAllTrudidoEvents(
        calendarId: calendarId,
        startDate: now.subtract(const Duration(days: 365)),
        endDate: now.add(const Duration(days: 730)),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted $deleted events from calendar')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }
}
