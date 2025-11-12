import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing user default tab settings
///
/// This service handles persistence of the user's preferred starting tab
/// using SharedPreferences. It provides methods to get and set the default
/// tab with proper error handling and fallback behavior.
class DefaultTabService {
  static const String _defaultTabKey = 'user_default_starting_tab';
  static const String _defaultFallback = 'tasks'; // Default to tasks tab

  /// Available tab options that match your app's navigation structure
  static const Map<String, int> tabIndices = {'tasks': 0, 'notes': 1};

  /// Get the user's preferred default tab
  /// Returns the tab ID string (e.g., 'tasks', 'notes')
  static Future<String> getDefaultTab() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTab = prefs.getString(_defaultTabKey);

      // Validate that the saved tab is still valid
      if (savedTab != null && tabIndices.containsKey(savedTab)) {
        return savedTab;
      }
    } catch (e) {
      // If reading fails, fall back to default
    }

    return _defaultFallback;
  }

  /// Get the default tab as an index for NavigationBar
  /// Returns the index (0-3) corresponding to the user's preference
  static Future<int> getDefaultTabIndex() async {
    final tabId = await getDefaultTab();
    return tabIndices[tabId] ?? 0; // Fallback to index 0 (tasks)
  }

  /// Set the user's preferred default tab
  /// tabId should be one of: 'tasks', 'notes'
  static Future<bool> setDefaultTab(String tabId) async {
    // Validate tab ID
    if (!tabIndices.containsKey(tabId)) {
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_defaultTabKey, tabId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get display name for tab ID
  static String getTabDisplayName(String tabId) {
    switch (tabId) {
      case 'tasks':
        return 'Tasks';
      case 'notes':
        return 'Notes';
      default:
        return 'Unknown';
    }
  }

  /// Get all available tab options with their display names
  static Map<String, String> getAllTabs() {
    return {
      for (final tabId in tabIndices.keys) tabId: getTabDisplayName(tabId),
    };
  }

  /// Reset default tab to the original fallback (tasks)
  static Future<bool> resetToDefault() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_defaultTabKey);
      return true;
    } catch (e) {
      return false;
    }
  }
}
