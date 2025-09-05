import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/preferences_state.dart';
import '../services/preferences_service.dart';
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

  Future<void> toggleDynamicColor() => _update(useDynamicColor: !state.useDynamicColor);
  Future<void> toggleBlackTheme() => _update(useBlackTheme: !state.useBlackTheme);
  Future<void> toggleCompactDensity() => _update(compactDensity: !state.compactDensity);
  Future<void> toggleHighContrast() => _update(highContrast: !state.highContrast);
  Future<void> toggleHideGreeting() => _update(hideGreeting: !state.hideGreeting);
  Future<void> setFabPosition(String pos) => _update(fabPosition: pos);

  Future<void> _update({
    String? themeMode,
    bool? useDynamicColor,
    bool? useBlackTheme,
    bool? compactDensity,
    bool? highContrast,
    bool? hideGreeting,
    String? fabPosition,
  }) async {
    final updated = await service.update(
      themeMode: themeMode,
      useDynamicColor: useDynamicColor,
      useBlackTheme: useBlackTheme,
      compactDensity: compactDensity,
      highContrast: highContrast,
      hideGreeting: hideGreeting,
      fabPosition: fabPosition,
    );
    ref.read(preferencesStateProvider.notifier).state = updated;
  }
}
