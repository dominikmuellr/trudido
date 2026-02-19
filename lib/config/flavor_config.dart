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

/// Build flavor configuration for PlayStore vs FDroid releases.
///
/// FDroid builds use `--dart-define=IS_FDROID=true` to enable donations.
/// PlayStore builds omit this flag, so donations are hidden.
class FlavorConfig {
  FlavorConfig._();

  /// True when built for FDroid (donations enabled).
  /// False for PlayStore builds (donations hidden).
  static const bool isFDroid =
      String.fromEnvironment('IS_FDROID', defaultValue: 'false') == 'true';

  /// True when donations should be shown (only on FDroid).
  static const bool showDonations = isFDroid;
}
