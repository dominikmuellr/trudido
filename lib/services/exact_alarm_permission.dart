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
