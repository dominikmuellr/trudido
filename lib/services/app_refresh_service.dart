import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';

class AppRefreshService {
  static const AppRefreshService instance = AppRefreshService._();
  const AppRefreshService._();

  /// Refreshes all app data providers after import or major data changes
  Future<void> refreshAllProviders(WidgetRef ref) async {
    try {
      debugPrint('[AppRefreshService] Starting provider refresh...');

      // Refresh tasks
      final tasksNotifier = ref.read(tasksProvider.notifier);
      await tasksNotifier.refresh();
      debugPrint('[AppRefreshService] Tasks refreshed');

      // Refresh preferences state
      ref.invalidate(preferencesStateProvider);
      debugPrint('[AppRefreshService] Preferences state invalidated');

      debugPrint('[AppRefreshService] All providers refreshed successfully');
    } catch (e, stackTrace) {
      debugPrint('[AppRefreshService] Error refreshing providers: $e');
      debugPrint('[AppRefreshService] Stack trace: $stackTrace');
      rethrow;
    }
  }
}
