import '../models/todo.dart';

/// Utility class for handling recurring task logic
class RecurrenceUtils {
  /// Calculate the next occurrence date for a recurring task
  static DateTime? calculateNextOccurrence(Todo todo) {
    if (!todo.isRecurring || todo.dueDate == null) return null;

    final now = DateTime.now();
    final currentDue = todo.dueDate!;

    // If the current due date is in the future, return it
    if (currentDue.isAfter(now)) return currentDue;

    // Check if recurrence has ended
    if (todo.repeatEndDate != null && now.isAfter(todo.repeatEndDate!)) {
      return null;
    }

    DateTime nextDate = currentDue;

    switch (todo.repeatType) {
      case 'daily':
        final interval = todo.repeatInterval ?? 1;
        // Find the next occurrence after now
        while (nextDate.isBefore(now) || _isSameDay(nextDate, now)) {
          nextDate = nextDate.add(Duration(days: interval));
        }
        break;

      case 'weekly':
        final interval = todo.repeatInterval ?? 1;
        final daysOfWeek = todo.repeatDays ?? [currentDue.weekday];

        // Start from the current due date
        nextDate = currentDue;
        int attempts = 0;

        while (attempts < 365) {
          // Safety limit
          nextDate = nextDate.add(const Duration(days: 1));

          // Check if this day is in our repeat days and is after now
          if (daysOfWeek.contains(nextDate.weekday) && nextDate.isAfter(now)) {
            // For weekly intervals > 1, ensure we're in the correct week
            if (interval == 1) {
              break;
            } else {
              final weeksSinceStart =
                  nextDate.difference(currentDue).inDays ~/ 7;
              if (weeksSinceStart % interval == 0) {
                break;
              }
            }
          }
          attempts++;
        }
        break;

      case 'monthly':
        final interval = todo.repeatInterval ?? 1;
        final dayOfMonth = currentDue.day;

        // Add months until we find a date after now
        nextDate = currentDue;
        while (nextDate.isBefore(now) || _isSameDay(nextDate, now)) {
          final newMonth = nextDate.month + interval;
          final newYear = nextDate.year + (newMonth - 1) ~/ 12;
          final actualMonth = ((newMonth - 1) % 12) + 1;

          // Handle edge case: if day doesn't exist in target month, use last day
          final daysInMonth = DateTime(newYear, actualMonth + 1, 0).day;
          final actualDay = dayOfMonth > daysInMonth ? daysInMonth : dayOfMonth;

          nextDate = DateTime(
            newYear,
            actualMonth,
            actualDay,
            nextDate.hour,
            nextDate.minute,
          );
        }
        break;

      case 'custom':
        // Custom logic already handled by other cases with intervals and days
        return null;

      default:
        return null;
    }

    // Check if next occurrence exceeds end date
    if (todo.repeatEndDate != null && nextDate.isAfter(todo.repeatEndDate!)) {
      return null;
    }

    return nextDate;
  }

  /// Check if a recurring task should appear on a specific date
  static bool shouldAppearOnDate(Todo todo, DateTime date) {
    if (!todo.isRecurring || todo.dueDate == null) return false;

    final targetDate = DateTime(date.year, date.month, date.day);
    final startDate = DateTime(
      todo.dueDate!.year,
      todo.dueDate!.month,
      todo.dueDate!.day,
    );

    // Don't show before the start date
    if (targetDate.isBefore(startDate)) return false;

    // Don't show after the end date
    if (todo.repeatEndDate != null) {
      final endDate = DateTime(
        todo.repeatEndDate!.year,
        todo.repeatEndDate!.month,
        todo.repeatEndDate!.day,
      );
      if (targetDate.isAfter(endDate)) return false;
    }

    switch (todo.repeatType) {
      case 'daily':
        final interval = todo.repeatInterval ?? 1;
        final daysDiff = targetDate.difference(startDate).inDays;
        return daysDiff >= 0 && daysDiff % interval == 0;

      case 'weekly':
        final interval = todo.repeatInterval ?? 1;
        final daysOfWeek = todo.repeatDays ?? [todo.dueDate!.weekday];

        // Check if this day of week matches
        if (!daysOfWeek.contains(targetDate.weekday)) return false;

        // Check if we're in the correct week interval
        final weeksDiff = targetDate.difference(startDate).inDays ~/ 7;
        return weeksDiff % interval == 0;

      case 'monthly':
        final interval = todo.repeatInterval ?? 1;
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

      default:
        return false;
    }
  }

  /// Get a human-readable description of the recurrence pattern
  static String getRecurrenceDescription(Todo todo) {
    if (!todo.isRecurring) return 'Does not repeat';

    final interval = todo.repeatInterval ?? 1;
    final endDate = todo.repeatEndDate;
    String description = '';

    switch (todo.repeatType) {
      case 'daily':
        if (interval == 1) {
          description = 'Every day';
        } else {
          description = 'Every $interval days';
        }
        break;

      case 'weekly':
        if (interval == 1) {
          if (todo.repeatDays == null || todo.repeatDays!.isEmpty) {
            description = 'Every week';
          } else if (todo.repeatDays!.length == 1) {
            description = 'Every ${_getDayName(todo.repeatDays![0])}';
          } else {
            final days = todo.repeatDays!.map(_getDayName).join(', ');
            description = 'Weekly on $days';
          }
        } else {
          if (todo.repeatDays == null || todo.repeatDays!.isEmpty) {
            description = 'Every $interval weeks';
          } else {
            final days = todo.repeatDays!.map(_getDayName).join(', ');
            description = 'Every $interval weeks on $days';
          }
        }
        break;

      case 'monthly':
        if (interval == 1) {
          description = 'Every month';
        } else {
          description = 'Every $interval months';
        }
        break;

      case 'custom':
        description = 'Custom recurrence';
        break;

      default:
        description = 'Does not repeat';
    }

    if (endDate != null) {
      final formattedEnd = '${endDate.month}/${endDate.day}/${endDate.year}';
      description += ' (until $formattedEnd)';
    }

    return description;
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }
}
