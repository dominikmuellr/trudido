import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/permissions_channel.dart';
import '../providers/alarm_settings_providers.dart';

class ComprehensiveNotificationSettings extends ConsumerStatefulWidget {
  const ComprehensiveNotificationSettings({super.key});

  @override
  ConsumerState<ComprehensiveNotificationSettings> createState() =>
      _ComprehensiveNotificationSettingsState();
}

class _ComprehensiveNotificationSettingsState
    extends ConsumerState<ComprehensiveNotificationSettings>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(alarmSettingsWatcherProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canExactAlarms = ref.watch(canExactAlarmsProvider);
    final ignoringBattery = ref.watch(ignoringBatteryOptimizationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: theme.colorScheme.surfaceTint,
      ),
      body: ListView(
        children: [
          // Permissions Section
          _buildSectionHeader(context, 'Permissions'),

          FutureBuilder<bool>(
            future: PermissionsChannel.instance.areNotificationsEnabled(),
            builder: (context, snapshot) {
              final isGranted = snapshot.data ?? false;
              return _buildPermissionTile(
                context: context,
                icon: Icons.notifications,
                title: 'Notification Permission',
                subtitle: 'Allow app to show notifications',
                isGranted: isGranted,
                onTap: () =>
                    PermissionsChannel.instance.openAppNotificationSettings(),
              );
            },
          ),

          _buildPermissionTile(
            context: context,
            icon: Icons.alarm,
            title: 'Exact Alarms',
            subtitle: 'Precise timing for reminders',
            isGranted: canExactAlarms,
            onTap: () => PermissionsChannel.instance.openExactAlarmSettings(),
          ),

          _buildPermissionTile(
            context: context,
            icon: Icons.battery_full,
            title: 'Battery Optimization',
            subtitle: 'Disable to ensure notifications work',
            isGranted: ignoringBattery,
            onTap: () =>
                PermissionsChannel.instance.openBatteryOptimizationSettings(),
          ),

          // System Settings Section
          _buildSectionHeader(context, 'System Settings'),

          ListTile(
            leading: Icon(Icons.settings),
            title: const Text('App Notification Settings'),
            subtitle: const Text('Open system settings for this app'),
            trailing: Icon(Icons.open_in_new),
            onTap: () =>
                PermissionsChannel.instance.openAppNotificationSettings(),
          ),

          if (Platform.isAndroid) ...[
            ListTile(
              leading: Icon(Icons.battery_full),
              title: const Text('Battery Settings'),
              subtitle: const Text('Open battery optimization settings'),
              trailing: Icon(Icons.open_in_new),
              onTap: () =>
                  PermissionsChannel.instance.openBatteryOptimizationSettings(),
            ),
            ListTile(
              leading: Icon(Icons.alarm),
              title: const Text('Alarms & Reminders'),
              subtitle: const Text('Open system alarm settings'),
              trailing: Icon(Icons.open_in_new),
              onTap: () => PermissionsChannel.instance.openExactAlarmSettings(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final statusColor = isGranted ? Colors.green : Colors.orange;
    final statusText = isGranted ? 'Granted' : 'Required';

    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withAlpha(26),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withAlpha(77)),
        ),
        child: Text(
          statusText,
          style: theme.textTheme.labelSmall?.copyWith(
            color: statusColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      onTap: isGranted ? null : onTap,
    );
  }
}
