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

import 'package:flutter/material.dart';

/// Material 3 January 2026 Contrast Levels
///
/// Three-level contrast system as per Material Design 3 August 2024 update.
/// - Standard: Default contrast for most users
/// - Medium: Enhanced contrast for improved readability
/// - High: Maximum contrast for accessibility needs
enum ContrastLevel {
  /// Default contrast level - standard Material 3 colors
  standard,

  /// Enhanced contrast - slightly increased color differences
  medium,

  /// Maximum contrast - highest color differences for accessibility
  high,
}

/// Extension methods for ContrastLevel
extension ContrastLevelExtension on ContrastLevel {
  /// Display name for UI
  String get displayName {
    switch (this) {
      case ContrastLevel.standard:
        return 'Standard';
      case ContrastLevel.medium:
        return 'Medium';
      case ContrastLevel.high:
        return 'High';
    }
  }

  /// Description for UI
  String get description {
    switch (this) {
      case ContrastLevel.standard:
        return 'Default contrast for most users';
      case ContrastLevel.medium:
        return 'Enhanced readability';
      case ContrastLevel.high:
        return 'Maximum contrast for accessibility';
    }
  }

  /// Icon for UI
  IconData get icon {
    switch (this) {
      case ContrastLevel.standard:
        return Icons.contrast;
      case ContrastLevel.medium:
        return Icons.contrast_outlined;
      case ContrastLevel.high:
        return Icons.accessibility_new;
    }
  }

  /// Convert to string for persistence
  String toStorageString() {
    switch (this) {
      case ContrastLevel.standard:
        return 'standard';
      case ContrastLevel.medium:
        return 'medium';
      case ContrastLevel.high:
        return 'high';
    }
  }

  /// Create from storage string
  static ContrastLevel fromStorageString(String? value) {
    switch (value) {
      case 'medium':
        return ContrastLevel.medium;
      case 'high':
        return ContrastLevel.high;
      case 'standard':
      default:
        return ContrastLevel.standard;
    }
  }
}

/// Material 3 tone values for surface colors (January 2026)
///
/// These are the exact token values from the Material Design 3 specification.
/// Surface tones are used to create visual hierarchy without relying on elevation.
class M3SurfaceTones {
  M3SurfaceTones._();

  // Light theme surface tones (exact Material 3 tokens)
  static const int surfaceLight = 98;
  static const int surfaceContainerLowestLight = 100;
  static const int surfaceContainerLowLight = 96;
  static const int surfaceContainerLight = 94;
  static const int surfaceContainerHighLight = 92;
  static const int surfaceContainerHighestLight = 90;

  // Dark theme surface tones (exact Material 3 tokens)
  static const int surfaceDark = 6;
  static const int surfaceContainerLowestDark = 4;
  static const int surfaceContainerLowDark = 10;
  static const int surfaceContainerDark = 12;
  static const int surfaceContainerHighDark = 17;
  static const int surfaceContainerHighestDark = 22;

  // On-surface tones
  static const int onSurfaceLight = 10;
  static const int onSurfaceDark = 90;
  static const int onSurfaceVariantLight = 30;
  static const int onSurfaceVariantDark = 80;

  // Outline tones
  static const int outlineLight = 50;
  static const int outlineDark = 60;
  static const int outlineVariantLight = 80;
  static const int outlineVariantDark = 30;
}

/// State layer opacities per Material 3 spec
///
/// State layers are semi-transparent overlays that indicate interaction states.
class M3StateLayerOpacity {
  M3StateLayerOpacity._();

  /// Hover state overlay opacity (8%)
  static const double hover = 0.08;

  /// Focus state overlay opacity (10%)
  static const double focus = 0.10;

  /// Pressed state overlay opacity (12%)
  static const double pressed = 0.12;

  /// Dragged state overlay opacity (16%)
  static const double dragged = 0.16;

  /// Disabled container opacity (12%)
  static const double disabledContainer = 0.12;

  /// Disabled content opacity (38%)
  static const double disabledContent = 0.38;
}

/// Contrast-adjusted color generation utilities
class ContrastColorUtils {
  ContrastColorUtils._();

  /// Adjust color based on contrast level
  ///
  /// For medium/high contrast, colors are adjusted to increase
  /// the difference between foreground and background.
  static Color adjustForContrast(
    Color color,
    ContrastLevel level,
    Brightness brightness,
  ) {
    switch (level) {
      case ContrastLevel.standard:
        return color;
      case ContrastLevel.medium:
        return _adjustMediumContrast(color, brightness);
      case ContrastLevel.high:
        return _adjustHighContrast(color, brightness);
    }
  }

  static Color _adjustMediumContrast(Color color, Brightness brightness) {
    final hsl = HSLColor.fromColor(color);
    if (brightness == Brightness.light) {
      // Darken colors in light mode
      return hsl.withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0)).toColor();
    } else {
      // Lighten colors in dark mode
      return hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0)).toColor();
    }
  }

  static Color _adjustHighContrast(Color color, Brightness brightness) {
    final hsl = HSLColor.fromColor(color);
    if (brightness == Brightness.light) {
      // Significantly darken colors in light mode
      return hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor();
    } else {
      // Significantly lighten colors in dark mode
      return hsl.withLightness((hsl.lightness + 0.2).clamp(0.0, 1.0)).toColor();
    }
  }

  /// Get on-surface color with proper contrast
  static Color getOnSurfaceColor(
    Color surface,
    ContrastLevel level,
    Brightness brightness,
  ) {
    switch (level) {
      case ContrastLevel.standard:
        return brightness == Brightness.light
            ? const Color(0xFF1D1B20)
            : const Color(0xFFE6E0E9);
      case ContrastLevel.medium:
        return brightness == Brightness.light
            ? const Color(0xFF121212)
            : const Color(0xFFF5F5F5);
      case ContrastLevel.high:
        return brightness == Brightness.light ? Colors.black : Colors.white;
    }
  }

  /// Get outline color with proper contrast
  static Color getOutlineColor(ContrastLevel level, Brightness brightness) {
    switch (level) {
      case ContrastLevel.standard:
        return brightness == Brightness.light
            ? const Color(0xFF79747E)
            : const Color(0xFF938F99);
      case ContrastLevel.medium:
        return brightness == Brightness.light
            ? const Color(0xFF5A5660)
            : const Color(0xFFB0ACB5);
      case ContrastLevel.high:
        return brightness == Brightness.light
            ? const Color(0xFF3A3640)
            : const Color(0xFFD0CCD5);
    }
  }
}
