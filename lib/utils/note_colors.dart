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
/// Light card = tone 90  |  Dark card = tone 22
/// Light editor= tone 96 |  Dark editor= tone 12
const List<NoteColorOption> kNoteColorPalette = [
  NoteColorOption(index: null, label: 'Default'),
  // Yellow  hue ~95
  NoteColorOption(
    index: 1,
    label: 'Yellow',
    cardLight: 0xFFEEE0A0,
    cardDark: 0xFF3A3100,
    editorLight: 0xFFF9F6E2,
    editorDark: 0xFF1D1900,
  ),
  // Green   hue ~140
  NoteColorOption(
    index: 2,
    label: 'Green',
    cardLight: 0xFFC5E1A5,
    cardDark: 0xFF183A08,
    editorLight: 0xFFEBF5E3,
    editorDark: 0xFF0B1E04,
  ),
  // Blue    hue ~220
  NoteColorOption(
    index: 3,
    label: 'Blue',
    cardLight: 0xFFAEC6E8,
    cardDark: 0xFF003159,
    editorLight: 0xFFE4EFF8,
    editorDark: 0xFF001A2F,
  ),
  // Pink    hue ~345
  NoteColorOption(
    index: 4,
    label: 'Pink',
    cardLight: 0xFFEDB6CA,
    cardDark: 0xFF4A001E,
    editorLight: 0xFFFAE7EF,
    editorDark: 0xFF270010,
  ),
  // Purple  hue ~275
  NoteColorOption(
    index: 5,
    label: 'Purple',
    cardLight: 0xFFD3B8EC,
    cardDark: 0xFF36005E,
    editorLight: 0xFFF3EAF9,
    editorDark: 0xFF1C0032,
  ),
  // Orange  hue ~30
  NoteColorOption(
    index: 6,
    label: 'Orange',
    cardLight: 0xFFEFC18C,
    cardDark: 0xFF4A1B00,
    editorLight: 0xFFFAEDD8,
    editorDark: 0xFF270E00,
  ),
  // Teal    hue ~185
  NoteColorOption(
    index: 7,
    label: 'Teal',
    cardLight: 0xFFA4D7DF,
    cardDark: 0xFF003035,
    editorLight: 0xFFE4F5F7,
    editorDark: 0xFF00191C,
  ),
  // Lime    hue ~115
  NoteColorOption(
    index: 8,
    label: 'Lime',
    cardLight: 0xFFCCDE88,
    cardDark: 0xFF1D3000,
    editorLight: 0xFFEFF5D8,
    editorDark: 0xFF101900,
  ),
  // Amber   hue ~60
  NoteColorOption(
    index: 9,
    label: 'Amber',
    cardLight: 0xFFEBDF84,
    cardDark: 0xFF343000,
    editorLight: 0xFFF7F3D0,
    editorDark: 0xFF1B1900,
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

/// Convenience: resolves the card [Color] for a stored [colorValue] and
/// the current [brightness]. Returns null when no custom colour is set.
Color? resolveNoteColor(int? colorValue, Brightness brightness) {
  return noteColorOptionFor(colorValue)?.colorForBrightness(brightness);
}

/// Convenience: resolves the subtle editor/toolbar [Color] for a stored
/// [colorValue]. Returns null when no custom colour is set (uses theme default).
Color? resolveNoteEditorColor(int? colorValue, Brightness brightness) {
  return noteColorOptionFor(colorValue)?.editorColorForBrightness(brightness);
}
