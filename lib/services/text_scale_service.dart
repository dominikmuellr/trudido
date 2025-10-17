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
