import 'package:flutter/material.dart';

/// Solarized Color Palette
/// Based on https://github.com/altercation/solarized
///
/// Solarized is a sixteen color palette (eight monotones, eight accent colors)
/// designed for use with terminal and gui applications.
class SolarizedColors {
  // Base (Monotone) Colors
  // Light theme uses base3 as background, base00 as primary text
  // Dark theme uses base03 as background, base0 as primary text

  static const Color base03 = Color(0xFF002B36); // darkest - dark background
  static const Color base02 = Color(0xFF073642); // dark background highlights
  static const Color base01 = Color(0xFF586E75); // dark content / comments
  static const Color base00 = Color(0xFF657B83); // light emphasized content
  static const Color base0 = Color(0xFF839496); // dark emphasized content
  static const Color base1 = Color(0xFF93A1A1); // light content / comments
  static const Color base2 = Color(0xFFEEE8D5); // light background highlights
  static const Color base3 = Color(0xFFFDF6E3); // lightest - light background

  // Accent Colors
  static const Color yellow = Color(0xFFB58900);
  static const Color orange = Color(0xFFCB4B16);
  static const Color red = Color(0xFFDC322F);
  static const Color magenta = Color(0xFFD33682);
  static const Color violet = Color(0xFF6C71C4);
  static const Color blue = Color(0xFF268BD2);
  static const Color cyan = Color(0xFF2AA198);
  static const Color green = Color(0xFF859900);

  /// Helper to convert hex string at runtime if needed
  static Color fromHex(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    return Color(int.parse('0xFF$cleaned'));
  }
}
