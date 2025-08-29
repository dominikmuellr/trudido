import 'package:flutter/material.dart';
import '../services/system_settings_service.dart';
import '../services/navigation_service.dart';

/// Shows rationale + navigates to exact alarm settings if user accepts.
/// Returns true if after the potential settings navigation we can schedule exact alarms.
Future<bool> showExactAlarmDialogIfNeeded(BuildContext context) async {
  final service = SystemSettingsService.instance;
  if (await service.canScheduleExactAlarms()) return true;

  final dialogContext = await _materialDialogContext(context);
  final proceed = await showDialog<bool>(
    context: dialogContext,
    builder: (ctx) => AlertDialog(
      title: const Text('Enable Exact Alarms'),
      content: const Text(
        'Exact alarms keep reminders precise even when:\n'
        '- Device is idle / in Doze\n'
        '- After overnight charging\n'
        '- During short snoozes (5-15 min)\n\n'
        'Android requires a manual toggle. We\'ll open system settings; enable it then come back.'
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Later')),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Open Settings')),
      ],
    ),
  );
  if (proceed == true) {
    await service.openExactAlarmSettings();
    // Give the system a moment; actual state re-check also occurs when app resumes.
    await Future.delayed(const Duration(milliseconds: 300));
  }
  return service.canScheduleExactAlarms();
}

/// Shows rationale for disabling battery optimization. Returns true if ignoring optimization afterwards.
Future<bool> showBatteryOptimizationDialogIfNeeded(BuildContext context) async {
  final service = SystemSettingsService.instance;
  if (await service.isIgnoringBatteryOptimizations()) return true;

  final dialogContext = await _materialDialogContext(context);
  final proceed = await showDialog<bool>(
    context: dialogContext,
    builder: (ctx) => AlertDialog(
      title: const Text('Allow Unrestricted Background'),
      content: const Text(
        'To prevent the system from delaying or cancelling reminders, allow the app to bypass battery optimization. '
        'We will open the system screen; accept the prompt (or add to the allowlist), then return here.'
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Later')),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Open Settings')),
      ],
    ),
  );
  if (proceed == true) {
    await service.requestIgnoreBatteryOptimizations();
    await Future.delayed(const Duration(milliseconds: 300));
  }
  return service.isIgnoringBatteryOptimizations();
}

/// Ensures we have a BuildContext with MaterialLocalizations.
Future<BuildContext> _materialDialogContext(BuildContext fallback) async {
  for (var i = 0; i < 12; i++) {
    final ctx = NavigationService.context ?? fallback;
    final has = Localizations.of<MaterialLocalizations>(ctx, MaterialLocalizations) != null;
    if (has) return ctx;
    await Future.delayed(Duration(milliseconds: 40 * (i + 1)));
  }
  return NavigationService.context ?? fallback; // last resort (may still assert if not ready)
}
