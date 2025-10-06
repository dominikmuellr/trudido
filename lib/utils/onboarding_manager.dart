import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Utility class for managing onboarding state
///
/// This class provides methods to check and reset the onboarding tooltip state
/// for development and testing purposes.
class OnboardingManager {
  static const String _tooltipSeenKey = 'notes_onboarding_tooltip_seen';

  /// Check if the user has seen the onboarding tooltip
  static Future<bool> hasSeenTooltip() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_tooltipSeenKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Mark the tooltip as seen (dismisses it permanently)
  static Future<void> markTooltipAsSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_tooltipSeenKey, true);
    } catch (e) {
      // Handle error silently
    }
  }

  /// Reset the tooltip state for testing/debugging
  ///
  /// Call this method to force the tooltip to show again.
  /// Useful during development to test the onboarding flow.
  static Future<void> resetTooltip() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tooltipSeenKey);
    } catch (e) {
      // Handle error silently
    }
  }

  /// Clear all onboarding data
  static Future<void> clearAllOnboardingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.contains('onboarding') || key.contains('tooltip')) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }
}

/// Debug widget for testing onboarding in development
///
/// Add this to your app during development to easily test the onboarding flow.
/// It provides buttons to reset and check the tooltip state.
///
/// Usage:
/// ```dart
/// if (kDebugMode) OnboardingDebugPanel(),
/// ```

class OnboardingDebugPanel extends StatefulWidget {
  const OnboardingDebugPanel({super.key});

  @override
  State<OnboardingDebugPanel> createState() => _OnboardingDebugPanelState();
}

class _OnboardingDebugPanelState extends State<OnboardingDebugPanel> {
  bool? _hasSeenTooltip;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final hasSeen = await OnboardingManager.hasSeenTooltip();
    setState(() {
      _hasSeenTooltip = hasSeen;
    });
  }

  Future<void> _resetTooltip() async {
    await OnboardingManager.resetTooltip();
    await _checkStatus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Onboarding tooltip reset! Restart app to see it again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha((255 * 0.1).round()),
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.build, size: 16, color: Colors.orange),
              const SizedBox(width: 8),
              const Text(
                'DEBUG: Onboarding Controls',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tooltip Status: ${_hasSeenTooltip == null
                ? 'Loading...'
                : _hasSeenTooltip!
                ? 'Seen'
                : 'Not seen'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _resetTooltip,
                icon: Icon(Icons.refresh, size: 16),
                label: const Text('Reset Tooltip'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _checkStatus,
                icon: Icon(Icons.hourglass_empty, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
