// Trudido - A privacy-focused todo and notes app
// Copyright (C) 2026 Dominik Müller
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
import '../services/system_settings_service.dart';
import '../services/navigation_service.dart';
import '../services/preferences_service.dart';
import '../widgets/common/common.dart';

Future<bool> showExactAlarmDialogIfNeeded(BuildContext context) async {
  final service = SystemSettingsService.instance;
  if (await service.canScheduleExactAlarms()) return true;
  if (!context.mounted) return false;
  final dialogContext = _bestDialogContext(context);
  if (!dialogContext.mounted) return false;
  final proceed = await showDialog<bool>(
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
        ExpressiveTextButton(
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
  if (proceed == true) {
    await service.openExactAlarmSettings();
    await Future.delayed(const Duration(milliseconds: 200));
  }
  return service.canScheduleExactAlarms();
}

Future<bool> showBatteryOptimizationDialogIfNeeded(BuildContext context) async {
  final service = SystemSettingsService.instance;
  if (await service.isIgnoringBatteryOptimizations()) return true;
  // User previously chose "Don't show again" — skip the prompt
  if (PreferencesService().snapshot.dismissedBatteryOptimizationReminder) {
    return true;
  }
  if (!context.mounted) return false;
  final dialogContext = _bestDialogContext(context);
  if (!dialogContext.mounted) return false;
  // 0 = 'Later', 1 = 'Open Settings', 2 = 'Don\'t show again'
  final result = await showDialog<int>(
    context: dialogContext,
    builder: (ctx) => AlertDialog(
      title: const Text('Allow Unrestricted Background'),
      content: const Text(
        'To prevent the system from delaying or cancelling reminders, allow the app to bypass battery optimization. '
        'We will open the system screen; accept the prompt (or add to the allowlist), then return here.',
      ),
      actions: [
        ExpressiveTextButton(
          onPressed: () => Navigator.of(ctx).pop(2),
          child: const Text("Don't show again"),
        ),
        ExpressiveTextButton(
          onPressed: () => Navigator.of(ctx).pop(0),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(1),
          child: const Text('Open Settings'),
        ),
      ],
    ),
  );
  if (result == 2) {
    // Persist the user's choice to suppress future prompts
    await PreferencesService().update(
      dismissedBatteryOptimizationReminder: true,
    );
    return true;
  }
  if (result == 1) {
    await service.requestIgnoreBatteryOptimizations();
    await Future.delayed(const Duration(milliseconds: 200));
  }
  return service.isIgnoringBatteryOptimizations();
}

/// Returns the best available BuildContext for showing a dialog.
/// Prefers NavigationService.context if it has MaterialLocalizations,
/// otherwise falls back to the provided context.
BuildContext _bestDialogContext(BuildContext fallback) {
  final ctx = NavigationService.context;
  if (ctx != null) {
    final has =
        Localizations.of<MaterialLocalizations>(ctx, MaterialLocalizations) !=
        null;
    if (has) return ctx;
  }
  return fallback;
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
