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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/alarm_settings_watcher.dart';

class _AlarmSettingsWatcherNotifier extends Notifier<AlarmSettingsWatcher> {
  @override
  AlarmSettingsWatcher build() {
    final watcher = AlarmSettingsWatcher();
    watcher.start();
    ref.onDispose(() => watcher.disposeWatcher());
    return watcher;
  }
}

/// Provides a singleton AlarmSettingsWatcher that starts automatically.
final alarmSettingsWatcherProvider =
    NotifierProvider<_AlarmSettingsWatcherNotifier, AlarmSettingsWatcher>(
      _AlarmSettingsWatcherNotifier.new,
    );

/// Derived providers for convenience.
final canExactAlarmsProvider = Provider<bool>(
  (ref) => ref.watch(alarmSettingsWatcherProvider).canExact,
);
final ignoringBatteryOptimizationsProvider = Provider<bool>(
  (ref) => ref.watch(alarmSettingsWatcherProvider).ignoringBattery,
);
