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
import '../widgets/hybrid_todo_item.dart';
import '../widgets/calendar_view.dart';
import '../widgets/filter_chips.dart';
import '../screens/task_editor_screen.dart';
import '../models/todo.dart';
import '../models/holiday.dart';
import '../theme/spacing_tokens.dart';
import '../widgets/common/common.dart';

class TodoListTab extends ConsumerWidget {
  const TodoListTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredTodos = ref.watch(filteredTasksProvider);
    final viewType = ref.watch(taskViewTypeProvider);

    return Column(
      children: [
        // Hide filters in calendar view
        if (viewType != TaskViewType.calendar) const FilterChips(),
        Expanded(
          child: ExpressiveGestureDetector(
            onPanUpdate: (details) {
              if (viewType == TaskViewType.calendar || filteredTodos.isEmpty) {
                if (details.delta.dy > 60) {
                  ref.read(searchModeProvider.notifier).state = true;
                }
              }
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (scrollNotification) {
                if (viewType == TaskViewType.list && filteredTodos.isNotEmpty) {
                  if (scrollNotification is ScrollUpdateNotification) {
                    if (scrollNotification.metrics.extentBefore <= 0) {
                      if (scrollNotification.metrics.pixels <= -120) {
                        ref.read(searchModeProvider.notifier).state = true;
                        return true;
                      }
                    }
                  }

                  if (scrollNotification is OverscrollNotification) {
                    if (scrollNotification.metrics.extentBefore <= 0) {
                      if (scrollNotification.overscroll <= -80) {
                        ref.read(searchModeProvider.notifier).state = true;
                        return true;
                      }
                    }
                  }
                }

                return false;
              },
              child: viewType == TaskViewType.calendar
                  ? CalendarView(
                      key: ValueKey(ref.watch(selectedCalendarDateProvider)),
                      tasks: filteredTodos,
                    )
                  : filteredTodos.isEmpty &&
                        !ref.watch(showHolidaysInCalendarProvider)
                  ? _buildEmptyState(
                      context,
                      ref.watch(searchQueryProvider).isNotEmpty,
                    )
                  : _buildGroupedList(context, ref, filteredTodos),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isSearching) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Icons.search : Icons.check_circle_outline,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          SpacingGap.gapV16,
          Text(
            isSearching ? 'No tasks found' : 'No tasks yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          SpacingGap.gapV8,
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

  /// Build grouped list with TODAY, TOMORROW, UPCOMING sections
  Widget _buildGroupedList(
    BuildContext context,
    WidgetRef ref,
    List<Todo> tasks,
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

    // Get all tasks with due dates
    final allTasks = tasks.where((t) => t.dueDate != null).toList();

    // Group items by time period
    final todayItems = <dynamic>[];
    final tomorrowItems = <dynamic>[];
    final upcomingItems = <dynamic>[];

    // Add tasks to groups
    for (final task in allTasks) {
      final taskDate = DateTime(
        task.dueDate!.year,
        task.dueDate!.month,
        task.dueDate!.day,
      );

      if (taskDate.isAtSameMomentAs(today)) {
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

    // Sort each group by date/time
    todayItems.sort((a, b) {
      final aTime = a is Todo ? a.dueDate! : (a as Holiday).date;
      final bTime = b is Todo ? b.dueDate! : (b as Holiday).date;
      return aTime.compareTo(bTime);
    });

    tomorrowItems.sort((a, b) {
      final aTime = a is Todo ? a.dueDate! : (a as Holiday).date;
      final bTime = b is Todo ? b.dueDate! : (b as Holiday).date;
      return aTime.compareTo(bTime);
    });

    upcomingItems.sort((a, b) {
      final aTime = a is Todo ? a.dueDate! : (a as Holiday).date;
      final bTime = b is Todo ? b.dueDate! : (b as Holiday).date;
      return aTime.compareTo(bTime);
    });

    // Check if all groups are empty
    final isEmpty =
        todayItems.isEmpty && tomorrowItems.isEmpty && upcomingItems.isEmpty;

    if (isEmpty) {
      return _buildEmptyState(
        context,
        ref.watch(searchQueryProvider).isNotEmpty,
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: SpacingEdgeInsets.insets16,
      children: [
        // TODAY section
        if (todayItems.isNotEmpty) ...[
          _buildSectionHeader(context, 'TODAY', colorScheme),
          ...todayItems.map(
            (item) => _buildListItem(context, ref, item, theme, colorScheme),
          ),
          const SizedBox(height: 16),
        ],

        // TOMORROW section
        if (tomorrowItems.isNotEmpty) ...[
          _buildSectionHeader(context, 'TOMORROW', colorScheme),
          ...tomorrowItems.map(
            (item) => _buildListItem(context, ref, item, theme, colorScheme),
          ),
          const SizedBox(height: 16),
        ],

        // UPCOMING section
        if (upcomingItems.isNotEmpty) ...[
          _buildSectionHeader(context, 'UPCOMING', colorScheme),
          ...upcomingItems.map(
            (item) => _buildListItem(context, ref, item, theme, colorScheme),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  /// Build section header
  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
    if (item is Todo) {
      final multiMode = ref.watch(multiSelectModeProvider);
      final selectedIds = ref.watch(selectedTodoIdsProvider);

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: HybridTodoItem(
          todo: item,
          onToggle: () =>
              ref.read(taskControllerProvider.notifier).toggleComplete(item.id),
          onEdit: () => _showEditDialog(context, ref, item),
          onDelete: () => _deleteTodoWithConfirmation(context, ref, item),
          selectable: multiMode,
          selected: selectedIds.contains(item.id),
          onSelectToggle: () {
            final wasMulti = ref.read(multiSelectModeProvider);
            if (!wasMulti) {
              ref.read(multiSelectModeProvider.notifier).state = true;
            }
            ref.read(selectedTodoIdsProvider.notifier).toggle(item.id);
            HapticFeedback.selectionClick();
          },
        ),
      );
    } else if (item is Holiday) {
      return _buildHolidayCard(context, ref, item, theme, colorScheme);
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
        DismissDirection.startToEnd,
        preferences.swipeRightAction,
        colorScheme,
      ),
      secondaryBackground: _buildSwipeBackground(
        context,
        DismissDirection.endToStart,
        preferences.swipeLeftAction,
        colorScheme,
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: SpacingBorderRadius.md),
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
        child: Padding(
          padding: SpacingEdgeInsets.insets16,
          child: Row(
            children: [
              Icon(
                Icons.celebration_outlined,
                size: 24,
                color: colorScheme.tertiary,
              ),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 4),
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

  /// Build swipe background
  Widget _buildSwipeBackground(
    BuildContext context,
    DismissDirection direction,
    String action,
    ColorScheme colorScheme,
  ) {
    if (action != 'delete') {
      return Container();
    }

    final isStartToEnd = direction == DismissDirection.startToEnd;

    return Container(
      alignment: isStartToEnd ? Alignment.centerLeft : Alignment.centerRight,
      padding: isStartToEnd
          ? const EdgeInsets.only(left: 20)
          : const EdgeInsets.only(right: 20),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: SpacingBorderRadius.md,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.delete, color: Colors.white, size: 28),
          SizedBox(height: 4),
          Text(
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
