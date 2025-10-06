import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_providers.dart';
// (preferences state accessed via preferencesStateProvider import from app_providers)

// Theme provider
// Legacy themed notifier removed; theme mode now lives in PreferencesState.

/// Holds whether dynamic color is enabled by user.
// Dynamic color flag now derived from PreferencesState; keep provider for backward compatibility if imported.
final dynamicColorEnabledProvider = Provider<bool>(
  (ref) => ref.watch(preferencesStateProvider).useDynamicColor,
);

// AMOLED black preference
final blackThemeEnabledProvider = Provider<bool>(
  (ref) => ref.watch(preferencesStateProvider).useBlackTheme,
);

// Compact density preference
final compactDensityProvider = Provider<bool>(
  (ref) => ref.watch(preferencesStateProvider).compactDensity,
);

// High contrast preference
final highContrastProvider = Provider<bool>(
  (ref) => ref.watch(preferencesStateProvider).highContrast,
);

// Removed individual StateNotifiers (logic centralized in PreferencesController).

/// Dynamic color schemes provider that can be invalidated when system colors change
final dynamicColorSchemesProvider =
    FutureProvider.autoDispose<({ColorScheme? light, ColorScheme? dark})>((
      ref,
    ) async {
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
  static const Color legacyPrimarySeed = Color(
    0xFF2196F3,
  ); // seed when dynamic disabled

  // Priority colors - keep these for now as they're used by widgets
  static const Color highPriority = Color(0xFFE57373);
  static const Color mediumPriority = Color(0xFFFFB74D);
  static const Color lowPriority = Color(0xFF81C784);

  /// Creates a comprehensive text theme with Montserrat for headlines/titles and Inter for body text
  static TextTheme _buildTextTheme(Brightness brightness) {
    final baseTextTheme = brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;

    // Use Montserrat for headlines, titles, and labels
    final montserratTextTheme = GoogleFonts.montserratTextTheme(baseTextTheme)
        .copyWith(
          displayLarge: GoogleFonts.montserrat(
            fontWeight: FontWeight.w300,
            letterSpacing: -1.5,
          ),
          displayMedium: GoogleFonts.montserrat(
            fontWeight: FontWeight.w300,
            letterSpacing: -0.5,
          ),
          displaySmall: GoogleFonts.montserrat(fontWeight: FontWeight.w400),
          headlineLarge: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.25,
          ),
          headlineMedium: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
          headlineSmall: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
          titleLarge: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.15,
          ),
          titleMedium: GoogleFonts.montserrat(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.15,
          ),
          titleSmall: GoogleFonts.montserrat(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
          labelLarge: GoogleFonts.montserrat(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
          labelMedium: GoogleFonts.montserrat(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
          labelSmall: GoogleFonts.montserrat(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        );

    // Use Inter for body text (more readable for longer content)
    // Using w500 for better readability - w400 can appear too thin
    return montserratTextTheme.copyWith(
      bodyLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w500, // Medium weight for better presence
        letterSpacing: 0.5,
      ),
      bodyMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w500, // Medium weight for consistency
        letterSpacing: 0.25,
      ),
      bodySmall: GoogleFonts.inter(
        fontWeight: FontWeight.w500, // Consistent across all body text
        letterSpacing: 0.4,
      ),
    );
  }

  /// Helper method for code/monospace text styling that works well with our typography system
  static TextStyle getCodeTextStyle(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    final theme = Theme.of(context);
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize ?? theme.textTheme.bodyMedium?.fontSize,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color ?? theme.colorScheme.onSurfaceVariant,
      letterSpacing: 0.0,
    );
  }

  static ThemeData _baseLight(ColorScheme colorScheme) => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: colorScheme,
    textTheme: _buildTextTheme(Brightness.light),
    scaffoldBackgroundColor: colorScheme.surface, // Material 3 color-aware
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: colorScheme.surface, // Material 3 color-aware
      foregroundColor: colorScheme.onSurface, // Material 3 color-aware
    ),
    cardTheme: CardThemeData(
      elevation: 1, // Material 3 standard for most cards
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colorScheme.surfaceContainerLow, // Material 3 elevated surface
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      hintStyle: TextStyle(
        color: colorScheme.onSurfaceVariant.withOpacity(0.7),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    // Material 3 ListTile styling
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      horizontalTitleGap: 16,
      minVerticalPadding: 8,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surfaceContainerHighest,
      selectedColor: colorScheme.primary.withValues(alpha: 0.25),
      labelStyle: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    // Material 3 PopupMenu styling
    popupMenuTheme: PopupMenuThemeData(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colorScheme.surfaceContainer,
    ),
    // Material 3 Dialog styling
    dialogTheme: DialogThemeData(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: colorScheme.surfaceContainerHigh,
    ),
  );

  static ThemeData _baseDark(ColorScheme colorScheme) => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    textTheme: _buildTextTheme(Brightness.dark),
    scaffoldBackgroundColor: colorScheme.surface, // Material 3 color-aware
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: colorScheme.surface, // Material 3 color-aware
      foregroundColor: colorScheme.onSurface, // Material 3 color-aware
    ),
    cardTheme: CardThemeData(
      elevation: 1, // Material 3 standard for most cards
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colorScheme.surfaceContainerLow, // Material 3 elevated surface
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      hintStyle: TextStyle(
        color: colorScheme.onSurfaceVariant.withOpacity(0.7),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    // Material 3 ListTile styling
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      horizontalTitleGap: 16,
      minVerticalPadding: 8,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surfaceContainerHighest,
      selectedColor: colorScheme.primary.withValues(alpha: 0.3),
      labelStyle: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    // Material 3 PopupMenu styling
    popupMenuTheme: PopupMenuThemeData(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colorScheme.surfaceContainer,
    ),
    // Material 3 Dialog styling
    dialogTheme: DialogThemeData(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: colorScheme.surfaceContainerHigh,
    ),
  );

  /// Build current light/dark themes (dynamic aware) given optional dynamic schemes.
  static (ThemeData light, ThemeData dark) buildThemes({
    ColorScheme? dynamicLight,
    ColorScheme? dynamicDark,
    bool compact = false,
    bool highContrast = false,
  }) {
    final seedLight = ColorScheme.fromSeed(
      seedColor: legacyPrimarySeed,
      brightness: Brightness.light,
    );
    final seedDark = ColorScheme.fromSeed(
      seedColor: legacyPrimarySeed,
      brightness: Brightness.dark,
    );
    var light = _baseLight(dynamicLight ?? seedLight);
    var dark = _baseDark(dynamicDark ?? seedDark);

    if (compact) {
      light = light.copyWith(
        visualDensity: VisualDensity.compact,
        listTileTheme: const ListTileThemeData(
          dense: true,
          horizontalTitleGap: 8,
          minVerticalPadding: 4,
        ),
        chipTheme: light.chipTheme.copyWith(
          labelStyle: light.textTheme.labelMedium,
        ),
        cardTheme: light.cardTheme.copyWith(
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      dark = dark.copyWith(
        visualDensity: VisualDensity.compact,
        listTileTheme: const ListTileThemeData(
          dense: true,
          horizontalTitleGap: 8,
          minVerticalPadding: 4,
        ),
        chipTheme: dark.chipTheme.copyWith(
          labelStyle: dark.textTheme.labelMedium,
        ),
        cardTheme: dark.cardTheme.copyWith(
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
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
        textTheme: light.textTheme.apply(
          bodyColor: light.colorScheme.onSurface,
          displayColor: light.colorScheme.onSurface,
        ),
        // 0.4 => alpha 102
        dividerColor: light.colorScheme.onSurface.withValues(alpha: 102),
      );
      dark = dark.copyWith(
        colorScheme: boost(dark.colorScheme),
        textTheme: dark.textTheme.apply(
          bodyColor: dark.colorScheme.onSurface,
          displayColor: dark.colorScheme.onSurface,
        ),
        // 0.6 => alpha 153
        dividerColor: dark.colorScheme.onSurface.withValues(alpha: 153),
      );
    }
    // Attach extension so widgets can adapt spacing & contrast specifics.
    final appOpts = AppOptions(compact: compact, highContrast: highContrast);
    light = light.copyWith(extensions: [...light.extensions.values, appOpts]);
    dark = dark.copyWith(extensions: [...dark.extensions.values, appOpts]);
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
      navigationBarTheme: darkBase.navigationBarTheme.copyWith(
        backgroundColor: Colors.black,
      ),
      colorScheme: cs.copyWith(surface: const Color(0xFF111111)),
      dialogTheme: DialogThemeData(backgroundColor: const Color(0xFF111111)),
    );
  }

  // Legacy static fallbacks kept for code referencing them before refactor completes.
  static ThemeData lightTheme = buildThemes().$1;
  static ThemeData darkTheme = buildThemes().$2;

  // Helper methods for priority colors - updated for Material 3
  static Color getPriorityColor(String priority, ColorScheme colorScheme) {
    switch (priority.toLowerCase()) {
      case 'high':
        return colorScheme.error;
      case 'medium':
        return colorScheme.tertiary;
      case 'low':
        return colorScheme.secondary;
      default:
        return colorScheme.outline;
    }
  }

  // Legacy method - kept for backwards compatibility
  @deprecated
  static Color getPriorityColorLegacy(String priority, {bool isDark = false}) {
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
        return Icons.keyboard_arrow_up;
      case 'medium':
        return Icons.remove;
      case 'low':
        return Icons.keyboard_arrow_down;
      default:
        return Icons.circle_outlined;
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
