import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/permissions_channel.dart';
import '../providers/alarm_settings_providers.dart';
import '../services/system_settings_service.dart';
import '../services/files_channel.dart';

import '../providers/app_providers.dart';

/// Single consolidated settings page using AlarmSettingsWatcher (Riverpod) and unified dialogs.
class UnifiedSettingsPage extends ConsumerStatefulWidget {
  const UnifiedSettingsPage({super.key});
  @override
  ConsumerState<UnifiedSettingsPage> createState() =>
      _UnifiedSettingsPageState();
}

class _UnifiedSettingsPageState extends ConsumerState<UnifiedSettingsPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Ensure native files channel is ready
    // ignore: discarded_futures
    FilesChannel.instance.ensureInitialized();

    // Set up import callbacks for refreshing UI
    FilesChannel.instance.setImportCallbacks(
      onComplete: (message) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.green,
              duration: const Duration(milliseconds: 2000),
            ),
          );
        }
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
              duration: const Duration(milliseconds: 2500),
            ),
          );
        }
      },
      onRefreshNeeded: () {
        if (mounted) {
          _refreshAllProviders();
        }
      },
    );
  }

  Future<void> _refreshAllProviders() async {
    try {
      // Refresh tasks
      final tasksNotifier = ref.read(tasksProvider.notifier);
      await tasksNotifier.refresh();

      // Refresh preferences state
      ref.invalidate(preferencesStateProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Data refreshed - your imported tasks should now be visible!',
            ),
            backgroundColor: Colors.blue,
            duration: Duration(milliseconds: 2000),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refresh failed: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(_notificationsStatusProvider);
      ref.read(alarmSettingsWatcherProvider).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final watcher = ref.watch(alarmSettingsWatcherProvider);
    final perms = PermissionsChannel.instance;
    final notifEnabledAsync = ref.watch(_notificationsStatusProvider);

    final loaded = watcher.loaded;
    return Scaffold(
      appBar: AppBar(title: const Text('Reminder Reliability')),
      body: RefreshIndicator(
        onRefresh: () async {
          // Trigger manual refresh
          await watcher.refresh();
          ref.invalidate(_notificationsStatusProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Control permissions & system settings that affect reminder timing.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            _StatusTile(
              title: 'Notifications',
              status: notifEnabledAsync.maybeWhen(
                orElse: () => true,
                data: (v) => v,
              ),
              description: 'Required to display reminder alerts and snoozes.',
              onTap: () async {
                // Always show explicit popup when not granted.
                final enabledNow = await perms.areNotificationsEnabled();
                if (enabledNow) return; // should be disabled tile already
                final localCtx = context;
                // ignore: use_build_context_synchronously (localCtx captured for immediate dialog display only)
                final proceed = await _showRationale(
                  localCtx,
                  title: 'Enable Notifications',
                  body:
                      'We use notifications to remind you of upcoming tasks and snoozed reminders.'
                      '\n\nOn Android 13+ you\'ll see a system permission prompt next.',
                  action: 'Request',
                );
                if (!proceed) return;
                await perms.requestPostNotifications();
                await Future.delayed(const Duration(milliseconds: 300));
                // Double-check and if still disabled offer to open settings
                var stillDisabled = !(await perms.areNotificationsEnabled());
                if (stillDisabled && context.mounted) {
                  final open = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Still Disabled'),
                      content: const Text(
                        'Permission not granted. Open system notification settings?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Open Settings'),
                        ),
                      ],
                    ),
                  );
                  if (open == true) {
                    await perms.openAppNotificationSettings();
                    await Future.delayed(const Duration(milliseconds: 350));
                  }
                }
                ref.invalidate(_notificationsStatusProvider);
              },
            ),
            _StatusTile(
              title: 'Exact alarms',
              status: watcher.canExact,
              description: loaded
                  ? 'Allow precise delivery even in Doze / idle.'
                  : 'Checking…',
              loading: !loaded,
              onTap: () async {
                if (!loaded) {
                  await watcher.refresh();
                  return;
                }
                if (!watcher.canExact) {
                  final localCtx = context;
                  // ignore: use_build_context_synchronously (localCtx captured for immediate dialog display only)
                  final proceed = await _showRationale(
                    localCtx,
                    title: 'Allow Exact Alarms',
                    body:
                        'Exact alarms let reminders fire exactly on time even in Doze or standby.'
                        '\n\nAndroid shows no popup. We\'ll open the system settings screen; toggle the permission then return.',
                    action: 'Open Settings',
                  );
                  if (proceed) {
                    // Directly open settings (single dialog UX)
                    await SystemSettingsService.instance
                        .openExactAlarmSettings();
                  }
                  await Future.delayed(const Duration(milliseconds: 250));
                  await watcher.refresh();
                  if (!watcher.canExact && context.mounted) {
                    final messenger = ScaffoldMessenger.maybeOf(context);
                    messenger?.showSnackBar(
                      const SnackBar(
                        content: Text('Exact alarms still disabled.'),
                      ),
                    );
                  }
                }
              },
            ),
            _StatusTile(
              title: 'Battery optimization',
              status: watcher.ignoringBattery,
              description: loaded
                  ? 'Disable optimization for reliable background scheduling.'
                  : 'Checking…',
              loading: !loaded,
              onTap: () async {
                if (!loaded) {
                  await watcher.refresh();
                  return;
                }
                if (!watcher.ignoringBattery) {
                  final localCtx = context;
                  // ignore: use_build_context_synchronously (localCtx captured for immediate dialog display only)
                  final proceed = await _showRationale(
                    localCtx,
                    title: 'Disable Battery Optimization',
                    body:
                        'Exclude the app from battery optimization so reminders aren\'t delayed or cancelled.'
                        '\n\nWe\'ll open the system screen; confirm the prompt or add the app to the allowlist.',
                    action: 'Open Settings',
                  );
                  if (proceed) {
                    await SystemSettingsService.instance
                        .requestIgnoreBatteryOptimizations();
                  }
                  await Future.delayed(const Duration(milliseconds: 250));
                  await watcher.refresh();
                  if (!watcher.ignoringBattery && context.mounted) {
                    final messenger = ScaffoldMessenger.maybeOf(context);
                    messenger?.showSnackBar(
                      const SnackBar(
                        content: Text('Battery optimization still enabled.'),
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 24),
            const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              '• Exact alarms show no popup: you must toggle in system settings.\n'
              '• Some OEMs add extra background limits; check auto-start / battery menus if delays persist.',
            ),
            if (const bool.fromEnvironment('dart.vm.product') == false) ...[
              const SizedBox(height: 32),
              const Text(
                'Debug',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () async {
                  final ok = await SystemSettingsService.instance
                      .scheduleDebugExactAlarm();
                  if (!context.mounted) return;
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  messenger?.showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'Debug exact alarm set for ~2 min'
                            : 'Failed to schedule debug alarm',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.alarm),
                label: const Text('Schedule Debug Exact Alarm (2 min)'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Use this once to force system to list the app under "Alarms & reminders".'
                ' Remove before release.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Future<bool> _showRationale(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return res == true;
  }
}

// Async notifications status provider (simple FutureProvider wrapper) so UI rebuilds after invalidation.
final _notificationsStatusProvider = FutureProvider<bool>((ref) async {
  if (!Platform.isAndroid) return true;
  return PermissionsChannel.instance.areNotificationsEnabled();
});

class _StatusTile extends StatelessWidget {
  final String title;
  final bool status;
  final String description;
  final VoidCallback onTap;
  final bool loading;
  const _StatusTile({
    required this.title,
    required this.status,
    required this.description,
    required this.onTap,
    this.loading = false,
  });
  @override
  Widget build(BuildContext context) {
    final color = loading
        ? Theme.of(context).colorScheme.outline
        : status
        ? Colors.green
        : Theme.of(context).colorScheme.error;
    final icon = loading
        ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(status ? Icons.check_circle : Icons.info_outline, color: color);
    return Card(
      child: ListTile(
        leading: icon,
        title: Text(title),
        subtitle: Text(
          '$description\nStatus: ${loading
              ? '…'
              : status
              ? 'Enabled'
              : 'Disabled'}',
        ),
        isThreeLine: true,
        trailing: (status || loading) ? null : const Icon(Icons.arrow_forward),
        onTap: (status || loading) ? null : onTap,
      ),
    );
  }
}
