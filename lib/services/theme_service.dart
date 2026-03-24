// Trudido - A privacy-focused todo and notes app
// Copyright (C) 2026 Dominik Müller
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

import 'dart:io' show Platform;
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Removed google_fonts package to reduce APK size - using system default fonts
import '../providers/app_providers.dart';
import '../utils/state_notifiers.dart';
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

// High contrast preference (legacy - maintained for backwards compatibility)
final highContrastProvider = Provider<bool>(
  (ref) => ref.watch(preferencesStateProvider).highContrast,
);

// Contrast level preference (Material 3 January 2026: standard | medium | high)
final contrastLevelProvider = Provider<String>(
  (ref) => ref.watch(preferencesStateProvider).contrastLevel,
);

/// Bump this to force the app to reload custom theme colors from storage.
/// Used when a custom theme is edited and saved (content changed, same ID).
final customThemeRevisionProvider = stateProvider<int>(0);

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

  // Material 3 seed color options for accent color selection
  static const List<int> accentColorSeeds = [
    // Standard Material 3 seed colors
    0xFF2196F3, // Blue (default)
    0xFFE91E63, // Pink
    0xFF9C27B0, // Purple
    0xFF673AB7, // Deep Purple
    0xFF3F51B5, // Indigo
    0xFF009688, // Teal
    0xFF4CAF50, // Green
    0xFF8BC34A, // Light Green
    0xFFCDDC39, // Lime
    0xFFFFC107, // Amber
    0xFFFF9800, // Orange
    0xFFFF5722, // Deep Orange
    0xFF795548, // Brown
    0xFF607D8B, // Blue Grey
    // Custom theme colors with special behavior
    0xFF9E9E9E, // Monochrome (black/white accents)
    0xFF757575, // Grey (grey accents)
    0xFF00FF00, // Hack (Matrix green, dark mode only)
    0xFFBD93F9, // Dracula (authentic Dracula colors, dark mode only)
    0xFF268BD2, // Solarized (authentic Solarized colors with proper light/dark modes)
  ];

  static String getAccentColorName(int colorValue) {
    switch (colorValue) {
      case 0xFF2196F3:
        return 'Blue';
      case 0xFFE91E63:
        return 'Pink';
      case 0xFF9C27B0:
        return 'Purple';
      case 0xFF673AB7:
        return 'Deep Purple';
      case 0xFF3F51B5:
        return 'Indigo';
      case 0xFF009688:
        return 'Teal';
      case 0xFF4CAF50:
        return 'Green';
      case 0xFF8BC34A:
        return 'Light Green';
      case 0xFFCDDC39:
        return 'Lime';
      case 0xFFFFC107:
        return 'Amber';
      case 0xFFFF9800:
        return 'Orange';
      case 0xFFFF5722:
        return 'Deep Orange';
      case 0xFF795548:
        return 'Brown';
      case 0xFF9E9E9E:
        return 'Monochrome';
      case 0xFF757575:
        return 'Grey';
      case 0xFF00FF00:
        return 'Hack';
      case 0xFFBD93F9:
        return 'Dracula';
      case 0xFF268BD2:
        return 'Solarized';
      case 0xFF607D8B:
        return 'Blue Grey';
      default:
        return 'Custom';
    }
  }

  // Priority colors - keep these for now as they're used by widgets
  static const Color highPriority = Color(0xFFE57373);
  static const Color mediumPriority = Color(0xFFFFB74D);
  static const Color lowPriority = Color(0xFF81C784);

  /// Maps user font preference to actual font family name
  /// Returns null for Flutter/Material default (Roboto on Android, SF on iOS)
  static String? _getFontFamily(String? preference) {
    switch (preference) {
      case 'opensans':
        return 'OpenSans';
      case 'inter':
        return 'Inter';
      case 'jetbrains':
        return 'JetBrainsMono';
      case 'lexend':
        return 'Lexend';
      case 'roboto':
      default:
        return null; // null = use Flutter/Material default (Roboto on Android, SF on iOS)
    }
  }

  /// Creates a comprehensive text theme with customizable font family
  static TextTheme _buildTextTheme(Brightness brightness, String? fontFamily) {
    // Map font preference to actual font family name
    // null or 'roboto' = use Flutter/Material platform default
    final String? actualFontFamily = _getFontFamily(fontFamily);

    final baseTextTheme = brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;

    // Customize weights and letter spacing
    return baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontFamily: actualFontFamily,
        fontWeight: FontWeight.w500,
        letterSpacing: -1.5,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        fontFamily: actualFontFamily,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.5,
      ),
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        fontFamily: actualFontFamily,
        fontWeight: FontWeight.w500,
      ),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontFamily: actualFontFamily,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.25,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontFamily: actualFontFamily,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontFamily: actualFontFamily,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontFamily: actualFontFamily,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.15,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontFamily: actualFontFamily,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontFamily: actualFontFamily,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontFamily: actualFontFamily,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontFamily: actualFontFamily,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        fontFamily: actualFontFamily,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontFamily: actualFontFamily,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontFamily: actualFontFamily,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontFamily: actualFontFamily,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
      ),
    );
  }

  /// Helper method for code/monospace text styling
  static TextStyle getCodeTextStyle(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    final theme = Theme.of(context);
    return TextStyle(
      fontFamily: 'monospace',
      fontSize: fontSize ?? theme.textTheme.bodyMedium?.fontSize,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color ?? theme.colorScheme.onSurfaceVariant,
      letterSpacing: 0.0,
    );
  }

  /// Safe accessor for custom text styles using system default font
  static TextStyle safeMontserrat(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) {
    final theme = Theme.of(context);
    return TextStyle(
      fontSize: fontSize ?? theme.textTheme.titleLarge?.fontSize,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color ?? theme.colorScheme.primary,
      letterSpacing: letterSpacing ?? 0.0,
    );
  }

  /// When true, AppTheme will avoid using google_fonts API and fall back to
  /// platform fonts. Tests should set this to true in `setUpAll` when they
  /// disable runtime fetching to prevent google_fonts from throwing.
  static bool disableGoogleFonts = false;

  /// Helper to lighten a color by a percentage (0.0 to 1.0)
  static Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  /// Helper to darken a color by a percentage (0.0 to 1.0)
  static Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  /// Boost saturation of a color by a multiplier (clamped to 1.0).
  static Color _boostSaturation(Color color, double factor) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation((hsl.saturation * factor).clamp(0.0, 1.0))
        .toColor();
  }

  /// Enhance dark mode: lighten surfaces & text for contrast, boost surface
  /// container saturation so the accent hue is clearly visible.
  static ColorScheme _enhanceDarkExpressiveness(ColorScheme darkScheme) {
    return darkScheme.copyWith(
      // Lighten + boost saturation for visible hue-tinted surfaces
      surfaceContainerLowest: _boostSaturation(
        _lighten(darkScheme.surfaceContainerLowest, 0.05),
        1.3,
      ),
      surfaceContainerLow: _boostSaturation(
        _lighten(darkScheme.surfaceContainerLow, 0.08),
        1.3,
      ),
      surfaceContainer: _boostSaturation(
        _lighten(darkScheme.surfaceContainer, 0.08),
        1.3,
      ),
      surfaceContainerHigh: _boostSaturation(
        _lighten(darkScheme.surfaceContainerHigh, 0.10),
        1.3,
      ),
      surfaceContainerHighest: _boostSaturation(
        _lighten(darkScheme.surfaceContainerHighest, 0.12),
        1.3,
      ),
      // Make text slightly brighter for better readability
      onSurface: _lighten(darkScheme.onSurface, 0.05),
      onSurfaceVariant: _lighten(darkScheme.onSurfaceVariant, 0.08),
    );
  }

  /// Normalize schemes to a two-color model by mirroring tertiary to secondary.
  static ColorScheme _normalizeTwoColorScheme(ColorScheme scheme) {
    return scheme.copyWith(
      tertiary: scheme.secondary,
      onTertiary: scheme.onSecondary,
      tertiaryContainer: scheme.secondaryContainer,
      onTertiaryContainer: scheme.onSecondaryContainer,
      tertiaryFixed: scheme.secondaryFixed,
      tertiaryFixedDim: scheme.secondaryFixedDim,
      onTertiaryFixed: scheme.onSecondaryFixed,
      onTertiaryFixedVariant: scheme.onSecondaryFixedVariant,
    );
  }

  static ThemeData _baseLight(ColorScheme colorScheme, [String? fontFamily]) {
    final scheme = _normalizeTwoColorScheme(colorScheme);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      fontFamily: _getFontFamily(fontFamily),
      textTheme: _buildTextTheme(Brightness.light, fontFamily),
      scaffoldBackgroundColor: scheme.surface, // Material 3 color-aware
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: scheme.surface, // Material 3 color-aware
        foregroundColor: scheme.onSurface, // Material 3 color-aware
      ),
      cardTheme: CardThemeData(
        elevation:
            0, // Material 3 January 2026: use tone-based surfaces instead of elevation
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: scheme.surfaceContainerLow, // Material 3 elevated surface
      ),
      // Material 3 January 2026: FABs use Enhanced (secondary) container colors
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.secondaryContainer,
        foregroundColor: scheme.onSecondaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0, // Material 3: FABs use tone, not elevation
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
      ),
      // Material 3 January 2026: Filled input fields (primary style)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: scheme.primary),
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      // Material 3 January 2026: Elevated buttons with proper state layers
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.onSurface.withValues(alpha: 0.12);
            }
            return scheme.surfaceContainerLow;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.onSurface.withValues(alpha: 0.38);
            }
            return scheme.primary;
          }),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return scheme.primary.withValues(alpha: 0.12);
            }
            if (states.contains(WidgetState.hovered)) {
              return scheme.primary.withValues(alpha: 0.08);
            }
            if (states.contains(WidgetState.focused)) {
              return scheme.primary.withValues(alpha: 0.10);
            }
            return null;
          }),
          elevation: const WidgetStatePropertyAll(1),
        ),
      ),
      // Material 3 January 2026: Filled buttons with state layers
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return scheme.onPrimary.withValues(alpha: 0.12);
            }
            if (states.contains(WidgetState.hovered)) {
              return scheme.onPrimary.withValues(alpha: 0.08);
            }
            if (states.contains(WidgetState.focused)) {
              return scheme.onPrimary.withValues(alpha: 0.10);
            }
            return null;
          }),
        ),
      ),
      // Material 3 January 2026: Outlined buttons with state layers
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(
                color: scheme.onSurface.withValues(alpha: 0.12),
              );
            }
            if (states.contains(WidgetState.focused)) {
              return BorderSide(color: scheme.primary, width: 2);
            }
            return BorderSide(color: scheme.outline);
          }),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return scheme.primary.withValues(alpha: 0.12);
            }
            if (states.contains(WidgetState.hovered)) {
              return scheme.primary.withValues(alpha: 0.08);
            }
            if (states.contains(WidgetState.focused)) {
              return scheme.primary.withValues(alpha: 0.10);
            }
            return null;
          }),
        ),
      ),
      // Material 3 January 2026: Text buttons with state layers
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return scheme.primary.withValues(alpha: 0.12);
            }
            if (states.contains(WidgetState.hovered)) {
              return scheme.primary.withValues(alpha: 0.08);
            }
            if (states.contains(WidgetState.focused)) {
              return scheme.primary.withValues(alpha: 0.10);
            }
            return null;
          }),
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
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primaryContainer,
        labelStyle: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        secondaryLabelStyle: TextStyle(
          fontSize: 13,
          color: scheme.onPrimaryContainer,
        ),
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 18),
      ),
      // Material 3 PopupMenu styling
      popupMenuTheme: PopupMenuThemeData(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: scheme.surfaceContainer,
      ),
      // Material 3 Dialog styling
      dialogTheme: DialogThemeData(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: scheme.surfaceContainerHigh,
      ),
      // Bottom sheet styling
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      // Navigation bar styling (Android 14+ feel)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: scheme.onPrimaryContainer);
          }
          return IconThemeData(color: scheme.onSurfaceVariant);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            );
          }
          return TextStyle(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          );
        }),
      ),
      // Icon button styling for three-dot menus
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          iconSize: 20,
        ),
      ),
      // Modern circular checkboxes
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: scheme.outline, width: 2),
      ),
    );
  }

  static ThemeData _baseDark(ColorScheme colorScheme, [String? fontFamily]) {
    final scheme = _normalizeTwoColorScheme(colorScheme);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: _getFontFamily(fontFamily),
      textTheme: _buildTextTheme(Brightness.dark, fontFamily),
      scaffoldBackgroundColor: scheme.surface, // Material 3 color-aware
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: scheme.surface, // Material 3 color-aware
        foregroundColor: scheme.onSurface, // Material 3 color-aware
      ),
      cardTheme: CardThemeData(
        elevation:
            0, // Material 3 January 2026: use tone-based surfaces instead of elevation
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: scheme.surfaceContainerLow, // Material 3 elevated surface
      ),
      // Material 3 January 2026: FABs use Enhanced (secondary) container colors
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.secondaryContainer,
        foregroundColor: scheme.onSecondaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0, // Material 3: FABs use tone, not elevation
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
      ),
      // Material 3 January 2026: Filled input fields (primary style)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: scheme.primary),
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      // Material 3 January 2026: Elevated buttons with proper state layers
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.onSurface.withValues(alpha: 0.12);
            }
            return scheme.surfaceContainerLow;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.onSurface.withValues(alpha: 0.38);
            }
            return scheme.primary;
          }),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return scheme.primary.withValues(alpha: 0.12);
            }
            if (states.contains(WidgetState.hovered)) {
              return scheme.primary.withValues(alpha: 0.08);
            }
            if (states.contains(WidgetState.focused)) {
              return scheme.primary.withValues(alpha: 0.10);
            }
            return null;
          }),
          elevation: const WidgetStatePropertyAll(1),
        ),
      ),
      // Material 3 January 2026: Filled buttons with state layers
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return scheme.onPrimary.withValues(alpha: 0.12);
            }
            if (states.contains(WidgetState.hovered)) {
              return scheme.onPrimary.withValues(alpha: 0.08);
            }
            if (states.contains(WidgetState.focused)) {
              return scheme.onPrimary.withValues(alpha: 0.10);
            }
            return null;
          }),
        ),
      ),
      // Material 3 January 2026: Outlined buttons with state layers
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(
                color: scheme.onSurface.withValues(alpha: 0.12),
              );
            }
            if (states.contains(WidgetState.focused)) {
              return BorderSide(color: scheme.primary, width: 2);
            }
            return BorderSide(color: scheme.outline);
          }),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return scheme.primary.withValues(alpha: 0.12);
            }
            if (states.contains(WidgetState.hovered)) {
              return scheme.primary.withValues(alpha: 0.08);
            }
            if (states.contains(WidgetState.focused)) {
              return scheme.primary.withValues(alpha: 0.10);
            }
            return null;
          }),
        ),
      ),
      // Material 3 January 2026: Text buttons with state layers
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return scheme.primary.withValues(alpha: 0.12);
            }
            if (states.contains(WidgetState.hovered)) {
              return scheme.primary.withValues(alpha: 0.08);
            }
            if (states.contains(WidgetState.focused)) {
              return scheme.primary.withValues(alpha: 0.10);
            }
            return null;
          }),
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
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primaryContainer,
        labelStyle: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        secondaryLabelStyle: TextStyle(
          fontSize: 13,
          color: scheme.onPrimaryContainer,
        ),
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 18),
      ),
      // Material 3 PopupMenu styling
      popupMenuTheme: PopupMenuThemeData(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: scheme.surfaceContainer,
      ),
      // Material 3 Dialog styling
      dialogTheme: DialogThemeData(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: scheme.surfaceContainerHigh,
      ),
      // Bottom sheet styling
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      // Navigation bar styling (Android 14+ feel)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: scheme.onPrimaryContainer);
          }
          return IconThemeData(color: scheme.onSurfaceVariant);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            );
          }
          return TextStyle(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          );
        }),
      ),
      // Icon button styling for three-dot menus
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          iconSize: 20,
        ),
      ),
      // Modern circular checkboxes
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: scheme.outline, width: 2),
      ),
    );
  }

  /// Creates a monochromatic light color scheme with black accents
  static ColorScheme _createMonochromaticLightScheme() {
    return const ColorScheme.light(
      primary: Colors.black,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFE0E0E0),
      onPrimaryContainer: Colors.black,
      secondary: Colors.black87,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFF5F5F5),
      onSecondaryContainer: Colors.black87,
      tertiary: Colors.black54,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFF0F0F0),
      onTertiaryContainer: Colors.black54,
      error: Color(0xFFBA1A1A),
      onError: Colors.white,
      surface: Color(0xFFFFFBFE),
      onSurface: Colors.black,
      surfaceContainerHighest: Color(0xFFE6E0E9),
      onSurfaceVariant: Color(0xFF49454F),
      outline: Color(0xFF79747E),
    );
  }

  /// Creates a monochromatic dark color scheme with white accents
  static ColorScheme _createMonochromaticDarkScheme() {
    return const ColorScheme.dark(
      primary: Colors.white,
      onPrimary: Colors.black,
      primaryContainer: Color(0xFF424242),
      onPrimaryContainer: Colors.white,
      secondary: Color(0xFFE6E0E9),
      onSecondary: Color(0xFF1D1B20),
      secondaryContainer: Color(0xFF303030),
      onSecondaryContainer: Color(0xFFE6E0E9),
      tertiary: Color(0xFFCAC4D0),
      onTertiary: Color(0xFF322F35),
      tertiaryContainer: Color(0xFF484848),
      onTertiaryContainer: Color(0xFFCAC4D0),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      surface: Color(0xFF1D1B20),
      onSurface: Colors.white,
      surfaceContainerHighest: Color(0xFF49454F),
      onSurfaceVariant: Color(0xFFCAC4D0),
      outline: Color(0xFF938F99),
    );
  }

  /// Creates a grey light color scheme with grey accents
  static ColorScheme _createGreyLightScheme() {
    return const ColorScheme.light(
      primary: Color(0xFF616161),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFE0E0E0),
      onPrimaryContainer: Color(0xFF424242),
      secondary: Color(0xFF757575),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFF5F5F5),
      onSecondaryContainer: Color(0xFF616161),
      tertiary: Color(0xFF9E9E9E),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFEEEEEE),
      onTertiaryContainer: Color(0xFF757575),
      error: Color(0xFFBA1A1A),
      onError: Colors.white,
      surface: Color(0xFFFFFBFE),
      onSurface: Color(0xFF424242),
      surfaceContainerHighest: Color(0xFFE0E0E0),
      onSurfaceVariant: Color(0xFF616161),
      outline: Color(0xFF9E9E9E),
    );
  }

  /// Creates a grey dark color scheme with grey accents
  static ColorScheme _createGreyDarkScheme() {
    return const ColorScheme.dark(
      primary: Color(0xFFBDBDBD),
      onPrimary: Color(0xFF212121),
      primaryContainer: Color(0xFF616161),
      onPrimaryContainer: Color(0xFFE0E0E0),
      secondary: Color(0xFF9E9E9E),
      onSecondary: Color(0xFF303030),
      secondaryContainer: Color(0xFF424242),
      onSecondaryContainer: Color(0xFFBDBDBD),
      tertiary: Color(0xFF757575),
      onTertiary: Color(0xFF424242),
      tertiaryContainer: Color(0xFF484848),
      onTertiaryContainer: Color(0xFF9E9E9E),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      surface: Color(0xFF212121),
      onSurface: Color(0xFFE0E0E0),
      surfaceContainerHighest: Color(0xFF424242),
      onSurfaceVariant: Color(0xFFBDBDBD),
      outline: Color(0xFF757575),
    );
  }

  /// Creates a hack dark color scheme with Matrix green accents and terminal feel
  static ColorScheme _createHackDarkScheme() {
    return const ColorScheme.dark(
      primary: Color(0xFF00FF00), // Bright Matrix green for dark mode
      onPrimary: Color(0xFF000000),
      primaryContainer: Color(0xFF005500), // Dark green container
      onPrimaryContainer: Color(0xFF80FF80),
      secondary: Color(0xFF00CC00),
      onSecondary: Color(0xFF000000),
      secondaryContainer: Color(0xFF004400),
      onSecondaryContainer: Color(0xFF66FF66),
      tertiary: Color(0xFF00AA00),
      onTertiary: Color(0xFF000000),
      tertiaryContainer: Color(0xFF003300),
      onTertiaryContainer: Color(0xFF4DFF4D),
      error: Color(0xFFFF4444), // Bright red for terminal errors
      onError: Color(0xFF000000),
      surface: Color(0xFF0A0A0A), // Very dark surface (terminal-like)
      onSurface: Color(0xFF00FF00), // Green text on dark
      surfaceContainerHighest: Color(0xFF001100), // Very dark green
      onSurfaceVariant: Color(0xFF00CC00), // Medium green for secondary text
      outline: Color(0xFF007700),
    );
  }

  /// Creates a hack light scheme (for Matrix theme light mode fallback)
  static ColorScheme _createHackLightScheme() {
    return const ColorScheme.light(
      primary: Color(0xFF006600), // Dark green for light mode
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFF80FF80), // Light green container
      onPrimaryContainer: Color(0xFF003300),
      secondary: Color(0xFF005500),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFF99FF99),
      onSecondaryContainer: Color(0xFF002200),
      tertiary: Color(0xFF004400),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFB3FFB3),
      onTertiaryContainer: Color(0xFF001100),
      error: Color(0xFFCC0000), // Dark red for light mode errors
      onError: Color(0xFFFFFFFF),
      surface: Color(0xFFF8F8F8), // Light surface
      onSurface: Color(0xFF006600), // Dark green text on light
      surfaceContainerHighest: Color(0xFFE8F5E8), // Light green tint
      onSurfaceVariant: Color(
        0xFF005500,
      ), // Medium dark green for secondary text
      outline: Color(0xFF007700),
    );
  }

  /// Creates a Dracula dark color scheme with authentic Dracula colors and deep dark background
  static ColorScheme _createDraculaDarkScheme() {
    return const ColorScheme.dark(
      primary: Color(0xFFBD93F9), // Dracula Purple
      onPrimary: Color(0xFF1A1A1A), // Even darker for contrast
      primaryContainer: Color(0xFF44475A), // Dracula Selection
      onPrimaryContainer: Color(0xFFBD93F9),
      secondary: Color(0xFFFF79C6), // Dracula Pink
      onSecondary: Color(0xFF1A1A1A),
      secondaryContainer: Color(0xFF44475A),
      onSecondaryContainer: Color(0xFFFF79C6),
      tertiary: Color(0xFF8BE9FD), // Dracula Cyan
      onTertiary: Color(0xFF1A1A1A),
      tertiaryContainer: Color(0xFF44475A),
      onTertiaryContainer: Color(0xFF8BE9FD),
      error: Color(0xFFFF5555), // Dracula Red
      onError: Color(0xFF1A1A1A),
      surface: Color(0xFF1A1A1A), // Very dark surface (similar to hack theme)
      onSurface: Color(0xFFF8F8F2), // Dracula Foreground
      surfaceContainerHighest: Color(
        0xFF282A36,
      ), // Dracula Background as container
      onSurfaceVariant: Color(0xFF6272A4), // Dracula Comment
      outline: Color(0xFF6272A4), // Dracula Comment
    );
  }

  /// Creates a Dracula light scheme (fallback for light mode)
  static ColorScheme _createDraculaLightScheme() {
    return const ColorScheme.light(
      primary: Color(0xFF6B46C1), // Darker purple for light mode
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFE9D5FF), // Light purple container
      onPrimaryContainer: Color(0xFF4C1D95),
      secondary: Color(0xFFD946EF), // Adjusted pink for light mode
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFFDF2FF),
      onSecondaryContainer: Color(0xFF86198F),
      tertiary: Color(0xFF0891B2), // Adjusted cyan for light mode
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFE0F2FE),
      onTertiaryContainer: Color(0xFF0C4A6E),
      error: Color(0xFFDC2626), // Adjusted red for light mode
      onError: Color(0xFFFFFFFF),
      surface: Color(0xFFFAFAFA), // Light surface
      onSurface: Color(0xFF1F2937), // Dark text on light
      surfaceContainerHighest: Color(0xFFF3F4F6), // Light grey container
      onSurfaceVariant: Color(0xFF6B7280), // Medium grey for secondary text
      outline: Color(0xFF9CA3AF), // Light grey outline
    );
  }

  /// Creates a Solarized light color scheme with authentic Solarized colors
  /// Based on https://github.com/altercation/solarized
  static ColorScheme _createSolarizedLightScheme() {
    return const ColorScheme.light(
      primary: Color(0xFF268BD2), // Solarized Blue
      onPrimary: Color(0xFFFDF6E3), // base3 (light background)
      primaryContainer: Color(0xFFEEE8D5), // base2
      onPrimaryContainer: Color(0xFF586E75), // base01
      secondary: Color(0xFF2AA198), // Solarized Cyan
      onSecondary: Color(0xFFFDF6E3), // base3
      secondaryContainer: Color(0xFFEEE8D5), // base2
      onSecondaryContainer: Color(0xFF586E75), // base01
      tertiary: Color(0xFF859900), // Solarized Green
      onTertiary: Color(0xFFFDF6E3), // base3
      tertiaryContainer: Color(0xFFEEE8D5), // base2
      onTertiaryContainer: Color(0xFF586E75), // base01
      error: Color(0xFFDC322F), // Solarized Red
      onError: Color(0xFFFDF6E3), // base3
      surface: Color(0xFFFDF6E3), // base3 (light background)
      onSurface: Color(0xFF657B83), // base00 (emphasized content)
      surfaceContainerHighest: Color(
        0xFFEEE8D5,
      ), // base2 (background highlights)
      onSurfaceVariant: Color(
        0xFF586E75,
      ), // base01 (optional emphasized content)
      outline: Color(0xFF93A1A1), // base1 (comments / secondary content)
    );
  }

  /// Creates a Solarized dark color scheme with authentic Solarized colors
  /// Based on https://github.com/altercation/solarized
  static ColorScheme _createSolarizedDarkScheme() {
    return const ColorScheme.dark(
      primary: Color(0xFF268BD2), // Solarized Blue
      onPrimary: Color(0xFF002B36), // base03 (dark background)
      primaryContainer: Color(0xFF073642), // base02
      onPrimaryContainer: Color(0xFF93A1A1), // base1
      secondary: Color(0xFF2AA198), // Solarized Cyan
      onSecondary: Color(0xFF002B36), // base03
      secondaryContainer: Color(0xFF073642), // base02
      onSecondaryContainer: Color(0xFF93A1A1), // base1
      tertiary: Color(0xFF859900), // Solarized Green
      onTertiary: Color(0xFF002B36), // base03
      tertiaryContainer: Color(0xFF073642), // base02
      onTertiaryContainer: Color(0xFF93A1A1), // base1
      error: Color(0xFFDC322F), // Solarized Red
      onError: Color(0xFF002B36), // base03
      surface: Color(0xFF002B36), // base03 (dark background)
      onSurface: Color(0xFF839496), // base0 (emphasized content)
      surfaceContainerHighest: Color(
        0xFF073642,
      ), // base02 (background highlights)
      onSurfaceVariant: Color(
        0xFF93A1A1,
      ), // base1 (optional emphasized content)
      outline: Color(0xFF586E75), // base01 (comments / secondary content)
    );
  }

  /// Build current light/dark themes (dynamic aware) given optional dynamic schemes.
  static (ThemeData light, ThemeData dark) buildThemes({
    ColorScheme? dynamicLight,
    ColorScheme? dynamicDark,
    Color? accentColorSeed,
    String? fontFamily,
    bool compact = false,
    bool highContrast = false,
    String contrastLevel = 'standard',
    ColorScheme? customLightScheme,
    ColorScheme? customDarkScheme,
  }) {
    ThemeData light;
    ThemeData dark;

    final seedColor = accentColorSeed ?? const Color(0xFF6750A4);

    if (customLightScheme != null && customDarkScheme != null) {
      light = _baseLight(customLightScheme, fontFamily);
      dark = _baseDark(customDarkScheme, fontFamily);
    }
    // Special handling for Monochrome - black/white accents
    else if (seedColor.toARGB32() == 0xFF9E9E9E) {
      final monoLight = _createMonochromaticLightScheme();
      final monoDark = _createMonochromaticDarkScheme();
      light = _baseLight(dynamicLight ?? monoLight, fontFamily);
      dark = _baseDark(
        dynamicDark != null
            ? _enhanceDarkExpressiveness(dynamicDark)
            : monoDark,
        fontFamily,
      );
    }
    // Special handling for Grey - grey accents
    else if (seedColor.toARGB32() == 0xFF757575) {
      final greyLight = _createGreyLightScheme();
      final greyDark = _createGreyDarkScheme();
      light = _baseLight(dynamicLight ?? greyLight, fontFamily);
      dark = _baseDark(
        dynamicDark != null
            ? _enhanceDarkExpressiveness(dynamicDark)
            : greyDark,
        fontFamily,
      );
    }
    // Special handling for Hack - Matrix green terminal theme
    else if (seedColor.toARGB32() == 0xFF00FF00) {
      final hackLight = _createHackLightScheme();
      final hackDark = _createHackDarkScheme();
      light = _baseLight(dynamicLight ?? hackLight, fontFamily);
      dark = _baseDark(
        dynamicDark != null
            ? _enhanceDarkExpressiveness(dynamicDark)
            : hackDark,
        fontFamily,
      );
    }
    // Special handling for Dracula - authentic Dracula colors
    else if (seedColor.toARGB32() == 0xFFBD93F9) {
      final draculaLight = _createDraculaLightScheme();
      final draculaDark = _createDraculaDarkScheme();
      // Use proper light/dark schemes with matching brightness
      light = _baseLight(dynamicLight ?? draculaLight, fontFamily);
      dark = _baseDark(
        dynamicDark != null
            ? _enhanceDarkExpressiveness(dynamicDark)
            : draculaDark,
        fontFamily,
      );
    }
    // Special handling for Solarized - create authentic Solarized color scheme
    else if (seedColor.toARGB32() == 0xFF268BD2) {
      final solarizedLight = _createSolarizedLightScheme();
      final solarizedDark = _createSolarizedDarkScheme();
      // Use proper light/dark schemes with matching brightness
      light = _baseLight(dynamicLight ?? solarizedLight, fontFamily);
      dark = _baseDark(
        dynamicDark != null
            ? _enhanceDarkExpressiveness(dynamicDark)
            : solarizedDark,
        fontFamily,
      );
    } else {
      // Use normal Material 3 color generation for other colors
      final seedLight = ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      );
      final seedDark = ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      );
      // Boost dark mode contrast by adjusting surface colors
      final enhancedDark = _enhanceDarkExpressiveness(seedDark);
      light = _baseLight(dynamicLight ?? seedLight, fontFamily);
      dark = _baseDark(
        dynamicDark != null
            ? _enhanceDarkExpressiveness(dynamicDark)
            : enhancedDark,
        fontFamily,
      );
    }

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
            borderRadius: BorderRadius.circular(14),
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
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }

    // Special handling for Dracula theme - use pink (secondary) color for chip labels
    if (seedColor.toARGB32() == 0xFFBD93F9) {
      dark = dark.copyWith(
        chipTheme: dark.chipTheme.copyWith(
          labelStyle: TextStyle(
            fontSize: 12,
            color: dark.colorScheme.secondary, // Use Dracula Pink
          ),
          iconTheme: IconThemeData(color: dark.colorScheme.secondary, size: 18),
        ),
      );
    }

    // Apply contrast level adjustments (Material 3 January 2026)
    // This is separate from the legacy highContrast boolean for backwards compatibility
    if (contrastLevel == 'medium' || contrastLevel == 'high') {
      final isHighContrast = contrastLevel == 'high';
      // Increase adjustments to be clearly visible (25% for medium, 40% for high)
      final adjustment = isHighContrast ? 0.40 : 0.25;

      ColorScheme adjustContrastLight(ColorScheme cs) {
        return cs.copyWith(
          // P1: Full adjustment - primary text & structure
          onSurface: _darken(cs.onSurface, adjustment),
          onSurfaceVariant: _darken(cs.onSurfaceVariant, adjustment),
          outline: _darken(cs.outline, adjustment),

          // P2: Increased from 0.5x - primary & secondary actions
          primary: _darken(cs.primary, adjustment),
          secondary: _darken(cs.secondary, adjustment * 0.75),
          tertiary: _darken(cs.tertiary, adjustment * 0.75),
          outlineVariant: _darken(cs.outlineVariant, adjustment * 0.75),

          // P3: Full adjustment - error & action text
          error: _darken(cs.error, adjustment),
          // Conservative adjustment for onContainer tokens to maintain legibility
          onError: _darken(cs.onError, adjustment * 0.5),
          onPrimary: _darken(cs.onPrimary, adjustment * 0.5),
          onSecondary: _darken(cs.onSecondary, adjustment * 0.5),
          onTertiary: _darken(cs.onTertiary, adjustment * 0.5),
        );
      }

      ColorScheme adjustContrastDark(ColorScheme cs) {
        return cs.copyWith(
          // P1: Full adjustment - primary text & structure
          onSurface: _lighten(cs.onSurface, adjustment),
          onSurfaceVariant: _lighten(cs.onSurfaceVariant, adjustment),
          outline: _lighten(cs.outline, adjustment),

          // P2: Increased from 0.5x - primary & secondary actions
          primary: _lighten(cs.primary, adjustment),
          secondary: _lighten(cs.secondary, adjustment * 0.75),
          tertiary: _lighten(cs.tertiary, adjustment * 0.75),
          outlineVariant: _lighten(cs.outlineVariant, adjustment * 0.75),

          // P3: Full adjustment - error & action text
          error: _lighten(cs.error, adjustment),
          // Conservative adjustment for onContainer tokens to maintain legibility
          onError: _lighten(cs.onError, adjustment * 0.5),
          onPrimary: _lighten(cs.onPrimary, adjustment * 0.5),
          onSecondary: _lighten(cs.onSecondary, adjustment * 0.5),
          onTertiary: _lighten(cs.onTertiary, adjustment * 0.5),
        );
      }

      light = light.copyWith(
        colorScheme: adjustContrastLight(light.colorScheme),
      );
      dark = dark.copyWith(colorScheme: adjustContrastDark(dark.colorScheme));
    }

    // Legacy highContrast boolean handling (maintained for backwards compatibility)
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
    final appOpts = AppOptions(
      compact: compact,
      highContrast: highContrast,
      contrastLevel: contrastLevel,
    );
    light = light.copyWith(extensions: [...light.extensions.values, appOpts]);
    dark = dark.copyWith(extensions: [...dark.extensions.values, appOpts]);
    return (light, dark);
  }

  /// Derive a true AMOLED-black variant of a dark theme with hue-tinted surfaces.
  ///
  /// Instead of flat grey, surface containers inherit the hue from the accent
  /// color with decreasing saturation as lightness rises — giving an expressive
  /// look that still saves power on OLED panels.
  static ThemeData blackify(ThemeData darkBase) {
    final cs = darkBase.colorScheme;

    // Build a tinted near-black from the scheme's primary hue.
    Color tintedBlack(Color source, double lightness, double satScale) {
      final hsl = HSLColor.fromColor(source);
      return HSLColor.fromAHSL(
        1.0,
        hsl.hue,
        (hsl.saturation * satScale).clamp(0.0, 1.0),
        lightness,
      ).toColor();
    }

    final primary = cs.primary;
    final newScheme = cs.copyWith(
      surface: Colors.black,
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: tintedBlack(primary, 0.06, 0.65),
      surfaceContainer: tintedBlack(primary, 0.10, 0.65),
      surfaceContainerHigh: tintedBlack(primary, 0.13, 0.60),
      surfaceContainerHighest: tintedBlack(primary, 0.17, 0.55),
      outline: _darken(cs.outline, 0.35),
      outlineVariant: _darken(cs.outlineVariant, 0.45),
    );

    return darkBase.copyWith(
      colorScheme: newScheme,
      scaffoldBackgroundColor: Colors.black,
      canvasColor: Colors.black,
      cardColor: newScheme.surfaceContainerLow,
      appBarTheme: darkBase.appBarTheme.copyWith(backgroundColor: Colors.black),
      navigationBarTheme: darkBase.navigationBarTheme.copyWith(
        backgroundColor: newScheme.surfaceContainer,
      ),
      cardTheme: darkBase.cardTheme.copyWith(
        color: newScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide.none,
        ),
      ),
      chipTheme: darkBase.chipTheme.copyWith(
        side: BorderSide(color: newScheme.outline.withValues(alpha: 0.25)),
      ),
      dialogTheme: darkBase.dialogTheme.copyWith(
        backgroundColor: newScheme.surfaceContainerHigh,
      ),
      bottomSheetTheme: darkBase.bottomSheetTheme.copyWith(
        backgroundColor: newScheme.surfaceContainer,
      ),
      popupMenuTheme: darkBase.popupMenuTheme.copyWith(
        color: newScheme.surfaceContainer,
      ),
      inputDecorationTheme: darkBase.inputDecorationTheme.copyWith(
        fillColor: newScheme.surfaceContainerHighest,
      ),
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
  final String
  contrastLevel; // Material 3 January 2026: standard | medium | high

  const AppOptions({
    required this.compact,
    required this.highContrast,
    this.contrastLevel = 'standard',
  });

  @override
  ThemeExtension<AppOptions> copyWith({
    bool? compact,
    bool? highContrast,
    String? contrastLevel,
  }) {
    return AppOptions(
      compact: compact ?? this.compact,
      highContrast: highContrast ?? this.highContrast,
      contrastLevel: contrastLevel ?? this.contrastLevel,
    );
  }

  @override
  ThemeExtension<AppOptions> lerp(ThemeExtension<AppOptions>? other, double t) {
    if (other is! AppOptions) return this;
    // Bool flags snap based on t > 0.5
    return AppOptions(
      compact: t < 0.5 ? compact : other.compact,
      highContrast: t < 0.5 ? highContrast : other.highContrast,
      contrastLevel: t < 0.5 ? contrastLevel : other.contrastLevel,
    );
  }

  /// Check if using medium or high contrast
  bool get isEnhancedContrast =>
      contrastLevel == 'medium' || contrastLevel == 'high';

  /// Check if using high contrast specifically
  bool get isMaxContrast => contrastLevel == 'high';
}
