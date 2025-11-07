/// Immutable snapshot of user preferences consumed by widgets.
class PreferencesState {
  final String themeMode; // system | light | dark
  final bool useDynamicColor;
  final bool useBlackTheme;
  final int accentColorSeed; // Color value for Material 3 seed color
  final bool compactDensity;
  final bool highContrast;
  final bool hideGreeting;
  final int greetingLanguage; // Language index for greeting header
  final String fabPosition; // left | center | right
  final String swipeLeftAction; // 'none', 'delete', 'pin'
  final String swipeRightAction; // 'none', 'delete', 'pin'

  const PreferencesState({
    required this.themeMode,
    required this.useDynamicColor,
    required this.useBlackTheme,
    required this.accentColorSeed,
    required this.compactDensity,
    required this.highContrast,
    required this.hideGreeting,
    required this.greetingLanguage,
    required this.fabPosition,
    required this.swipeLeftAction,
    required this.swipeRightAction,
  });

  PreferencesState copyWith({
    String? themeMode,
    bool? useDynamicColor,
    bool? useBlackTheme,
    int? accentColorSeed,
    bool? compactDensity,
    bool? highContrast,
    bool? hideGreeting,
    int? greetingLanguage,
    String? fabPosition,
    String? swipeLeftAction,
    String? swipeRightAction,
  }) => PreferencesState(
    themeMode: themeMode ?? this.themeMode,
    useDynamicColor: useDynamicColor ?? this.useDynamicColor,
    useBlackTheme: useBlackTheme ?? this.useBlackTheme,
    accentColorSeed: accentColorSeed ?? this.accentColorSeed,
    compactDensity: compactDensity ?? this.compactDensity,
    highContrast: highContrast ?? this.highContrast,
    hideGreeting: hideGreeting ?? this.hideGreeting,
    greetingLanguage: greetingLanguage ?? this.greetingLanguage,
    fabPosition: fabPosition ?? this.fabPosition,
    swipeLeftAction: swipeLeftAction ?? this.swipeLeftAction,
    swipeRightAction: swipeRightAction ?? this.swipeRightAction,
  );

  static const defaultState = PreferencesState(
    themeMode: 'system',
    useDynamicColor: true,
    useBlackTheme: false,
    accentColorSeed: 0xFF2196F3, // Default blue color
    compactDensity: false,
    highContrast: false,
    hideGreeting: false,
    greetingLanguage: 0, // Default: English (index 0)
    fabPosition: 'right',
    swipeLeftAction: 'delete', // Default: left to delete
    swipeRightAction: 'pin', // Default: right to pin
  );
}
