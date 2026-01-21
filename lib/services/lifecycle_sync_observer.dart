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

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_action_sync.dart';
import 'widget_service.dart';
import '../providers/app_providers.dart';
import '../controllers/task_controller.dart';

/// Observes app lifecycle to trigger native pending action sync when the app
/// returns to foreground (resumed). Ensures no persisted native action is lost.
class LifecycleSyncObserver with WidgetsBindingObserver {
  final Ref ref;
  LifecycleSyncObserver(this.ref);

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _initWidgetService();

    // Listen for real-time toggles from the widget
    WidgetService.instance.onToggleTasks.listen((ids) {
      _processToggleIds(ids);
    });
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  Future<void> _initWidgetService() async {
    // Ensure tasks are loaded before processing toggles
    await ref.read(tasksProvider.notifier).refresh();

    await WidgetService.instance.initialize();
    await _processPendingWidgetToggles();
    await _updateWidgetData();
  }

  Future<void> _processPendingWidgetToggles() async {
    // This triggers the stream, which is handled by the listener in start()
    await WidgetService.instance.processPendingToggles();
  }

  Future<void> _processToggleIds(List<String> ids) async {
    if (ids.isEmpty) return;

    final taskController = ref.read(taskControllerProvider.notifier);
    for (final taskId in ids) {
      try {
        await taskController.toggleComplete(taskId);
      } catch (e) {
        debugPrint('[LifecycleSyncObserver] Failed to toggle task $taskId: $e');
      }
    }
  }

  Future<void> _updateWidgetData() async {
    final tasks = ref.read(tasksProvider);
    final incomplete = tasks.where((t) => !t.isCompleted).toList();
    await WidgetService.instance.updateWidgetData(incomplete);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationActionSync.instance.syncPending(ref);
      _processPendingWidgetToggles();
      _updateWidgetData();
    }
  }
}
