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

import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing user default tab settings
///
/// This service handles persistence of the user's preferred starting tab
/// using SharedPreferences. It provides methods to get and set the default
/// tab with proper error handling and fallback behavior.
class DefaultTabService {
  static const String _defaultTabKey = 'user_default_starting_tab';
  static const String _defaultFallback = 'overview';
  static const String _hideNavKey = 'hide_bottom_navigation';

  /// Available tab options that match the app's navigation structure.
  /// Order: Overview, Todo, Events, Notes.
  static const Map<String, int> tabIndices = {
    'overview': 0,
    'todo': 1,
    'events': 2,
    'notes': 3,
  };

  /// Legacy tab IDs saved before the 4-tab split.
  /// Old 'tasks' maps to 'overview'; 'notes' stays as 'notes'.
  static const Map<String, String> _legacyMigration = {'tasks': 'overview'};

  // Simple in-memory cache to avoid first-frame flicker
  static String? _cachedTabId;
  static int? _cachedTabIndex;
  static bool? _cachedHideNav;

  /// Get the user's preferred default tab
  /// Returns the tab ID string (e.g., 'tasks', 'notes')
  static Future<String> getDefaultTab() async {
    if (_cachedTabId != null) return _cachedTabId!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTab = prefs.getString(_defaultTabKey);

      if (savedTab != null) {
        // Migrate legacy values transparently
        final migrated = _legacyMigration[savedTab] ?? savedTab;
        if (tabIndices.containsKey(migrated)) {
          // Persist the migrated value so we only migrate once
          if (migrated != savedTab) {
            await prefs.setString(_defaultTabKey, migrated);
          }
          _cachedTabId = migrated;
          _cachedTabIndex = tabIndices[migrated];
          return migrated;
        }
      }
    } catch (e) {
      // If reading fails, fall back to default
    }

    _cachedTabId = _defaultFallback;
    _cachedTabIndex = tabIndices[_defaultFallback];
    return _defaultFallback;
  }

  /// Get the default tab as an index for NavigationBar
  /// Returns the index (0-3) corresponding to the user's preference
  static Future<int> getDefaultTabIndex() async {
    if (_cachedTabIndex != null) return _cachedTabIndex!;
    final tabId = await getDefaultTab();
    _cachedTabIndex = tabIndices[tabId] ?? 0;
    return _cachedTabIndex!; // Fallback to index 0 (tasks)
  }

  /// Set the user's preferred default tab.
  /// tabId should be one of: 'overview', 'todo', 'events', 'notes'.
  static Future<bool> setDefaultTab(String tabId) async {
    if (!tabIndices.containsKey(tabId)) {
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_defaultTabKey, tabId);
      _cachedTabId = tabId;
      _cachedTabIndex = tabIndices[tabId];
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get display name for tab ID.
  static String getTabDisplayName(String tabId) {
    switch (tabId) {
      case 'overview':
        return 'Overview';
      case 'todo':
        return 'Todo';
      case 'events':
        return 'Events';
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
      _cachedTabId = _defaultFallback;
      _cachedTabIndex = tabIndices[_defaultFallback];
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get whether bottom navigation/rail should be hidden entirely
  static Future<bool> getHideNavigation() async {
    if (_cachedHideNav != null) return _cachedHideNav!;
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedHideNav = prefs.getBool(_hideNavKey) ?? false;
      return _cachedHideNav!;
    } catch (e) {
      return _cachedHideNav ?? false;
    }
  }

  /// Set whether navigation UI (bottom nav/rail) is hidden
  static Future<bool> setHideNavigation(bool hide) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hideNavKey, hide);
      _cachedHideNav = hide;
      return true;
    } catch (e) {
      return false;
    }
  }
}
