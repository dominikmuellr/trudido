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
