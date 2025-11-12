import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Thin wrapper around native MethodChannel 'app.perms'.
/// All calls are idempotent + API guarded on native side; here we add
/// Dart-level guards & error handling so UI code stays clean.
class PermissionsChannel {
  static const MethodChannel _channel = MethodChannel('app.perms');
  PermissionsChannel._();
  static final instance = PermissionsChannel._();

  Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;
    try {
      return (await _channel.invokeMethod('canScheduleExactAlarms')) == true;
    } catch (e) {
      _log('canScheduleExactAlarms', e);
      return true;
    }
  }

  Future<bool> openExactAlarmSettings() async {
    if (!Platform.isAndroid) return true;
    try {
      return (await _channel.invokeMethod('openExactAlarmSettings')) == true;
    } catch (e) {
      _log('openExactAlarmSettings', e);
      return false;
    }
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      return (await _channel.invokeMethod('isIgnoringBatteryOptimizations')) ==
          true;
    } catch (e) {
      _log('isIgnoringBatteryOptimizations', e);
      return true;
    }
  }

  Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      return (await _channel.invokeMethod(
            'requestIgnoreBatteryOptimizations',
          )) ==
          true;
    } catch (e) {
      _log('requestIgnoreBatteryOptimizations', e);
      return false;
    }
  }

  Future<bool> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return true;
    try {
      return (await _channel.invokeMethod('openBatteryOptimizationSettings')) ==
          true;
    } catch (e) {
      _log('openBatteryOptimizationSettings', e);
      return false;
    }
  }

  Future<bool> areNotificationsEnabled() async {
    if (!Platform.isAndroid) return true;
    try {
      return (await _channel.invokeMethod('areNotificationsEnabled')) == true;
    } catch (e) {
      _log('areNotificationsEnabled', e);
      return true;
    }
  }

  Future<bool> requestPostNotifications() async {
    if (!Platform.isAndroid) return true;
    try {
      return (await _channel.invokeMethod('requestPostNotifications')) == true;
    } catch (e) {
      _log('requestPostNotifications', e);
      return false;
    }
  }

  Future<bool> openAppNotificationSettings() async {
    if (!Platform.isAndroid) return true;
    try {
      return (await _channel.invokeMethod('openAppNotificationSettings')) ==
          true;
    } catch (e) {
      _log('openAppNotificationSettings', e);
      return false;
    }
  }

  Future<int> getSdkInt() async {
    if (!Platform.isAndroid) return 0;
    try {
      final v = await _channel.invokeMethod('getSdkInt');
      return (v is int) ? v : 0;
    } catch (e) {
      _log('getSdkInt', e);
      return 0;
    }
  }

  void _log(String m, Object e) {
    debugPrint('[PermissionsChannel] $m error: $e');
  }
}
