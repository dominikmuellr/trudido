import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridges to native LateAlarmTracker to see if a battery optimization nudge should appear.
class LateAlarmNudgeService {
  LateAlarmNudgeService._();
  static final instance = LateAlarmNudgeService._();

  static const _channel = MethodChannel('app.perms');

  Future<bool> consumePromptIfNeeded() async {
    try {
      final r = await _channel.invokeMethod('consumeLateAlarmPrompt');
      return r == true;
    } catch (e, st) {
      debugPrint(
        '[LateAlarmNudgeService] consumePromptIfNeeded error: $e\n$st',
      );
      return false;
    }
  }
}
