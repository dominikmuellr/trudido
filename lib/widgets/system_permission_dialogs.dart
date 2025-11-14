import 'package:flutter/material.dart';
import '../services/system_settings_service.dart';
import '../services/navigation_service.dart';

Future<bool> showExactAlarmDialogIfNeeded(BuildContext context) async {
  final service = SystemSettingsService.instance;
  if (await service.canScheduleExactAlarms()) return true;
  final dialogContext = await _materialDialogContext(context);
  bool? proceed;
  if (dialogContext.mounted) {
    proceed = await showDialog<bool>(
      context: dialogContext,
      builder: (ctx) => AlertDialog(
        title: const Text('Enable Exact Alarms'),
        content: const Text(
          'Exact alarms keep reminders precise even when:\n'
          '- Device is idle / in Doze\n'
          '- After overnight charging\n'
          '- During short snoozes (5-15 min)\n\n'
          'Android requires a manual toggle. We\'ll open system settings; enable it then come back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
  if (proceed == true) {
    await service.openExactAlarmSettings();
    await Future.delayed(const Duration(milliseconds: 200));
  }
  return service.canScheduleExactAlarms();
}

Future<bool> showBatteryOptimizationDialogIfNeeded(BuildContext context) async {
  final service = SystemSettingsService.instance;
  if (await service.isIgnoringBatteryOptimizations()) return true;
  final dialogContext = await _materialDialogContext(context);
  bool? proceed;
  if (dialogContext.mounted) {
    proceed = await showDialog<bool>(
      context: dialogContext,
      builder: (ctx) => AlertDialog(
        title: const Text('Allow Unrestricted Background'),
        content: const Text(
          'To prevent the system from delaying or cancelling reminders, allow the app to bypass battery optimization. '
          'We will open the system screen; accept the prompt (or add to the allowlist), then return here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
  if (proceed == true) {
    await service.requestIgnoreBatteryOptimizations();
    await Future.delayed(const Duration(milliseconds: 200));
  }
  return service.isIgnoringBatteryOptimizations();
}

Future<BuildContext> _materialDialogContext(BuildContext fallback) async {
  for (var i = 0; i < 12; i++) {
    final ctx = NavigationService.context ?? fallback;
    final has =
        Localizations.of<MaterialLocalizations>(ctx, MaterialLocalizations) !=
        null;
    if (has) return ctx;
    await Future.delayed(Duration(milliseconds: 30 * (i + 1)));
  }
  return NavigationService.context ?? fallback;
}

Future<bool> showExactAlarmDialogIfNeededAuto() async {
  final ctx = NavigationService.navigatorKey.currentContext;
  if (ctx == null) return false;
  return showExactAlarmDialogIfNeeded(ctx);
}

Future<bool> showBatteryOptimizationDialogIfNeededAuto() async {
  final ctx = NavigationService.navigatorKey.currentContext;
  if (ctx == null) return false;
  return showBatteryOptimizationDialogIfNeeded(ctx);
}
