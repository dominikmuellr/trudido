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
