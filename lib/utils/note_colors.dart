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

import 'package:flutter/material.dart';

/// A named colour that adapts to light / dark mode.
/// Stores two tonal levels per hue:
///  - card:   the richer tint used on the preview card (M3 tone ~88 / ~22)
///  - editor: the very subtle tint used on the editor bg and toolbar (M3 tone ~96 / ~13)
class NoteColorOption {
  final int? index; // null = default; 1–9 = colour family
  final String label;
  final int? cardLight; // M3 tone-88 in light mode
  final int? cardDark; // M3 tone-22 in dark mode
  final int? editorLight; // M3 tone-96 in light mode (barely-there tint)
  final int? editorDark; // M3 tone-13 in dark mode  (barely-there tint)

  const NoteColorOption({
    required this.index,
    required this.label,
    this.cardLight,
    this.cardDark,
    this.editorLight,
    this.editorDark,
  });

  /// The richer card background colour.
  Color? colorForBrightness(Brightness brightness) {
    if (index == null) return null;
    return Color(brightness == Brightness.dark ? cardDark! : cardLight!);
  }

  /// The subtle editor / toolbar background colour.
  Color? editorColorForBrightness(Brightness brightness) {
    if (index == null) return null;
    return Color(brightness == Brightness.dark ? editorDark! : editorLight!);
  }
}

/// Shared colour palette – values derived from the M3 HCT tonal palette.
/// Light card  = tone 90  |  Dark card   = tone 22
/// Light editor = tone 96 |  Dark editor = tone 12
const List<NoteColorOption> kNoteColorPalette = [
  NoteColorOption(index: null, label: 'Default'),
  // Yellow  hue ~90
  NoteColorOption(
    index: 1,
    label: 'Yellow',
    cardLight: 0xFFEEE8A9,
    cardDark: 0xFF3C3400,
    editorLight: 0xFFFAF8DC,
    editorDark: 0xFF1F1C00,
  ),
  // Green   hue ~155
  NoteColorOption(
    index: 2,
    label: 'Green',
    cardLight: 0xFFB6F2B4,
    cardDark: 0xFF003916,
    editorLight: 0xFFEDFBED,
    editorDark: 0xFF001E0A,
  ),
  // Blue    hue ~222
  NoteColorOption(
    index: 3,
    label: 'Blue',
    cardLight: 0xFFDAE2FF,
    cardDark: 0xFF0E1B58,
    editorLight: 0xFFF1F4FF,
    editorDark: 0xFF04092E,
  ),
  // Pink    hue ~349
  NoteColorOption(
    index: 4,
    label: 'Pink',
    cardLight: 0xFFFFD8E4,
    cardDark: 0xFF31111D,
    editorLight: 0xFFFFF8FA,
    editorDark: 0xFF1A000F,
  ),
  // Purple  hue ~280
  NoteColorOption(
    index: 5,
    label: 'Purple',
    cardLight: 0xFFEADDFF,
    cardDark: 0xFF21005D,
    editorLight: 0xFFFDF7FF,
    editorDark: 0xFF110030,
  ),
  // Orange  hue ~35
  NoteColorOption(
    index: 6,
    label: 'Orange',
    cardLight: 0xFFFFDBC1,
    cardDark: 0xFF4A1C00,
    editorLight: 0xFFFFF7EE,
    editorDark: 0xFF260E00,
  ),
  // Teal    hue ~195
  NoteColorOption(
    index: 7,
    label: 'Teal',
    cardLight: 0xFFBFECF0,
    cardDark: 0xFF003739,
    editorLight: 0xFFEEFAFB,
    editorDark: 0xFF001B1D,
  ),
  // Lime    hue ~115
  NoteColorOption(
    index: 8,
    label: 'Lime',
    cardLight: 0xFFD5EDAF,
    cardDark: 0xFF1A3800,
    editorLight: 0xFFF3FBDE,
    editorDark: 0xFF0C1E00,
  ),
  // Amber   hue ~65
  NoteColorOption(
    index: 9,
    label: 'Amber',
    cardLight: 0xFFF0E68C,
    cardDark: 0xFF363100,
    editorLight: 0xFFFAF6D8,
    editorDark: 0xFF1C1900,
  ),
];

/// Looks up the palette entry for [colorValue] (as stored on Note.colorValue).
NoteColorOption? noteColorOptionFor(int? colorValue) {
  if (colorValue == null) return null;
  for (final o in kNoteColorPalette) {
    if (o.index == colorValue) return o;
  }
  return null;
}

/// Returns true when [colorValue] is a raw ARGB custom colour (not a palette index).
bool isCustomNoteColor(int? colorValue) {
  if (colorValue == null) return false;
  return noteColorOptionFor(colorValue) == null;
}

/// Convenience: resolves the card [Color] for a stored [colorValue] and
/// the current [brightness]. Returns null when no custom colour is set.
/// Raw ARGB custom colours are blended with white at 35 % in light mode
/// so they appear as a light pastel (matching the tone of palette colours).
Color? resolveNoteColor(int? colorValue, Brightness brightness) {
  if (colorValue == null) return null;
  final option = noteColorOptionFor(colorValue);
  if (option != null) return option.colorForBrightness(brightness);
  // Raw ARGB custom colour: lighten for light mode, keep full colour for dark.
  final base = Color(colorValue);
  if (brightness == Brightness.light) {
    return Color.alphaBlend(base.withValues(alpha: 0.35), Colors.white);
  }
  return base;
}

/// Convenience: resolves the subtle editor/toolbar [Color] for a stored
/// [colorValue]. Returns null when no custom colour is set (uses theme default).
/// Custom colours are blended with white at 15 % in light mode for a barely-there
/// tint, or applied at 12 % opacity in dark mode.
Color? resolveNoteEditorColor(int? colorValue, Brightness brightness) {
  if (colorValue == null) return null;
  final option = noteColorOptionFor(colorValue);
  if (option != null) return option.editorColorForBrightness(brightness);
  // Raw ARGB custom colour → subtle tint for editor / toolbar.
  final base = Color(colorValue);
  if (brightness == Brightness.light) {
    return Color.alphaBlend(base.withValues(alpha: 0.15), Colors.white);
  }
  return base.withValues(alpha: 0.12);
}
