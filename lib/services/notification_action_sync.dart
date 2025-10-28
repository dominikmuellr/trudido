import 'dart:async';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';
import 'storage_service.dart';
import '../providers/app_providers.dart';
import '../providers/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A singleton responsible for idempotent handling of notification actions
/// coming from native Android via [NotificationBridge].
class NotificationActionSync {
  static final NotificationActionSync instance = NotificationActionSync._();
  NotificationActionSync._();

  static const _appliedActionsKey = 'applied_notification_actions_v1';
  final Set<String> _applied = <String>{};
  bool _loaded = false;
  StreamSubscription? _sub;

  Future<void> initialize(ProviderContainer container) async {
    if (!_loaded) {
      _loadApplied();
      _loaded = true;
      // Pull any pending native actions (emits via bridge stream)
      await NotificationBridge.instance.pullPendingNativeActions();
      // Schedule a secondary pull shortly after startup in case native channel
      // handlers or storage weren’t fully ready at the first attempt.
      Future.delayed(const Duration(seconds: 1), () async {
        try {
          await NotificationBridge.instance.pullPendingNativeActions();
        } catch (e) {
          if (kDebugMode)
            debugPrint('[NotificationActionSync] secondary pull failed: $e');
        }
      });
    }
    _sub ??= NotificationBridge.instance.actions.listen((a) {
      _processAction(a, container);
    });
  }

  /// Called on app lifecycle resume/start to ensure any newly added native
  /// persisted actions (e.g., produced while engine was not alive) are applied.
  Future<void> syncPending(ProviderContainer container) async {
    await NotificationBridge.instance.pullPendingNativeActions();
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  Future<void> _processAction(
    NotificationAction action,
    ProviderContainer? container,
  ) async {
    if (kDebugMode)
      debugPrint('[NotificationActionSync] processing action $action');
    final key = _actionKey(action);
    if (_applied.contains(key)) {
      if (kDebugMode)
        debugPrint('[NotificationActionSync] Skipping duplicate action $key');
      return; // idempotent skip
    }

    // Load current task state from storage directly to avoid stale UI state
    final todo = await StorageService.getTodoAsync(action.taskId);
    if (action.type == 'taskCompleted') {
      if (todo == null) {
        if (kDebugMode)
          debugPrint(
            '[NotificationActionSync] Task not found ${action.taskId}',
          );
        _markApplied(key); // Avoid reprocessing
        return;
      }
      if (todo.isCompleted) {
        _markApplied(key); // Already complete
        return;
      }
      // Update task as completed
      final now = container?.read(clockProvider).now() ?? DateTime.now();
      final updated = todo.copyWith(isCompleted: true, completedAt: now);
      if (kDebugMode)
        debugPrint(
          '[NotificationActionSync] marking task ${action.taskId} complete',
        );
      await StorageService.updateTodo(updated);
      // Update provider state if available
      try {
        // Force tasks list refresh (tasksProvider loads from repository/storage)
        await container?.read(tasksProvider.notifier).refresh();
      } catch (e) {
        if (kDebugMode)
          debugPrint('[NotificationActionSync] refresh failed: $e');
      }
      _markApplied(key);
    } else if (action.type == 'taskSnoozed') {
      // Optional: adjust reminders or track next notification time
      // For idempotency, only apply if newScheduledTime differs from last stored meta.
      if (action.newScheduledTime != null) {
        final metaKey = 'snooze_last_${action.taskId}';
        final last = StorageService.getMeta(metaKey);
        final newMillis = action.newScheduledTime!.millisecondsSinceEpoch
            .toString();
        if (last == newMillis) {
          _markApplied(key);
          return; // duplicate snooze event
        }
        StorageService.setMeta(metaKey, newMillis);
        if (kDebugMode)
          debugPrint(
            '[NotificationActionSync] recorded snooze for ${action.taskId} newTime=${action.newScheduledTime}',
          );
      }
      _markApplied(key);
    }
  }

  String _actionKey(NotificationAction a) {
    if (a.type == 'taskSnoozed' && a.newScheduledTime != null) {
      return '${a.type}:${a.taskId}:${a.newScheduledTime!.millisecondsSinceEpoch}';
    }
    return '${a.type}:${a.taskId}';
  }

  void _loadApplied() {
    final raw = StorageService.getMeta(_appliedActionsKey);
    if (raw != null && raw.isNotEmpty) {
      _applied.addAll(raw.split('|').where((e) => e.isNotEmpty));
    }
  }

  void _markApplied(String key) {
    _applied.add(key);
    // Persist compressed
    StorageService.setMeta(_appliedActionsKey, _applied.join('|'));
  }
}
