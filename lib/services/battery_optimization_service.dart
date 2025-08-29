/// (Legacy stub) Use SystemSettingsService instead.
@deprecated
class BatteryOptimizationService {
  BatteryOptimizationService._();
  static final instance = BatteryOptimizationService._();
  Never _deprecated() => throw UnimplementedError('BatteryOptimizationService removed. Use SystemSettingsService.');
  Future<bool> isIgnoringOptimizations() async => _deprecated();
  Future<void> openSettings() async => _deprecated();
  bool get hasAcknowledged => false;
  Future<void> setAcknowledged() async => _deprecated();
}
