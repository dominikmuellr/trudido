import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';
import '../providers/app_providers.dart';
// (preferences state accessed via preferencesStateProvider import from app_providers)

// Theme provider
// Legacy themed notifier removed; theme mode now lives in PreferencesState.

/// Holds whether dynamic color is enabled by user.
// Dynamic color flag now derived from PreferencesState; keep provider for backward compatibility if imported.
final dynamicColorEnabledProvider = Provider<bool>((ref) => ref.watch(preferencesStateProvider).useDynamicColor);

// AMOLED black preference
final blackThemeEnabledProvider = Provider<bool>((ref) => ref.watch(preferencesStateProvider).useBlackTheme);

// Compact density preference
final compactDensityProvider = Provider<bool>((ref) => ref.watch(preferencesStateProvider).compactDensity);

// High contrast preference
final highContrastProvider = Provider<bool>((ref) => ref.watch(preferencesStateProvider).highContrast);

// Removed individual StateNotifiers (logic centralized in PreferencesController).

/// Async provider that fetches dynamic color schemes (light/dark) if supported & allowed.
// Exposed so main.dart can watch for dynamic schemes.
final dynamicColorSchemesProvider = FutureProvider<({ColorScheme? light, ColorScheme? dark})>((ref) async {
  final enabled = ref.watch(dynamicColorEnabledProvider);
  if (!enabled) return (light: null, dark: null);
  if (!Platform.isAndroid) return (light: null, dark: null);
  // dynamic_color returns null if not supported (pre-Android 12)
  final palettes = await DynamicColorPlugin.getCorePalette();
  if (palettes == null) return (light: null, dark: null);
  final light = palettes.toColorScheme();
  final dark = palettes.toColorScheme(brightness: Brightness.dark);
  return (light: light, dark: dark);
});

// ThemeMode selection now via preferences controller (theme_mode key).

// App theme definitions
class AppTheme {
  static const Color legacyPrimarySeed = Color(0xFF2196F3); // seed when dynamic disabled
  static const Color legacySecondary = Color(0xFF03DAC6);
  
  // Light theme colors
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightSurface = Colors.white;
  static const Color lightOnSurface = Color(0xFF1A1A1A);
  
  // Dark theme colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkOnSurface = Color(0xFFE1E1E1);
  
  // Priority colors
  static const Color highPriority = Color(0xFFE57373);
  static const Color mediumPriority = Color(0xFFFFB74D);
  static const Color lowPriority = Color(0xFF81C784);
  
  static ThemeData _baseLight(ColorScheme colorScheme) => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: lightBackground,
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: lightBackground,
      foregroundColor: lightOnSurface,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: lightSurface,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.grey.shade200,
  selectedColor: colorScheme.primary.withValues(alpha: 0.2),
      labelStyle: const TextStyle(fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );

  static ThemeData _baseDark(ColorScheme colorScheme) => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
  scaffoldBackgroundColor: darkBackground,
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: darkBackground,
      foregroundColor: darkOnSurface,
    ),
    cardTheme: CardThemeData(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: darkSurface,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade700),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.grey.shade800,
  selectedColor: colorScheme.primary.withValues(alpha: 0.3),
      labelStyle: const TextStyle(fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );

  /// Build current light/dark themes (dynamic aware) given optional dynamic schemes.
  static (ThemeData light, ThemeData dark) buildThemes({ColorScheme? dynamicLight, ColorScheme? dynamicDark, bool compact = false, bool highContrast = false}) {
    final seedLight = ColorScheme.fromSeed(
      seedColor: legacyPrimarySeed,
      brightness: Brightness.light,
      surface: lightSurface,
      onSurface: lightOnSurface,
    );
    final seedDark = ColorScheme.fromSeed(
      seedColor: legacyPrimarySeed,
      brightness: Brightness.dark,
      surface: darkSurface,
      onSurface: darkOnSurface,
    );
    var light = _baseLight(dynamicLight ?? seedLight);
    var dark = _baseDark(dynamicDark ?? seedDark);

    if (compact) {
      light = light.copyWith(
        visualDensity: VisualDensity.compact,
        listTileTheme: const ListTileThemeData(dense: true, horizontalTitleGap: 8, minVerticalPadding: 4),
        chipTheme: light.chipTheme.copyWith(labelStyle: light.textTheme.labelMedium),
        cardTheme: light.cardTheme.copyWith(
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      dark = dark.copyWith(
        visualDensity: VisualDensity.compact,
        listTileTheme: const ListTileThemeData(dense: true, horizontalTitleGap: 8, minVerticalPadding: 4),
        chipTheme: dark.chipTheme.copyWith(labelStyle: dark.textTheme.labelMedium),
        cardTheme: dark.cardTheme.copyWith(
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    if (highContrast) {
      ColorScheme boost(ColorScheme cs) => cs.copyWith(
        primary: cs.primary,
        onPrimary: cs.onPrimary,
        surface: cs.surface,
        onSurface: cs.onSurface,
        // 0.8 opacity => alpha 204
        outline: cs.onSurface.withValues(alpha: 204),
      );
      light = light.copyWith(
        colorScheme: boost(light.colorScheme),
        textTheme: light.textTheme.apply(bodyColor: light.colorScheme.onSurface, displayColor: light.colorScheme.onSurface),
  // 0.4 => alpha 102
  dividerColor: light.colorScheme.onSurface.withValues(alpha: 102),
      );
      dark = dark.copyWith(
        colorScheme: boost(dark.colorScheme),
        textTheme: dark.textTheme.apply(bodyColor: dark.colorScheme.onSurface, displayColor: dark.colorScheme.onSurface),
  // 0.6 => alpha 153
  dividerColor: dark.colorScheme.onSurface.withValues(alpha: 153),
      );
    }
    // Attach extension so widgets can adapt spacing & contrast specifics.
    final appOpts = AppOptions(compact: compact, highContrast: highContrast);
    light = light.copyWith(extensions: [
      ...light.extensions.values,
      appOpts,
    ]);
    dark = dark.copyWith(extensions: [
      ...dark.extensions.values,
      appOpts,
    ]);
    return (light, dark);
  }

  /// Derive a pure black variant of an existing dark ThemeData while keeping its ColorScheme.
  static ThemeData blackify(ThemeData darkBase) {
    final cs = darkBase.colorScheme;
    return darkBase.copyWith(
      scaffoldBackgroundColor: Colors.black,
      canvasColor: Colors.black,
      cardColor: const Color(0xFF111111),
      appBarTheme: darkBase.appBarTheme.copyWith(backgroundColor: Colors.black),
      navigationBarTheme: darkBase.navigationBarTheme.copyWith(backgroundColor: Colors.black),
      colorScheme: cs.copyWith(surface: const Color(0xFF111111)), dialogTheme: DialogThemeData(backgroundColor: const Color(0xFF111111)),
    );
  }

  // Legacy static fallbacks kept for code referencing them before refactor completes.
  static ThemeData lightTheme = buildThemes().$1;
  static ThemeData darkTheme = buildThemes().$2;

  // Helper methods for priority colors
  static Color getPriorityColor(String priority, {bool isDark = false}) {
    switch (priority.toLowerCase()) {
      case 'high':
        return highPriority;
      case 'medium':
        return mediumPriority;
      case 'low':
        return lowPriority;
      default:
        return isDark ? Colors.grey.shade600 : Colors.grey.shade400;
    }
  }

  static IconData getPriorityIcon(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Icons.keyboard_double_arrow_up;
      case 'medium':
        return Icons.keyboard_arrow_up;
      case 'low':
        return Icons.keyboard_arrow_down;
      default:
        return Icons.remove;
    }
  }
}

// ThemeExtension to pass custom layout/accessibility flags to widgets.
class AppOptions extends ThemeExtension<AppOptions> {
  final bool compact;
  final bool highContrast;
  const AppOptions({required this.compact, required this.highContrast});

  @override
  ThemeExtension<AppOptions> copyWith({bool? compact, bool? highContrast}) {
    return AppOptions(
      compact: compact ?? this.compact,
      highContrast: highContrast ?? this.highContrast,
    );
  }

  @override
  ThemeExtension<AppOptions> lerp(ThemeExtension<AppOptions>? other, double t) {
    if (other is! AppOptions) return this;
    // Bool flags snap based on t > 0.5
    return AppOptions(
      compact: t < 0.5 ? compact : other.compact,
      highContrast: t < 0.5 ? highContrast : other.highContrast,
    );
  }
}
