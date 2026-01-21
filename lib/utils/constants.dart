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

/// Application-wide constants for Trudido.
/// Centralized configuration for magic numbers and sentinel values.
class AppConstants {
  // Tab indices
  static const int tasksTab = 0;
  static const int notesTab = 1;
  static const int settingsTab = 2;
  static const int calendarTab = 3;
  static const int vaultTab = 4;

  // Animation durations
  static const Duration fadeDuration = Duration(milliseconds: 200);
  static const Duration slideDuration = Duration(milliseconds: 300);

  // Numeric thresholds
  static const int minSearchLength = 2;
  static const int notificationThrottleMs = 500;

  // Prevent instantiation
  AppConstants._();
}
