# Repeatable Tasks - Quick Developer Reference

## Key Components

### Data Model

```dart
// lib/models/todo.dart
class Todo {
  String repeatType;        // 'none', 'daily', 'weekly', 'monthly', 'custom'
  int? repeatInterval;      // e.g., 2 for "every 2 days"
  List<int>? repeatDays;    // [1,3,5] for Mon/Wed/Fri (1=Mon, 7=Sun)
  DateTime? repeatEndDate;  // Optional end date

  bool get isRecurring => repeatType != 'none';
}
```

### Utility Functions

```dart
// lib/utils/recurrence_utils.dart
RecurrenceUtils.calculateNextOccurrence(Todo todo) -> DateTime?
RecurrenceUtils.shouldAppearOnDate(Todo todo, DateTime date) -> bool
RecurrenceUtils.getRecurrenceDescription(Todo todo) -> String
```

### Task Controller

```dart
// lib/controllers/task_controller.dart
toggleComplete(String id) {
  // When completing a recurring task:
  // 1. Mark current as complete
  // 2. Calculate next occurrence
  // 3. Create new task if next occurrence exists
}
```

### UI Components

#### Task Editor

- `_repeatType`, `_repeatInterval`, `_repeatDays`, `_repeatEndDate` state variables
- `_showRepeatSelector()` - Shows bottom sheet with repeat options
- `_buildCustomRepeatOptions()` - Custom repeat configuration UI

#### Calendar View

- `_shouldRecurringTaskAppearOnDate()` - Determines if task shows on a date
- Integrated into `_getTasksForDay()` method

#### Task Item

- `_buildRepeatChip()` - Visual indicator for recurring tasks

## Repeat Type Examples

### Daily

```dart
repeatType: 'daily'
repeatInterval: 1  // Every day
```

### Weekly (Multiple Days)

```dart
repeatType: 'weekly'
repeatInterval: 1
repeatDays: [1, 3, 5]  // Mon, Wed, Fri
```

### Monthly

```dart
repeatType: 'monthly'
repeatInterval: 2  // Every 2 months
```

### Custom (Every 3 days)

```dart
repeatType: 'custom'
repeatInterval: 3
repeatDays: []  // Empty = daily pattern
```

## Database Schema (Hive)

- Field 13: repeatType (String)
- Field 14: repeatInterval (int?)
- Field 15: repeatDays (List<int>?)
- Field 16: repeatEndDate (DateTime?)
- Field 17: parentRecurringTaskId (String?)

## Testing Checklist

- [ ] Create daily recurring task
- [ ] Create weekly task with multiple days
- [ ] Create monthly task on 31st, verify behavior in shorter months
- [ ] Complete recurring task, verify next instance created
- [ ] Set end date, verify recurrence stops
- [ ] View recurring task in calendar, verify appears on correct dates
- [ ] Edit recurring task repeat settings
- [ ] Uncomplete recurring task
- [ ] Delete recurring task

## Common Issues & Solutions

**Issue**: Task doesn't appear on expected calendar date
**Solution**: Check `_shouldRecurringTaskAppearOnDate()` logic for that repeat type

**Issue**: Next occurrence not created after completion
**Solution**: Check `_calculateNextOccurrence()` in task_controller.dart

**Issue**: Hive storage error
**Solution**: Regenerate adapter with `flutter pub run build_runner build --delete-conflicting-outputs`

## Files Modified

- ✅ lib/models/todo.dart
- ✅ lib/models/todo.g.dart (auto-generated)
- ✅ lib/screens/task_editor_screen.dart
- ✅ lib/controllers/task_controller.dart
- ✅ lib/widgets/calendar_view.dart
- ✅ lib/widgets/hybrid_todo_item.dart
- ✅ lib/utils/recurrence_utils.dart (new)
