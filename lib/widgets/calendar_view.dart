import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';
import '../screens/task_editor_screen.dart';
import '../controllers/task_controller.dart';
import '../providers/filter_providers.dart';
import 'hybrid_todo_item.dart';

/// Material Design 3 Calendar View for Tasks
/// Shows tasks in a beautiful calendar layout with proper Material theming
class CalendarView extends ConsumerStatefulWidget {
  final List<Todo> tasks;

  const CalendarView({super.key, required this.tasks});

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    // Initialize the provider with today's date
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedCalendarDateProvider.notifier).state = _selectedDay;
    });
  }

  /// Get tasks for a specific day
  List<Todo> _getTasksForDay(DateTime day) {
    return widget.tasks.where((task) {
      if (task.dueDate == null) return false;

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

    for (final task in widget.tasks) {
      if (task.dueDate == null) continue;

      if (task.startDate != null) {
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

    return SingleChildScrollView(
      child: Column(
        children: [
          // Calendar Widget - Fixed height to prevent overflow
          Container(
            height: 360, // Reduced height for better fit
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: TableCalendar<Todo>(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                calendarFormat: _calendarFormat,
                startingDayOfWeek: StartingDayOfWeek.monday,
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
                  titleTextStyle:
                      theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ) ??
                      TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                ),

                calendarStyle: CalendarStyle(
                  // Calendar sizing - more compact
                  tablePadding: const EdgeInsets.all(4),
                  cellPadding: const EdgeInsets.all(2),
                  rowDecoration: const BoxDecoration(),

                  // Today styling
                  todayDecoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: colorScheme.primary, width: 1.5),
                  ),
                  todayTextStyle: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),

                  // Selected day styling
                  selectedDecoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: TextStyle(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),

                  // Weekend styling
                  weekendTextStyle: TextStyle(color: colorScheme.error),

                  // Default styling
                  defaultTextStyle: TextStyle(color: colorScheme.onSurface),
                  outsideTextStyle: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                  ),

                  // Markers (task indicators)
                  markerDecoration: BoxDecoration(
                    color: colorScheme.secondary,
                    shape: BoxShape.circle,
                  ),
                  markersMaxCount: 3,
                  markerSize: 6,
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
                  setState(() {
                    _calendarFormat = format;
                  });
                },

                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
              ),
            ),
          ),

          // Selected Day Tasks
          if (_selectedDay != null) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.event, size: 20, color: colorScheme.primary),
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
            Icons.event,
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
