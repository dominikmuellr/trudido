import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// New native notification bridge.
/// All scheduling and display logic lives in Android (Kotlin).
/// This Dart class only:
///  * Exposes a method channel API to request schedule/cancel
///  * Listens for background action callbacks (taskCompleted / taskSnoozed)
///  * Pulls any pending native updates persisted while Flutter was dead
///  * Forwards events to app-layer listeners so UI/state can update
class NotificationBridge {
  static const MethodChannel _channel = MethodChannel(
    'com.trudido.app/notifications',
  );

  static final NotificationBridge instance = NotificationBridge._();
  NotificationBridge._();

  final StreamController<NotificationAction> _actionController =
      StreamController.broadcast();
  Stream<NotificationAction> get actions => _actionController.stream;

  bool _initialized = false;
  bool _channelProven = false; // set true once a call succeeds
  int _probeAttempts = 0;
  bool _probeScheduled = false;

  Future<void> initialize({
    Future<void> Function()? syncPendingNativeUpdates,
  }) async {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'notificationAction':
          final data = Map<dynamic, dynamic>.from(call.arguments as Map);
          _handleIncomingAction(data);
          break;
        default:
          if (kDebugMode) {
            print(
              '[NotificationBridge] Unknown method from native: ${call.method}',
            );
          }
      }
    });

    // On startup, optionally sync any pending native updates
    if (syncPendingNativeUpdates != null) {
      await syncPendingNativeUpdates();
    } else {
      await _trySingleProbePull();
      _scheduleProbeRetry();
    }
  }

  /// Ask native side to schedule a notification.
  Future<bool> scheduleTaskNotification({
    required String taskId,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? uniqueKey,
  }) async {
    try {
      final result = await _channel.invokeMethod('scheduleNotification', {
        'taskId': taskId,
        'title': title,
        'body': body,
        'triggerTime': scheduledTime.millisecondsSinceEpoch,
        if (uniqueKey != null) 'uniqueKey': uniqueKey,
      });
      return result == true;
    } catch (e) {
      debugPrint('[NotificationBridge] schedule error: $e');
      return false;
    }
  }

  Future<bool> cancelTaskNotification(String taskId) async {
    try {
      final result = await _channel.invokeMethod(
        'cancelScheduledNotification',
        {'taskId': taskId},
      );
      return result == true;
    } catch (e) {
      debugPrint('[NotificationBridge] cancel error: $e');
      return false;
    }
  }

  /// Fetch any actions that occurred while Flutter was terminated.
  Future<void> pullPendingNativeActions() async {
    if (!_channelProven) {
      // If channel hasn't been proven yet, do a probe instead to avoid noisy exceptions.
      await _trySingleProbePull();
      return;
    }
    try {
      final list = await _channel.invokeMethod('getPendingActions');
      if (kDebugMode)
        print(
          '[NotificationBridge] pulled pending list=${list is List ? list.length : 'non-list'}',
        );
      if (list is List) {
        for (final raw in list) {
          if (raw is Map) {
            if (kDebugMode)
              print('[NotificationBridge] applying pending raw=$raw');
            _handleIncomingAction(Map<String, dynamic>.from(raw));
          }
        }
      }
      await _channel.invokeMethod('clearPendingActions');
    } catch (e) {
      debugPrint('[NotificationBridge] pull pending error: $e');
    }
  }

  Future<void> _trySingleProbePull() async {
    try {
      final list = await _channel.invokeMethod('getPendingActions');
      _channelProven = true;
      if (kDebugMode)
        print(
          '[NotificationBridge] probe success; list type=${list.runtimeType}',
        );
      if (list is List) {
        for (final raw in list) {
          if (raw is Map) _handleIncomingAction(Map<String, dynamic>.from(raw));
        }
      }
      await _channel.invokeMethod('clearPendingActions');
    } catch (e) {
      if (kDebugMode)
        print(
          '[NotificationBridge] probe failed (will retry later, suppressed): $e',
        );
    }
  }

  void _scheduleProbeRetry() {
    if (_channelProven) return;
    if (_probeScheduled) return;
    if (_probeAttempts >= 6)
      return; // stop after max attempts (~backoff total < ~5s)
    _probeScheduled = true;
    final attempt = ++_probeAttempts;
    // Exponential backoff: 100ms * 2^(attempt-1), capped at 1600ms
    final delayMs = (100 * (1 << (attempt - 1))).clamp(100, 1600);
    Future.delayed(Duration(milliseconds: delayMs), () async {
      _probeScheduled = false;
      if (_channelProven) return;
      await _trySingleProbePull();
      _scheduleProbeRetry();
    });
  }

  void _handleIncomingAction(Map data) {
    final type = data['type'] as String?;
    final taskId = data['taskId'] as String?;
    if (type == null || taskId == null) return;
    final action = NotificationAction(
      type: type,
      taskId: taskId,
      newScheduledTime: data['newTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['newTime'] as int)
          : null,
    );
    _actionController.add(action);
  }

  void dispose() {
    _actionController.close();
  }
}

class NotificationAction {
  final String type; // 'taskCompleted' | 'taskSnoozed'
  final String taskId;
  final DateTime? newScheduledTime; // only for snooze
  NotificationAction({
    required this.type,
    required this.taskId,
    this.newScheduledTime,
  });
  @override
  String toString() =>
      'NotificationAction(type=$type, taskId=$taskId, newScheduledTime=$newScheduledTime)';
}
