import 'package:flutter/services.dart';

/// Haptic Feedback Service
/// Provides consistent haptic feedback throughout the app following Material Design guidelines
class HapticFeedbackService {
  /// Light impact feedback for subtle interactions
  /// Use for: chip selections, switch toggles, minor UI changes
  static Future<void> lightImpact() async {
    await HapticFeedback.lightImpact();
  }

  /// Medium impact feedback for standard interactions
  /// Use for: button presses, card taps, list item selections
  static Future<void> mediumImpact() async {
    await HapticFeedback.mediumImpact();
  }

  /// Heavy impact feedback for important interactions
  /// Use for: FAB presses, delete confirmations, major actions
  static Future<void> heavyImpact() async {
    await HapticFeedback.heavyImpact();
  }

  /// Selection feedback for picker-style interactions
  /// Use for: scrolling through options, date pickers, dropdowns
  static Future<void> selectionClick() async {
    await HapticFeedback.selectionClick();
  }

  /// Vibrate for success actions
  /// Use for: task completion, successful saves
  static Future<void> success() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
  }

  /// Vibrate for error actions
  /// Use for: failed operations, validation errors
  static Future<void> error() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticFeedback.mediumImpact();
  }

  /// Vibrate for warning actions
  /// Use for: important confirmations, destructive actions
  static Future<void> warning() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.mediumImpact();
  }
}
