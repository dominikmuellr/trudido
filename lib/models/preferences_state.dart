/// Immutable snapshot of user preferences consumed by widgets.
class PreferencesState {
  final String themeMode; // system | light | dark
  final bool useDynamicColor;
  final bool useBlackTheme;
  final bool compactDensity;
  final bool highContrast;
  final bool hideGreeting;
  final String fabPosition; // left | center | right
  final String swipeLeftAction; // 'none', 'delete', 'pin'
  final String swipeRightAction; // 'none', 'delete', 'pin'

  const PreferencesState({
    required this.themeMode,
    required this.useDynamicColor,
    required this.useBlackTheme,
    required this.compactDensity,
    required this.highContrast,
    required this.hideGreeting,
    required this.fabPosition,
    required this.swipeLeftAction,
    required this.swipeRightAction,
  });

  PreferencesState copyWith({
    String? themeMode,
    bool? useDynamicColor,
    bool? useBlackTheme,
    bool? compactDensity,
    bool? highContrast,
    bool? hideGreeting,
    String? fabPosition,
    String? swipeLeftAction,
    String? swipeRightAction,
  }) => PreferencesState(
        themeMode: themeMode ?? this.themeMode,
        useDynamicColor: useDynamicColor ?? this.useDynamicColor,
        useBlackTheme: useBlackTheme ?? this.useBlackTheme,
        compactDensity: compactDensity ?? this.compactDensity,
        highContrast: highContrast ?? this.highContrast,
        hideGreeting: hideGreeting ?? this.hideGreeting,
        fabPosition: fabPosition ?? this.fabPosition,
        swipeLeftAction: swipeLeftAction ?? this.swipeLeftAction,
        swipeRightAction: swipeRightAction ?? this.swipeRightAction,
      );

  static const defaultState = PreferencesState(
    themeMode: 'system',
    useDynamicColor: true,
    useBlackTheme: false,
    compactDensity: false,
    highContrast: false,
  hideGreeting: false,
    fabPosition: 'right',
    swipeLeftAction: 'delete', // Default: left to delete
    swipeRightAction: 'pin', // Default: right to pin
  );
}
