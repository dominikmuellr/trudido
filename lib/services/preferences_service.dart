import 'package:shared_preferences/shared_preferences.dart';

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
    // Reuse existing fast prefs init path in StorageService.
    await StorageService.ensurePrefs();
    // Access private copy via SharedPreferences.getInstance again.
    _prefs = await SharedPreferences.getInstance();
    _hydrate();
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
      hideGreeting:
          p.getBool('hide_greeting') ??
          PreferencesState.defaultState.hideGreeting,
      randomGreetingsEnabled:
          p.getBool('random_greetings_enabled') ??
          PreferencesState.defaultState.randomGreetingsEnabled,
      fixedGreetingLanguage:
          p.getInt('fixed_greeting_language') ??
          PreferencesState.defaultState.fixedGreetingLanguage,
      fabPosition: _sanitizeFabPosition(p.getString('fab_position')),
      swipeLeftAction:
          p.getString('swipe_left_action') ??
          PreferencesState.defaultState.swipeLeftAction,
      swipeRightAction:
          p.getString('swipe_right_action') ??
          PreferencesState.defaultState.swipeRightAction,
    );
  }

  String _sanitizeFabPosition(String? v) {
    if (v == 'left' || v == 'center' || v == 'right') return v!;
    return PreferencesState.defaultState.fabPosition;
  }

  Future<PreferencesState> update({
    String? themeMode,
    bool? useDynamicColor,
    bool? useBlackTheme,
    int? accentColorSeed,
    bool? hideGreeting,
    bool? randomGreetingsEnabled,
    int? fixedGreetingLanguage,
    String? fabPosition,
    String? swipeLeftAction,
    String? swipeRightAction,
  }) async {
    final p = _prefs;
    if (p == null) {
      throw const AppError(AppErrorType.storageRead, 'Prefs not initialized');
    }
    try {
      if (themeMode != null) await p.setString('theme_mode', themeMode);
      if (useDynamicColor != null)
        await p.setBool('use_dynamic_color', useDynamicColor);
      if (useBlackTheme != null)
        await p.setBool('use_black_theme', useBlackTheme);
      if (accentColorSeed != null)
        await p.setInt('accent_color_seed', accentColorSeed);
      if (hideGreeting != null) await p.setBool('hide_greeting', hideGreeting);
      if (randomGreetingsEnabled != null)
        await p.setBool('random_greetings_enabled', randomGreetingsEnabled);
      if (fixedGreetingLanguage != null)
        await p.setInt('fixed_greeting_language', fixedGreetingLanguage);
      if (fabPosition != null) await p.setString('fab_position', fabPosition);
      if (swipeLeftAction != null)
        await p.setString('swipe_left_action', swipeLeftAction);
      if (swipeRightAction != null)
        await p.setString('swipe_right_action', swipeRightAction);
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
