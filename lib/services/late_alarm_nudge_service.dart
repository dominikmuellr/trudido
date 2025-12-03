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
