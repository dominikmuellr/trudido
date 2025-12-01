import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';
import '../screens/task_editor_screen.dart';
import '../controllers/task_controller.dart';
import '../providers/filter_providers.dart';
import '../providers/clock.dart';
import 'hybrid_todo_item.dart';

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

  const CalendarView({super.key, required this.tasks});

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  // Convert custom format to table_calendar format
  CalendarFormat get _calendarFormat {
    final customFormat = ref.watch(calendarFormatProvider);
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
    // Increase padding to prevent overflow
    final extraPadding = fmt == CustomCalendarFormat.month
        ? 15.0 // Increased to add more space
        : fmt == CustomCalendarFormat.twoWeeks
        ? 12.0 // Increased from 4.0 to fix 7.4 pixel overflow
        : 6.0; // Increased from 0.0 to fix 1.7 pixel overflow
    return headerHeight + daysOfWeekHeight + rows * cellHeight + extraPadding;
  }

  Widget _buildDayTimetable(BuildContext context, ColorScheme colorScheme) {
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
              IconButton(
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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
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
              const SizedBox(width: 8),
              // Right chevron
              IconButton(
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
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allDayTasks.map((task) {
                    return InkWell(
                      onTap: () => _editTask(context, task),
                      onLongPress: () {
                        // Show confirmation dialog before deleting
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Task'),
                            content: Text('Delete "${task.text}"?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
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
                          ).withOpacity(0.2),
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
          child: ListView.builder(
            itemCount: 24, // 24 hours
            itemBuilder: (context, hour) {
              // Get all tasks for this hour
              final hourTasks = timedTasks.where((task) {
                if (task.dueDate == null) return false;
                return task.dueDate!.hour == hour;
              }).toList();

              // Sort by minute
              hourTasks.sort((a, b) {
                final aMinute = a.dueDate?.minute ?? 0;
                final bMinute = b.dueDate?.minute ?? 0;
                return aMinute.compareTo(bMinute);
              });

              // Group tasks by exact time (hour:minute)
              final Map<String, List<Todo>> tasksByTime = {};
              for (var task in hourTasks) {
                if (task.dueDate != null) {
                  final timeKey =
                      '${task.dueDate!.hour}:${task.dueDate!.minute.toString().padLeft(2, '0')}';
                  tasksByTime[timeKey] = tasksByTime[timeKey] ?? [];
                  tasksByTime[timeKey]!.add(task);
                }
              }

              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: colorScheme.outlineVariant.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time label
                    SizedBox(
                      width: 60,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          '${hour.toString().padLeft(2, '0')}:00',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    // Tasks for this hour - grouped by exact time
                    Expanded(
                      child: hourTasks.isEmpty
                          ? const SizedBox(height: 50)
                          : Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: tasksByTime.entries.map((entry) {
                                  final tasksAtSameTime = entry.value;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: tasksAtSameTime.map((task) {
                                        return IntrinsicWidth(
                                          child: InkWell(
                                            onTap: () =>
                                                _editTask(context, task),
                                            onLongPress: () {
                                              // Show confirmation dialog before deleting
                                              showDialog(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: const Text(
                                                    'Delete Task',
                                                  ),
                                                  content: Text(
                                                    'Delete "${task.text}"?',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            context,
                                                          ),
                                                      child: const Text(
                                                        'Cancel',
                                                      ),
                                                    ),
                                                    TextButton(
                                                      onPressed: () {
                                                        ref
                                                            .read(
                                                              taskControllerProvider
                                                                  .notifier,
                                                            )
                                                            .delete(task.id);
                                                        Navigator.pop(context);
                                                      },
                                                      child: const Text(
                                                        'Delete',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Container(
                                              constraints: const BoxConstraints(
                                                minWidth: 100,
                                              ),
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                  ),
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: _getColorForPriority(
                                                  task.priority,
                                                  colorScheme,
                                                ).withOpacity(0.2),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: _getColorForPriority(
                                                    task.priority,
                                                    colorScheme,
                                                  ),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    task.text,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          colorScheme.onSurface,
                                                    ),
                                                  ),
                                                  if (task.dueDate != null)
                                                    Text(
                                                      DateFormat.jm().format(
                                                        task.dueDate!,
                                                      ),
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ), // Container
                                          ), // InkWell
                                        ); // IntrinsicWidth
                                      }).toList(),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                    ),
                  ],
                ),
              );
            },
          ), // ListView.builder
        ), // Expanded
      ], // Column children
    ); // Column - end of day timetable
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
        return Colors.orange;
      case 'low':
        return Colors.blue;
      default:
        return colorScheme.tertiary;
    }
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
        ref.read(selectedCalendarDateProvider.notifier).state = _selectedDay;
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

  /// Get task count indicators for calendar markers
  Map<DateTime, List<Todo>> _getTasksGroupedByDay() {
    final Map<DateTime, List<Todo>> taskMap = {};

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
            taskMap[date] = taskMap[date] ?? [];
            taskMap[date]!.add(task);
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
          taskMap[date] = taskMap[date] ?? [];
          taskMap[date]!.add(task);
        }
      } else {
        // Single-day task
        final taskDate = DateTime(
          task.dueDate!.year,
          task.dueDate!.month,
          task.dueDate!.day,
        );
        taskMap[taskDate] = taskMap[taskDate] ?? [];
        taskMap[taskDate]!.add(task);
      }
    }

    return taskMap;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedDayTasks = _selectedDay != null
        ? _getTasksForDay(_selectedDay!)
        : <Todo>[];
    final customFormat = ref.watch(calendarFormatProvider);

    return SingleChildScrollView(
      child: Column(
        children: [
          // Calendar Widget - Animated height based on format
          AnimatedContainer(
            key: ValueKey(customFormat),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOutCubicEmphasized,
            height: _heightForFormat(context, customFormat) + 8,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Use consistent small font size for all months to prevent overflow
                    const headerFontSize = 16.0;

                    // Show day timetable when format is day, otherwise show calendar
                    if (customFormat == CustomCalendarFormat.day) {
                      return _buildDayTimetable(context, colorScheme);
                    }

                    return TableCalendar<Todo>(
                      key: ValueKey(
                        'calendar_${_focusedDay.month}_${_focusedDay.year}',
                      ),
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDay, day),
                      calendarFormat: _calendarFormat,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      // Long-press on a day to create a new task prefilled with that date
                      onDayLongPressed: (selectedDay, focusedDay) {
                        final dateOnly = DateTime(
                          selectedDay.year,
                          selectedDay.month,
                          selectedDay.day,
                        );
                        // Update provider so editor can prefill the date
                        ref.read(selectedCalendarDateProvider.notifier).state =
                            dateOnly;
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
                          _getTasksGroupedByDay()[DateTime(
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

                      calendarBuilders: CalendarBuilders<Todo>(
                        // Custom today builder with underline
                        todayBuilder: (context, day, focusedDay) {
                          final isSelected = isSameDay(_selectedDay, day);
                          // Fade out today's underline when another day is selected
                          final opacity = isSelected ? 1.0 : 0.5;

                          return GestureDetector(
                            onDoubleTap: () {
                              final dateOnly = DateTime(
                                day.year,
                                day.month,
                                day.day,
                              );
                              ref
                                      .read(
                                        selectedCalendarDateProvider.notifier,
                                      )
                                      .state =
                                  dateOnly;
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

                          return GestureDetector(
                            onDoubleTap: () {
                              final dateOnly = DateTime(
                                day.year,
                                day.month,
                                day.day,
                              );
                              ref
                                      .read(
                                        selectedCalendarDateProvider.notifier,
                                      )
                                      .state =
                                  dateOnly;
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
                        markerBuilder: (context, day, events) {
                          if (events.isEmpty) return const SizedBox.shrink();

                          // Sort events: tasks with calendar colors first, then by priority
                          final sortedEvents = events.toList()
                            ..sort((a, b) {
                              // First sort by whether they have a calendar color
                              final aHasColor = a.sourceCalendarColor != null;
                              final bHasColor = b.sourceCalendarColor != null;
                              if (aHasColor != bHasColor) {
                                return aHasColor ? -1 : 1;
                              }
                              // Then by priority
                              const priorityOrder = {
                                'high': 0,
                                'medium': 1,
                                'low': 2,
                                'none': 3,
                              };
                              final aPriority =
                                  priorityOrder[a.priority.toLowerCase()] ?? 4;
                              final bPriority =
                                  priorityOrder[b.priority.toLowerCase()] ?? 4;
                              return aPriority.compareTo(bPriority);
                            });

                          const maxBars = 2;
                          final bars = sortedEvents.take(maxBars).toList();
                          final extra = sortedEvents.length - bars.length;

                          return Positioned(
                            top: 4,
                            bottom: 4,
                            left: 4,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var event in bars)
                                  Container(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 1,
                                    ),
                                    width: 4,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      // Use calendar color if available, otherwise priority color
                                      color: event.sourceCalendarColor != null
                                          ? Color(event.sourceCalendarColor!)
                                          : _getColorForPriority(
                                              event.priority,
                                              colorScheme,
                                            ),
                                      borderRadius: BorderRadius.circular(2),
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
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      '+$extra',
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: theme.textTheme.bodySmall?.color,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
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
                        ref.read(selectedCalendarDateProvider.notifier).state =
                            selectedDay;
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
          // Selected Day Tasks - Only show when NOT in day view
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
                  if (selectedDayTasks.isNotEmpty)
                    Text(
                      '${selectedDayTasks.length} task${selectedDayTasks.length == 1 ? '' : 's'}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tasks List for Selected Day
            Container(
              constraints: const BoxConstraints(minHeight: 200),
              child: selectedDayTasks.isEmpty
                  ? _buildEmptyState(context, colorScheme)
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: selectedDayTasks.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final task = selectedDayTasks[index];
                        return HybridTodoItem(
                          todo: task,
                          onToggle: () => _toggleTaskCompletion(task),
                          onEdit: () => _editTask(context, task),
                          onDelete: () => ref
                              .read(taskControllerProvider.notifier)
                              .delete(task.id),
                          onSelectToggle:
                              () {}, // Not selectable in calendar view
                        );
                      },
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
            'No tasks for this day',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              final dateOnly = _selectedDay != null
                  ? DateTime(
                      _selectedDay!.year,
                      _selectedDay!.month,
                      _selectedDay!.day,
                    )
                  : null;
              // Ensure provider is set to current selected day
              if (dateOnly != null) {
                ref.read(selectedCalendarDateProvider.notifier).state =
                    dateOnly;
              }
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TaskEditorScreen(
                    presetDueDate: dateOnly,
                    onSave: (t) =>
                        ref.read(taskControllerProvider.notifier).add(t),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add task'),
          ),
        ],
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
