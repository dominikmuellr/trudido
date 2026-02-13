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

import 'dart:convert';
import 'package:flutter/material.dart';

/// Represents a user-created custom theme with full Material 3 color roles.
///
/// Users can customize all 48 Material 3 ColorScheme roles for both light
/// and dark modes. Colors that are not explicitly set will be auto-generated
/// from the primary seed color using Material 3 tonal palette rules.
class CustomTheme {
  /// Unique identifier for this theme
  final String id;

  /// User-facing name for this theme
  String name;

  /// Version for future-proofing the JSON format
  static const int formatVersion = 1;

  /// Light mode color overrides (role name -> color value as int)
  /// Only stores colors explicitly set by the user.
  /// Missing roles are auto-generated from the seed colors.
  final Map<String, int> lightColors;

  /// Dark mode color overrides (role name -> color value as int)
  final Map<String, int> darkColors;

  /// Optional font family override
  String? fontFamily;

  /// Creation timestamp (ISO 8601)
  final String createdAt;

  /// Last modification timestamp (ISO 8601)
  String modifiedAt;

  CustomTheme({
    required this.id,
    required this.name,
    Map<String, int>? lightColors,
    Map<String, int>? darkColors,
    this.fontFamily,
    String? createdAt,
    String? modifiedAt,
  }) : lightColors = lightColors ?? {},
       darkColors = darkColors ?? {},
       createdAt = createdAt ?? DateTime.now().toIso8601String(),
       modifiedAt = modifiedAt ?? DateTime.now().toIso8601String();

  /// Creates a copy of this theme with a new id and name
  CustomTheme duplicate({required String newId, required String newName}) {
    return CustomTheme(
      id: newId,
      name: newName,
      lightColors: Map<String, int>.from(lightColors),
      darkColors: Map<String, int>.from(darkColors),
      fontFamily: fontFamily,
    );
  }

  // ============================================================================
  // Color Role Definitions - Simplified
  // ============================================================================

  /// Simple color roles - just the essentials
  static const List<ColorRoleSection> colorSections = [
    ColorRoleSection(
      'Theme Colors',
      'Each color creates its own palette throughout the app',
      [
        ColorRoleInfo(
          'primary',
          'Essential',
          'Main buttons, app bars, FABs, and active elements',
          Icons.palette,
        ),
        ColorRoleInfo(
          'secondary',
          'Enhanced',
          'Secondary buttons, switches, sliders, and selections',
          Icons.brush,
        ),
      ],
    ),
  ];

  /// All unique role keys across all sections
  static List<String> get allRoleKeys {
    final keys = <String>{};
    for (final section in colorSections) {
      for (final role in section.roles) {
        keys.add(role.key);
      }
    }
    return keys.toList();
  }

  // ============================================================================
  // ColorScheme Building
  // ============================================================================

  /// Build a ColorScheme using Material You's expressive color system.
  /// Takes up to 2 seed colors and generates a professional palette.
  ColorScheme buildColorScheme(Brightness brightness) {
    final colors = brightness == Brightness.light ? lightColors : darkColors;

    // Get user's colors or Material 3 baseline defaults
    final primaryColor = Color(colors['primary'] ?? 0xFF6750A4);
    final secondaryColor = Color(colors['secondary'] ?? 0xFF625B71);

    // Generate base scheme from primary
    final baseScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: brightness,
    );

    // Generate scheme from secondary for all non-primary colors
    final secondaryScheme = ColorScheme.fromSeed(
      seedColor: secondaryColor,
      brightness: brightness,
    );

    // Combine: use primary scheme as base, but take secondary colors from its
    // scheme to get proper containers and "on" colors
    return baseScheme.copyWith(
      // Secondary colors from secondary scheme
      secondary: secondaryScheme.primary,
      onSecondary: secondaryScheme.onPrimary,
      secondaryContainer: secondaryScheme.primaryContainer,
      onSecondaryContainer: secondaryScheme.onPrimaryContainer,

      // Tertiary colors mirror secondary to keep all accents aligned
      tertiary: secondaryScheme.primary,
      onTertiary: secondaryScheme.onPrimary,
      tertiaryContainer: secondaryScheme.primaryContainer,
      onTertiaryContainer: secondaryScheme.onPrimaryContainer,
    );
  }

  /// Get color for a specific role, always resolved through the Material You
  /// color scheme so the displayed color matches the actual app UI.
  Color getResolvedColor(String roleKey, Brightness brightness) {
    final scheme = buildColorScheme(brightness);
    return _getSchemeColor(scheme, roleKey);
  }

  /// Get the raw seed color stored for a role (before Material You processing).
  /// Use this for color picker selection matching, not for display.
  Color getSeedColor(String roleKey, Brightness brightness) {
    final colors = brightness == Brightness.light ? lightColors : darkColors;
    if (colors.containsKey(roleKey)) {
      return Color(colors[roleKey]!);
    }
    // Default Material 3 baseline seeds
    switch (roleKey) {
      case 'primary':
        return const Color(0xFF6750A4);
      case 'secondary':
        return const Color(0xFF625B71);
      case 'tertiary':
        return Color(colors['secondary'] ?? 0xFF625B71);
      default:
        final scheme = buildColorScheme(brightness);
        return _getSchemeColor(scheme, roleKey);
    }
  }

  /// Whether a color role has been explicitly set by the user
  bool isColorCustomized(String roleKey, Brightness brightness) {
    final colors = brightness == Brightness.light ? lightColors : darkColors;
    return colors.containsKey(roleKey);
  }

  /// Set a color for a specific role
  void setColor(String roleKey, Color color, Brightness brightness) {
    final colors = brightness == Brightness.light ? lightColors : darkColors;
    colors[roleKey] = color.toARGB32();
    modifiedAt = DateTime.now().toIso8601String();
  }

  /// Remove a custom color (revert to auto-generated)
  void resetColor(String roleKey, Brightness brightness) {
    final colors = brightness == Brightness.light ? lightColors : darkColors;
    colors.remove(roleKey);
    modifiedAt = DateTime.now().toIso8601String();
  }

  /// Reset all colors for a brightness
  void resetAll(Brightness brightness) {
    if (brightness == Brightness.light) {
      lightColors.clear();
    } else {
      darkColors.clear();
    }
    modifiedAt = DateTime.now().toIso8601String();
  }

  // ============================================================================
  // Serialization
  // ============================================================================

  /// Serialize to JSON map
  Map<String, dynamic> toJson() {
    return {
      'version': formatVersion,
      'id': id,
      'name': name,
      'lightColors': lightColors,
      'darkColors': darkColors,
      if (fontFamily != null) 'fontFamily': fontFamily,
      'createdAt': createdAt,
      'modifiedAt': modifiedAt,
    };
  }

  /// Serialize to JSON string (for export/sharing)
  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Deserialize from JSON map
  factory CustomTheme.fromJson(Map<String, dynamic> json) {
    return CustomTheme(
      id: json['id'] as String,
      name: json['name'] as String,
      lightColors:
          (json['lightColors'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as int),
          ) ??
          {},
      darkColors:
          (json['darkColors'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as int),
          ) ??
          {},
      fontFamily: json['fontFamily'] as String?,
      createdAt: json['createdAt'] as String?,
      modifiedAt: json['modifiedAt'] as String?,
    );
  }

  /// Deserialize from JSON string
  factory CustomTheme.fromJsonString(String jsonString) {
    return CustomTheme.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  /// Validate an imported JSON string. Returns null if valid, error message if not.
  static String? validateJson(String jsonString) {
    try {
      final json = jsonDecode(jsonString);
      if (json is! Map<String, dynamic>) {
        return 'Invalid format: expected JSON object';
      }
      if (json['id'] is! String) return 'Missing or invalid "id" field';
      if (json['name'] is! String) return 'Missing or invalid "name" field';
      // lightColors and darkColors are optional maps
      if (json['lightColors'] != null && json['lightColors'] is! Map) {
        return 'Invalid "lightColors" field';
      }
      if (json['darkColors'] != null && json['darkColors'] is! Map) {
        return 'Invalid "darkColors" field';
      }
      return null; // valid
    } catch (e) {
      return 'Invalid JSON: $e';
    }
  }

  // ============================================================================
  // Helpers
  // ============================================================================

  /// Get a color from a ColorScheme by role key name
  static Color _getSchemeColor(ColorScheme scheme, String key) {
    switch (key) {
      case 'primary':
        return scheme.primary;
      case 'onPrimary':
        return scheme.onPrimary;
      case 'primaryContainer':
        return scheme.primaryContainer;
      case 'onPrimaryContainer':
        return scheme.onPrimaryContainer;
      case 'primaryFixed':
        return scheme.primaryFixed;
      case 'primaryFixedDim':
        return scheme.primaryFixedDim;
      case 'onPrimaryFixed':
        return scheme.onPrimaryFixed;
      case 'onPrimaryFixedVariant':
        return scheme.onPrimaryFixedVariant;
      case 'secondary':
        return scheme.secondary;
      case 'onSecondary':
        return scheme.onSecondary;
      case 'secondaryContainer':
        return scheme.secondaryContainer;
      case 'onSecondaryContainer':
        return scheme.onSecondaryContainer;
      case 'secondaryFixed':
        return scheme.secondaryFixed;
      case 'secondaryFixedDim':
        return scheme.secondaryFixedDim;
      case 'onSecondaryFixed':
        return scheme.onSecondaryFixed;
      case 'onSecondaryFixedVariant':
        return scheme.onSecondaryFixedVariant;
      case 'tertiary':
        return scheme.tertiary;
      case 'onTertiary':
        return scheme.onTertiary;
      case 'tertiaryContainer':
        return scheme.tertiaryContainer;
      case 'onTertiaryContainer':
        return scheme.onTertiaryContainer;
      case 'tertiaryFixed':
        return scheme.tertiaryFixed;
      case 'tertiaryFixedDim':
        return scheme.tertiaryFixedDim;
      case 'onTertiaryFixed':
        return scheme.onTertiaryFixed;
      case 'onTertiaryFixedVariant':
        return scheme.onTertiaryFixedVariant;
      case 'error':
        return scheme.error;
      case 'onError':
        return scheme.onError;
      case 'errorContainer':
        return scheme.errorContainer;
      case 'onErrorContainer':
        return scheme.onErrorContainer;
      case 'surface':
        return scheme.surface;
      case 'onSurface':
        return scheme.onSurface;
      case 'onSurfaceVariant':
        return scheme.onSurfaceVariant;
      case 'surfaceDim':
        return scheme.surfaceDim;
      case 'surfaceBright':
        return scheme.surfaceBright;
      case 'surfaceContainerLowest':
        return scheme.surfaceContainerLowest;
      case 'surfaceContainerLow':
        return scheme.surfaceContainerLow;
      case 'surfaceContainer':
        return scheme.surfaceContainer;
      case 'surfaceContainerHigh':
        return scheme.surfaceContainerHigh;
      case 'surfaceContainerHighest':
        return scheme.surfaceContainerHighest;
      case 'surfaceTint':
        return scheme.surfaceTint;
      case 'outline':
        return scheme.outline;
      case 'outlineVariant':
        return scheme.outlineVariant;
      case 'shadow':
        return scheme.shadow;
      case 'scrim':
        return scheme.scrim;
      case 'inverseSurface':
        return scheme.inverseSurface;
      case 'onInverseSurface':
        return scheme.onInverseSurface;
      case 'inversePrimary':
        return scheme.inversePrimary;
      default:
        return scheme.primary;
    }
  }

  /// Calculate WCAG contrast ratio between two colors
  static double contrastRatio(Color foreground, Color background) {
    final fgLuminance = foreground.computeLuminance() + 0.05;
    final bgLuminance = background.computeLuminance() + 0.05;
    return fgLuminance > bgLuminance
        ? fgLuminance / bgLuminance
        : bgLuminance / fgLuminance;
  }

  /// Check if contrast ratio meets WCAG AA for normal text (4.5:1)
  static bool meetsContrastAA(Color foreground, Color background) {
    return contrastRatio(foreground, background) >= 4.5;
  }

  /// Check if a color is problematic (too close to pure white or black)
  static bool isProblematicColor(Color color, Brightness brightness) {
    final luminance = color.computeLuminance();
    if (brightness == Brightness.light) {
      // In light mode, colors too close to white are problematic
      return luminance > 0.95;
    } else {
      // In dark mode, colors too close to black are problematic
      return luminance < 0.05;
    }
  }

  /// Get a warning message for problematic colors
  static String? getColorWarning(Color color, Brightness brightness) {
    if (isProblematicColor(color, brightness)) {
      if (brightness == Brightness.light) {
        return 'This color is too close to white and may cause poor contrast in light mode';
      } else {
        return 'This color is too close to black and may cause poor contrast in dark mode';
      }
    }
    return null;
  }

  /// Generate an auto-name from the theme's colors
  String generateAutoName() {
    final colors = lightColors.isNotEmpty ? lightColors : darkColors;

    if (colors.isEmpty) {
      return 'Untitled Theme';
    }

    final names = <String>[];

    // Get color names for the 3 main colors
    if (colors.containsKey('primary')) {
      names.add(_getColorName(Color(colors['primary']!)));
    }
    if (colors.containsKey('secondary')) {
      names.add(_getColorName(Color(colors['secondary']!)));
    }
    if (colors.containsKey('tertiary')) {
      names.add(_getColorName(Color(colors['tertiary']!)));
    }

    if (names.isEmpty) {
      return 'Custom Theme';
    }

    // Create name from up to 3 colors
    if (names.length == 1) {
      return names[0];
    } else if (names.length == 2) {
      return '${names[0]} & ${names[1]}';
    } else {
      return '${names[0]}, ${names[1]} & ${names[2]}';
    }
  }

  /// Get a simple color name from a Color
  static String _getColorName(Color color) {
    final hue = HSLColor.fromColor(color).hue;
    final saturation = HSLColor.fromColor(color).saturation;
    final lightness = HSLColor.fromColor(color).lightness;

    // Low saturation = grayscale
    if (saturation < 0.15) {
      if (lightness > 0.85) return 'White';
      if (lightness > 0.6) return 'Silver';
      if (lightness > 0.4) return 'Gray';
      if (lightness > 0.2) return 'Charcoal';
      return 'Black';
    }

    // Determine hue name
    if (hue >= 0 && hue < 15) return 'Red';
    if (hue >= 15 && hue < 45) return 'Orange';
    if (hue >= 45 && hue < 70) return 'Yellow';
    if (hue >= 70 && hue < 150) return 'Green';
    if (hue >= 150 && hue < 200) return 'Cyan';
    if (hue >= 200 && hue < 260) return 'Blue';
    if (hue >= 260 && hue < 300) return 'Purple';
    if (hue >= 300 && hue < 330) return 'Magenta';
    if (hue >= 330) return 'Red';
    return 'Color';
  }
}

/// Describes a single color role with metadata for UI display
class ColorRoleInfo {
  final String key;
  final String label;
  final String description;
  final IconData icon;

  const ColorRoleInfo(this.key, this.label, this.description, this.icon);
}

/// Groups color roles into expandable sections for advanced mode
class ColorRoleSection {
  final String title;
  final String description;
  final List<ColorRoleInfo> roles;

  const ColorRoleSection(this.title, this.description, this.roles);
}
