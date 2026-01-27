// Trudido - A privacy-focused todo and notes app
// Copyright (C) 2025 Dominik Müller
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

/// Immutable snapshot of user preferences consumed by widgets.
class PreferencesState {
  final String themeMode; // system | light | dark
  final bool useDynamicColor;
  final bool useBlackTheme;
  final int accentColorSeed; // Color value for Material 3 seed color
  final bool compactDensity;
  final bool highContrast;
  final String
  contrastLevel; // standard | medium | high (Material 3 January 2026)
  final bool hideGreeting;
  final int greetingLanguage; // Language index for greeting header
  final bool
  showSearchBar; // Show search bar in header (when false, keeps greeting)
  final String fabPosition; // left | center | right
  final String swipeLeftAction; // 'none', 'delete', 'pin'
  final String swipeRightAction; // 'none', 'delete', 'pin'
  final bool hideNoteToolbar; // Hide formatting toolbar in note editor
  final bool showMoreNoteToolbar; // Show expanded toolbar options
  final bool
  useFloatingNoteToolbar; // Use floating FAB toolbar instead of top toolbar
  final bool useQuickInputBar; // Use bottom input bar instead of FAB menu
  final bool
  enableNoteHistory; // Enable note history, undo/redo feature (experimental)
  final bool hideBottomNavigation; // Hide bottom nav/rail
  final int firstDayOfWeek; // 0=Sunday, 1=Monday, ..., 6=Saturday
  final String defaultTaskView; // list | calendar - default view on app start
  final bool hapticsEnabled; // Enable haptic feedback for interactions
  final double? _lineHeightMultiplier; // Line height multiplier (e.g. 1.2)
  double get lineHeightMultiplier => _lineHeightMultiplier ?? 1.2;
  final double? _paragraphSpacing; // Paragraph spacing in points (e.g. 8.0)
  double get paragraphSpacing => _paragraphSpacing ?? 8.0;

  const PreferencesState({
    required this.themeMode,
    required this.useDynamicColor,
    required this.useBlackTheme,
    required this.accentColorSeed,
    required this.compactDensity,
    required this.highContrast,
    required this.contrastLevel,
    required this.hideGreeting,
    required this.greetingLanguage,
    required this.showSearchBar,
    required this.fabPosition,
    required this.swipeLeftAction,
    required this.swipeRightAction,
    required this.hideNoteToolbar,
    required this.showMoreNoteToolbar,
    required this.useFloatingNoteToolbar,
    required this.useQuickInputBar,
    required this.enableNoteHistory,
    required this.hideBottomNavigation,
    required this.firstDayOfWeek,
    required this.defaultTaskView,
    required this.hapticsEnabled,
    double? lineHeightMultiplier,
    double? paragraphSpacing,
  }) : _lineHeightMultiplier = lineHeightMultiplier,
       _paragraphSpacing = paragraphSpacing;

  PreferencesState copyWith({
    String? themeMode,
    bool? useDynamicColor,
    bool? useBlackTheme,
    int? accentColorSeed,
    bool? compactDensity,
    bool? highContrast,
    String? contrastLevel,
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
    bool? hapticsEnabled,
    double? lineHeightMultiplier,
    double? paragraphSpacing,
  }) => PreferencesState(
    themeMode: themeMode ?? this.themeMode,
    useDynamicColor: useDynamicColor ?? this.useDynamicColor,
    useBlackTheme: useBlackTheme ?? this.useBlackTheme,
    accentColorSeed: accentColorSeed ?? this.accentColorSeed,
    compactDensity: compactDensity ?? this.compactDensity,
    highContrast: highContrast ?? this.highContrast,
    contrastLevel: contrastLevel ?? this.contrastLevel,
    hideGreeting: hideGreeting ?? this.hideGreeting,
    greetingLanguage: greetingLanguage ?? this.greetingLanguage,
    showSearchBar: showSearchBar ?? this.showSearchBar,
    fabPosition: fabPosition ?? this.fabPosition,
    swipeLeftAction: swipeLeftAction ?? this.swipeLeftAction,
    swipeRightAction: swipeRightAction ?? this.swipeRightAction,
    hideNoteToolbar: hideNoteToolbar ?? this.hideNoteToolbar,
    showMoreNoteToolbar: showMoreNoteToolbar ?? this.showMoreNoteToolbar,
    useFloatingNoteToolbar:
        useFloatingNoteToolbar ?? this.useFloatingNoteToolbar,
    useQuickInputBar: useQuickInputBar ?? this.useQuickInputBar,
    enableNoteHistory: enableNoteHistory ?? this.enableNoteHistory,
    hideBottomNavigation: hideBottomNavigation ?? this.hideBottomNavigation,
    firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
    defaultTaskView: defaultTaskView ?? this.defaultTaskView,
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    lineHeightMultiplier: lineHeightMultiplier ?? this.lineHeightMultiplier,
    paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
  );

  static const defaultState = PreferencesState(
    themeMode: 'system',
    useDynamicColor: true,
    useBlackTheme: false,
    accentColorSeed: 0xFF2196F3, // Default blue color
    compactDensity: false,
    highContrast: false,
    contrastLevel:
        'standard', // Material 3 January 2026: standard | medium | high
    hideGreeting: false,
    greetingLanguage: 0, // Default: English (index 0)
    showSearchBar: true, // Default: show search bar
    fabPosition: 'right',
    swipeLeftAction: 'delete', // Default: left to delete
    swipeRightAction: 'pin', // Default: right to pin
    hideNoteToolbar: false, // Default: show toolbar
    showMoreNoteToolbar: false, // Default: collapsed
    useFloatingNoteToolbar:
        false, // Default: use top toolbar (experimental feature off)
    useQuickInputBar: false, // Default: use FAB menu (experimental feature off)
    enableNoteHistory:
        false, // Default: note history feature off (experimental)
    hideBottomNavigation: false, // Default: show nav
    firstDayOfWeek: 1, // Default: Monday (0=Sunday, 1=Monday, etc.)
    defaultTaskView: 'list', // Default: list view
    hapticsEnabled: true, // Default: haptic feedback enabled
    lineHeightMultiplier: 1.2,
    paragraphSpacing: 8.0,
  );
}
