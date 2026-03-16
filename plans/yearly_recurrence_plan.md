# Yearly Recurrence Implementation Plan

## Overview

Add 'yearly' recurrence option to Trudido events and tasks.

## Current State

- `repeatType` field in Event and Todo models is a String with values: 'none', 'daily', 'weekly', 'monthly', 'custom'
- UI shows options: Daily, Weekly, Monthly, Custom...
- Calculation logic exists in multiple files

## Files to Update

### 1. Model Documentation

- `lib/models/event.dart`: Update comment on line 64 to include 'yearly'
- `lib/models/todo.dart`: Likely similar comment (need to check)

### 2. Calculation Logic

#### Event Controller (`lib/controllers/event_controller.dart`)

Add case 'yearly' to `_calculateNextOccurrence` method:

```dart
case 'yearly':
  final interval = event.repeatInterval ?? 1;
  final newYear = currentStart.year + interval;

  // Handle February 29th edge case
  final daysInMonth = DateTime(newYear, currentStart.month + 1, 0).day;
  final actualDay = currentStart.day > daysInMonth
      ? daysInMonth
      : currentStart.day;

  nextDate = DateTime(
    newYear,
    currentStart.month,
    actualDay,
    currentStart.hour,
    currentStart.minute,
  );
  break;
```

#### Task Controller (`lib/controllers/task_controller.dart`)

Add similar case 'yearly' to `_calculateNextOccurrence` method.

#### Recurrence Utils (`lib/utils/recurrence_utils.dart`)

Three switch statements need updating:

1. `calculateNextOccurrence` method (line 38)
2. `_calculateNextOccurrence` method (line 141)
3. Another switch (line 186)

### 3. UI Updates

#### Event Editor Screen (`lib/screens/event_editor_screen.dart`)

1. Add 'yearly' option to `_showRepeatSelector` method (after monthly, before custom)
2. Update `_getRepeatLabel` method to handle 'yearly' case
3. Update `_buildRepeatOption` calls

#### Task Editor Screen (`lib/screens/task_editor_screen.dart`)

Similar updates needed (check if it has same structure)

### 4. Display/Export Logic

#### ICS Export Service (`lib/services/ics_export_service.dart`)

Update switch statement for repeatType to handle 'yearly' (line 214)

#### Hybrid Todo Item (`lib/widgets/hybrid_todo_item.dart`)

Update switch statement for repeatText (line 399)

#### Calendar View (`lib/widgets/calendar_view.dart`)

Update switch statement (line 664)

## Implementation Details

### Yearly Calculation Logic

For yearly recurrence with interval N:

- Add N years to the year component
- Keep month and day the same
- Handle edge case: February 29th on non-leap years → use February 28th
- Handle edge case: Day 31 in months with 30 days → use last day of month

### UI Changes

1. Add new option in repeat selector with icon `Icons.calendar_today` or similar
2. Label: "Yearly"
3. In `_getRepeatLabel`: "Repeats yearly" or "Repeats every N years"

### Database Compatibility

- No schema changes needed (repeatType is already a String)
- Existing data unaffected
- New 'yearly' values will be stored as string 'yearly'

## Testing Considerations

1. Test yearly recurrence with interval 1
2. Test yearly recurrence with interval > 1
3. Test edge cases (Feb 29th, day 31 in April, etc.)
4. Test with repeatEndDate
5. Test UI displays correctly
6. Test ICS export includes yearly recurrence

## Order of Implementation

1. Model documentation
2. Calculation logic (event_controller, task_controller, recurrence_utils)
3. UI (event_editor_screen, task_editor_screen)
4. Display logic (ics_export_service, hybrid_todo_item, calendar_view)
5. Verification and testing

## Notes

- Do not modify generated files (`event.g.dart`, `todo.g.dart`)
- Ensure all switch statements have a default case
- Follow existing code style and patterns
