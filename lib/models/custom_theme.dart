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
  // Color Role Definitions
  // ============================================================================

  /// Essential color roles shown in Normal mode (10 roles per brightness)
  static const List<ColorRoleInfo> essentialRoles = [
    ColorRoleInfo(
      'primary',
      'Primary',
      'Main accent color used for key UI elements',
      Icons.palette,
    ),
    ColorRoleInfo(
      'secondary',
      'Secondary',
      'Supporting accent for less prominent elements',
      Icons.color_lens,
    ),
    ColorRoleInfo(
      'tertiary',
      'Tertiary',
      'Complementary accent for balance',
      Icons.brush,
    ),
    ColorRoleInfo(
      'error',
      'Error',
      'Color for error states and destructive actions',
      Icons.error_outline,
    ),
    ColorRoleInfo(
      'surface',
      'Surface',
      'Background for cards, sheets, and menus',
      Icons.layers,
    ),
    ColorRoleInfo(
      'onPrimary',
      'On Primary',
      'Text/icons on primary-colored backgrounds',
      Icons.text_fields,
    ),
    ColorRoleInfo(
      'onSecondary',
      'On Secondary',
      'Text/icons on secondary-colored backgrounds',
      Icons.text_fields,
    ),
    ColorRoleInfo(
      'onSurface',
      'On Surface',
      'Primary text and icon color',
      Icons.format_color_text,
    ),
    ColorRoleInfo(
      'onSurfaceVariant',
      'On Surface Variant',
      'Secondary text color',
      Icons.format_color_text,
    ),
    ColorRoleInfo(
      'outline',
      'Outline',
      'Borders and dividers',
      Icons.border_style,
    ),
  ];

  /// Advanced color role sections
  static const List<ColorRoleSection> advancedSections = [
    ColorRoleSection('Primary Colors', [
      ColorRoleInfo('primary', 'Primary', 'Main accent', Icons.palette),
      ColorRoleInfo(
        'onPrimary',
        'On Primary',
        'Content on primary',
        Icons.text_fields,
      ),
      ColorRoleInfo(
        'primaryContainer',
        'Primary Container',
        'Less prominent primary areas',
        Icons.crop_square,
      ),
      ColorRoleInfo(
        'onPrimaryContainer',
        'On Primary Container',
        'Content on primary container',
        Icons.text_fields,
      ),
      ColorRoleInfo(
        'primaryFixed',
        'Primary Fixed',
        'Fixed primary tone',
        Icons.lock,
      ),
      ColorRoleInfo(
        'primaryFixedDim',
        'Primary Fixed Dim',
        'Dimmed fixed primary',
        Icons.lock_outline,
      ),
      ColorRoleInfo(
        'onPrimaryFixed',
        'On Primary Fixed',
        'Content on fixed primary',
        Icons.text_fields,
      ),
      ColorRoleInfo(
        'onPrimaryFixedVariant',
        'On Primary Fixed Variant',
        'Variant content on fixed primary',
        Icons.text_fields,
      ),
    ]),
    ColorRoleSection('Secondary Colors', [
      ColorRoleInfo(
        'secondary',
        'Secondary',
        'Supporting accent',
        Icons.color_lens,
      ),
      ColorRoleInfo(
        'onSecondary',
        'On Secondary',
        'Content on secondary',
        Icons.text_fields,
      ),
      ColorRoleInfo(
        'secondaryContainer',
        'Secondary Container',
        'Less prominent secondary areas',
        Icons.crop_square,
      ),
      ColorRoleInfo(
        'onSecondaryContainer',
        'On Secondary Container',
        'Content on secondary container',
        Icons.text_fields,
      ),
      ColorRoleInfo(
        'secondaryFixed',
        'Secondary Fixed',
        'Fixed secondary tone',
        Icons.lock,
      ),
      ColorRoleInfo(
        'secondaryFixedDim',
        'Secondary Fixed Dim',
        'Dimmed fixed secondary',
        Icons.lock_outline,
      ),
      ColorRoleInfo(
        'onSecondaryFixed',
        'On Secondary Fixed',
        'Content on fixed secondary',
        Icons.text_fields,
      ),
      ColorRoleInfo(
        'onSecondaryFixedVariant',
        'On Secondary Fixed Variant',
        'Variant content on fixed secondary',
        Icons.text_fields,
      ),
    ]),
    ColorRoleSection('Tertiary Colors', [
      ColorRoleInfo(
        'tertiary',
        'Tertiary',
        'Complementary accent',
        Icons.brush,
      ),
      ColorRoleInfo(
        'onTertiary',
        'On Tertiary',
        'Content on tertiary',
        Icons.text_fields,
      ),
      ColorRoleInfo(
        'tertiaryContainer',
        'Tertiary Container',
        'Less prominent tertiary areas',
        Icons.crop_square,
      ),
      ColorRoleInfo(
        'onTertiaryContainer',
        'On Tertiary Container',
        'Content on tertiary container',
        Icons.text_fields,
      ),
      ColorRoleInfo(
        'tertiaryFixed',
        'Tertiary Fixed',
        'Fixed tertiary tone',
        Icons.lock,
      ),
      ColorRoleInfo(
        'tertiaryFixedDim',
        'Tertiary Fixed Dim',
        'Dimmed fixed tertiary',
        Icons.lock_outline,
      ),
      ColorRoleInfo(
        'onTertiaryFixed',
        'On Tertiary Fixed',
        'Content on fixed tertiary',
        Icons.text_fields,
      ),
      ColorRoleInfo(
        'onTertiaryFixedVariant',
        'On Tertiary Fixed Variant',
        'Variant content on fixed tertiary',
        Icons.text_fields,
      ),
    ]),
    ColorRoleSection('Error Colors', [
      ColorRoleInfo('error', 'Error', 'Error states', Icons.error_outline),
      ColorRoleInfo(
        'onError',
        'On Error',
        'Content on error',
        Icons.text_fields,
      ),
      ColorRoleInfo(
        'errorContainer',
        'Error Container',
        'Less prominent error areas',
        Icons.crop_square,
      ),
      ColorRoleInfo(
        'onErrorContainer',
        'On Error Container',
        'Content on error container',
        Icons.text_fields,
      ),
    ]),
    ColorRoleSection('Surface Colors', [
      ColorRoleInfo('surface', 'Surface', 'Main background', Icons.layers),
      ColorRoleInfo(
        'onSurface',
        'On Surface',
        'Primary text color',
        Icons.format_color_text,
      ),
      ColorRoleInfo(
        'onSurfaceVariant',
        'On Surface Variant',
        'Secondary text',
        Icons.format_color_text,
      ),
      ColorRoleInfo(
        'surfaceDim',
        'Surface Dim',
        'Dimmed surface',
        Icons.brightness_low,
      ),
      ColorRoleInfo(
        'surfaceBright',
        'Surface Bright',
        'Bright surface',
        Icons.brightness_high,
      ),
      ColorRoleInfo(
        'surfaceContainerLowest',
        'Container Lowest',
        'Lowest elevation surface',
        Icons.layers_outlined,
      ),
      ColorRoleInfo(
        'surfaceContainerLow',
        'Container Low',
        'Low elevation surface',
        Icons.layers_outlined,
      ),
      ColorRoleInfo(
        'surfaceContainer',
        'Container',
        'Medium elevation surface',
        Icons.layers,
      ),
      ColorRoleInfo(
        'surfaceContainerHigh',
        'Container High',
        'High elevation surface',
        Icons.layers,
      ),
      ColorRoleInfo(
        'surfaceContainerHighest',
        'Container Highest',
        'Highest elevation surface',
        Icons.layers,
      ),
      ColorRoleInfo(
        'surfaceTint',
        'Surface Tint',
        'Tint overlay on surfaces',
        Icons.opacity,
      ),
    ]),
    ColorRoleSection('Utility Colors', [
      ColorRoleInfo(
        'outline',
        'Outline',
        'Borders and dividers',
        Icons.border_style,
      ),
      ColorRoleInfo(
        'outlineVariant',
        'Outline Variant',
        'Subtle borders',
        Icons.border_style,
      ),
      ColorRoleInfo(
        'shadow',
        'Shadow',
        'Drop shadow color',
        Icons.filter_drama,
      ),
      ColorRoleInfo(
        'scrim',
        'Scrim',
        'Overlay behind sheets/dialogs',
        Icons.gradient,
      ),
      ColorRoleInfo(
        'inverseSurface',
        'Inverse Surface',
        'Snackbar/tooltip background',
        Icons.invert_colors,
      ),
      ColorRoleInfo(
        'onInverseSurface',
        'On Inverse Surface',
        'Content on inverse surface',
        Icons.text_fields,
      ),
      ColorRoleInfo(
        'inversePrimary',
        'Inverse Primary',
        'Primary on inverse surfaces',
        Icons.invert_colors,
      ),
    ]),
  ];

  /// All unique role keys across essential + advanced
  static List<String> get allRoleKeys {
    final keys = <String>{};
    for (final section in advancedSections) {
      for (final role in section.roles) {
        keys.add(role.key);
      }
    }
    return keys.toList();
  }

  // ============================================================================
  // ColorScheme Building
  // ============================================================================

  /// Build a ColorScheme for the given brightness, using user-set colors
  /// and auto-generating missing ones from the primary seed.
  ColorScheme buildColorScheme(Brightness brightness) {
    final colors = brightness == Brightness.light ? lightColors : darkColors;

    // Get seed color (primary or default blue)
    final seedColor = Color(colors['primary'] ?? 0xFF2196F3);

    // Generate base scheme from seed
    final baseScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    // Apply user overrides on top of auto-generated scheme
    return baseScheme.copyWith(
      primary: _getColor(colors, 'primary'),
      onPrimary: _getColor(colors, 'onPrimary'),
      primaryContainer: _getColor(colors, 'primaryContainer'),
      onPrimaryContainer: _getColor(colors, 'onPrimaryContainer'),
      primaryFixed: _getColor(colors, 'primaryFixed'),
      primaryFixedDim: _getColor(colors, 'primaryFixedDim'),
      onPrimaryFixed: _getColor(colors, 'onPrimaryFixed'),
      onPrimaryFixedVariant: _getColor(colors, 'onPrimaryFixedVariant'),
      secondary: _getColor(colors, 'secondary'),
      onSecondary: _getColor(colors, 'onSecondary'),
      secondaryContainer: _getColor(colors, 'secondaryContainer'),
      onSecondaryContainer: _getColor(colors, 'onSecondaryContainer'),
      secondaryFixed: _getColor(colors, 'secondaryFixed'),
      secondaryFixedDim: _getColor(colors, 'secondaryFixedDim'),
      onSecondaryFixed: _getColor(colors, 'onSecondaryFixed'),
      onSecondaryFixedVariant: _getColor(colors, 'onSecondaryFixedVariant'),
      tertiary: _getColor(colors, 'tertiary'),
      onTertiary: _getColor(colors, 'onTertiary'),
      tertiaryContainer: _getColor(colors, 'tertiaryContainer'),
      onTertiaryContainer: _getColor(colors, 'onTertiaryContainer'),
      tertiaryFixed: _getColor(colors, 'tertiaryFixed'),
      tertiaryFixedDim: _getColor(colors, 'tertiaryFixedDim'),
      onTertiaryFixed: _getColor(colors, 'onTertiaryFixed'),
      onTertiaryFixedVariant: _getColor(colors, 'onTertiaryFixedVariant'),
      error: _getColor(colors, 'error'),
      onError: _getColor(colors, 'onError'),
      errorContainer: _getColor(colors, 'errorContainer'),
      onErrorContainer: _getColor(colors, 'onErrorContainer'),
      surface: _getColor(colors, 'surface'),
      onSurface: _getColor(colors, 'onSurface'),
      onSurfaceVariant: _getColor(colors, 'onSurfaceVariant'),
      surfaceDim: _getColor(colors, 'surfaceDim'),
      surfaceBright: _getColor(colors, 'surfaceBright'),
      surfaceContainerLowest: _getColor(colors, 'surfaceContainerLowest'),
      surfaceContainerLow: _getColor(colors, 'surfaceContainerLow'),
      surfaceContainer: _getColor(colors, 'surfaceContainer'),
      surfaceContainerHigh: _getColor(colors, 'surfaceContainerHigh'),
      surfaceContainerHighest: _getColor(colors, 'surfaceContainerHighest'),
      surfaceTint: _getColor(colors, 'surfaceTint'),
      outline: _getColor(colors, 'outline'),
      outlineVariant: _getColor(colors, 'outlineVariant'),
      shadow: _getColor(colors, 'shadow'),
      scrim: _getColor(colors, 'scrim'),
      inverseSurface: _getColor(colors, 'inverseSurface'),
      onInverseSurface: _getColor(colors, 'onInverseSurface'),
      inversePrimary: _getColor(colors, 'inversePrimary'),
    );
  }

  /// Helper: returns Color if key exists in map, null otherwise
  Color? _getColor(Map<String, int> colors, String key) {
    final value = colors[key];
    return value != null ? Color(value) : null;
  }

  /// Get color for a specific role in a specific brightness, resolving
  /// to the auto-generated value if not explicitly set.
  Color getResolvedColor(String roleKey, Brightness brightness) {
    final colors = brightness == Brightness.light ? lightColors : darkColors;
    if (colors.containsKey(roleKey)) {
      return Color(colors[roleKey]!);
    }
    // Generate from seed and return the corresponding role value
    final scheme = buildColorScheme(brightness);
    return _getSchemeColor(scheme, roleKey);
  }

  /// Whether a color role has been explicitly set by the user
  bool isColorCustomized(String roleKey, Brightness brightness) {
    final colors = brightness == Brightness.light ? lightColors : darkColors;
    return colors.containsKey(roleKey);
  }

  /// Set a color for a specific role
  void setColor(String roleKey, Color color, Brightness brightness) {
    final colors = brightness == Brightness.light ? lightColors : darkColors;
    colors[roleKey] = color.value;
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
      if (json is! Map<String, dynamic>)
        return 'Invalid format: expected JSON object';
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
  final List<ColorRoleInfo> roles;

  const ColorRoleSection(this.title, this.roles);
}
