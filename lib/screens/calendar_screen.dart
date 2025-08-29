import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/todo_provider.dart';
import '../models/todo.dart';

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
    final todos = ref.read(todosProvider);
    return todos.where((todo) {
      if (todo.dueDate == null) return false;
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
    final todos = ref.watch(todosProvider);

    return Column(
      children: [
        TableCalendar<Todo>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          eventLoader: (day) {
            return todos.where((todo) {
              if (todo.dueDate == null) return false;
              return isSameDay(todo.dueDate!, day);
            }).toList();
          },
          startingDayOfWeek: StartingDayOfWeek.monday,
          calendarStyle: CalendarStyle(
            outsideDaysVisible: false,
            // Weekend styling
            weekendTextStyle: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
            holidayTextStyle: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
            // Selected date styling - solid blue circle
            selectedDecoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            // Today styling - semi-transparent with border
            todayDecoration: BoxDecoration(
              color: Colors.blue.withAlpha(77),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.blue,
                width: 2.0,
              ),
            ),
            todayTextStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
            // Event markers styling
            markersMaxCount: 3,
            markerDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
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
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(12.0),
            ),
            formatButtonTextStyle: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
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
          selectedDayPredicate: (day) {
            return isSameDay(_selectedDay, day);
          },
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
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: value.length,
                      itemBuilder: (context, index) {
                        final todo = value[index];
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              todo.isCompleted
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: todo.isCompleted
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.primary,
                            ),
                            title: Text(
                              todo.text,
                              style: TextStyle(
                                decoration: todo.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            subtitle: todo.notes?.isNotEmpty == true
                                ? Text(todo.notes!)
                                : null,
                            trailing: Chip(
                              label: Text(
                                todo.priority.toUpperCase(),
                                style: const TextStyle(fontSize: 10),
                              ),
                              backgroundColor: _getPriorityColor(todo.priority),
                            ),
                            onTap: () {
                              ref.read(todosProvider.notifier).toggleTodo(todo.id);
                              _selectedEvents.value = _getEventsForDay(_selectedDay!);
                            },
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

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red.withAlpha(51);
      case 'medium':
        return Colors.orange.withAlpha(51);
      case 'low':
        return Colors.green.withAlpha(51);
      default:
        return Colors.grey.withAlpha(51);
    }
  }
}
