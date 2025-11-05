import 'package:flutter/material.dart';
import 'dart:ui';

/// Frosted Glass Theme Colors and Utilities
///
/// Provides frosted glass effect styling with semi-transparent backgrounds,
/// blur effects, and subtle borders for a modern, depth-filled UI.
class FrostedGlassTheme {
  // Background colors with opacity for glass effect
  static const Color glassLightBackground = Color(0x40FFFFFF); // 25% white
  static const Color glassDarkBackground = Color(0x30000000); // 19% black

  // Border colors for glass effect
  static const Color glassLightBorder = Color(0x30FFFFFF); // 19% white
  static const Color glassDarkBorder = Color(0x20FFFFFF); // 12% white

  // Accent colors with high opacity for contrast
  static const Color accentBlue = Color(0xFF64B5F6);
  static const Color accentPurple = Color(0xFFAB47BC);
  static const Color accentCyan = Color(0xFF4DD0E1);
  static const Color accentPink = Color(0xFFEC407A);

  // Blur strength for backdrop filter
  static const double blurStrength = 10.0;
  static const double strongBlurStrength = 20.0;

  /// Creates a glassmorphic container decoration
  static BoxDecoration glassDecoration({
    required bool isDark,
    Color? customColor,
    double? opacity,
    bool strongBorder = false,
  }) {
    return BoxDecoration(
      color:
          customColor?.withOpacity(opacity ?? 0.1) ??
          (isDark ? glassDarkBackground : glassLightBackground),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark ? glassDarkBorder : glassLightBorder,
        width: strongBorder ? 1.5 : 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? Colors.black.withOpacity(0.3)
              : Colors.black.withOpacity(0.1),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Creates a widget with glassmorphic effect
  static Widget glassContainer({
    required Widget child,
    required bool isDark,
    double? blur,
    Color? customColor,
    double? opacity,
    BorderRadius? borderRadius,
    EdgeInsets? padding,
    bool strongBorder = false,
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blur ?? blurStrength,
          sigmaY: blur ?? blurStrength,
        ),
        child: Container(
          decoration: glassDecoration(
            isDark: isDark,
            customColor: customColor,
            opacity: opacity,
            strongBorder: strongBorder,
          ),
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }

  /// Creates glassmorphic card theme
  static CardTheme glassCardTheme(bool isDark) {
    return CardTheme(
      elevation: 0,
      color: isDark ? glassDarkBackground : glassLightBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? glassDarkBorder : glassLightBorder,
          width: 1,
        ),
      ),
    );
  }

  /// Creates glassmorphic app bar theme
  static AppBarTheme glassAppBarTheme(bool isDark) {
    return AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  /// Creates glassmorphic bottom navigation bar theme
  static BottomNavigationBarThemeData glassBottomNavTheme(bool isDark) {
    return BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      selectedItemColor: isDark ? accentCyan : accentBlue,
      unselectedItemColor: isDark
          ? Colors.white.withOpacity(0.6)
          : Colors.black.withOpacity(0.6),
      type: BottomNavigationBarType.fixed,
    );
  }

  /// Creates a glassmorphic scaffold background
  static Widget glassScaffoldBackground(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF0A0E27),
                  const Color(0xFF1A1A2E),
                  const Color(0xFF16213E),
                ]
              : [
                  const Color(0xFFE3F2FD),
                  const Color(0xFFBBDEFB),
                  const Color(0xFF90CAF9),
                ],
        ),
      ),
    );
  }

  /// Creates floating action button theme
  static FloatingActionButtonThemeData glassFABTheme(bool isDark) {
    return FloatingActionButtonThemeData(
      elevation: 0,
      backgroundColor: isDark
          ? accentCyan.withOpacity(0.3)
          : accentBlue.withOpacity(0.3),
      foregroundColor: isDark ? Colors.white : Colors.black87,
    );
  }
}
