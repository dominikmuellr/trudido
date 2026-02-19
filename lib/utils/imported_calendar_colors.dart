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

/// Utility class for generating deterministic colors for imported calendars
class ImportedCalendarColors {
  /// Standard palette of distinct colors for imported calendars
  static const List<int> colorPalette = [
    0xFF2196F3, // Blue
    0xFF4CAF50, // Green
    0xFFFF9800, // Orange
    0xFFE91E63, // Pink
    0xFF9C27B0, // Purple
    0xFF00BCD4, // Cyan
    0xFFF44336, // Red
    0xFFFFC107, // Amber
    0xFF673AB7, // Deep Purple
    0xFF3F51B5, // Indigo
    0xFF795548, // Brown
    0xFF607D8B, // Blue Grey
  ];

  static int getColorForCalendarName(String calendarName) {
    if (calendarName.isEmpty) {
      return colorPalette.first;
    }

    // Hash the calendar name and use modulo to pick from palette
    int hash = calendarName.hashCode.abs();
    int index = hash % colorPalette.length;
    return colorPalette[index];
  }

  static int getColorByIndex(int index) {
    return colorPalette[index % colorPalette.length];
  }

  static int get paletteLength => colorPalette.length;
}
