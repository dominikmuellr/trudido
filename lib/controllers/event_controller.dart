// Trudido - A privacy-focused todo and notes app
// Copyright (C) 2026 Dominik Müller
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

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event.dart';
import '../repositories/event_repository.dart';
import '../providers/app_providers.dart';
import '../providers/clock.dart';
import '../services/notification_service.dart';
import '../services/calendar_sync_service.dart';
import '../models/app_error.dart';

final eventControllerProvider =
    NotifierProvider<EventController, AsyncValue<void>>(EventController.new);

class EventController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);
  EventRepository get _repo => ref.read(eventRepositoryProvider);
  final _notifications = NotificationBridge.instance;
  final _calendarSync = CalendarSyncService();

  List<Event> get events => ref.read(eventsProvider);

  Future<void> add(Event event) async {
    debugPrint('[EventController] Adding event: "${event.text}"');
    debugPrint(
      '[EventController]   Start: ${event.startDateTime}, End: ${event.endDateTime}',
    );
    state = const AsyncLoading();
    try {
      await _repo.add(event);
      await _scheduleNotifications(event);
      await _syncToCalendar(event);
      await ref.read(eventsProvider.notifier).refresh();
      state = const AsyncData(null);
      debugPrint('[EventController] Event add complete');
    } catch (e, st) {
      debugPrint('[EventController] ERROR adding event: $e');
      state = AsyncError(e, st);
    }
  }

  Future<void> update(Event updated) async {
    debugPrint('[EventController] Updating event: "${updated.text}"');
    state = const AsyncLoading();
    try {
      final existing = events.firstWhere(
        (e) => e.id == updated.id,
        orElse: () =>
            throw const AppError(AppErrorType.notFound, 'Event not found'),
      );
      await _cancelNotifications(existing);
      await _repo.update(updated);
      if (!updated.isCompleted) {
        await _scheduleNotifications(updated);
      }
      await _syncToCalendar(updated);
      await ref.read(eventsProvider.notifier).refresh();
      state = const AsyncData(null);
      debugPrint('[EventController] Event update complete');
    } catch (e, st) {
      debugPrint('[EventController] ERROR updating event: $e');
      state = AsyncError(e, st);
    }
  }

  Future<void> toggleComplete(String id) async {
    final event = events.firstWhere(
      (e) => e.id == id,
      orElse: () =>
          throw const AppError(AppErrorType.notFound, 'Event not found'),
    );

    if (!event.isCompleted && event.isRecurring) {
      final nextOccurrence = _calculateNextOccurrence(event);

      if (nextOccurrence != null) {
        final now = ref.read(clockProvider).now();
        final duration = event.duration;
        final newEvent = event.copyWith(
          id: now.millisecondsSinceEpoch.toString(),
          startDateTime: nextOccurrence,
          endDateTime: nextOccurrence.add(duration),
          isCompleted: false,
          completedAt: null,
          createdAt: now,
        );
        await add(newEvent);
      }

      final updated = event.copyWith(
        isCompleted: true,
        completedAt: ref.read(clockProvider).now(),
      );
      await update(updated);
    } else {
      final now = ref.read(clockProvider).now();
      final updated = event.copyWith(
        isCompleted: !event.isCompleted,
        completedAt: event.isCompleted ? null : now,
      );
      await update(updated);
    }
  }

  DateTime? _calculateNextOccurrence(Event event) {
    if (!event.isRecurring) return null;

    final now = ref.read(clockProvider).now();
    final currentStart = event.startDateTime;

    if (event.repeatEndDate != null && now.isAfter(event.repeatEndDate!)) {
      return null;
    }

    DateTime nextDate = currentStart;

    switch (event.repeatType) {
      case 'daily':
        final interval = event.repeatInterval ?? 1;
        nextDate = currentStart.add(Duration(days: interval));
        break;

      case 'weekly':
        final interval = event.repeatInterval ?? 1;
        nextDate = currentStart.add(Duration(days: 7 * interval));
        break;

      case 'monthly':
        final interval = event.repeatInterval ?? 1;
        final newMonth = currentStart.month + interval;
        final newYear = currentStart.year + (newMonth - 1) ~/ 12;
        final actualMonth = ((newMonth - 1) % 12) + 1;

        final daysInMonth = DateTime(newYear, actualMonth + 1, 0).day;
        final actualDay = currentStart.day > daysInMonth
            ? daysInMonth
            : currentStart.day;

        nextDate = DateTime(
          newYear,
          actualMonth,
          actualDay,
          currentStart.hour,
          currentStart.minute,
        );
        break;

      case 'custom':
        if (event.repeatDays != null && event.repeatDays!.isNotEmpty) {
          final interval = event.repeatInterval ?? 1;
          nextDate = currentStart.add(Duration(days: 7 * interval));
        } else {
          final interval = event.repeatInterval ?? 1;
          nextDate = currentStart.add(Duration(days: interval));
        }
        break;

      default:
        return null;
    }

    if (event.repeatEndDate != null && nextDate.isAfter(event.repeatEndDate!)) {
      return null;
    }

    return nextDate;
  }

  Future<void> delete(String id) async {
    state = const AsyncLoading();
    try {
      final existing = events.firstWhere(
        (e) => e.id == id,
        orElse: () =>
            throw const AppError(AppErrorType.notFound, 'Event not found'),
      );
      await _cancelNotifications(existing);
      await _deleteFromCalendar(id);
      await _repo.delete(id);
      await ref.read(eventsProvider.notifier).refresh();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> bulkDelete(Iterable<String> ids) async {
    state = const AsyncLoading();
    try {
      for (final id in ids) {
        try {
          final event = events.firstWhere((e) => e.id == id);
          await _cancelNotifications(event);
          await _deleteFromCalendar(id);
        } catch (_) {
          // ignore missing event
        }
      }
      await _repo.bulkDelete(ids);
      await ref.read(eventsProvider.notifier).refresh();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> bulkComplete(Iterable<String> ids) async {
    state = const AsyncLoading();
    try {
      final now = ref.read(clockProvider).now();
      for (final id in ids) {
        try {
          final event = events.firstWhere((e) => e.id == id);
          if (!event.isCompleted) {
            final completed = event.copyWith(
              isCompleted: true,
              completedAt: now,
            );
            await _repo.update(completed);
            await _cancelNotifications(event);
          }
        } catch (_) {
          // ignore missing event
        }
      }
      await ref.read(eventsProvider.notifier).refresh();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> clearCompleted() async {
    final completed = events.where((e) => e.isCompleted).map((e) => e.id);
    await bulkDelete(completed);
  }

  Future<void> _scheduleNotifications(Event event) async {
    final now = ref.read(clockProvider).now();
    // Schedule reminders relative to startDateTime
    for (final offset in event.reminderOffsetsMinutes.toSet()) {
      if (offset < 0) continue;
      final when = event.startDateTime.subtract(Duration(minutes: offset));
      if (when.isAfter(now)) {
        await _notifications.scheduleTaskNotification(
          taskId: event.id,
          title: 'Event Reminder',
          body: event.text,
          scheduledTime: when,
          uniqueKey: '${event.id}_$offset',
        );
      }
    }
  }

  Future<void> _cancelNotifications(Event event) async {
    for (final offset in event.reminderOffsetsMinutes) {
      await _notifications.cancelTaskNotification('${event.id}_$offset');
    }
    await _notifications.cancelTaskNotification(event.id);
  }

  Future<void> _syncToCalendar(Event event) async {
    try {
      await _calendarSync.ensureInitialized();
      if (_calendarSync.isEnabled) {
        await _calendarSync.syncEventToCalendar(event);
      }
    } catch (e) {
      // Calendar sync errors should not block event operations
    }
  }

  Future<void> _deleteFromCalendar(String eventId) async {
    try {
      await _calendarSync.ensureInitialized();
      if (_calendarSync.isEnabled) {
        await _calendarSync.deleteEventFromDeviceCalendar(eventId);
      }
    } catch (e) {
      // Calendar sync errors should not block event operations
    }
  }
}
