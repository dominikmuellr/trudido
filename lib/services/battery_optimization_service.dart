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

/// (Legacy stub) Use SystemSettingsService instead.
@Deprecated('Replaced by SystemSettingsService. Will be removed after v1.1.0.')
class BatteryOptimizationService {
  BatteryOptimizationService._();
  static final instance = BatteryOptimizationService._();
  Never _deprecated() => throw UnimplementedError(
    'BatteryOptimizationService removed. Use SystemSettingsService.',
  );
  Future<bool> isIgnoringOptimizations() async => _deprecated();
  Future<void> openSettings() async => _deprecated();
  bool get hasAcknowledged => false;
  Future<void> setAcknowledged() async => _deprecated();
}
