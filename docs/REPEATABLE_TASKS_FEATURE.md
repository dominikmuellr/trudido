# Repeatable Tasks Feature

## Overview

The Repeatable Tasks feature allows users to create tasks that recur automatically on a schedule. When a recurring task is marked as complete, a new instance is automatically created for the next occurrence.

## Implementation Details

### Data Model Changes

The `Todo` model has been extended with the following fields:

- `repeatType` (String): Type of recurrence - 'none', 'daily', 'weekly', 'monthly', 'custom'
- `repeatInterval` (int?): Interval for recurrence (e.g., every 2 days/weeks/months)
- `repeatDays` (List<int>?): Days of the week for weekly recurrence (1=Mon, 7=Sun)
- `repeatEndDate` (DateTime?): Optional end date for the recurrence
- `parentRecurringTaskId` (String?): Reference to the original recurring task (for future use)

### User Interface

#### Task Editor

1. **Repeat Button**: New quick action chip in the task editor showing current repeat status
2. **Repeat Selector**: Bottom sheet with options:
   - Does not repeat
   - Daily
   - Weekly
   - Monthly
   - Custom...
3. **Custom Options**: When "Custom" is selected:
   - Interval selector (every X days/weeks)
   - Day of week selector (for weekly patterns)
4. **End Date**: Optional end date picker for all repeat types

#### Visual Indicators

- **Repeat Chip**: Tasks with repeat settings show a "Repeats" chip in the task list
- **Calendar View**: Recurring tasks automatically appear on all relevant dates in the calendar

### Behavior

#### Creating a Recurring Task

1. User creates a task with a due date
2. User taps the "Repeat" option
3. User selects repeat type and configures settings
4. Task is saved with recurrence information

#### Completing a Recurring Task

When a recurring task is marked as complete:

1. The current instance is marked as completed
2. The next occurrence date is calculated based on the repeat settings
3. If a next occurrence exists (and hasn't passed the end date):
   - A new task instance is automatically created
   - The new task has the same properties (title, notes, priority, folder, reminders)
   - The new task has a new ID and creation date
   - The new task's due date is set to the next occurrence
4. If no next occurrence exists (end date reached), no new task is created

#### Calendar Display

- Recurring tasks appear on all dates where they should occur
- The logic checks:
  - Start date (first occurrence)
  - End date (if set)
  - Repeat pattern (daily, weekly, monthly)
  - Repeat interval
  - Days of week (for weekly patterns)

### Recurrence Patterns

#### Daily

- **Standard**: Every day
- **Interval**: Every X days (e.g., every 2 days)

#### Weekly

- **Standard**: Every week on the original day
- **Custom Days**: Every week on selected days (Mon, Tue, Wed, etc.)
- **Interval**: Every X weeks on selected days

#### Monthly

- **Standard**: Every month on the same day
- **Interval**: Every X months on the same day
- **Edge Case**: For days 29-31, if the target month has fewer days, uses the last day of that month

#### Custom

- **Daily Pattern**: Every X days
- **Weekly Pattern**: Every X weeks on selected days

### Code Structure

#### New Files

- `lib/utils/recurrence_utils.dart`: Utility class for recurrence calculations
  - `calculateNextOccurrence()`: Calculate next occurrence date
  - `shouldAppearOnDate()`: Check if a task should appear on a specific date
  - `getRecurrenceDescription()`: Human-readable description of recurrence pattern

#### Modified Files

- `lib/models/todo.dart`: Extended with recurrence fields
- `lib/models/todo.g.dart`: Auto-generated Hive adapter
- `lib/screens/task_editor_screen.dart`: Added repeat UI and logic
- `lib/controllers/task_controller.dart`: Added logic for creating next occurrence
- `lib/widgets/calendar_view.dart`: Added logic to show recurring tasks on calendar
- `lib/widgets/hybrid_todo_item.dart`: Added repeat indicator chip

### Database Migration

The Hive database automatically handles the new fields:

- Existing tasks will have `repeatType = 'none'` by default
- No manual migration required

### Edge Cases Handled

1. **Month with fewer days**: If a task recurs on the 31st but the target month has 30 days, it will occur on the 30th
2. **End date**: Tasks won't recur past the specified end date
3. **Leap years**: Handled automatically by Dart's DateTime
4. **Completed recurring tasks**: Only create next occurrence when marking incomplete task as complete
5. **Uncompleting recurring tasks**: Simply unmarks the current instance without affecting future occurrences

### Future Enhancements (Not Implemented)

Potential future improvements:

- Edit all future occurrences of a recurring task
- Skip individual occurrences
- Different recurrence patterns (yearly, every weekday, etc.)
- "Repeat after completion" pattern (reschedule X days after completion, not from due date)
- More complex patterns (e.g., "last Friday of each month")

### Testing Recommendations

1. Create a daily recurring task and verify it appears on multiple calendar days
2. Complete a recurring task and verify a new instance is created
3. Create a weekly task with multiple days selected
4. Create a monthly task on the 31st and verify behavior in months with fewer days
5. Set an end date and verify recurrence stops at that date
6. Test custom intervals (every 2 days, every 3 weeks, etc.)

## User Documentation

### How to Create a Repeating Task

1. Create or edit a task
2. Tap the "Does not repeat" button
3. Select your repeat pattern:
   - **Daily**: Task repeats every day
   - **Weekly**: Task repeats every week
   - **Monthly**: Task repeats every month
   - **Custom**: Configure your own pattern
4. (Optional) Set an end date for the recurrence
5. Save the task

### Understanding Repeat Patterns

- **Daily**: Task will repeat every single day
- **Weekly**: Task will repeat on the same day each week
- **Monthly**: Task will repeat on the same date each month
- **Custom**: You can set it to repeat every X days or every X weeks on specific days

### Completing Repeating Tasks

When you complete a repeating task:

- The current task is marked as complete
- A new task is automatically created for the next occurrence
- The new task has the same details (title, notes, priority, etc.)

### Stopping a Repeating Task

To stop a task from repeating:

1. Edit the task
2. Tap the repeat settings
3. Select "Does not repeat"
4. Save the task
