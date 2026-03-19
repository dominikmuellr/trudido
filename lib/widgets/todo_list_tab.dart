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
import '../services/folder_provider.dart';
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
    final itemTypeFilter = ref.watch(listItemTypeFilterProvider);
    final filteredTodos = itemTypeFilter == 'events_only'
        ? <Todo>[]
        : ref.watch(filteredTasksProvider);
    final events = itemTypeFilter == 'tasks_only'
        ? <app_event.Event>[]
        : ref.watch(filteredEventsProvider);
    // Optimize: only rebuild when viewType changes
    final viewType = ref.watch(taskViewTypeProvider.select((type) => type));
    final multiMode = ref.watch(multiSelectModeProvider);

    return Column(
      children: [
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
        // Bulk action bar shown when multi-select is active (not in calendar view)
        if (multiMode && viewType != TaskViewType.calendar)
          _buildBulkActionBar(context, ref, filteredTodos, events),
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

  /// Build bulk action bar for multi-select mode
  Widget _buildBulkActionBar(
    BuildContext context,
    WidgetRef ref,
    List<Todo> todos,
    List<app_event.Event> events,
  ) {
    final cs = Theme.of(context).colorScheme;
    final selectedTodoIds = ref.watch(selectedTodoIdsProvider);
    final selectedEventIds = ref.watch(selectedEventIdsProvider);
    final totalSelected = selectedTodoIds.length + selectedEventIds.length;
    final totalItems = todos.length + events.length;
    final allSelected = totalSelected == totalItems && totalItems > 0;

    return Material(
      elevation: 8,
      color: cs.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              // Select all / none
              TextButton(
                onPressed: () {
                  if (allSelected) {
                    ref.read(selectedTodoIdsProvider.notifier).clear();
                    ref.read(selectedEventIdsProvider.notifier).clear();
                  } else {
                    ref
                        .read(selectedTodoIdsProvider.notifier)
                        .selectAll(todos.map((t) => t.id));
                    ref
                        .read(selectedEventIdsProvider.notifier)
                        .selectAll(events.map((e) => e.id));
                  }
                },
                child: Text(allSelected ? 'None' : 'All'),
              ),
              Text(
                '$totalSelected selected',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: cs.onSurface),
              ),
              const Spacer(),
              // Delete
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: totalSelected == 0
                      ? cs.onSurface.withValues(alpha: 0.3)
                      : cs.error,
                ),
                tooltip: 'Move to Bin',
                onPressed: totalSelected == 0
                    ? null
                    : () => _showTasksBulkDeleteConfirmation(
                        context,
                        ref,
                        selectedTodoIds,
                        selectedEventIds,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTasksBulkDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    Set<String> todoIds,
    Set<String> eventIds,
  ) async {
    final count = todoIds.length + eventIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to Bin'),
        content: Text(
          'Move $count selected ${count == 1 ? 'item' : 'items'} to bin? You can restore them later.',
        ),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Move to Bin'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (todoIds.isNotEmpty) {
        await ref.read(taskControllerProvider.notifier).bulkDelete(todoIds);
      }
      if (eventIds.isNotEmpty) {
        await ref.read(eventControllerProvider.notifier).bulkDelete(eventIds);
      }
      ref.read(selectedTodoIdsProvider.notifier).clear();
      ref.read(selectedEventIdsProvider.notifier).clear();
      ref.read(multiSelectModeProvider.notifier).update(false);
    }
  }

  /// Build grouped list with TODAY, ANYTIME, SCHEDULED sections
  Widget _buildGroupedList(
    BuildContext context,
    WidgetRef ref,
    List<Todo> tasks,
    List<app_event.Event> events,
  ) {
    final now = ref.watch(clockProvider).now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final endOfWeek = today.add(Duration(days: 7 - today.weekday));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Get all visible holidays
    final showHolidays = ref.watch(showHolidaysInCalendarProvider);
    final allHolidays = showHolidays
        ? ref.watch(visibleHolidaysProvider)
        : <Holiday>[];

    // === TODAY: overdue todos + today's todos + today's events ===
    final todayTodos = <Todo>[];
    final todayEvents = <app_event.Event>[];
    final todayHolidays = <Holiday>[];

    // === ANYTIME: no-date todos + future todos (todos only) ===
    final anytimeTodos = <Todo>[];

    // === SCHEDULED: future events grouped by time period (events only) ===
    final scheduledTomorrow = <dynamic>[];
    final scheduledThisWeek = <dynamic>[];
    final scheduledLater = <dynamic>[];

    // Categorize tasks
    for (final task in tasks) {
      if (task.dueDate == null) {
        anytimeTodos.add(task);
        continue;
      }
      final taskDate = DateTime(
        task.dueDate!.year,
        task.dueDate!.month,
        task.dueDate!.day,
      );

      if (taskDate.isBefore(today) || taskDate.isAtSameMomentAs(today)) {
        // Overdue or due today → TODAY section
        todayTodos.add(task);
      } else {
        // Future todos → ANYTIME section
        anytimeTodos.add(task);
      }
    }

    // Categorize events
    for (final event in events) {
      // Multi-day events appear in TODAY as long as any day spans today
      if (event.occursOn(today)) {
        todayEvents.add(event);
      } else if (event.hasEnded) {
        // Ended event that doesn't occur today — skip (already past)
      } else if (event.occursOn(tomorrow)) {
        scheduledTomorrow.add(event);
      } else {
        final eventDate = DateTime(
          event.startDateTime.year,
          event.startDateTime.month,
          event.startDateTime.day,
        );
        if (eventDate.isAfter(tomorrow) && !eventDate.isAfter(endOfWeek)) {
          scheduledThisWeek.add(event);
        } else if (eventDate.isAfter(endOfWeek)) {
          scheduledLater.add(event);
        }
      }
    }

    // Categorize holidays
    for (final holiday in allHolidays) {
      if (holiday.occursOn(today)) {
        todayHolidays.add(holiday);
      } else if (holiday.occursOn(tomorrow)) {
        scheduledTomorrow.add(holiday);
      } else {
        final holidayDate = DateTime(
          holiday.date.year,
          holiday.date.month,
          holiday.date.day,
        );
        if (holidayDate.isAfter(tomorrow) && !holidayDate.isAfter(endOfWeek)) {
          scheduledThisWeek.add(holiday);
        } else if (holidayDate.isAfter(endOfWeek)) {
          scheduledLater.add(holiday);
        }
      }
    }

    // Sort within sections
    // TODAY: all-day events first, then by start time, then todos by due date
    todayEvents.sort((a, b) {
      if (a.isAllDay && !b.isAllDay) return -1;
      if (!a.isAllDay && b.isAllDay) return 1;
      return a.startDateTime.compareTo(b.startDateTime);
    });
    todayTodos.sort((a, b) {
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    });
    // ANYTIME: no-date first, then future by due date
    anytimeTodos.sort((a, b) {
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return -1;
      if (b.dueDate == null) return 1;
      return a.dueDate!.compareTo(b.dueDate!);
    });

    // SCHEDULED: all-day events first, then chronological
    int scheduledCompare(dynamic a, dynamic b) {
      final aIsAllDay = a is app_event.Event && a.isAllDay;
      final bIsAllDay = b is app_event.Event && b.isAllDay;
      if (aIsAllDay && !bIsAllDay) return -1;
      if (!aIsAllDay && bIsAllDay) return 1;
      final aTime = a is app_event.Event
          ? a.startDateTime
          : (a as Holiday).date;
      final bTime = b is app_event.Event
          ? b.startDateTime
          : (b as Holiday).date;
      return aTime.compareTo(bTime);
    }

    scheduledTomorrow.sort(scheduledCompare);
    scheduledThisWeek.sort(scheduledCompare);
    scheduledLater.sort(scheduledCompare);

    // Check if all sections are empty
    final hasTodaySection =
        todayTodos.isNotEmpty ||
        todayEvents.isNotEmpty ||
        todayHolidays.isNotEmpty;
    final hasScheduledSection =
        scheduledTomorrow.isNotEmpty ||
        scheduledThisWeek.isNotEmpty ||
        scheduledLater.isNotEmpty;
    final isEmpty =
        !hasTodaySection && anytimeTodos.isEmpty && !hasScheduledSection;

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
        // TODAY section
        if (hasTodaySection) ...[
          _buildSectionHeader(
            context,
            ref,
            'TODAY',
            Icons.push_pin_outlined,
            colorScheme.primary,
          ),
          // Today's holidays
          ...todayHolidays.map(
            (holiday) => RepaintBoundary(
              child: _buildHolidayCard(
                context,
                ref,
                holiday,
                theme,
                colorScheme,
              ),
            ),
          ),
          // Today's events as compact one-liners
          ...todayEvents.map(
            (event) => RepaintBoundary(
              child: _buildCompactEventCard(
                context,
                ref,
                event,
                theme,
                colorScheme,
              ),
            ),
          ),
          // Today's todos (including overdue)
          ...todayTodos.map(
            (todo) => _buildListItem(context, ref, todo, theme, colorScheme),
          ),
          SizedBox(height: spacing.s16),
        ],

        // ANYTIME section
        if (anytimeTodos.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            ref,
            'ANYTIME',
            Icons.all_inbox_outlined,
            colorScheme.onSurfaceVariant,
          ),
          ...anytimeTodos.map(
            (todo) => _buildListItem(context, ref, todo, theme, colorScheme),
          ),
          SizedBox(height: spacing.s16),
        ],

        // SCHEDULED section
        if (hasScheduledSection) ...[
          _buildSectionHeader(
            context,
            ref,
            'SCHEDULED',
            Icons.calendar_month_outlined,
            colorScheme.tertiary,
          ),
          // Tomorrow sub-group
          if (scheduledTomorrow.isNotEmpty) ...[
            _buildSubHeader(context, ref, 'Tomorrow'),
            ...scheduledTomorrow.map(
              (item) => _buildListItem(context, ref, item, theme, colorScheme),
            ),
          ],
          // This Week sub-group
          if (scheduledThisWeek.isNotEmpty) ...[
            _buildSubHeader(context, ref, 'This Week'),
            ...scheduledThisWeek.map(
              (item) => _buildListItem(context, ref, item, theme, colorScheme),
            ),
          ],
          // Later sub-group
          if (scheduledLater.isNotEmpty) ...[
            _buildSubHeader(context, ref, 'Later'),
            ...scheduledLater.map(
              (item) => _buildListItem(context, ref, item, theme, colorScheme),
            ),
          ],
          SizedBox(height: spacing.s16),
        ],
      ],
    );
  }

  /// Build section header with icon and color
  Widget _buildSectionHeader(
    BuildContext context,
    WidgetRef ref,
    String title,
    IconData icon,
    Color color,
  ) {
    final spacing = ref.watch(adaptiveSpacingProvider);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.s8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: spacing.s8),
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Build sub-header for SCHEDULED time groups
  Widget _buildSubHeader(BuildContext context, WidgetRef ref, String title) {
    final spacing = ref.watch(adaptiveSpacingProvider);
    return Padding(
      padding: EdgeInsets.only(
        top: spacing.s8,
        bottom: spacing.s4,
        left: spacing.s4,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
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
      final multiMode = ref.watch(multiSelectModeProvider);
      final selectedEventIds = ref.watch(selectedEventIdsProvider);
      return RepaintBoundary(
        child: _buildEventCard(
          context,
          ref,
          item,
          theme,
          colorScheme,
          selectable: multiMode,
          selected: selectedEventIds.contains(item.id),
          onSelectToggle: () {
            if (!ref.read(multiSelectModeProvider)) {
              ref.read(multiSelectModeProvider.notifier).update(true);
            }
            ref.read(selectedEventIdsProvider.notifier).toggle(item.id);
            HapticFeedback.selectionClick();
          },
        ),
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

  /// Build compact event card for TODAY section – one-liner with time + title
  /// Resolve event dot color: folder color > event color > tertiary
  Color _getEventDotColor(
    WidgetRef ref,
    app_event.Event event,
    ColorScheme colorScheme,
  ) {
    if (event.folderId != null) {
      final folder = ref.watch(folderByIdProvider(event.folderId!));
      if (folder != null) return Color(folder.color);
    }
    if (event.color != null) return Color(event.color!);
    return colorScheme.tertiary;
  }

  Widget _buildCompactEventCard(
    BuildContext context,
    WidgetRef ref,
    app_event.Event event,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final spacing = ref.watch(adaptiveSpacingProvider);
    final preferences = ref.watch(preferencesStateProvider);
    final dotColor = _getEventDotColor(ref, event, colorScheme);
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('MMM d');
    final String timeText;
    if (event.isMultiDay) {
      timeText =
          '${dateFormat.format(event.startDateTime)} – ${dateFormat.format(event.endDateTime)}';
    } else if (event.isAllDay) {
      timeText = 'All day';
    } else {
      timeText = timeFormat.format(event.startDateTime);
    }

    final cardContent = Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.s2),
      child: InkWell(
        onTap: () {
          final multiMode = ref.read(multiSelectModeProvider);
          if (multiMode) {
            if (!ref.read(multiSelectModeProvider)) {
              ref.read(multiSelectModeProvider.notifier).update(true);
            }
            ref.read(selectedEventIdsProvider.notifier).toggle(event.id);
            HapticFeedback.selectionClick();
          } else {
            _showEditEventDialog(context, ref, event);
          }
        },
        onLongPress: () {
          final multiMode = ref.read(multiSelectModeProvider);
          if (!multiMode) {
            ref.read(multiSelectModeProvider.notifier).update(true);
          }
          ref.read(selectedEventIdsProvider.notifier).toggle(event.id);
          HapticFeedback.selectionClick();
        },
        borderRadius: SpacingBorderRadius.sm,
        child: Builder(
          builder: (context) {
            final multiMode = ref.watch(multiSelectModeProvider);
            final selectedEventIds = ref.watch(selectedEventIdsProvider);
            final isSelected = selectedEventIds.contains(event.id);
            return Stack(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing.s12,
                    vertical: spacing.s8,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: spacing.s8),
                      Flexible(
                        flex: 0,
                        child: Text(
                          timeText,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(width: spacing.s8),
                      Expanded(
                        child: Text(
                          event.text,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (event.location != null && event.location!.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(left: spacing.s8),
                          child: Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      if (multiMode)
                        Padding(
                          padding: EdgeInsets.only(left: spacing.s8),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 120),
                            child: isSelected
                                ? Icon(
                                    Icons.check_circle,
                                    key: const ValueKey('chk'),
                                    size: 18,
                                    color: colorScheme.primary,
                                  )
                                : Icon(
                                    Icons.radio_button_unchecked,
                                    key: const ValueKey('unchk'),
                                    size: 18,
                                    color: colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.5),
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (multiMode && isSelected)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: SpacingBorderRadius.sm,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );

    final multiMode = ref.watch(multiSelectModeProvider);
    return Dismissible(
      key: ValueKey('compact_event_${event.id}'),
      direction: multiMode
          ? DismissDirection.none
          : DismissDirection.horizontal,
      confirmDismiss: (direction) async {
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
      child: cardContent,
    );
  }

  /// Build event card – time-first layout with tertiary color strip
  Widget _buildEventCard(
    BuildContext context,
    WidgetRef ref,
    app_event.Event event,
    ThemeData theme,
    ColorScheme colorScheme, {
    bool selectable = false,
    bool selected = false,
    VoidCallback? onSelectToggle,
  }) {
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
      direction: selectable
          ? DismissDirection.none
          : DismissDirection.horizontal,
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
        child: Stack(
          children: [
            Card(
              margin: EdgeInsets.symmetric(
                horizontal: spacing.s8,
                vertical: spacing.s4,
              ),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: SpacingBorderRadius.md,
              ),
              clipBehavior: Clip.antiAlias,
              color: colorScheme.tertiaryContainer.withValues(alpha: 0.4),
              child: InkWell(
                onTap: selectable
                    ? onSelectToggle
                    : () => _showEditEventDialog(context, ref, event),
                onLongPress: selectable ? null : onSelectToggle,
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
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: colorScheme
                                                  .onTertiaryContainer
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
                      // Checkbox in select mode, otherwise event icon
                      Padding(
                        padding: EdgeInsets.only(right: spacing.s12),
                        child: selectable
                            ? AnimatedSwitcher(
                                duration: const Duration(milliseconds: 120),
                                child: selected
                                    ? Icon(
                                        Icons.check_circle,
                                        key: const ValueKey('chk'),
                                        size: 20,
                                        color: colorScheme.primary,
                                      )
                                    : Icon(
                                        Icons.radio_button_unchecked,
                                        key: const ValueKey('unchk'),
                                        size: 20,
                                        color: colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.5),
                                      ),
                              )
                            : Icon(
                                Icons.event,
                                size: 20,
                                color: colorScheme.onTertiaryContainer
                                    .withValues(alpha: 0.5),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Selection highlight overlay
            if (selectable && selected)
              Positioned(
                left: spacing.s8,
                right: spacing.s8,
                top: spacing.s4,
                bottom: spacing.s4,
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: SpacingBorderRadius.md,
                    border: Border.all(color: colorScheme.primary, width: 2),
                  ),
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
      child: const Icon(Icons.delete, color: Colors.white, size: 24),
    );
  }
}
