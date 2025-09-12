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
      themeMode: p.getString('theme_mode') ?? PreferencesState.defaultState.themeMode,
      useDynamicColor: p.getBool('use_dynamic_color') ?? PreferencesState.defaultState.useDynamicColor,
      useBlackTheme: p.getBool('use_black_theme') ?? PreferencesState.defaultState.useBlackTheme,
      compactDensity: p.getBool('compact_density') ?? PreferencesState.defaultState.compactDensity,
      highContrast: p.getBool('high_contrast') ?? PreferencesState.defaultState.highContrast,
      hideGreeting: p.getBool('hide_greeting') ?? PreferencesState.defaultState.hideGreeting,
      fabPosition: _sanitizeFabPosition(p.getString('fab_position')),
      swipeLeftToDelete: p.getBool('swipe_left_to_delete') ?? PreferencesState.defaultState.swipeLeftToDelete,
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
    bool? compactDensity,
    bool? highContrast,
    bool? hideGreeting,
    String? fabPosition,
    bool? swipeLeftToDelete,
  }) async {
    final p = _prefs;
    if (p == null) {
      throw const AppError(AppErrorType.storageRead, 'Prefs not initialized');
    }
    try {
      if (themeMode != null) await p.setString('theme_mode', themeMode);
      if (useDynamicColor != null) await p.setBool('use_dynamic_color', useDynamicColor);
      if (useBlackTheme != null) await p.setBool('use_black_theme', useBlackTheme);
      if (compactDensity != null) await p.setBool('compact_density', compactDensity);
      if (highContrast != null) await p.setBool('high_contrast', highContrast);
      if (hideGreeting != null) await p.setBool('hide_greeting', hideGreeting);
      if (fabPosition != null) await p.setString('fab_position', fabPosition);
      if (swipeLeftToDelete != null) await p.setBool('swipe_left_to_delete', swipeLeftToDelete);
      _hydrate();
      return _cache;
    } catch (e, st) {
      throw AppError(AppErrorType.storageWrite, 'Failed to update preferences', cause: e, stackTrace: st);
    }
  }
}
