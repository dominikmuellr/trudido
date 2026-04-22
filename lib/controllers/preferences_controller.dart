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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/preferences_state.dart';
import '../services/preferences_service.dart';
import '../services/theme_service.dart';
import '../providers/app_providers.dart';

/// Central controller exposing mutation helpers for user preferences.
final preferencesControllerProvider = Provider<PreferencesController>((ref) {
  final svc = ref.read(preferencesServiceProvider);
  return PreferencesController(ref, svc);
});

class PreferencesController {
  final Ref ref;
  final PreferencesService service;
  PreferencesController(this.ref, this.service);

  PreferencesState get state => ref.read(preferencesStateProvider);

  Future<void> setThemeMode(String mode) async {
    await _update(themeMode: mode);
  }

  Future<void> toggleDynamicColor() async {
    final newDynamicColorState = !state.useDynamicColor;

    // If turning off dynamic colors and hack theme or Dracula theme is selected,
    // automatically switch to dark mode if currently in light or auto mode
    if (!newDynamicColorState &&
        (state.accentColorSeed == 0xFF00FF00 ||
            state.accentColorSeed == 0xFFBD93F9)) {
      if (state.themeMode == 'light' || state.themeMode == 'system') {
        await _update(useDynamicColor: newDynamicColorState, themeMode: 'dark');
      } else {
        await _update(useDynamicColor: newDynamicColorState);
      }
    } else {
      await _update(useDynamicColor: newDynamicColorState);
    }

    // Invalidate dynamic color schemes to refresh with new setting
    ref.invalidate(dynamicColorSchemesProvider);
  }

  Future<void> toggleBlackTheme() =>
      _update(useBlackTheme: !state.useBlackTheme);

  Future<void> toggleCompactDensity() =>
      _update(compactDensity: !state.compactDensity);

  Future<void> setAccentColorSeed(int colorSeed) async {
    // If setting hack theme (0xFF00FF00) or Dracula theme (0xFFBD93F9) while in light or auto mode,
    // and dynamic colors are disabled, automatically switch to dark mode
    if ((colorSeed == 0xFF00FF00 || colorSeed == 0xFFBD93F9) &&
        !state.useDynamicColor) {
      if (state.themeMode == 'light' || state.themeMode == 'system') {
        await _update(accentColorSeed: colorSeed, themeMode: 'dark');
      } else {
        await _update(accentColorSeed: colorSeed);
      }
    }
    // If setting Solarized theme (0xFF268BD2) and black theme is enabled,
    // automatically turn off black theme as Solarized is not compatible with AMOLED black
    else if (colorSeed == 0xFF268BD2 &&
        state.useBlackTheme &&
        !state.useDynamicColor) {
      await _update(accentColorSeed: colorSeed, useBlackTheme: false);
    } else {
      await _update(accentColorSeed: colorSeed);
    }

    // Invalidate dynamic color schemes to refresh themes with new color
    ref.invalidate(dynamicColorSchemesProvider);
  }

  Future<void> toggleHideGreeting() =>
      _update(hideGreeting: !state.hideGreeting);
  Future<void> setGreetingLanguage(int languageIndex) =>
      _update(greetingLanguage: languageIndex);
  Future<void> toggleShowSearchBar() =>
      _update(showSearchBar: !state.showSearchBar);
  Future<void> setFabPosition(String pos) => _update(fabPosition: pos);

  Future<void> setSwipeLeftAction(String action) =>
      _update(swipeLeftAction: action);
  Future<void> setSwipeRightAction(String action) =>
      _update(swipeRightAction: action);

  Future<void> toggleFloatingNoteToolbar() =>
      _update(useFloatingNoteToolbar: !state.useFloatingNoteToolbar);

  Future<void> toggleQuickInputBar() =>
      _update(useQuickInputBar: !state.useQuickInputBar);

  Future<void> toggleNoteHistory() =>
      _update(enableNoteHistory: !state.enableNoteHistory);

  Future<void> toggleSpatialCanvas() =>
      _update(enableSpatialCanvas: !state.enableSpatialCanvas);

  Future<void> toggleAutoOpenKeyboardInNotes() =>
      _update(autoOpenKeyboardInNotes: !state.autoOpenKeyboardInNotes);

  Future<void> toggleDefaultNoteReadMode() =>
      _update(defaultNoteReadMode: !state.defaultNoteReadMode);

  Future<void> setDefaultTaskView(String view) =>
      _update(defaultTaskView: view);

  Future<void> setDefaultNotesFolder(String? folderId) => _update(
    defaultNotesFolderId: folderId,
    clearDefaultNotesFolderId: folderId == null,
  );

  Future<void> setTimeFormat(String format) => _update(timeFormat: format);

  Future<void> setFirstDayOfWeek(int dayIndex) =>
      _update(firstDayOfWeek: dayIndex);

  Future<void> setLineHeightMultiplier(double value) =>
      _update(lineHeightMultiplier: value);

  Future<void> setParagraphSpacing(double value) =>
      _update(paragraphSpacing: value);

  Future<void> setContrastLevel(String level) => _update(contrastLevel: level);

  Future<void> toggleHaptics() =>
      _update(hapticsEnabled: !state.hapticsEnabled);

  Future<void> toggleBlackoutRecents() =>
      _update(blackoutRecents: !state.blackoutRecents);

  Future<void> toggleHideNavLabels() =>
      _update(hideNavLabels: !state.hideNavLabels);

  Future<void> toggleShowOverviewTab() =>
      _update(showOverviewTab: !state.showOverviewTab);

  Future<void> toggleBlurEffects() =>
      _update(useBlurEffects: !state.useBlurEffects);

  Future<void> toggleFloatingNavBar() =>
      _update(floatingNavBar: !state.floatingNavBar);

  Future<void> toggleCompactNotesView() =>
      _update(compactNotesView: !state.compactNotesView);

  Future<void> toggleAutoCompleteEvents() =>
      _update(autoCompleteEvents: !state.autoCompleteEvents);

  Future<void> dismissBatteryOptimizationReminder() =>
      _update(dismissedBatteryOptimizationReminder: true);

  Future<void> resetBatteryOptimizationReminder() =>
      _update(dismissedBatteryOptimizationReminder: false);

  Future<void> setEnableBin(bool value) => _update(enableBin: value);

  Future<void> setAutoDeleteDaysInBin(int days) =>
      _update(autoDeleteDaysInBin: days);

  Future<void> setFloatingToolbarPosition(double x, double y) =>
      _update(floatingToolbarX: x, floatingToolbarY: y);

  Future<void> setFloatingToolbarExpanded(bool expanded) =>
      _update(floatingToolbarExpanded: expanded);

  Future<void> setFloatingToolbarDragHintShown(bool shown) =>
      _update(floatingToolbarDragHintShown: shown);

  Future<void> _update({
    String? themeMode,
    bool? useDynamicColor,
    bool? useBlackTheme,
    int? accentColorSeed,
    bool? compactDensity,
    bool? hideGreeting,
    int? greetingLanguage,
    bool? showSearchBar,
    String? fabPosition,
    String? swipeLeftAction,
    String? swipeRightAction,
    bool? useFloatingNoteToolbar,
    bool? useQuickInputBar,
    bool? enableNoteHistory,
    bool? enableSpatialCanvas,
    int? firstDayOfWeek,
    String? defaultTaskView,
    String? defaultNotesFolderId,
    bool clearDefaultNotesFolderId = false,
    double? lineHeightMultiplier,
    double? paragraphSpacing,
    String? contrastLevel,
    bool? hapticsEnabled,
    String? fontFamily,
    String? timeFormat,
    String? activeCustomThemeId,
    bool? blackoutRecents,
    bool? autoOpenKeyboardInNotes,
    bool? defaultNoteReadMode,
    bool? dismissedBatteryOptimizationReminder,
    bool? enableBin,
    int? autoDeleteDaysInBin,
    double? floatingToolbarX,
    double? floatingToolbarY,
    bool? floatingToolbarExpanded,
    bool? floatingToolbarDragHintShown,
    bool? hideNavLabels,
    bool? showOverviewTab,
    bool? useBlurEffects,
    bool? floatingNavBar,
    bool? compactNotesView,
    bool? autoCompleteEvents,
    double? editorFontSize,
    String? editorFontFamily,
  }) async {
    final updated = await service.update(
      themeMode: themeMode,
      useDynamicColor: useDynamicColor,
      useBlackTheme: useBlackTheme,
      accentColorSeed: accentColorSeed,
      compactDensity: compactDensity,
      hideGreeting: hideGreeting,
      greetingLanguage: greetingLanguage,
      showSearchBar: showSearchBar,
      fabPosition: fabPosition,
      swipeLeftAction: swipeLeftAction,
      swipeRightAction: swipeRightAction,
      useFloatingNoteToolbar: useFloatingNoteToolbar,
      useQuickInputBar: useQuickInputBar,
      enableNoteHistory: enableNoteHistory,
      enableSpatialCanvas: enableSpatialCanvas,
      firstDayOfWeek: firstDayOfWeek,
      defaultTaskView: defaultTaskView,
      defaultNotesFolderId: defaultNotesFolderId,
      clearDefaultNotesFolderId: clearDefaultNotesFolderId,
      lineHeightMultiplier: lineHeightMultiplier,
      paragraphSpacing: paragraphSpacing,
      contrastLevel: contrastLevel,
      hapticsEnabled: hapticsEnabled,
      fontFamily: fontFamily,
      timeFormat: timeFormat,
      activeCustomThemeId: activeCustomThemeId,
      blackoutRecents: blackoutRecents,
      autoOpenKeyboardInNotes: autoOpenKeyboardInNotes,
      defaultNoteReadMode: defaultNoteReadMode,
      dismissedBatteryOptimizationReminder:
          dismissedBatteryOptimizationReminder,
      enableBin: enableBin,
      autoDeleteDaysInBin: autoDeleteDaysInBin,
      floatingToolbarX: floatingToolbarX,
      floatingToolbarY: floatingToolbarY,
      floatingToolbarExpanded: floatingToolbarExpanded,
      floatingToolbarDragHintShown: floatingToolbarDragHintShown,
      hideNavLabels: hideNavLabels,
      showOverviewTab: showOverviewTab,
      useBlurEffects: useBlurEffects,
      floatingNavBar: floatingNavBar,
      compactNotesView: compactNotesView,
      autoCompleteEvents: autoCompleteEvents,
      editorFontSize: editorFontSize,
      editorFontFamily: editorFontFamily,
    );
    ref.read(preferencesStateProvider.notifier).update(updated);
  }

  Future<void> _clearActiveCustomTheme() async {
    final updated = await service.update(clearActiveCustomTheme: true);
    ref.read(preferencesStateProvider.notifier).update(updated);
  }

  Future<void> setFontFamily(String fontFamily) async {
    await _update(fontFamily: fontFamily);
  }

  Future<void> setEditorFontFamily(String family) =>
      _update(editorFontFamily: family);

  Future<void> setEditorFontSize(double size) => _update(editorFontSize: size);

  Future<void> setActiveCustomTheme(String themeId) async {
    await _update(activeCustomThemeId: themeId);
  }

  Future<void> clearActiveCustomTheme() async {
    await _clearActiveCustomTheme();
  }

  /// Add a query to search history (dedup, front-insert, max 10).
  Future<void> addSearchHistory(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return;
    final current = List<String>.from(state.searchHistory);
    current.remove(trimmed);
    current.insert(0, trimmed);
    if (current.length > 10) current.removeRange(10, current.length);
    final updated = await service.update(searchHistory: current);
    ref.read(preferencesStateProvider.notifier).update(updated);
  }

  /// Clear all search history.
  Future<void> clearSearchHistory() async {
    final updated = await service.update(searchHistory: []);
    ref.read(preferencesStateProvider.notifier).update(updated);
  }
}
