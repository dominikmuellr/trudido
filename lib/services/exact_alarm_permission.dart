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

/// (Legacy stub) This file is retained only to avoid import errors during migration.
/// Use SystemSettingsService + AlarmSettingsWatcher + dialog helpers instead.
@Deprecated(
  'Replaced by SystemSettingsService + AlarmSettingsWatcher. Will be removed after v1.1.0.',
)
class ExactAlarmPermissionService {
  ExactAlarmPermissionService._();
  static final instance = ExactAlarmPermissionService._();
  Never _deprecated() => throw UnimplementedError(
    'ExactAlarmPermissionService removed. Use SystemSettingsService.',
  );
  Future<bool> canScheduleExactAlarms() async => _deprecated();
  Future<void> openSettings() async => _deprecated();
  bool get hasAcknowledged => false;
  Future<void> setAcknowledged() async => _deprecated();
}
