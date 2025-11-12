import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_action_sync.dart';

/// Observes app lifecycle to trigger native pending action sync when the app
/// returns to foreground (resumed). Ensures no persisted native action is lost.
class LifecycleSyncObserver with WidgetsBindingObserver {
  final ProviderContainer container;
  LifecycleSyncObserver(this.container);

  void start() {
    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationActionSync.instance.syncPending(container);
    }
  }
}
