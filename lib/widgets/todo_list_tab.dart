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
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../screens/home_screen_notifiers.dart';
import '../providers/filter_providers.dart';
import '../providers/app_providers.dart';
import '../providers/clock.dart';
import '../providers/holiday_providers.dart';
import '../controllers/task_controller.dart';
import '../controllers/event_controller.dart';
import '../widgets/hybrid_todo_item.dart';
import '../widgets/calendar_view.dart';
import '../widgets/filter_chips.dart';
import '../screens/task_editor_screen.dart';
import '../screens/event_editor_screen.dart';
import '../models/todo.dart';
import '../models/event.dart' as app_event;
import '../models/holiday.dart';
import '../theme/spacing_tokens.dart';
import '../widgets/common/common.dart';

class TodoListTab extends ConsumerWidget {
  const TodoListTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemFilter = ref.watch(calendarItemFilterProvider);
    final filteredTodos = itemFilter == 'events_only'
        ? <Todo>[]
        : ref.watch(filteredTasksProvider);
    final events = itemFilter == 'tasks_only'
        ? <app_event.Event>[]
        : ref.watch(filteredEventsProvider);
    // Optimize: only rebuild when viewType changes
    final viewType = ref.watch(taskViewTypeProvider.select((type) => type));

    return Column(
      children: [
        // Item type toggle (All / To-dos / Events)
        _buildItemTypeToggle(context, ref),
        // Hide filters in calendar view
        if (viewType != TaskViewType.calendar) const FilterChips(),
        Expanded(
          child: ExpressiveGestureDetector(
            onPanUpdate: (details) {
              if (viewType == TaskViewType.calendar || filteredTodos.isEmpty) {
                if (details.delta.dy > 60) {
                  ref.read(searchModeProvider.notifier).update(true);
                }
              }
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (scrollNotification) {
                if (viewType == TaskViewType.list && filteredTodos.isNotEmpty) {
                  if (scrollNotification is ScrollUpdateNotification) {
                    if (scrollNotification.metrics.extentBefore <= 0) {
                      if (scrollNotification.metrics.pixels <= -120) {
                        ref.read(searchModeProvider.notifier).update(true);
                        return true;
                      }
                    }
                  }

                  if (scrollNotification is OverscrollNotification) {
                    if (scrollNotification.metrics.extentBefore <= 0) {
                      if (scrollNotification.overscroll <= -80) {
                        ref.read(searchModeProvider.notifier).update(true);
                        return true;
                      }
                    }
                  }
                }

                return false;
              },
              child: viewType == TaskViewType.calendar
                  ? CalendarView(
                      key: ValueKey(
                        ref.watch(
                          selectedCalendarDateProvider.select((date) => date),
                        ),
                      ),
                      tasks: filteredTodos,
                      events: events,
                    )
                  : filteredTodos.isEmpty &&
                        events.isEmpty &&
                        !ref.watch(
                          showHolidaysInCalendarProvider.select((show) => show),
                        )
                  ? _buildEmptyState(
                      context,
                      ref,
                      ref.watch(
                        searchQueryProvider.select((query) => query.isNotEmpty),
                      ),
                    )
                  : _buildGroupedList(context, ref, filteredTodos, events),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    WidgetRef ref,
    bool isSearching,
  ) {
    final spacing = ref.watch(adaptiveSpacingProvider);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Icons.search : Icons.check_circle_outline,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          spacing.gapV16,
          Text(
            isSearching ? 'No tasks found' : 'No tasks yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          spacing.gapV8,
          Text(
            isSearching
                ? 'Try adjusting your search or filters'
                : 'Tap the + button to add your first task',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Todo todo) async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TaskEditorScreen(
          todo: todo,
          onSave: (updatedTodo) {
            ref.read(taskControllerProvider.notifier).update(updatedTodo);
          },
        ),
      ),
    );
  }

  void _deleteTodoWithConfirmation(
    BuildContext context,
    WidgetRef ref,
    Todo todo,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Bin'),
        content: Text(
          'Move "${todo.text}" to bin? You can restore it later from the Bin.',
        ),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ExpressiveTextButton(
            onPressed: () {
              ref.read(taskControllerProvider.notifier).delete(todo.id);
              Navigator.pop(context);
            },
            child: const Text('Move to Bin'),
          ),
        ],
      ),
    );
  }

  /// Build the All / To-dos / Events segmented toggle
  Widget _buildItemTypeToggle(BuildContext context, WidgetRef ref) {
    final current = ref.watch(calendarItemFilterProvider);
    final spacing = ref.watch(adaptiveSpacingProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.s16,
        vertical: spacing.s8,
      ),
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'all', label: Text('All')),
          ButtonSegment(value: 'tasks_only', label: Text('To-dos')),
          ButtonSegment(value: 'events_only', label: Text('Events')),
        ],
        selected: {current},
        onSelectionChanged: (newSelection) {
          ref
              .read(calendarItemFilterProvider.notifier)
              .update(newSelection.first);
        },
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.secondaryContainer;
            }
            return null;
          }),
        ),
      ),
    );
  }

  /// Build grouped list with TODAY, TOMORROW, UPCOMING sections
  Widget _buildGroupedList(
    BuildContext context,
    WidgetRef ref,
    List<Todo> tasks,
    List<app_event.Event> events,
  ) {
    final now = ref.watch(clockProvider).now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Get all visible holidays
    final showHolidays = ref.watch(showHolidaysInCalendarProvider);
    final allHolidays = showHolidays
        ? ref.watch(visibleHolidaysProvider)
        : <Holiday>[];

    // Group items by time period
    final overdueItems = <dynamic>[];
    final todayItems = <dynamic>[];
    final tomorrowItems = <dynamic>[];
    final upcomingItems = <dynamic>[];
    final noDateItems = <dynamic>[];

    // Add tasks to groups
    for (final task in tasks) {
      if (task.dueDate == null) {
        noDateItems.add(task);
        continue;
      }
      final taskDate = DateTime(
        task.dueDate!.year,
        task.dueDate!.month,
        task.dueDate!.day,
      );

      if (taskDate.isBefore(today)) {
        overdueItems.add(task);
      } else if (taskDate.isAtSameMomentAs(today)) {
        todayItems.add(task);
      } else if (taskDate.isAtSameMomentAs(tomorrow)) {
        tomorrowItems.add(task);
      } else if (taskDate.isAfter(tomorrow)) {
        upcomingItems.add(task);
      }
    }

    // Add holidays to groups
    for (final holiday in allHolidays) {
      final holidayDate = DateTime(
        holiday.date.year,
        holiday.date.month,
        holiday.date.day,
      );

      if (holiday.occursOn(today)) {
        todayItems.add(holiday);
      } else if (holiday.occursOn(tomorrow)) {
        tomorrowItems.add(holiday);
      } else if (holidayDate.isAfter(tomorrow)) {
        upcomingItems.add(holiday);
      }
    }

    // Add events to groups
    for (final event in events) {
      final eventDate = DateTime(
        event.startDateTime.year,
        event.startDateTime.month,
        event.startDateTime.day,
      );

      if (event.hasEnded && eventDate.isBefore(today)) {
        overdueItems.add(event);
      } else if (eventDate.isAtSameMomentAs(today) || event.occursOn(today)) {
        todayItems.add(event);
      } else if (eventDate.isAtSameMomentAs(tomorrow) ||
          event.occursOn(tomorrow)) {
        tomorrowItems.add(event);
      } else if (eventDate.isAfter(tomorrow)) {
        upcomingItems.add(event);
      }
    }

    // Only re-sort by time if using default or date-based sort
    // Otherwise preserve the user's selected sort order from filteredTasksProvider
    final sortBy = ref.watch(sortByProvider);
    final shouldSortByTime = sortBy == 'default' || sortBy == 'date_due';

    if (shouldSortByTime) {
      DateTime sortTime(dynamic a) {
        if (a is Todo) return a.dueDate!;
        if (a is app_event.Event) return a.startDateTime;
        return (a as Holiday).date;
      }

      // Sort each group by date/time
      overdueItems.sort((a, b) => sortTime(a).compareTo(sortTime(b)));
      todayItems.sort((a, b) => sortTime(a).compareTo(sortTime(b)));
      tomorrowItems.sort((a, b) => sortTime(a).compareTo(sortTime(b)));
      upcomingItems.sort((a, b) => sortTime(a).compareTo(sortTime(b)));
    }
    // else: keep the order from filteredTasksProvider which already applied the user's sort

    // Check if all groups are empty
    final isEmpty =
        overdueItems.isEmpty &&
        todayItems.isEmpty &&
        tomorrowItems.isEmpty &&
        upcomingItems.isEmpty &&
        noDateItems.isEmpty;

    if (isEmpty) {
      return _buildEmptyState(
        context,
        ref,
        ref.watch(searchQueryProvider).isNotEmpty,
      );
    }

    final spacing = ref.watch(adaptiveSpacingProvider);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: spacing.insets16,
      children: [
        // OVERDUE section
        if (overdueItems.isNotEmpty) ...[
          _buildSectionHeader(context, ref, 'OVERDUE', colorScheme),
          ...overdueItems.map(
            (item) => _buildListItem(context, ref, item, theme, colorScheme),
          ),
          SizedBox(height: spacing.s16),
        ],

        // TODAY section
        if (todayItems.isNotEmpty) ...[
          _buildSectionHeader(context, ref, 'TODAY', colorScheme),
          ...todayItems.map(
            (item) => _buildListItem(context, ref, item, theme, colorScheme),
          ),
          SizedBox(height: spacing.s16),
        ],

        // TOMORROW section
        if (tomorrowItems.isNotEmpty) ...[
          _buildSectionHeader(context, ref, 'TOMORROW', colorScheme),
          ...tomorrowItems.map(
            (item) => _buildListItem(context, ref, item, theme, colorScheme),
          ),
          SizedBox(height: spacing.s16),
        ],

        // UPCOMING section
        if (upcomingItems.isNotEmpty) ...[
          _buildSectionHeader(context, ref, 'UPCOMING', colorScheme),
          ...upcomingItems.map(
            (item) => _buildListItem(context, ref, item, theme, colorScheme),
          ),
          SizedBox(height: spacing.s16),
        ],

        // NO DATE section
        if (noDateItems.isNotEmpty) ...[
          _buildSectionHeader(context, ref, 'NO DATE', colorScheme),
          ...noDateItems.map(
            (item) => _buildListItem(context, ref, item, theme, colorScheme),
          ),
          SizedBox(height: spacing.s16),
        ],
      ],
    );
  }

  /// Build section header
  Widget _buildSectionHeader(
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

  /// Build list item (task or holiday)
  Widget _buildListItem(
    BuildContext context,
    WidgetRef ref,
    dynamic item,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final spacing = ref.watch(adaptiveSpacingProvider);
    if (item is Todo) {
      final multiMode = ref.watch(multiSelectModeProvider);
      final selectedIds = ref.watch(selectedTodoIdsProvider);

      // RepaintBoundary prevents unnecessary repaints during scrolling
      return RepaintBoundary(
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: spacing.isCompact ? 0 : spacing.s2,
          ),
          child: HybridTodoItem(
            todo: item,
            onToggle: () => ref
                .read(taskControllerProvider.notifier)
                .toggleComplete(item.id),
            onEdit: () => _showEditDialog(context, ref, item),
            onDelete: () => _deleteTodoWithConfirmation(context, ref, item),
            selectable: multiMode,
            selected: selectedIds.contains(item.id),
            onSelectToggle: () {
              final wasMulti = ref.read(multiSelectModeProvider);
              if (!wasMulti) {
                ref.read(multiSelectModeProvider.notifier).update(true);
              }
              ref.read(selectedTodoIdsProvider.notifier).toggle(item.id);
              HapticFeedback.selectionClick();
            },
          ),
        ),
      );
    } else if (item is Holiday) {
      // RepaintBoundary prevents unnecessary repaints during scrolling
      return RepaintBoundary(
        child: _buildHolidayCard(context, ref, item, theme, colorScheme),
      );
    } else if (item is app_event.Event) {
      return RepaintBoundary(
        child: _buildEventCard(context, ref, item, theme, colorScheme),
      );
    }
    return const SizedBox.shrink();
  }

  /// Build holiday card with swipe-to-delete
  Widget _buildHolidayCard(
    BuildContext context,
    WidgetRef ref,
    Holiday holiday,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final preferences = ref.watch(preferencesStateProvider);
    final spacing = ref.watch(adaptiveSpacingProvider);

    return Dismissible(
      key: ValueKey('holiday_${holiday.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        final action = direction == DismissDirection.startToEnd
            ? preferences.swipeRightAction
            : preferences.swipeLeftAction;

        if (action == 'delete') {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Move to Bin'),
              content: Text('Move "${holiday.name}" to bin?'),
              actions: [
                ExpressiveTextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ExpressiveTextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Move to Bin'),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            ref.read(holidaysProvider.notifier).deleteHoliday(holiday.id);
            return true;
          }
          return false;
        }
        return false;
      },
      background: _buildSwipeBackground(
        context,
        ref,
        DismissDirection.startToEnd,
        preferences.swipeRightAction,
        colorScheme,
      ),
      secondaryBackground: _buildSwipeBackground(
        context,
        ref,
        DismissDirection.endToStart,
        preferences.swipeLeftAction,
        colorScheme,
      ),
      child: Card(
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
      ),
    );
  }

  /// Build event card – time-first layout with tertiary color strip
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

    return Dismissible(
      key: ValueKey('event_${event.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        final preferences = ref.read(preferencesStateProvider);
        final action = direction == DismissDirection.startToEnd
            ? preferences.swipeRightAction
            : preferences.swipeLeftAction;

        if (action == 'delete') {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Move to Bin'),
              content: Text('Move "${event.text}" to bin?'),
              actions: [
                ExpressiveTextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ExpressiveTextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Move to Bin'),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            ref.read(eventControllerProvider.notifier).delete(event.id);
            return true;
          }
          return false;
        }
        return false;
      },
      background: _buildSwipeBackground(
        context,
        ref,
        DismissDirection.startToEnd,
        ref.read(preferencesStateProvider).swipeRightAction,
        colorScheme,
      ),
      secondaryBackground: _buildSwipeBackground(
        context,
        ref,
        DismissDirection.endToStart,
        ref.read(preferencesStateProvider).swipeLeftAction,
        colorScheme,
      ),
      child: Padding(
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
                  // Color strip on the left
                  Container(width: 4, color: eventColor),
                  SizedBox(width: spacing.s12),
                  // Time column
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
                  // Event details
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
                                color: colorScheme.onTertiaryContainer
                                    .withValues(alpha: 0.7),
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
                  // Event icon
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

  /// Build swipe background
  Widget _buildSwipeBackground(
    BuildContext context,
    WidgetRef ref,
    DismissDirection direction,
    String action,
    ColorScheme colorScheme,
  ) {
    if (action != 'delete') {
      return Container();
    }

    final spacing = ref.watch(adaptiveSpacingProvider);
    final isStartToEnd = direction == DismissDirection.startToEnd;

    return Container(
      alignment: isStartToEnd ? Alignment.centerLeft : Alignment.centerRight,
      padding: isStartToEnd
          ? EdgeInsets.only(left: spacing.s20)
          : EdgeInsets.only(right: spacing.s20),
      margin: EdgeInsets.symmetric(
        horizontal: spacing.s8,
        vertical: spacing.s4,
      ),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: SpacingBorderRadius.md,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.delete, color: Colors.white, size: 28),
          SizedBox(height: spacing.s4),
          const Text(
            'DELETE',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
