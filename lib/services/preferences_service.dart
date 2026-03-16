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
import 'dart:ui' as ui;

import '../models/app_error.dart';
import '../models/preferences_state.dart';
import 'storage_service.dart';

/// Centralized preferences wrapper (cached & typed) independent of Hive boxes.
/// Wraps SharedPreferences keys already used inside StorageService so legacy
/// code continues to function while new UI reads from [PreferencesState].
class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  SharedPreferences? _prefs;
  PreferencesState _cache = PreferencesState.defaultState;

  bool get isReady => _prefs != null;
  PreferencesState get snapshot => _cache;

  Future<void> ensureInitialized() async {
    if (_prefs != null) return;
    // Reuse fast prefs init path in StorageService.
    await StorageService.ensurePrefs();
    // Access private copy via SharedPreferences.getInstance again.
    _prefs = await SharedPreferences.getInstance();

    // On first launch, detect device language and set greeting language
    await _setInitialGreetingLanguage();

    _hydrate();
  }

  /// Detect device language and set greeting language on first launch
  Future<void> _setInitialGreetingLanguage() async {
    final p = _prefs!;

    // Check if greeting language has already been set
    if (p.containsKey('greeting_language')) {
      return; // Already configured, don't override user preference
    }

    // Get device locale
    final locale = ui.PlatformDispatcher.instance.locale;
    final languageCode = locale.languageCode.toLowerCase();

    // Map language codes to greeting language indices
    int greetingIndex = 0; // Default to English

    switch (languageCode) {
      case 'es': // Spanish
        greetingIndex = 1;
        break;
      case 'fr': // French
        greetingIndex = 2;
        break;
      case 'de': // German
        greetingIndex = 3;
        break;
      case 'it': // Italian
        greetingIndex = 4;
        break;
      case 'nl': // Dutch
        greetingIndex = 5;
        break;
      case 'pt': // Portuguese
        greetingIndex = 6;
        break;
      case 'sv': // Swedish
        greetingIndex = 7;
        break;
      case 'da': // Danish
        greetingIndex = 8;
        break;
      case 'no': // Norwegian
      case 'nb': // Norwegian Bokmål
      case 'nn': // Norwegian Nynorsk
        greetingIndex = 9;
        break;
      case 'fi': // Finnish
        greetingIndex = 10;
        break;
      case 'pl': // Polish
        greetingIndex = 11;
        break;
      case 'cs': // Czech
        greetingIndex = 12;
        break;
      case 'hu': // Hungarian
        greetingIndex = 13;
        break;
      case 'ro': // Romanian
        greetingIndex = 14;
        break;
      case 'tr': // Turkish
        greetingIndex = 15;
        break;
      case 'uk': // Ukrainian
        greetingIndex = 16;
        break;
      default:
        greetingIndex = 0; // English fallback
    }

    // Set the detected language
    await p.setInt('greeting_language', greetingIndex);
  }

  void _hydrate() {
    final p = _prefs!;
    _cache = PreferencesState(
      themeMode:
          p.getString('theme_mode') ?? PreferencesState.defaultState.themeMode,
      useDynamicColor:
          p.getBool('use_dynamic_color') ??
          PreferencesState.defaultState.useDynamicColor,
      useBlackTheme:
          p.getBool('use_black_theme') ??
          PreferencesState.defaultState.useBlackTheme,
      accentColorSeed:
          p.getInt('accent_color_seed') ??
          PreferencesState.defaultState.accentColorSeed,
      compactDensity:
          p.getBool('compact_density') ??
          PreferencesState.defaultState.compactDensity,
      highContrast:
          p.getBool('high_contrast') ??
          PreferencesState.defaultState.highContrast,
      contrastLevel:
          p.getString('contrast_level') ??
          PreferencesState.defaultState.contrastLevel,
      hideGreeting:
          p.getBool('hide_greeting') ??
          PreferencesState.defaultState.hideGreeting,
      greetingLanguage:
          p.getInt('greeting_language') ??
          PreferencesState.defaultState.greetingLanguage,
      showSearchBar:
          p.getBool('show_search_bar') ??
          PreferencesState.defaultState.showSearchBar,
      fabPosition: _sanitizeFabPosition(p.getString('fab_position')),
      swipeLeftAction:
          p.getString('swipe_left_action') ??
          PreferencesState.defaultState.swipeLeftAction,
      swipeRightAction:
          p.getString('swipe_right_action') ??
          PreferencesState.defaultState.swipeRightAction,
      hideNoteToolbar:
          p.getBool('hide_note_toolbar') ??
          PreferencesState.defaultState.hideNoteToolbar,
      showMoreNoteToolbar:
          p.getBool('show_more_note_toolbar') ??
          PreferencesState.defaultState.showMoreNoteToolbar,
      useFloatingNoteToolbar:
          p.getBool('use_floating_note_toolbar') ??
          PreferencesState.defaultState.useFloatingNoteToolbar,
      useQuickInputBar:
          p.getBool('use_quick_input_bar') ??
          PreferencesState.defaultState.useQuickInputBar,
      enableNoteHistory:
          p.getBool('enable_note_history') ??
          PreferencesState.defaultState.enableNoteHistory,
      hideBottomNavigation:
          p.getBool('hide_bottom_navigation') ??
          PreferencesState.defaultState.hideBottomNavigation,
      firstDayOfWeek:
          p.getInt('first_day_of_week') ??
          PreferencesState.defaultState.firstDayOfWeek,
      defaultTaskView:
          p.getString('default_task_view') ??
          PreferencesState.defaultState.defaultTaskView,
      defaultNotesFolderId: p.getString('default_notes_folder_id'),
      hapticsEnabled:
          p.getBool('haptics_enabled') ??
          PreferencesState.defaultState.hapticsEnabled,
      fontFamily: _sanitizeFontFamily(p.getString('font_family')),
      timeFormat: _sanitizeTimeFormat(p.getString('time_format')),
      lineHeightMultiplier:
          p.getDouble('line_height_multiplier') ??
          PreferencesState.defaultState.lineHeightMultiplier,
      paragraphSpacing:
          p.getDouble('paragraph_spacing') ??
          PreferencesState.defaultState.paragraphSpacing,
      activeCustomThemeId: p.getString('active_custom_theme_id'),
      blackoutRecents: p.getBool('blackout_recents'),
      autoOpenKeyboardInNotes: p.getBool('auto_open_keyboard_in_notes'),
      defaultNoteReadMode: p.getBool('default_note_read_mode'),
      dismissedBatteryOptimizationReminder: p.getBool(
        'dismissed_battery_opt_reminder',
      ),
      enableBin: p.getBool('enable_bin'),
      autoDeleteDaysInBin: p.getInt('auto_delete_days_in_bin'),
      floatingToolbarX: p.getDouble('floating_toolbar_x'),
      floatingToolbarY: p.getDouble('floating_toolbar_y'),
      floatingToolbarExpanded: p.getBool('floating_toolbar_expanded'),
      floatingToolbarDragHintShown: p.getBool(
        'floating_toolbar_drag_hint_shown',
      ),
      hideNavLabels: p.getBool('hide_nav_labels'),
      showOverviewTab: p.getBool('show_overview_tab'),
    );
  }

  String _sanitizeFabPosition(String? v) {
    if (v == 'left' || v == 'center' || v == 'right') return v!;
    return PreferencesState.defaultState.fabPosition;
  }

  String _sanitizeFontFamily(String? v) {
    switch (v) {
      case 'roboto':
      case 'opensans':
      case 'jetbrains':
      case 'lexend':
        return v!;
      default:
        return PreferencesState.defaultState.fontFamily;
    }
  }

  String _sanitizeTimeFormat(String? v) {
    if (v == 'system' || v == '12h' || v == '24h') return v!;
    return PreferencesState.defaultState.timeFormat;
  }

  Future<PreferencesState> update({
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
    bool? hideNoteToolbar,
    bool? showMoreNoteToolbar,
    bool? useFloatingNoteToolbar,
    bool? useQuickInputBar,
    bool? enableNoteHistory,
    bool? hideBottomNavigation,
    int? firstDayOfWeek,
    String? defaultTaskView,
    String? defaultNotesFolderId,
    bool clearDefaultNotesFolderId = false,
    bool? hapticsEnabled,
    String? fontFamily,
    String? timeFormat,
    double? lineHeightMultiplier,
    double? paragraphSpacing,
    String? contrastLevel,
    String? activeCustomThemeId,
    bool clearActiveCustomTheme = false,
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
  }) async {
    final p = _prefs;
    if (p == null) {
      throw const AppError(AppErrorType.storageRead, 'Prefs not initialized');
    }
    try {
      if (themeMode != null) await p.setString('theme_mode', themeMode);
      if (useDynamicColor != null) {
        await p.setBool('use_dynamic_color', useDynamicColor);
      }
      if (useBlackTheme != null) {
        await p.setBool('use_black_theme', useBlackTheme);
      }
      if (accentColorSeed != null) {
        await p.setInt('accent_color_seed', accentColorSeed);
      }
      if (compactDensity != null) {
        await p.setBool('compact_density', compactDensity);
      }
      if (hideGreeting != null) await p.setBool('hide_greeting', hideGreeting);
      if (greetingLanguage != null) {
        await p.setInt('greeting_language', greetingLanguage);
      }
      if (showSearchBar != null) {
        await p.setBool('show_search_bar', showSearchBar);
      }
      if (fabPosition != null) await p.setString('fab_position', fabPosition);
      if (swipeLeftAction != null) {
        await p.setString('swipe_left_action', swipeLeftAction);
      }
      if (swipeRightAction != null) {
        await p.setString('swipe_right_action', swipeRightAction);
      }
      if (hideNoteToolbar != null) {
        await p.setBool('hide_note_toolbar', hideNoteToolbar);
      }
      if (showMoreNoteToolbar != null) {
        await p.setBool('show_more_note_toolbar', showMoreNoteToolbar);
      }
      if (useFloatingNoteToolbar != null) {
        await p.setBool('use_floating_note_toolbar', useFloatingNoteToolbar);
      }
      if (useQuickInputBar != null) {
        await p.setBool('use_quick_input_bar', useQuickInputBar);
      }
      if (enableNoteHistory != null) {
        await p.setBool('enable_note_history', enableNoteHistory);
      }
      if (hideBottomNavigation != null) {
        await p.setBool('hide_bottom_navigation', hideBottomNavigation);
      }
      if (firstDayOfWeek != null) {
        await p.setInt('first_day_of_week', firstDayOfWeek);
      }
      if (defaultTaskView != null) {
        await p.setString('default_task_view', defaultTaskView);
      }
      if (defaultNotesFolderId != null) {
        await p.setString('default_notes_folder_id', defaultNotesFolderId);
      }
      if (clearDefaultNotesFolderId) {
        await p.remove('default_notes_folder_id');
      }
      if (hapticsEnabled != null) {
        await p.setBool('haptics_enabled', hapticsEnabled);
      }
      if (fontFamily != null) await p.setString('font_family', fontFamily);
      if (timeFormat != null) await p.setString('time_format', timeFormat);
      if (lineHeightMultiplier != null) {
        await p.setDouble('line_height_multiplier', lineHeightMultiplier);
      }
      if (paragraphSpacing != null) {
        await p.setDouble('paragraph_spacing', paragraphSpacing);
      }
      if (contrastLevel != null) {
        await p.setString('contrast_level', contrastLevel);
      }
      if (activeCustomThemeId != null) {
        await p.setString('active_custom_theme_id', activeCustomThemeId);
      }
      if (clearActiveCustomTheme) await p.remove('active_custom_theme_id');
      if (blackoutRecents != null) {
        await p.setBool('blackout_recents', blackoutRecents);
      }
      if (autoOpenKeyboardInNotes != null) {
        await p.setBool('auto_open_keyboard_in_notes', autoOpenKeyboardInNotes);
      }
      if (defaultNoteReadMode != null) {
        await p.setBool('default_note_read_mode', defaultNoteReadMode);
      }
      if (dismissedBatteryOptimizationReminder != null) {
        await p.setBool(
          'dismissed_battery_opt_reminder',
          dismissedBatteryOptimizationReminder,
        );
      }
      if (enableBin != null) await p.setBool('enable_bin', enableBin);
      if (autoDeleteDaysInBin != null) {
        await p.setInt('auto_delete_days_in_bin', autoDeleteDaysInBin);
      }
      if (floatingToolbarX != null) {
        await p.setDouble('floating_toolbar_x', floatingToolbarX);
      }
      if (floatingToolbarY != null) {
        await p.setDouble('floating_toolbar_y', floatingToolbarY);
      }
      if (floatingToolbarExpanded != null) {
        await p.setBool('floating_toolbar_expanded', floatingToolbarExpanded);
      }
      if (floatingToolbarDragHintShown != null) {
        await p.setBool(
          'floating_toolbar_drag_hint_shown',
          floatingToolbarDragHintShown,
        );
      }
      if (hideNavLabels != null) {
        await p.setBool('hide_nav_labels', hideNavLabels);
      }
      if (showOverviewTab != null) {
        await p.setBool('show_overview_tab', showOverviewTab);
      }
      _hydrate();
      return _cache;
    } catch (e, st) {
      throw AppError(
        AppErrorType.storageWrite,
        'Failed to update preferences',
        cause: e,
        stackTrace: st,
      );
    }
  }
}
