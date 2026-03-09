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

import 'package:meta/meta.dart';
import '../models/app_error.dart';
import '../models/event.dart';
import '../services/preferences_service.dart';
import '../services/storage_service.dart';

class EventRepository {
  List<Event> _cache = const [];
  bool _loaded = false;
  bool get isLoaded => _loaded;

  List<Event> get events => _cache;

  @visibleForTesting
  void setTestEvents(List<Event> list) {
    _cache = List<Event>.from(list);
    _loaded = true;
  }

  Future<void> load() async {
    try {
      await StorageService.waitEventsReady();
      _cache = await StorageService.getAllEventsAsync();
      _loaded = true;
    } catch (e, st) {
      throw AppError(
        AppErrorType.storageRead,
        'Failed to load events',
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<Event> add(Event event) async {
    await StorageService.saveEvent(event);
    _cache = [..._cache, event];
    return event;
  }

  Future<Event> update(Event event) async {
    final index = _cache.indexWhere((e) => e.id == event.id);
    if (index == -1) {
      throw const AppError(AppErrorType.notFound, 'Event not found');
    }
    await StorageService.updateEvent(event);
    final list = [..._cache];
    list[index] = event;
    _cache = list;
    return event;
  }

  Future<void> delete(String id) async {
    final before = _cache.length;
    if (PreferencesService().snapshot.enableBin) {
      await StorageService.deleteEvent(id);
    } else {
      await StorageService.permanentlyDeleteEvent(id);
    }
    _cache = _cache.where((e) => e.id != id).toList();
    if (_cache.length == before) {
      throw const AppError(AppErrorType.notFound, 'Event not found');
    }
  }

  Future<void> bulkDelete(Iterable<String> ids) async {
    final set = ids.toSet();
    for (final id in set) {
      await StorageService.deleteEvent(id);
    }
    _cache = _cache.where((e) => !set.contains(e.id)).toList();
  }

  Future<void> saveOrder(List<Event> ordered) async {
    await StorageService.saveEventsOrder(ordered);
    _cache = List<Event>.from(ordered);
  }

  Future<List<Event>> getDeletedEvents() async {
    await StorageService.waitEventsReady();
    return StorageService.getDeletedEvents();
  }

  Future<void> restoreEvent(String id) async {
    await StorageService.restoreEvent(id);
    await load();
  }

  Future<void> permanentlyDeleteEvent(String id) async {
    await StorageService.permanentlyDeleteEvent(id);
  }

  Future<void> emptyBin() async {
    final deleted = await StorageService.getDeletedEvents();
    for (final event in deleted) {
      await StorageService.permanentlyDeleteEvent(event.id);
    }
  }
}
