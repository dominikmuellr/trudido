/// Immutable snapshot of user preferences consumed by widgets.
class PreferencesState {
  final String themeMode; // system | light | dark
  final bool useDynamicColor;
  final bool useBlackTheme;
  final bool compactDensity;
  final bool highContrast;
  final bool hideGreeting;
  final String fabPosition; // left | center | right
  final bool swipeLeftToDelete; // true = left to delete, right to pin | false = left to pin, right to delete

  const PreferencesState({
    required this.themeMode,
    required this.useDynamicColor,
    required this.useBlackTheme,
    required this.compactDensity,
    required this.highContrast,
    required this.hideGreeting,
    required this.fabPosition,
    required this.swipeLeftToDelete,
  });

  PreferencesState copyWith({
    String? themeMode,
    bool? useDynamicColor,
    bool? useBlackTheme,
    bool? compactDensity,
    bool? highContrast,
    bool? hideGreeting,
    String? fabPosition,
    bool? swipeLeftToDelete,
  }) => PreferencesState(
        themeMode: themeMode ?? this.themeMode,
        useDynamicColor: useDynamicColor ?? this.useDynamicColor,
        useBlackTheme: useBlackTheme ?? this.useBlackTheme,
        compactDensity: compactDensity ?? this.compactDensity,
        highContrast: highContrast ?? this.highContrast,
        hideGreeting: hideGreeting ?? this.hideGreeting,
        fabPosition: fabPosition ?? this.fabPosition,
        swipeLeftToDelete: swipeLeftToDelete ?? this.swipeLeftToDelete,
      );

  static const defaultState = PreferencesState(
    themeMode: 'system',
    useDynamicColor: true,
    useBlackTheme: false,
    compactDensity: false,
    highContrast: false,
    hideGreeting: true,
    fabPosition: 'right',
    swipeLeftToDelete: true, // Default: left to delete, right to pin
  );
}
