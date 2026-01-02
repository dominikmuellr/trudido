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

import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/todo.dart';

/// Service for managing the home screen widget.
/// Handles communication between Flutter and the native Android widget.
class WidgetService {
  static const MethodChannel _channel = MethodChannel('com.trudido.app/widget');

  static final WidgetService instance = WidgetService._();
  WidgetService._();

  final StreamController<int?> _openTaskCreationController =
      StreamController.broadcast();
  final StreamController<List<String>> _toggleTaskController =
      StreamController.broadcast();

  /// Stream that emits when the widget requests task creation screen to open.
  Stream<int?> get onOpenTaskCreation => _openTaskCreationController.stream;

  /// Stream that emits when tasks are toggled from the widget.
  Stream<List<String>> get onToggleTasks => _toggleTaskController.stream;

  bool _initialized = false;

  /// Initialize the widget service and set up method call handlers.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'openTaskCreation':
          debugPrint('[WidgetService] Open task creation requested');
          final args = call.arguments as Map?;
          final date = args?['date'] as int?;
          _openTaskCreationController.add(date);
          break;
        case 'widgetToggleTask':
          debugPrint('[WidgetService] Widget toggle task: ${call.arguments}');
          // Immediately process pending toggles when notified by the widget
          await processPendingToggles();
          break;
        default:
          debugPrint('[WidgetService] Unknown method: ${call.method}');
      }
    });
  }

  /// Update the widget with the current list of incomplete tasks.
  /// Call this after any task operation (add, update, delete, toggle).
  Future<bool> updateWidgetData(List<Todo> incompleteTasks) async {
    try {
      final tasksJson = incompleteTasks
          .map(
            (task) => {
              'id': task.id,
              'title': task.text,
              'dueDate': task.dueDate?.millisecondsSinceEpoch,
              'startDate': task.startDate?.millisecondsSinceEpoch,
              'repeatType': task.repeatType,
            },
          )
          .toList();

      final jsonString = jsonEncode(tasksJson);
      final result = await _channel.invokeMethod(
        'updateWidgetData',
        jsonString,
      );
      return result == true;
    } catch (e) {
      debugPrint('[WidgetService] updateWidgetData error: $e');
      return false;
    }
  }

  /// Trigger a widget refresh without updating data.
  Future<bool> refreshWidget() async {
    try {
      final result = await _channel.invokeMethod('refreshWidget');
      return result == true;
    } catch (e) {
      debugPrint('[WidgetService] refreshWidget error: $e');
      return false;
    }
  }

  /// Get any pending task toggle actions from the widget.
  /// These are task IDs that were toggled while Flutter wasn't running.
  Future<List<String>> getPendingToggles() async {
    try {
      final result = await _channel.invokeMethod('getPendingToggles');
      if (result is List) {
        return result.cast<String>();
      }
      return [];
    } catch (e) {
      debugPrint('[WidgetService] getPendingToggles error: $e');
      return [];
    }
  }

  /// Process any pending widget toggles.
  /// Returns the list of task IDs that were toggled.
  Future<List<String>> processPendingToggles() async {
    final pendingIds = await getPendingToggles();
    if (pendingIds.isNotEmpty) {
      debugPrint(
        '[WidgetService] Processing ${pendingIds.length} pending toggles',
      );
      _toggleTaskController.add(pendingIds);
    }
    return pendingIds;
  }

  void dispose() {
    _openTaskCreationController.close();
    _toggleTaskController.close();
  }
}
