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
import '../services/late_alarm_nudge_service.dart';
import '../services/system_settings_service.dart';

/// Periodically checks if native layer flagged repeated late alarms and shows a gentle prompt.
class BatteryOptimizationNudge extends StatefulWidget {
  final Widget child;
  const BatteryOptimizationNudge({super.key, required this.child});
  @override
  State<BatteryOptimizationNudge> createState() =>
      _BatteryOptimizationNudgeState();
}

class _BatteryOptimizationNudgeState extends State<BatteryOptimizationNudge> {
  @override
  void initState() {
    super.initState();
    // Delay to avoid showing over critical first-run flows.
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    final needed = await LateAlarmNudgeService.instance.consumePromptIfNeeded();
    if (!needed || !mounted) return;
    if (await SystemSettingsService.instance.isIgnoringBatteryOptimizations())
      return; // Already optimized
    if (!mounted) return;
    // Show lightweight SnackBar with action.
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: const Text(
          'Reminders seem delayed. Allow unrestricted background?',
        ),
        action: SnackBarAction(
          label: 'Allow',
          onPressed: () => SystemSettingsService.instance
              .requestIgnoreBatteryOptimizations(),
        ),
        duration: const Duration(milliseconds: 4000),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
