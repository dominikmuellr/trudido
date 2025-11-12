import 'package:flutter/widgets.dart';
import '../services/system_settings_service.dart';

/// Observes app lifecycle; on resume re-checks system settings relevant to reminders.
/// Notify listeners when the state changes so UI (settings screen / indicators) can refresh.
class AlarmSettingsWatcher with WidgetsBindingObserver, ChangeNotifier {
  bool _canExact = false; // pessimistic until first refresh
  bool _ignoringBattery = false; // pessimistic until first refresh
  bool _loaded = false;
  bool get canExact => _canExact;
  bool get ignoringBattery => _ignoringBattery;
  bool get loaded => _loaded;

  final _svc = SystemSettingsService.instance;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    // Kick off after a microtask so channel registration on cold start finishes.
    Future.microtask(() async {
      try {
        await SystemSettingsService.instance.ensureReady();
      } catch (_) {}
      if (_started) refresh();
    });
  }

  void disposeWatcher() {
    if (!_started) return;
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refresh();
    }
  }

  Future<void> refresh() async {
    final can = await _svc.canScheduleExactAlarms();
    final batt = await _svc.isIgnoringBatteryOptimizations();
    final changed = can != _canExact || batt != _ignoringBattery || !_loaded;
    _canExact = can;
    _ignoringBattery = batt;
    _loaded = true;
    if (changed) notifyListeners();
  }
}
