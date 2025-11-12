import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/alarm_settings_watcher.dart';

/// Provides a singleton AlarmSettingsWatcher that starts automatically.
final alarmSettingsWatcherProvider =
    ChangeNotifierProvider<AlarmSettingsWatcher>((ref) {
      final watcher = AlarmSettingsWatcher();
      watcher.start();
      ref.onDispose(() => watcher.disposeWatcher());
      return watcher;
    });

/// Derived providers for convenience.
final canExactAlarmsProvider = Provider<bool>(
  (ref) => ref.watch(alarmSettingsWatcherProvider).canExact,
);
final ignoringBatteryOptimizationsProvider = Provider<bool>(
  (ref) => ref.watch(alarmSettingsWatcherProvider).ignoringBattery,
);
