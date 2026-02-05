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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/default_tab_service.dart';
import '../utils/state_notifiers.dart';

/// Manages the set of selected todo IDs for bulk operations (multi-select mode).
class SelectedTodoIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  /// Toggle the selection state of a todo ID.
  void toggle(String id) {
    if (state.contains(id)) {
      state = {...state}..remove(id);
    } else {
      state = {...state, id};
    }
  }

  /// Clear all selected todo IDs.
  void clear() => state = <String>{};
}

/// Notifier for managing current tab state with default tab support.
class CurrentTabNotifier extends Notifier<int> {
  @override
  int build() {
    _initializeDefaultTab();
    return 0;
  }

  /// Initialize with user's preferred default tab.
  Future<void> _initializeDefaultTab() async {
    try {
      final defaultIndex = await DefaultTabService.getDefaultTabIndex();
      state = defaultIndex;
    } catch (e) {
      // Silently fall back to tasks tab (index 0) if loading fails
      state = 0;
    }
  }

  /// Update current tab.
  void setTab(int index) {
    state = index;
  }

  /// Reset to default tab.
  Future<void> resetToDefault() async {
    final defaultIndex = await DefaultTabService.getDefaultTabIndex();
    state = defaultIndex;
  }
}

// Multi-select providers
final multiSelectModeProvider = stateProvider<bool>(false);

final selectedTodoIdsProvider =
    NotifierProvider<SelectedTodoIdsNotifier, Set<String>>(
      SelectedTodoIdsNotifier.new,
    );

// Provider for tracking search mode state
final searchModeProvider = stateProvider<bool>(false);

// Provider for current tab index with default tab initialization
final currentTabProvider = NotifierProvider<CurrentTabNotifier, int>(
  CurrentTabNotifier.new,
);
