// Trudido - A privacy-focused todo and notes app
// Copyright (C) 2026 Dominik Müller
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

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kTextScaleKey = 'textScale';
const _kIgnoreSystemKey = 'ignoreSystemTextScale';
const MethodChannel _platform = MethodChannel('trudido/text_scale');

final ValueNotifier<double> textScaleNotifier = ValueNotifier<double>(1.0);
final ValueNotifier<bool> ignoreSystemNotifier = ValueNotifier<bool>(false);

Future<void> initTextScale() async {
  final prefs = await SharedPreferences.getInstance();
  textScaleNotifier.value = prefs.getDouble(_kTextScaleKey) ?? 1.0;
  ignoreSystemNotifier.value = prefs.getBool(_kIgnoreSystemKey) ?? false;
}

Future<void> setTextScale(double value) async {
  // Clamp to avoid floating-point precision issues (Android standard range)
  final clamped = value.clamp(0.9, 1.3);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble(_kTextScaleKey, clamped);
  textScaleNotifier.value = clamped;
  // Tell native to update widget display
  try {
    await _platform.invokeMethod('updateWidgetTextSize', {
      'scale': clamped,
      'ignoreSystem': ignoreSystemNotifier.value,
    });
  } catch (e) {
    debugPrint('Failed to update widget text size: $e');
  }
}

Future<void> setIgnoreSystem(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kIgnoreSystemKey, value);
  ignoreSystemNotifier.value = value;
  // Notify native widget
  try {
    await _platform.invokeMethod('updateWidgetTextSize', {
      'scale': textScaleNotifier.value,
      'ignoreSystem': value,
    });
  } catch (e) {
    debugPrint('Failed to update widget text size: $e');
  }
}
