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
      hideGreeting:
          p.getBool('hide_greeting') ??
          PreferencesState.defaultState.hideGreeting,
      greetingLanguage:
          p.getInt('greeting_language') ??
          PreferencesState.defaultState.greetingLanguage,
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
    int? greetingLanguage,
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
      if (greetingLanguage != null)
        await p.setInt('greeting_language', greetingLanguage);
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
