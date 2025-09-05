import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/app_providers.dart';
import '../controllers/task_controller.dart';
import '../models/todo.dart';
import '../services/theme_service.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late final ValueNotifier<List<Todo>> _selectedEvents;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  List<Todo> _getEventsForDay(DateTime day) {
    final todos = ref.read(tasksProvider);
    return todos.where((todo) {
      if (todo.dueDate == null) return false;
      // Include multi-day spans
      if (todo.startDate != null && todo.dueDate != null && !todo.dueDate!.isBefore(todo.startDate!)) {
        final d = DateTime(day.year, day.month, day.day);
        final s = DateTime(todo.startDate!.year, todo.startDate!.month, todo.startDate!.day);
        final e = DateTime(todo.dueDate!.year, todo.dueDate!.month, todo.dueDate!.day);
        return (d.isAtSameMomentAs(s) || d.isAfter(s)) && (d.isAtSameMomentAs(e) || d.isBefore(e));
      }
      return isSameDay(todo.dueDate!, day);
    }).toList();
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      _selectedEvents.value = _getEventsForDay(selectedDay);
    }
  }

  @override
  Widget build(BuildContext context) {
  ref.watch(tasksProvider); // trigger rebuild on tasks change

    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        TableCalendar<Todo>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          eventLoader: (day) => _getEventsForDay(day),
          startingDayOfWeek: StartingDayOfWeek.monday,
          calendarStyle: CalendarStyle(
            outsideDaysVisible: false,
            // Weekend styling
            weekendTextStyle: TextStyle(
              color: cs.error,
            ),
            holidayTextStyle: TextStyle(
              color: cs.error,
            ),
            // Selected date styling - solid blue circle
            selectedDecoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: TextStyle(
              color: cs.onPrimary,
              fontWeight: FontWeight.bold,
            ),
            // Today styling - semi-transparent with border
            todayDecoration: BoxDecoration(
              color: cs.primary.withAlpha(77),
              shape: BoxShape.circle,
              border: Border.all(
                color: cs.primary,
                width: 2.0,
              ),
            ),
            todayTextStyle: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.bold,
            ),
            // Event markers styling
            markersMaxCount: 3,
            markerDecoration: BoxDecoration(
              color: cs.secondary,
              shape: BoxShape.circle,
            ),
            markerMargin: const EdgeInsets.symmetric(horizontal: 0.5),
            markersAlignment: Alignment.bottomCenter,
          ),
      headerStyle: HeaderStyle(
            formatButtonVisible: true,
            titleCentered: true,
            formatButtonShowsNext: false,
            formatButtonDecoration: BoxDecoration(
        color: cs.primary,
              borderRadius: BorderRadius.circular(12.0),
            ),
            formatButtonTextStyle: TextStyle(
        color: cs.onPrimary,
            ),
          ),
          onDaySelected: _onDaySelected,
          onFormatChanged: (format) {
            if (_calendarFormat != format) {
              setState(() {
                _calendarFormat = format;
              });
            }
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, events) {
              if (events.isEmpty) return null;
              final max = events.length > 3 ? 3 : events.length;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(max, (i) {
                  final todo = events[i];
                  final color = AppTheme.getPriorityColor(todo.priority, isDark: Theme.of(context).brightness == Brightness.dark);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.0),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                  );
                }),
              );
            },
            defaultBuilder: (context, day, focusedDay) {
              final spanTodos = _getEventsForDay(day).where((t) => t.startDate != null && t.startDate != t.dueDate).toList();
              if (spanTodos.isEmpty) return null;
              final cs = Theme.of(context).colorScheme;
              return Container(
                decoration: BoxDecoration(
                  color: cs.primary.withAlpha(24),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text('${day.day}', style: Theme.of(context).textTheme.bodyMedium),
              );
            },
          ),
        ),
        
        const SizedBox(height: 8.0),
        
        // Selected day tasks
        Expanded(
          child: ValueListenableBuilder<List<Todo>>(
            valueListenable: _selectedEvents,
            builder: (context, value, _) {
              return value.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_available,
                            size: 80,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No tasks for ${DateFormat('MMM dd, yyyy').format(_selectedDay ?? DateTime.now())}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: value.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final todo = value[index];
                        final isSpan = todo.startDate != null && todo.dueDate != null && !todo.dueDate!.isBefore(todo.startDate!);
                        final color = AppTheme.getPriorityColor(todo.priority, isDark: cs.brightness == Brightness.dark);
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            ref.read(taskControllerProvider.notifier).toggleComplete(todo.id);
                            _selectedEvents.value = _getEventsForDay(_selectedDay!);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: color.withAlpha(90), width: 1),
                              color: todo.isCompleted ? color.withAlpha(30) : color.withAlpha(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      todo.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                                      color: color,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        todo.text,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getPriorityColor(todo.priority, cs),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(todo.priority.toUpperCase(), style: const TextStyle(fontSize: 10)),
                                    ),
                                  ],
                                ),
                                if (isSpan) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    '${DateFormat('MMM d').format(todo.startDate!)} → ${DateFormat('MMM d').format(todo.dueDate!)}' ' (${todo.dueDate!.difference(todo.startDate!).inDays + 1} days)',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                                  ),
                                ] else if (todo.dueDate != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    DateFormat('MMM d, HH:mm').format(todo.dueDate!),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                                  ),
                                ],
                                if (todo.notes?.isNotEmpty == true) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    todo.notes!,
                                    style: Theme.of(context).textTheme.bodySmall,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    );
            },
          ),
        ),
      ],
    );
  }

  Color _getPriorityColor(String priority, ColorScheme cs) {
    final base = AppTheme.getPriorityColor(priority, isDark: cs.brightness == Brightness.dark);
    return base.withAlpha(51);
  }
}
