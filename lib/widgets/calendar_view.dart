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
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';
import '../models/event.dart' as app_event;
import '../screens/task_editor_screen.dart';
import '../screens/event_editor_screen.dart';
import '../controllers/task_controller.dart';
import '../controllers/event_controller.dart';
import '../providers/filter_providers.dart';
import '../providers/app_providers.dart';
import '../providers/clock.dart';
import '../providers/holiday_providers.dart';
import '../services/folder_provider.dart';
import '../utils/week_start_utils.dart';
import '../utils/date_formatters.dart';
import 'hybrid_todo_item.dart';
import '../theme/spacing_tokens.dart';
import '../widgets/common/common.dart';

/// Custom calendar format that extends table_calendar formats
enum CustomCalendarFormat {
  month,
  twoWeeks,
  week,
  day, // Custom day view
}

/// Material Design 3 Calendar View for Tasks
/// Shows tasks in a beautiful calendar layout with proper Material theming
class CalendarView extends ConsumerStatefulWidget {
  final List<Todo> tasks;
  final List<app_event.Event> events;

  const CalendarView({super.key, required this.tasks, this.events = const []});

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  DateTime? _lastTappedDay;
  DateTime _lastTapTime = DateTime.now().subtract(const Duration(seconds: 1));

  // Convert custom format to table_calendar format
  CalendarFormat get _calendarFormat {
    // Optimize: only rebuild when the format value changes
    final customFormat = ref.watch(calendarFormatProvider.select((fmt) => fmt));
    switch (customFormat) {
      case CustomCalendarFormat.month:
        return CalendarFormat.month;
      case CustomCalendarFormat.twoWeeks:
        return CalendarFormat.twoWeeks;
      case CustomCalendarFormat.week:
      case CustomCalendarFormat.day:
        return CalendarFormat.week;
    }
  }

  /// Calculate responsive extra padding based on screen width
  /// Smaller screens need less padding, larger screens need more
  double _getResponsiveExtraPadding(
    BuildContext context,
    CustomCalendarFormat fmt,
  ) {
    final width = MediaQuery.of(context).size.width;

    // Base padding values - increased to prevent sub-pixel overflow
    double basePadding;
    if (fmt == CustomCalendarFormat.month) {
      basePadding = 16.0;
    } else if (fmt == CustomCalendarFormat.twoWeeks) {
      basePadding = 14.0;
    } else {
      basePadding = 8.0;
    }

    // Scale padding based on screen width
    // For screens wider than 400px, add extra padding proportionally
    if (width > 400) {
      final widthFactor = (width - 400) / 400;
      basePadding += widthFactor * 4.0; // Add up to 4px for very wide screens
    }

    return basePadding;
  }

  double _heightForFormat(BuildContext context, CustomCalendarFormat fmt) {
    final width = MediaQuery.of(context).size.width;
    final cellHeight = (width - 32) / 7;
    const headerHeight = 52.0;
    const daysOfWeekHeight = 24.0;

    // For day view, return a taller height for the timetable
    if (fmt == CustomCalendarFormat.day) {
      return MediaQuery.of(context).size.height * 0.7; // 70% of screen height
    }

    final rows = fmt == CustomCalendarFormat.month
        ? 6
        : fmt == CustomCalendarFormat.twoWeeks
        ? 2
        : 1;

    // Use responsive padding to prevent overflow across different screen sizes
    final extraPadding = _getResponsiveExtraPadding(context, fmt);
    // Add 30px buffer for table_calendar internal padding variance between month configurations
    return headerHeight +
        daysOfWeekHeight +
        rows * cellHeight +
        extraPadding +
        30;
  }

  Widget _buildDayTimetable(BuildContext context, ColorScheme colorScheme) {
    final prefs = ref.watch(preferencesStateProvider);
    final use24Hour = prefs.resolveUse24Hour(
      MediaQuery.of(context).alwaysUse24HourFormat,
    );
    final dayTasks = _selectedDay != null
        ? _getTasksForDay(_selectedDay!)
        : _getTasksForDay(_focusedDay);

    // Separate all-day tasks (tasks with time 00:00:00 or no specific time)
    final allDayTasks = dayTasks.where((task) {
      if (task.dueDate == null) return false;
      // Consider tasks at midnight as all-day tasks
      return task.dueDate!.hour == 0 &&
          task.dueDate!.minute == 0 &&
          task.dueDate!.second == 0;
    }).toList();

    // Get tasks with specific times
    final timedTasks = dayTasks.where((task) {
      if (task.dueDate == null) return false;
      // Exclude all-day tasks
      return !(task.dueDate!.hour == 0 &&
          task.dueDate!.minute == 0 &&
          task.dueDate!.second == 0);
    }).toList();

    return Column(
      children: [
        // Header with date, navigation, and format button - matching TableCalendar layout
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              // Left chevron
              ExpressiveIconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _focusedDay = _focusedDay.subtract(const Duration(days: 1));
                    _selectedDay = _focusedDay;
                  });
                },
              ),
              // Centered date title
              Expanded(
                child: Text(
                  DateFormat.yMMMMd().format(_selectedDay ?? _focusedDay),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              // Format button (positioned before right chevron)
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: SpacingBorderRadius.md,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ExpressiveInkWell(
                    borderRadius: SpacingBorderRadius.md,
                    onTap: _cycleCalendarFormat,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        'Day',
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SpacingGap.gapH8,
              // Right chevron
              ExpressiveIconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _focusedDay = _focusedDay.add(const Duration(days: 1));
                    _selectedDay = _focusedDay;
                  });
                },
              ),
            ],
          ),
        ), // Container
        // All-day tasks section
        if (allDayTasks.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All-day',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                SpacingGap.gapV8,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allDayTasks.map((task) {
                    return ExpressiveInkWell(
                      onTap: () => _editTask(context, task),
                      onLongPress: () {
                        // Show confirmation dialog before deleting
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Task'),
                            content: Text('Delete "${task.text}"?'),
                            actions: [
                              ExpressiveTextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              ExpressiveTextButton(
                                onPressed: () {
                                  ref
                                      .read(taskControllerProvider.notifier)
                                      .delete(task.id);
                                  Navigator.pop(context);
                                },
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getColorForPriority(
                            task.priority,
                            colorScheme,
                          ).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getColorForPriority(
                              task.priority,
                              colorScheme,
                            ),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          task.text,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ), // Container
        // Timetable
        Expanded(
          child: SingleChildScrollView(
            child: _buildTimedTasksGrid(
              context,
              colorScheme,
              timedTasks,
              use24Hour,
            ),
          ),
        ),
      ], // Column children
    ); // Column - end of day timetable
  }

  Widget _buildTimedTasksGrid(
    BuildContext context,
    ColorScheme colorScheme,
    List<Todo> timedTasks,
    bool use24Hour,
  ) {
    const hourHeight = 60.0; // Height per hour
    const totalHeight = 24 * hourHeight; // Total height for 24 hours
    const leftMargin = 70.0; // Space for time labels

    // Calculate layout for tasks considering overlaps
    final taskLayouts = _calculateTaskLayouts(timedTasks, hourHeight);

    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: [
          // Hour grid lines and labels
          Column(
            children: List.generate(24, (hour) {
              return Container(
                height: hourHeight,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time label
                    SizedBox(
                      width: leftMargin - 10,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          DateFormatters.formatHourLabel(
                            hour,
                            use24Hour: use24Hour,
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: Container()),
                  ],
                ),
              );
            }),
          ),
          // Tasks positioned based on their start time, duration, and overlaps
          ...taskLayouts.map((layout) {
            final task = layout.task;
            return Positioned(
              left: leftMargin + layout.leftOffset,
              top: layout.topPosition,
              width: layout.width,
              child: GestureDetector(
                onTap: () => _editTask(context, task),
                onLongPress: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Task'),
                      content: Text('Delete "${task.text}"?'),
                      actions: [
                        ExpressiveTextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        ExpressiveTextButton(
                          onPressed: () {
                            ref
                                .read(taskControllerProvider.notifier)
                                .delete(task.id);
                            Navigator.pop(context);
                          },
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
                child: Container(
                  height: layout.height,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 2,
                  ),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getColorForPriority(
                      task.priority,
                      colorScheme,
                    ).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getColorForPriority(task.priority, colorScheme),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        task.text,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (task.dueDate != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          DateFormatters.formatTime(
                            task.dueDate!,
                            use24Hour: use24Hour,
                          ),
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (task.durationMinutes != null) ...[
                          const SizedBox(height: 1),
                          Text(
                            _formatDuration(task.durationMinutes!),
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  List<_TaskLayout> _calculateTaskLayouts(List<Todo> tasks, double hourHeight) {
    if (tasks.isEmpty) return [];

    // Create task info with time ranges
    final taskInfos = tasks.where((task) => task.dueDate != null).map((task) {
      final startMinutes = task.dueDate!.hour * 60 + task.dueDate!.minute;
      final durationMinutes = task.durationMinutes ?? 30;
      final endMinutes = startMinutes + durationMinutes;
      return _TaskInfo(
        task: task,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
      );
    }).toList()..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    // Calculate available width
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 70 - 16;

    final layouts = <_TaskLayout>[];

    // Process each task
    for (int i = 0; i < taskInfos.length; i++) {
      final currentTask = taskInfos[i];

      // Find all tasks that overlap with current task
      final overlappingTasks = <_TaskInfo>[];
      for (int j = 0; j < taskInfos.length; j++) {
        final otherTask = taskInfos[j];
        // Tasks overlap if one starts before the other ends
        if (currentTask.startMinutes < otherTask.endMinutes &&
            otherTask.startMinutes < currentTask.endMinutes) {
          overlappingTasks.add(otherTask);
        }
      }

      // Find which column this task should be in
      int column = 0;
      final usedColumns = <int>{};
      for (final other in overlappingTasks) {
        if (other.task.id == currentTask.task.id) continue;

        // Check if this overlapping task is before current task
        if (other.startMinutes < currentTask.startMinutes ||
            (other.startMinutes == currentTask.startMinutes &&
                taskInfos.indexOf(other) < i)) {
          // Find which column it was assigned to
          final otherLayout = layouts.firstWhere(
            (l) => l.task.id == other.task.id,
            orElse: () => _TaskLayout(
              task: other.task,
              topPosition: 0,
              height: 0,
              leftOffset: 0,
              width: 0,
              column: 0,
            ),
          );
          usedColumns.add(otherLayout.column);
        }
      }

      // Find first available column
      while (usedColumns.contains(column)) {
        column++;
      }

      // Calculate max columns needed for this group
      final maxColumns = overlappingTasks.length;
      // Make tasks half width so more fit side-by-side
      final columnWidth = availableWidth / (maxColumns * 2);

      layouts.add(
        _TaskLayout(
          task: currentTask.task,
          topPosition: (currentTask.startMinutes / 60) * hourHeight,
          height:
              ((currentTask.endMinutes - currentTask.startMinutes) / 60) *
              hourHeight,
          leftOffset: column * columnWidth,
          width: columnWidth,
          column: column,
        ),
      );
    }

    return layouts;
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) {
      return '${mins}m';
    } else if (mins == 0) {
      return '${hours}h';
    } else {
      return '${hours}h ${mins}m';
    }
  }

  void _cycleCalendarFormat() {
    final currentFormat = ref.read(calendarFormatProvider);
    switch (currentFormat) {
      case CustomCalendarFormat.month:
        ref
            .read(calendarFormatProvider.notifier)
            .setFormat(CustomCalendarFormat.twoWeeks);
        break;
      case CustomCalendarFormat.twoWeeks:
        ref
            .read(calendarFormatProvider.notifier)
            .setFormat(CustomCalendarFormat.week);
        break;
      case CustomCalendarFormat.week:
        ref
            .read(calendarFormatProvider.notifier)
            .setFormat(CustomCalendarFormat.day);
        break;
      case CustomCalendarFormat.day:
        ref
            .read(calendarFormatProvider.notifier)
            .setFormat(CustomCalendarFormat.month);
        break;
    }
  }

  Color _getColorForPriority(String priority, ColorScheme colorScheme) {
    switch (priority.toLowerCase()) {
      case 'high':
        return colorScheme.error;
      case 'medium':
        return colorScheme.secondary;
      case 'low':
        return colorScheme.tertiary;
      default:
        return colorScheme.outline;
    }
  }

  /// Resolve event marker color: folder color > event color > tertiary
  Color _getEventMarkerColor(app_event.Event event, ColorScheme colorScheme) {
    if (event.folderId != null) {
      final folder = ref.watch(folderByIdProvider(event.folderId!));
      if (folder != null) return Color(folder.color);
    }
    if (event.color != null) return Color(event.color!);
    return colorScheme.tertiary;
  }

  /// Check if a recurring task should appear on a specific date
  bool _shouldRecurringTaskAppearOnDate(Todo task, DateTime date) {
    if (!task.isRecurring || task.dueDate == null) return false;

    final targetDate = DateTime(date.year, date.month, date.day);
    final startDate = DateTime(
      task.dueDate!.year,
      task.dueDate!.month,
      task.dueDate!.day,
    );

    // Don't show before the start date
    if (targetDate.isBefore(startDate)) return false;

    // Don't show after the end date
    if (task.repeatEndDate != null) {
      final endDate = DateTime(
        task.repeatEndDate!.year,
        task.repeatEndDate!.month,
        task.repeatEndDate!.day,
      );
      if (targetDate.isAfter(endDate)) return false;
    }

    switch (task.repeatType) {
      case 'daily':
        final interval = task.repeatInterval ?? 1;
        final daysDiff = targetDate.difference(startDate).inDays;
        return daysDiff >= 0 && daysDiff % interval == 0;

      case 'weekly':
        final interval = task.repeatInterval ?? 1;
        final daysOfWeek = task.repeatDays ?? [task.dueDate!.weekday];

        // Check if this day of week matches
        if (!daysOfWeek.contains(targetDate.weekday)) return false;

        // Check if we're in the correct week interval
        final weeksDiff = targetDate.difference(startDate).inDays ~/ 7;
        return weeksDiff % interval == 0;

      case 'monthly':
        final interval = task.repeatInterval ?? 1;
        final monthsDiff =
            (targetDate.year - startDate.year) * 12 +
            (targetDate.month - startDate.month);

        // Check if we're in the correct month interval
        if (monthsDiff < 0 || monthsDiff % interval != 0) return false;

        // Check if the day matches (or is last day of month)
        return targetDate.day == startDate.day ||
            (targetDate.day ==
                    DateTime(targetDate.year, targetDate.month + 1, 0).day &&
                startDate.day > targetDate.day);

      case 'custom':
        // Custom with specific days (weekly pattern)
        if (task.repeatDays != null && task.repeatDays!.isNotEmpty) {
          final interval = task.repeatInterval ?? 1;
          final daysOfWeek = task.repeatDays!;

          if (!daysOfWeek.contains(targetDate.weekday)) return false;

          final weeksDiff = targetDate.difference(startDate).inDays ~/ 7;
          return weeksDiff % interval == 0;
        } else {
          // Custom daily pattern
          final interval = task.repeatInterval ?? 1;
          final daysDiff = targetDate.difference(startDate).inDays;
          return daysDiff >= 0 && daysDiff % interval == 0;
        }

      default:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    // Read the selected date from provider, or use today if not set
    final selectedDate = ref.read(selectedCalendarDateProvider);
    final now = ref.read(clockProvider).now();

    if (selectedDate != null) {
      // Use the date from the provider (set by compact calendar or other sources)
      _focusedDay = selectedDate;
      _selectedDay = selectedDate;
    } else {
      // Default to today
      _focusedDay = now;
      _selectedDay = now;
      // Initialize the provider with today's date
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedCalendarDateProvider.notifier).update(_selectedDay);
      });
    }
  }

  /// Get tasks for a specific day
  List<Todo> _getTasksForDay(DateTime day) {
    return widget.tasks.where((task) {
      if (task.dueDate == null) return false;

      // For recurring tasks, check if they should appear on this day
      if (task.isRecurring && !task.isCompleted) {
        return _shouldRecurringTaskAppearOnDate(task, day);
      }

      // For multi-day tasks, check if day falls within range
      if (task.startDate != null) {
        final startDate = DateTime(
          task.startDate!.year,
          task.startDate!.month,
          task.startDate!.day,
        );
        final endDate = DateTime(
          task.dueDate!.year,
          task.dueDate!.month,
          task.dueDate!.day,
        );
        final checkDate = DateTime(day.year, day.month, day.day);

        return checkDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
            checkDate.isBefore(endDate.add(const Duration(days: 1)));
      }

      // For single-day tasks
      final taskDate = DateTime(
        task.dueDate!.year,
        task.dueDate!.month,
        task.dueDate!.day,
      );
      final checkDate = DateTime(day.year, day.month, day.day);
      return taskDate.isAtSameMomentAs(checkDate);
    }).toList();
  }

  /// Get task and event count indicators for calendar markers
  Map<DateTime, List<Object>> _getItemsGroupedByDay() {
    final Map<DateTime, List<Object>> itemMap = {};

    // Get the visible date range from the calendar
    final startOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final endOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

    // Extend to show full weeks
    final calendarStart = startOfMonth.subtract(
      Duration(days: startOfMonth.weekday - 1),
    );
    final calendarEnd = endOfMonth.add(Duration(days: 7 - endOfMonth.weekday));

    for (final task in widget.tasks) {
      if (task.dueDate == null) continue;

      // Handle recurring tasks
      if (task.isRecurring && !task.isCompleted) {
        // Add task to all days in the visible range where it should appear
        for (
          DateTime date = calendarStart;
          date.isBefore(calendarEnd.add(const Duration(days: 1)));
          date = date.add(const Duration(days: 1))
        ) {
          if (_shouldRecurringTaskAppearOnDate(task, date)) {
            itemMap[date] = itemMap[date] ?? [];
            itemMap[date]!.add(task);
          }
        }
      } else if (task.startDate != null) {
        // Multi-day task - add to all days in range
        final startDate = DateTime(
          task.startDate!.year,
          task.startDate!.month,
          task.startDate!.day,
        );
        final endDate = DateTime(
          task.dueDate!.year,
          task.dueDate!.month,
          task.dueDate!.day,
        );

        for (
          DateTime date = startDate;
          !date.isAfter(endDate);
          date = date.add(const Duration(days: 1))
        ) {
          itemMap[date] = itemMap[date] ?? [];
          itemMap[date]!.add(task);
        }
      } else {
        // Single-day task
        final taskDate = DateTime(
          task.dueDate!.year,
          task.dueDate!.month,
          task.dueDate!.day,
        );
        itemMap[taskDate] = itemMap[taskDate] ?? [];
        itemMap[taskDate]!.add(task);
      }
    }

    // Add events - multi-day events appear on all days they span
    for (final event in widget.events) {
      if (event.isDeleted) continue;
      final startDate = DateTime(
        event.startDateTime.year,
        event.startDateTime.month,
        event.startDateTime.day,
      );
      final endDate = DateTime(
        event.endDateTime.year,
        event.endDateTime.month,
        event.endDateTime.day,
      );

      for (
        DateTime date = startDate;
        !date.isAfter(endDate);
        date = date.add(const Duration(days: 1))
      ) {
        itemMap[date] = itemMap[date] ?? [];
        itemMap[date]!.add(event);
      }
    }

    return itemMap;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedDayTasks = _selectedDay != null
        ? _getTasksForDay(_selectedDay!)
        : <Todo>[];
    final selectedDayEvents = _selectedDay != null
        ? _getEventsForDay(_selectedDay!)
        : <app_event.Event>[];
    final totalSelectedDayItems =
        selectedDayTasks.length + selectedDayEvents.length;
    // Optimize: only rebuild when format value changes
    final customFormat = ref.watch(calendarFormatProvider.select((fmt) => fmt));

    // Optimize: only rebuild when import flag changes
    final showImported = ref.watch(
      showImportedEventsInCalendarProvider.select((show) => show),
    );

    return SingleChildScrollView(
      child: Column(
        children: [
          // Calendar Widget - Animated height based on format
          AnimatedContainer(
            key: ValueKey(customFormat),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOutCubicEmphasized,
            height: _heightForFormat(context, customFormat) + 10,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(1.0)),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Use consistent small font size for all months to prevent overflow
                    const headerFontSize = 16.0;

                    // Show day timetable when format is day, otherwise show calendar
                    if (customFormat == CustomCalendarFormat.day) {
                      return _buildDayTimetable(context, colorScheme);
                    }

                    return TableCalendar<Object>(
                      key: ValueKey(
                        'calendar_${_focusedDay.month}_${_focusedDay.year}',
                      ),
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDay, day),
                      calendarFormat: _calendarFormat,
                      startingDayOfWeek: WeekStartUtils.toTableCalendarDay(
                        ref.watch(
                          preferencesStateProvider.select(
                            (prefs) => prefs.firstDayOfWeek,
                          ),
                        ),
                      ),
                      // Long-press on a day to create a new task prefilled with that date
                      onDayLongPressed: (selectedDay, focusedDay) {
                        final dateOnly = DateTime(
                          selectedDay.year,
                          selectedDay.month,
                          selectedDay.day,
                        );
                        // Update provider so editor can prefill the date
                        ref
                            .read(selectedCalendarDateProvider.notifier)
                            .update(dateOnly);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TaskEditorScreen(
                              presetDueDate: dateOnly,
                              onSave: (t) => ref
                                  .read(taskControllerProvider.notifier)
                                  .add(t),
                            ),
                          ),
                        );
                      },
                      eventLoader: (day) =>
                          _getItemsGroupedByDay()[DateTime(
                            day.year,
                            day.month,
                            day.day,
                          )] ??
                          [],

                      // Material Design 3 Styling
                      headerStyle: HeaderStyle(
                        formatButtonVisible: true,
                        titleCentered: true,
                        formatButtonShowsNext: false,
                        formatButtonDecoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        formatButtonTextStyle: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                        leftChevronIcon: Icon(
                          Icons.chevron_left,
                          color: colorScheme.onSurface,
                        ),
                        rightChevronIcon: Icon(
                          Icons.chevron_right,
                          color: colorScheme.onSurface,
                        ),
                        // Dynamically adjust font size based on month name length
                        titleTextStyle: TextStyle(
                          fontSize: headerFontSize,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),

                      calendarStyle: CalendarStyle(
                        // Calendar sizing - more compact
                        tablePadding: const EdgeInsets.all(4),
                        cellPadding: const EdgeInsets.all(2),
                        rowDecoration: const BoxDecoration(),

                        // Today styling - transparent to allow custom builder
                        todayDecoration: const BoxDecoration(),
                        todayTextStyle: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),

                        // Selected day styling - transparent to allow custom builder
                        selectedDecoration: const BoxDecoration(),
                        selectedTextStyle: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),

                        // Weekend styling
                        weekendTextStyle: TextStyle(color: colorScheme.error),

                        // Default styling
                        defaultTextStyle: TextStyle(
                          color: colorScheme.onSurface,
                        ),
                        outsideTextStyle: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),

                      calendarBuilders: CalendarBuilders<Object>(
                        // Custom today builder with underline
                        todayBuilder: (context, day, focusedDay) {
                          final isSelected = isSameDay(_selectedDay, day);
                          // Fade out today's underline when another day is selected
                          final opacity = isSelected ? 1.0 : 0.5;

                          return ExpressiveGestureDetector(
                            onDoubleTap: () {
                              final dateOnly = DateTime(
                                day.year,
                                day.month,
                                day.day,
                              );
                              ref
                                  .read(selectedCalendarDateProvider.notifier)
                                  .update(dateOnly);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => TaskEditorScreen(
                                    presetDueDate: dateOnly,
                                    onSave: (t) => ref
                                        .read(taskControllerProvider.notifier)
                                        .add(t),
                                  ),
                                ),
                              );
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    color: colorScheme.primary.withValues(
                                      alpha: opacity,
                                    ),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  height: 2,
                                  width: 20,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(
                                      alpha: opacity,
                                    ),
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },

                        // Custom selected day builder with underline
                        selectedBuilder: (context, day, focusedDay) {
                          final isToday = isSameDay(
                            day,
                            ref.read(clockProvider).now(),
                          );

                          Widget content = Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${day.day}',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: 2,
                                width: 20,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            ],
                          );

                          // Today builder handles today visually, but we still add double-tap
                          if (isToday) {
                            // Return the same visual with gesture detector
                          }

                          return ExpressiveGestureDetector(
                            onDoubleTap: () {
                              final dateOnly = DateTime(
                                day.year,
                                day.month,
                                day.day,
                              );
                              ref
                                  .read(selectedCalendarDateProvider.notifier)
                                  .update(dateOnly);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => TaskEditorScreen(
                                    presetDueDate: dateOnly,
                                    onSave: (t) => ref
                                        .read(taskControllerProvider.notifier)
                                        .add(t),
                                  ),
                                ),
                              );
                            },
                            child: content,
                          );
                        },
                        // Custom marker builder - left bars style
                        markerBuilder: (context, day, items) {
                          // Filter out imported tasks if toggle is off
                          final visibleItems = showImported
                              ? items
                              : items
                                    .where(
                                      (e) =>
                                          e is! Todo ||
                                          e.sourceCalendarColor == null,
                                    )
                                    .toList();

                          if (visibleItems.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          // Sort: tasks with calendar colors first, then by priority, events last
                          final sortedItems = visibleItems.toList()
                            ..sort((a, b) {
                              // Events always after tasks
                              if (a is app_event.Event &&
                                  b is! app_event.Event) {
                                return 1;
                              }
                              if (a is! app_event.Event &&
                                  b is app_event.Event) {
                                return -1;
                              }
                              if (a is Todo && b is Todo) {
                                final aHasColor = a.sourceCalendarColor != null;
                                final bHasColor = b.sourceCalendarColor != null;
                                if (aHasColor != bHasColor) {
                                  return aHasColor ? -1 : 1;
                                }
                                const priorityOrder = {
                                  'high': 0,
                                  'medium': 1,
                                  'low': 2,
                                  'none': 3,
                                };
                                final aPriority =
                                    priorityOrder[a.priority.toLowerCase()] ??
                                    4;
                                final bPriority =
                                    priorityOrder[b.priority.toLowerCase()] ??
                                    4;
                                return aPriority.compareTo(bPriority);
                              }
                              return 0;
                            });

                          const maxBars = 3;
                          final bars = sortedItems.take(maxBars).toList();
                          final extra = sortedItems.length - bars.length;

                          return Stack(
                            children: [
                              // Item bars on the left
                              if (items.isNotEmpty)
                                Positioned(
                                  top: 4,
                                  bottom: 4,
                                  left: 4,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      for (var item in bars)
                                        Container(
                                          margin: const EdgeInsets.symmetric(
                                            vertical: 1,
                                          ),
                                          width: 4,
                                          height: item is app_event.Event
                                              ? 6
                                              : 8,
                                          decoration: BoxDecoration(
                                            color: item is app_event.Event
                                                ? _getEventMarkerColor(
                                                    item,
                                                    colorScheme,
                                                  )
                                                : item is Todo
                                                ? (item.sourceCalendarColor !=
                                                          null
                                                      ? Color(
                                                          item.sourceCalendarColor!,
                                                        )
                                                      : _getColorForPriority(
                                                          item.priority,
                                                          colorScheme,
                                                        ))
                                                : colorScheme.outline,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.06,
                                                ),
                                                blurRadius: 1,
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (extra > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Text(
                                            '+$extra',
                                            style: TextStyle(
                                              fontSize: 8,
                                              color: theme
                                                  .textTheme
                                                  .bodySmall
                                                  ?.color,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                      ),

                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                        weekendStyle: TextStyle(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                        // Update the provider so other widgets can access the selected date
                        ref
                            .read(selectedCalendarDateProvider.notifier)
                            .update(selectedDay);

                        // Detect double-tap to open task editor
                        final now = DateTime.now();
                        if (_lastTappedDay != null &&
                            isSameDay(_lastTappedDay, selectedDay) &&
                            now.difference(_lastTapTime).inMilliseconds < 500) {
                          // Double-tap detected, open task editor
                          final dateOnly = DateTime(
                            selectedDay.year,
                            selectedDay.month,
                            selectedDay.day,
                          );
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TaskEditorScreen(
                                presetDueDate: dateOnly,
                                onSave: (t) => ref
                                    .read(taskControllerProvider.notifier)
                                    .add(t),
                              ),
                            ),
                          );
                          _lastTappedDay = null; // Reset for next double-tap
                        } else {
                          _lastTappedDay = selectedDay;
                          _lastTapTime = now;
                        }
                      },

                      onFormatChanged: (format) {
                        _cycleCalendarFormat();
                      },

                      onPageChanged: (focusedDay) {
                        setState(() {
                          _focusedDay = focusedDay;
                        });
                      },
                    );
                  },
                ),
              ),
            ),
          ), // AnimatedContainer
          // Selected Day Tasks & Events - Only show when NOT in day view
          if (_selectedDay != null &&
              customFormat != CustomCalendarFormat.day) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('EEEE, MMMM d').format(_selectedDay!),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  if (totalSelectedDayItems > 0)
                    Text(
                      '$totalSelectedDayItems item${totalSelectedDayItems == 1 ? '' : 's'}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Combined task and event list for selected day
            Container(
              constraints: const BoxConstraints(minHeight: 200),
              child: totalSelectedDayItems == 0
                  ? _buildEmptyState(context, colorScheme)
                  : ListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        // Events first
                        for (int i = 0; i < selectedDayEvents.length; i++)
                          RepaintBoundary(
                            child: Padding(
                              padding: EdgeInsets.only(
                                bottom:
                                    (i < selectedDayEvents.length - 1 ||
                                        selectedDayTasks.isNotEmpty)
                                    ? 8
                                    : 0,
                              ),
                              child: _buildEventItem(
                                context,
                                selectedDayEvents[i],
                                colorScheme,
                                theme,
                              ),
                            ),
                          ),
                        // Tasks after events
                        for (int i = 0; i < selectedDayTasks.length; i++)
                          RepaintBoundary(
                            child: Padding(
                              padding: EdgeInsets.only(
                                bottom: i < selectedDayTasks.length - 1 ? 8 : 0,
                              ),
                              child: HybridTodoItem(
                                todo: selectedDayTasks[i],
                                onToggle: () =>
                                    _toggleTaskCompletion(selectedDayTasks[i]),
                                onEdit: () =>
                                    _editTask(context, selectedDayTasks[i]),
                                onDelete: () => ref
                                    .read(taskControllerProvider.notifier)
                                    .delete(selectedDayTasks[i].id),
                                onSelectToggle: () {},
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ], // This closes the if statement
        ], // This closes the Column children
      ), // This closes the SingleChildScrollView
    ); // This closes the return statement
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_outlined,
            size: 64,
            color: colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No items for this day',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  /// Get events for a specific day
  List<app_event.Event> _getEventsForDay(DateTime day) {
    return widget.events.where((event) {
      if (event.isDeleted) return false;
      return event.occursOn(day);
    }).toList()..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
  }

  Widget _buildEventItem(
    BuildContext context,
    app_event.Event event,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final prefs = ref.read(preferencesStateProvider);
    final use24Hour = prefs.resolveUse24Hour(
      MediaQuery.of(context).alwaysUse24HourFormat,
    );

    String timeText;
    if (event.isAllDay) {
      timeText = 'All day';
    } else {
      timeText = DateFormatters.formatTime(
        event.startDateTime,
        use24Hour: use24Hour,
      );
      if (!event.isAllDay) {
        timeText +=
            ' – ${DateFormatters.formatTime(event.endDateTime, use24Hour: use24Hour)}';
      }
    }

    return Material(
      color: Colors.transparent,
      child: ExpressiveInkWell(
        onTap: () => _editEvent(context, event),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: event.color != null
                ? Color(event.color!).withValues(alpha: 0.15)
                : colorScheme.tertiaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: event.color != null
                  ? Color(event.color!).withValues(alpha: 0.3)
                  : colorScheme.tertiary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: event.color != null
                      ? Color(event.color!)
                      : colorScheme.tertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: event.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: event.isCompleted
                            ? colorScheme.onSurface.withValues(alpha: 0.5)
                            : colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (event.location != null &&
                            event.location!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.location_on,
                            size: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              event.location!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (event.isRecurring)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.repeat,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _editEvent(BuildContext context, app_event.Event event) {
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

  void _toggleTaskCompletion(Todo task) {
    ref.read(taskControllerProvider.notifier).toggleComplete(task.id);
  }

  void _editTask(BuildContext context, Todo task) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TaskEditorScreen(
          todo: task,
          onSave: (updatedTask) {
            ref.read(taskControllerProvider.notifier).update(updatedTask);
          },
        ),
      ),
    );
  }
}

// Helper classes for task layout calculation
class _TaskInfo {
  final Todo task;
  final int startMinutes;
  final int endMinutes;

  _TaskInfo({
    required this.task,
    required this.startMinutes,
    required this.endMinutes,
  });
}

class _TaskLayout {
  final Todo task;
  final double topPosition;
  final double height;
  final double leftOffset;
  final double width;
  final int column;

  _TaskLayout({
    required this.task,
    required this.topPosition,
    required this.height,
    required this.leftOffset,
    required this.width,
    required this.column,
  });
}
