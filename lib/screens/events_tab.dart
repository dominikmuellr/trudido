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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/filter_providers.dart';
import '../providers/app_providers.dart';
import '../providers/clock.dart';
import '../providers/holiday_providers.dart';
import '../controllers/event_controller.dart';
import '../widgets/calendar_view.dart';
import '../screens/event_editor_screen.dart';
import '../models/event.dart' as app_event;
import '../models/todo.dart';
import '../models/holiday.dart';
import '../theme/spacing_tokens.dart';
import '../utils/state_notifiers.dart';

/// Provider for the events tab view type (calendar vs list).
final eventsViewTypeProvider = stateProvider<EventsViewType>(
  EventsViewType.calendar,
);

enum EventsViewType { calendar, list }

/// Events-only tab: calendar view and event list without todos.
class EventsTab extends ConsumerWidget {
  const EventsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(filteredEventsProvider);
    final viewType = ref.watch(eventsViewTypeProvider);

    return Column(
      children: [
        Expanded(
          child: viewType == EventsViewType.calendar
              ? CalendarView(
                  key: ValueKey(
                    ref.watch(
                      selectedCalendarDateProvider.select((date) => date),
                    ),
                  ),
                  tasks: const <Todo>[],
                  events: events,
                )
              : events.isEmpty
              ? _buildEmptyState(context, ref)
              : _buildEventList(context, ref, events),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    final spacing = ref.watch(adaptiveSpacingProvider);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          spacing.gapV16,
          Text(
            'No events yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          spacing.gapV8,
          Text(
            'Tap the + button to add your first event',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEventList(
    BuildContext context,
    WidgetRef ref,
    List<app_event.Event> events,
  ) {
    final now = ref.watch(clockProvider).now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = ref.watch(adaptiveSpacingProvider);

    // Get visible holidays
    final showHolidays = ref.watch(showHolidaysInCalendarProvider);
    final allHolidays = showHolidays
        ? ref.watch(visibleHolidaysProvider)
        : <Holiday>[];

    // Group events by time period
    final pastEvents = <dynamic>[];
    final todayEvents = <dynamic>[];
    final tomorrowEvents = <dynamic>[];
    final upcomingEvents = <dynamic>[];

    for (final event in events) {
      final eventDate = DateTime(
        event.startDateTime.year,
        event.startDateTime.month,
        event.startDateTime.day,
      );
      if (event.hasEnded && eventDate.isBefore(today)) {
        pastEvents.add(event);
      } else if (eventDate.isAtSameMomentAs(today) || event.occursOn(today)) {
        todayEvents.add(event);
      } else if (eventDate.isAtSameMomentAs(tomorrow) ||
          event.occursOn(tomorrow)) {
        tomorrowEvents.add(event);
      } else if (eventDate.isAfter(tomorrow)) {
        upcomingEvents.add(event);
      }
    }

    // Add holidays
    for (final holiday in allHolidays) {
      if (holiday.occursOn(today)) {
        todayEvents.add(holiday);
      } else if (holiday.occursOn(tomorrow)) {
        tomorrowEvents.add(holiday);
      } else {
        final hDate = DateTime(
          holiday.date.year,
          holiday.date.month,
          holiday.date.day,
        );
        if (hDate.isAfter(tomorrow)) {
          upcomingEvents.add(holiday);
        }
      }
    }

    DateTime sortTime(dynamic a) {
      if (a is app_event.Event) return a.startDateTime;
      return (a as Holiday).date;
    }

    todayEvents.sort((a, b) => sortTime(a).compareTo(sortTime(b)));
    tomorrowEvents.sort((a, b) => sortTime(a).compareTo(sortTime(b)));
    upcomingEvents.sort((a, b) => sortTime(a).compareTo(sortTime(b)));
    pastEvents.sort((a, b) => sortTime(a).compareTo(sortTime(b)));

    if (todayEvents.isEmpty &&
        tomorrowEvents.isEmpty &&
        upcomingEvents.isEmpty &&
        pastEvents.isEmpty) {
      return _buildEmptyState(context, ref);
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: spacing.insets16,
      children: [
        if (todayEvents.isNotEmpty) ...[
          _sectionHeader(context, ref, 'TODAY', colorScheme),
          ...todayEvents.map(
            (e) => _buildItem(context, ref, e, theme, colorScheme),
          ),
          SizedBox(height: spacing.s16),
        ],
        if (tomorrowEvents.isNotEmpty) ...[
          _sectionHeader(context, ref, 'TOMORROW', colorScheme),
          ...tomorrowEvents.map(
            (e) => _buildItem(context, ref, e, theme, colorScheme),
          ),
          SizedBox(height: spacing.s16),
        ],
        if (upcomingEvents.isNotEmpty) ...[
          _sectionHeader(context, ref, 'UPCOMING', colorScheme),
          ...upcomingEvents.map(
            (e) => _buildItem(context, ref, e, theme, colorScheme),
          ),
          SizedBox(height: spacing.s16),
        ],
        if (pastEvents.isNotEmpty) ...[
          _sectionHeader(context, ref, 'PAST', colorScheme),
          ...pastEvents.map(
            (e) => _buildItem(context, ref, e, theme, colorScheme),
          ),
          SizedBox(height: spacing.s16),
        ],
      ],
    );
  }

  Widget _sectionHeader(
    BuildContext context,
    WidgetRef ref,
    String title,
    ColorScheme colorScheme,
  ) {
    final spacing = ref.watch(adaptiveSpacingProvider);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.s8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    WidgetRef ref,
    dynamic item,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    if (item is app_event.Event) {
      return RepaintBoundary(
        child: _buildEventCard(context, ref, item, theme, colorScheme),
      );
    } else if (item is Holiday) {
      return RepaintBoundary(
        child: _buildHolidayCard(context, ref, item, theme, colorScheme),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildEventCard(
    BuildContext context,
    WidgetRef ref,
    app_event.Event event,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final spacing = ref.watch(adaptiveSpacingProvider);
    final eventColor = event.color != null
        ? Color(event.color!)
        : colorScheme.tertiary;
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('MMM d');

    final isAllDay = event.isAllDay;
    final timeText = isAllDay
        ? 'All day'
        : '${timeFormat.format(event.startDateTime)} – ${timeFormat.format(event.endDateTime)}';
    final dateText = event.isMultiDay
        ? '${dateFormat.format(event.startDateTime)} – ${dateFormat.format(event.endDateTime)}'
        : null;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.s2),
      child: Card(
        margin: EdgeInsets.symmetric(
          horizontal: spacing.s8,
          vertical: spacing.s4,
        ),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: SpacingBorderRadius.md),
        clipBehavior: Clip.antiAlias,
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.4),
        child: InkWell(
          onTap: () => _showEditEventDialog(context, ref, event),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(width: 4, color: eventColor),
                SizedBox(width: spacing.s12),
                SizedBox(
                  width: 56,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: spacing.s12),
                    child: Text(
                      timeText,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                SizedBox(width: spacing.s8),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: spacing.s12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          event.text,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onTertiaryContainer,
                            decoration: event.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (dateText != null) ...[
                          SizedBox(height: spacing.s2),
                          Text(
                            dateText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onTertiaryContainer.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                        if (event.location != null &&
                            event.location!.isNotEmpty) ...[
                          SizedBox(height: spacing.s2),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: colorScheme.onTertiaryContainer
                                    .withValues(alpha: 0.7),
                              ),
                              SizedBox(width: spacing.s4),
                              Expanded(
                                child: Text(
                                  event.location!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onTertiaryContainer
                                        .withValues(alpha: 0.7),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(right: spacing.s12),
                  child: Icon(
                    Icons.event,
                    size: 20,
                    color: colorScheme.onTertiaryContainer.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHolidayCard(
    BuildContext context,
    WidgetRef ref,
    Holiday holiday,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final spacing = ref.watch(adaptiveSpacingProvider);
    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: spacing.s8,
        vertical: spacing.s4,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: SpacingBorderRadius.md),
      color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: spacing.insets16,
        child: Row(
          children: [
            Icon(
              Icons.celebration_outlined,
              size: 24,
              color: colorScheme.tertiary,
            ),
            SizedBox(width: spacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    holiday.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onTertiaryContainer,
                    ),
                  ),
                  SizedBox(height: spacing.s4),
                  Text(
                    holiday.endDate != null
                        ? '${DateFormat('MMM d').format(holiday.date)} - ${DateFormat('MMM d, yyyy').format(holiday.endDate!)}'
                        : DateFormat('MMM d, yyyy').format(holiday.date),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onTertiaryContainer.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditEventDialog(
    BuildContext context,
    WidgetRef ref,
    app_event.Event event,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventEditorScreen(
          event: event,
          onSave: (updatedEvent) {
            ref.read(eventControllerProvider.notifier).update(updatedEvent);
          },
        ),
      ),
    );
  }
}
