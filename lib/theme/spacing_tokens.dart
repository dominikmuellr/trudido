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

/// Material 3 Semantic Spacing Tokens (January 2026)
///
/// A systematic spacing system based on a 4dp grid, following Material Design 3
/// specifications. All spacing values are multiples of 4dp for consistent
/// visual rhythm across the app.
///
/// Usage:
/// ```dart
/// Padding(padding: Spacing.insets16)
/// SizedBox(height: Spacing.s8)
/// ```
class Spacing {
  Spacing._();

  // ============================================================================
  // Base Spacing Values (4dp grid)
  // ============================================================================

  /// 0dp - No spacing
  static const double s0 = 0;

  /// 2dp - Micro spacing (half-step for fine adjustments)
  static const double s2 = 2;

  /// 4dp - Extra small spacing
  static const double s4 = 4;

  /// 6dp - Small-medium spacing (1.5x base)
  static const double s6 = 6;

  /// 8dp - Small spacing (2x base)
  static const double s8 = 8;

  /// 12dp - Medium-small spacing (3x base)
  static const double s12 = 12;

  /// 16dp - Medium spacing (4x base) - Most common
  static const double s16 = 16;

  /// 20dp - Medium-large spacing (5x base)
  static const double s20 = 20;

  /// 24dp - Large spacing (6x base)
  static const double s24 = 24;

  /// 28dp - Large spacing (7x base)
  static const double s28 = 28;

  /// 32dp - Extra large spacing (8x base)
  static const double s32 = 32;

  /// 40dp - Section spacing (10x base)
  static const double s40 = 40;

  /// 48dp - Large section spacing (12x base)
  static const double s48 = 48;

  /// 56dp - AppBar height / major section spacing
  static const double s56 = 56;

  /// 64dp - Large component spacing (Material 3 AppBar height)
  static const double s64 = 64;

  /// 72dp - Major section spacing
  static const double s72 = 72;

  /// 80dp - Bottom navigation height / major spacing
  static const double s80 = 80;

  // ============================================================================
  // Semantic Spacing Aliases
  // ============================================================================

  /// Compact padding for dense UI elements
  static const double paddingCompact = s8;

  /// Standard padding for most UI elements
  static const double paddingStandard = s16;

  /// Comfortable padding for spacious UI elements
  static const double paddingComfortable = s24;

  /// Gap between related elements (inline)
  static const double gapSmall = s4;

  /// Gap between elements in a group
  static const double gapMedium = s8;

  /// Gap between sections or groups
  static const double gapLarge = s16;

  /// Section separator spacing
  static const double sectionGap = s24;

  /// Card internal padding
  static const double cardPadding = s16;

  /// Card internal padding (compact)
  static const double cardPaddingCompact = s12;

  /// List tile horizontal padding
  static const double listTileHorizontal = s16;

  /// List tile vertical padding
  static const double listTileVertical = s4;

  /// Dialog content padding
  static const double dialogPadding = s24;

  /// Bottom sheet content padding
  static const double bottomSheetPadding = s16;

  /// FAB margin from edges
  static const double fabMargin = s16;

  /// Icon-to-text gap
  static const double iconTextGap = s8;

  /// Button horizontal padding
  static const double buttonHorizontalPadding = s24;

  /// Button vertical padding
  static const double buttonVerticalPadding = s12;

  /// Chip horizontal padding
  static const double chipHorizontalPadding = s12;

  /// Chip vertical padding
  static const double chipVerticalPadding = s8;

  // ============================================================================
  // Component-Specific Spacing
  // ============================================================================

  /// AppBar toolbar height (Material 3)
  static const double appBarHeight = s64;

  /// Bottom navigation height (Material 3)
  static const double bottomNavHeight = s80;

  /// Navigation rail width (collapsed)
  static const double navRailWidthCollapsed = s72;

  /// Navigation rail width (expanded)
  static const double navRailWidthExpanded = 256;

  /// FAB size (standard)
  static const double fabSize = s56;

  /// FAB size (small)
  static const double fabSizeSmall = s40;

  /// FAB size (large)
  static const double fabSizeLarge = s96;

  /// 96dp - FAB large size
  static const double s96 = 96;

  // ============================================================================
  // Border Radius Values (Material 3)
  // ============================================================================

  /// No radius
  static const double radiusNone = 0;

  /// Extra small radius (4dp) - Checkboxes, small chips
  static const double radiusXS = 4;

  /// Small radius (8dp) - Buttons, small cards
  static const double radiusS = 8;

  /// Medium radius (12dp) - Cards, inputs, list tiles
  static const double radiusM = 12;

  /// Large radius (16dp) - FABs, large cards
  static const double radiusL = 16;

  /// Extra large radius (20dp) - Chips, pills
  static const double radiusXL = 20;

  /// Full radius (28dp) - Dialogs, bottom sheets
  static const double radiusFull = 28;
}

/// Extension for convenient EdgeInsets creation
extension SpacingEdgeInsets on Spacing {
  // ============================================================================
  // Symmetric EdgeInsets
  // ============================================================================

  /// All sides: 0dp
  static const EdgeInsets insets0 = EdgeInsets.zero;

  /// All sides: 2dp
  static const EdgeInsets insets2 = EdgeInsets.all(Spacing.s2);

  /// All sides: 4dp
  static const EdgeInsets insets4 = EdgeInsets.all(Spacing.s4);

  /// All sides: 6dp
  static const EdgeInsets insets6 = EdgeInsets.all(Spacing.s6);

  /// All sides: 8dp
  static const EdgeInsets insets8 = EdgeInsets.all(Spacing.s8);

  /// All sides: 12dp
  static const EdgeInsets insets12 = EdgeInsets.all(Spacing.s12);

  /// All sides: 16dp
  static const EdgeInsets insets16 = EdgeInsets.all(Spacing.s16);

  /// All sides: 20dp
  static const EdgeInsets insets20 = EdgeInsets.all(Spacing.s20);

  /// All sides: 24dp
  static const EdgeInsets insets24 = EdgeInsets.all(Spacing.s24);

  /// All sides: 32dp
  static const EdgeInsets insets32 = EdgeInsets.all(Spacing.s32);

  // ============================================================================
  // Horizontal-only EdgeInsets
  // ============================================================================

  /// Horizontal: 4dp
  static const EdgeInsets insetsH4 = EdgeInsets.symmetric(
    horizontal: Spacing.s4,
  );

  /// Horizontal: 8dp
  static const EdgeInsets insetsH8 = EdgeInsets.symmetric(
    horizontal: Spacing.s8,
  );

  /// Horizontal: 12dp
  static const EdgeInsets insetsH12 = EdgeInsets.symmetric(
    horizontal: Spacing.s12,
  );

  /// Horizontal: 16dp
  static const EdgeInsets insetsH16 = EdgeInsets.symmetric(
    horizontal: Spacing.s16,
  );

  /// Horizontal: 24dp
  static const EdgeInsets insetsH24 = EdgeInsets.symmetric(
    horizontal: Spacing.s24,
  );

  // ============================================================================
  // Vertical-only EdgeInsets
  // ============================================================================

  /// Vertical: 4dp
  static const EdgeInsets insetsV4 = EdgeInsets.symmetric(vertical: Spacing.s4);

  /// Vertical: 8dp
  static const EdgeInsets insetsV8 = EdgeInsets.symmetric(vertical: Spacing.s8);

  /// Vertical: 12dp
  static const EdgeInsets insetsV12 = EdgeInsets.symmetric(
    vertical: Spacing.s12,
  );

  /// Vertical: 16dp
  static const EdgeInsets insetsV16 = EdgeInsets.symmetric(
    vertical: Spacing.s16,
  );

  /// Vertical: 24dp
  static const EdgeInsets insetsV24 = EdgeInsets.symmetric(
    vertical: Spacing.s24,
  );

  // ============================================================================
  // Common Combinations
  // ============================================================================

  /// Standard card padding: 16dp all sides
  static const EdgeInsets cardInsets = EdgeInsets.all(Spacing.s16);

  /// Compact card padding: 12dp all sides
  static const EdgeInsets cardInsetsCompact = EdgeInsets.all(Spacing.s12);

  /// List tile padding: horizontal 16dp, vertical 4dp
  static const EdgeInsets listTileInsets = EdgeInsets.symmetric(
    horizontal: Spacing.s16,
    vertical: Spacing.s4,
  );

  /// Dialog content padding: 24dp all sides
  static const EdgeInsets dialogInsets = EdgeInsets.all(Spacing.s24);

  /// Bottom sheet padding: 16dp all sides
  static const EdgeInsets bottomSheetInsets = EdgeInsets.all(Spacing.s16);

  /// Section header padding: top 24dp, horizontal 16dp, bottom 8dp
  static const EdgeInsets sectionHeaderInsets = EdgeInsets.fromLTRB(
    Spacing.s16,
    Spacing.s24,
    Spacing.s16,
    Spacing.s8,
  );

  /// Button padding: horizontal 24dp, vertical 12dp
  static const EdgeInsets buttonInsets = EdgeInsets.symmetric(
    horizontal: Spacing.s24,
    vertical: Spacing.s12,
  );

  /// Chip padding: horizontal 12dp, vertical 8dp
  static const EdgeInsets chipInsets = EdgeInsets.symmetric(
    horizontal: Spacing.s12,
    vertical: Spacing.s8,
  );
}

/// Extension for convenient SizedBox creation
extension SpacingGap on Spacing {
  // ============================================================================
  // Horizontal Gaps (SizedBox with width)
  // ============================================================================

  /// Horizontal gap: 4dp
  static const SizedBox gapH4 = SizedBox(width: Spacing.s4);

  /// Horizontal gap: 8dp
  static const SizedBox gapH8 = SizedBox(width: Spacing.s8);

  /// Horizontal gap: 12dp
  static const SizedBox gapH12 = SizedBox(width: Spacing.s12);

  /// Horizontal gap: 16dp
  static const SizedBox gapH16 = SizedBox(width: Spacing.s16);

  /// Horizontal gap: 24dp
  static const SizedBox gapH24 = SizedBox(width: Spacing.s24);

  // ============================================================================
  // Vertical Gaps (SizedBox with height)
  // ============================================================================

  /// Vertical gap: 2dp
  static const SizedBox gapV2 = SizedBox(height: Spacing.s2);

  /// Vertical gap: 4dp
  static const SizedBox gapV4 = SizedBox(height: Spacing.s4);

  /// Vertical gap: 6dp
  static const SizedBox gapV6 = SizedBox(height: Spacing.s6);

  /// Vertical gap: 8dp
  static const SizedBox gapV8 = SizedBox(height: Spacing.s8);

  /// Vertical gap: 12dp
  static const SizedBox gapV12 = SizedBox(height: Spacing.s12);

  /// Vertical gap: 16dp
  static const SizedBox gapV16 = SizedBox(height: Spacing.s16);

  /// Vertical gap: 24dp
  static const SizedBox gapV24 = SizedBox(height: Spacing.s24);

  /// Vertical gap: 32dp
  static const SizedBox gapV32 = SizedBox(height: Spacing.s32);

  /// Vertical gap: 48dp
  static const SizedBox gapV48 = SizedBox(height: Spacing.s48);
}

/// Extension for BorderRadius creation
extension SpacingBorderRadius on Spacing {
  /// No radius
  static final BorderRadius none = BorderRadius.zero;

  /// Extra small radius: 4dp
  static final BorderRadius xs = BorderRadius.circular(Spacing.radiusXS);

  /// Small radius: 8dp
  static final BorderRadius sm = BorderRadius.circular(Spacing.radiusS);

  /// Medium radius: 12dp
  static final BorderRadius md = BorderRadius.circular(Spacing.radiusM);

  /// Large radius: 16dp
  static final BorderRadius lg = BorderRadius.circular(Spacing.radiusL);

  /// Extra large radius: 20dp
  static final BorderRadius xl = BorderRadius.circular(Spacing.radiusXL);

  /// Full radius: 28dp (dialogs, bottom sheets)
  static final BorderRadius full = BorderRadius.circular(Spacing.radiusFull);

  /// Circular/pill shape
  static final BorderRadius circular = BorderRadius.circular(1000);
}
