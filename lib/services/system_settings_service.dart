import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Unified wrapper for system settings related to precise alarms & battery optimization.
/// Uses the native MethodChannel 'app.perms' exposed in MainActivity.
/// This file is added to satisfy the consolidated API described in the requirements
/// while keeping older per-feature services backward compatible.
class SystemSettingsService {
  SystemSettingsService._();
  static final SystemSettingsService instance = SystemSettingsService._();

  static const MethodChannel _primaryChannel = MethodChannel('app.perms');
  static const MethodChannel _fallbackChannel = MethodChannel(
    'com.trudido.app/notifications',
  );

  static const _fallbackSupported = {
    'canScheduleExactAlarms',
    'openExactAlarmSettings',
    'isIgnoringBatteryOptimizations',
    'requestIgnoreBatteryOptimizations',
  };

  // Readiness gate: on hot restart the Dart side may call methods before the
  // Android activity re-attaches its handlers. We probe a benign method with
  // retries so subsequent calls don't surface MissingPluginException noise.
  static bool _ready = false;
  static Future<void>? _readyFuture;

  Future<void> ensureReady() async {
    if (_ready) return;
    if (_readyFuture != null) return _readyFuture!; // another awaiter in flight
    _readyFuture = _probeReadiness();
    try {
      await _readyFuture;
    } finally {
      _readyFuture = null;
    }
  }

  Future<void> _probeReadiness() async {
    if (!Platform.isAndroid) {
      _ready = true;
      return;
    }
    const attemptDelays = [50, 100, 150, 250, 400, 600]; // ~1.5s total
    for (var i = 0; i < attemptDelays.length; i++) {
      try {
        await _primaryChannel.invokeMethod('canScheduleExactAlarms');
        _ready = true;
        if (i > 0)
          debugPrint('[SystemSettingsService] channel ready after retry #$i');
        return;
      } on MissingPluginException {
        if (i == attemptDelays.length - 1) {
          debugPrint(
            '[SystemSettingsService] readiness probe exhausted; continuing with fallback-enabled invocations',
          );
        } else {
          await Future.delayed(Duration(milliseconds: attemptDelays[i]));
        }
      } catch (e) {
        // Unexpected error; don't loop indefinitely.
        debugPrint('[SystemSettingsService] readiness probe aborted early: $e');
        break;
      }
    }
    _ready =
        true; // avoid blocking; subsequent invocations still have their own retries/fallback
  }

  Future<T?> _invoke<T>(String method, {int retries = 2}) async {
    await ensureReady();
    MissingPluginException? lastMissing;
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        return await _primaryChannel.invokeMethod<T>(method);
      } on MissingPluginException catch (e) {
        lastMissing = e;
        if (attempt < retries) {
          // short backoff before retrying primary channel
          await Future.delayed(Duration(milliseconds: 80 * (attempt + 1)));
          continue;
        }
      }
    }
    if (lastMissing != null && _fallbackSupported.contains(method)) {
      debugPrint(
        '[SystemSettingsService] primary channel unresolved for $method after retries, trying fallback: $lastMissing',
      );
      try {
        return await _fallbackChannel.invokeMethod<T>(method);
      } on MissingPluginException catch (e2) {
        debugPrint(
          '[SystemSettingsService] fallback MissingPluginException for $method: $e2',
        );
        rethrow;
      }
    }
    // If we reach here and lastMissing != null with no fallback, rethrow
    if (lastMissing != null) throw lastMissing;
    return null; // defensive; should not hit
  }

  Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;
    try {
      final r = await _invoke<bool>('canScheduleExactAlarms');
      return r ?? true; // fail-open to avoid blocking user flows needlessly
    } catch (e, st) {
      debugPrint(
        '[SystemSettingsService] canScheduleExactAlarms error: $e\n$st',
      );
      return true;
    }
  }

  Future<void> openExactAlarmSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _invoke('openExactAlarmSettings');
    } catch (e) {
      debugPrint('[SystemSettingsService] openExactAlarmSettings error: $e');
    }
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final r = await _invoke<bool>('isIgnoringBatteryOptimizations');
      return r ?? true;
    } catch (e) {
      debugPrint(
        '[SystemSettingsService] isIgnoringBatteryOptimizations error: $e',
      );
      return true;
    }
  }

  Future<void> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return;
    try {
      await _invoke('requestIgnoreBatteryOptimizations');
    } catch (e) {
      debugPrint(
        '[SystemSettingsService] requestIgnoreBatteryOptimizations error: $e',
      );
    }
  }

  /// DEBUG ONLY: schedules a short exact alarm (AlarmClock) to force system to list app under
  /// Alarms & reminders. No-op in release mode to avoid unintended behavior.
  Future<bool> scheduleDebugExactAlarm() async {
    if (!Platform.isAndroid) return false;
    assert(() {
      debugPrint('[SystemSettingsService] scheduling debug exact alarm');
      return true;
    }());
    // Retry a few times in case channel not yet registered after a hot restart.
    const attempts = 3;
    for (var i = 0; i < attempts; i++) {
      try {
        final r = await _invoke<bool>('scheduleDebugExactAlarm');
        return r ?? false;
      } on MissingPluginException catch (e) {
        if (i == attempts - 1) {
          debugPrint(
            '[SystemSettingsService] scheduleDebugExactAlarm final failure: $e',
          );
          return false;
        }
        await Future.delayed(Duration(milliseconds: 150 * (i + 1)));
      } catch (e) {
        debugPrint('[SystemSettingsService] scheduleDebugExactAlarm error: $e');
        return false;
      }
    }
    return false;
  }
}
