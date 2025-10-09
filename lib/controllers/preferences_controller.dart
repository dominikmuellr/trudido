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

    // If turning off dynamic colors and hack theme is selected,
    // automatically switch to dark mode if currently in light or auto mode
    if (!newDynamicColorState && state.accentColorSeed == 0xFF00FF00) {
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

  Future<void> setAccentColorSeed(int colorSeed) async {
    // If setting hack theme (0xFF00FF00) while in light or auto mode,
    // and dynamic colors are disabled, automatically switch to dark mode
    if (colorSeed == 0xFF00FF00 && !state.useDynamicColor) {
      if (state.themeMode == 'light' || state.themeMode == 'system') {
        await _update(accentColorSeed: colorSeed, themeMode: 'dark');
      } else {
        await _update(accentColorSeed: colorSeed);
      }
    } else {
      await _update(accentColorSeed: colorSeed);
    }

    // Invalidate dynamic color schemes to refresh themes with new color
    ref.invalidate(dynamicColorSchemesProvider);
  }

  Future<void> toggleHideGreeting() =>
      _update(hideGreeting: !state.hideGreeting);
  Future<void> setFabPosition(String pos) => _update(fabPosition: pos);

  Future<void> setSwipeLeftAction(String action) =>
      _update(swipeLeftAction: action);
  Future<void> setSwipeRightAction(String action) =>
      _update(swipeRightAction: action);

  Future<void> _update({
    String? themeMode,
    bool? useDynamicColor,
    bool? useBlackTheme,
    int? accentColorSeed,
    bool? hideGreeting,
    String? fabPosition,
    String? swipeLeftAction,
    String? swipeRightAction,
  }) async {
    final updated = await service.update(
      themeMode: themeMode,
      useDynamicColor: useDynamicColor,
      useBlackTheme: useBlackTheme,
      accentColorSeed: accentColorSeed,
      hideGreeting: hideGreeting,
      fabPosition: fabPosition,
      swipeLeftAction: swipeLeftAction,
      swipeRightAction: swipeRightAction,
    );
    ref.read(preferencesStateProvider.notifier).state = updated;
  }
}
