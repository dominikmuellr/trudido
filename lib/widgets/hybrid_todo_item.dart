import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';
import '../models/preferences_state.dart';
import '../providers/app_providers.dart';
import '../utils/responsive_size.dart';

class HybridTodoItem extends ConsumerWidget {
  final Todo todo;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onPin; // ADDED
  final bool showDragHandle;
  final bool selectable;
  final bool selected;
  final VoidCallback onSelectToggle;

  const HybridTodoItem({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.onPin, // ADDED
    this.showDragHandle = false,
    this.selectable = false,
    this.selected = false,
    required this.onSelectToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesStateProvider);

    return Dismissible(
      key: ValueKey(todo.id),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        // Note: DismissDirection.startToEnd == user swiped right (LTR)
        // and DismissDirection.endToStart == user swiped left.
        final action = direction == DismissDirection.startToEnd
            ? preferences.swipeRightAction
            : preferences.swipeLeftAction;

        if (action == 'delete') {
          onDelete();
          return true; // Dismiss
        } else if (action == 'pin') {
          onPin?.call();
          // For now, just prevent dismiss if it's pin
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Pin action performed')));
          return false; // Don't dismiss
        } else if (action == 'none') {
          return false; // Don't dismiss
        }
        return false; // Default to not dismissing
      },
      background: _buildSwipeBackground(
        context,
        DismissDirection.startToEnd,
        preferences,
      ),
      secondaryBackground: _buildSwipeBackground(
        context,
        DismissDirection.endToStart,
        preferences,
      ),
      child: GestureDetector(
        onTap: selectable ? onSelectToggle : onEdit,
        onLongPress: selectable ? null : onSelectToggle,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          elevation: 0, // Modern MD3: flat design with no shadow
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : (Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest // Lighter surface in dark mode
                    : Theme.of(context)
                          .colorScheme
                          .surfaceContainer), // Balanced elevation in light mode
          child: Container(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (selectable) ...[
                    Checkbox(
                      value: selected,
                      onChanged: (v) => onSelectToggle(),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          todo.text,
                          style: TextStyle(
                            decoration: todo.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: todo.isCompleted
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Show priority and due date/time in a row
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            // Calendar source color indicator (for imported tasks)
                            if (todo.sourceCalendarColor != null)
                              _buildCalendarSourceChip(context),
                            // Priority indicator (only show if not 'none')
                            if (todo.priority != 'none')
                              _buildPriorityChip(context),
                            // Due date and time
                            if (todo.dueDate != null)
                              _buildDueDateChip(context),
                            // Repeat indicator
                            if (todo.isRecurring) _buildRepeatChip(context),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Only show completion checkbox when NOT in multi-select mode
                  if (!selectable)
                    Checkbox(
                      value: todo.isCompleted,
                      onChanged: (value) => onToggle(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarSourceChip(BuildContext context) {
    final color = Color(todo.sourceCalendarColor!);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Icon(Icons.event, size: 12, color: color),
        ],
      ),
    );
  }

  Widget _buildPriorityChip(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color chipColor;
    Color textColor;
    IconData icon;

    switch (todo.priority) {
      case 'high':
        chipColor = colorScheme.errorContainer;
        textColor = colorScheme.onErrorContainer;
        icon = Icons.keyboard_arrow_up;
        break;
      case 'low':
        chipColor = colorScheme.tertiaryContainer;
        textColor = colorScheme.onTertiaryContainer;
        icon = Icons.keyboard_arrow_down;
        break;
      default: // medium
        chipColor = colorScheme.secondaryContainer;
        textColor = colorScheme.onSecondaryContainer;
        icon = Icons.remove;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            todo.priority.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDueDateChip(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dueDate = todo.dueDate!;

    // Format the date
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    // Check if time is set (not midnight)
    final hasTime = dueDate.hour != 0 || dueDate.minute != 0;

    String dateTimeText;
    if (hasTime) {
      dateTimeText =
          '${dateFormat.format(dueDate)} at ${timeFormat.format(dueDate)}';
    } else {
      dateTimeText = dateFormat.format(dueDate);
    }

    // Check if overdue
    final now = DateTime.now();
    final isOverdue = dueDate.isBefore(now) && !todo.isCompleted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOverdue
            ? colorScheme.errorContainer.withOpacity(0.5)
            : colorScheme.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasTime ? Icons.schedule : Icons.calendar_today,
            size: 14,
            color: isOverdue ? colorScheme.error : colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            dateTimeText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isOverdue
                  ? colorScheme.error
                  : colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepeatChip(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    String repeatText;
    switch (todo.repeatType) {
      case 'daily':
        repeatText = 'Daily';
        break;
      case 'weekly':
        repeatText = 'Weekly';
        break;
      case 'monthly':
        repeatText = 'Monthly';
        break;
      case 'custom':
        repeatText = 'Repeats';
        break;
      default:
        repeatText = 'Repeats';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.repeat, size: 14, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(
            repeatText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeBackground(
    BuildContext context,
    DismissDirection direction,
    PreferencesState preferences,
  ) {
    // direction == startToEnd -> user swiped right (show left-side background)
    final isStartToEnd = direction == DismissDirection.startToEnd;
    final action = isStartToEnd
        ? preferences.swipeRightAction
        : preferences.swipeLeftAction;

    if (action == 'none') {
      return Container(); // No background for 'none'
    }

    final IconData icon;
    final Color color;
    final String text;

    if (action == 'delete') {
      icon = Icons.delete;
      color = Colors.red;
      text = 'DELETE';
    } else if (action == 'pin') {
      icon = Icons.push_pin_outlined;
      color = Theme.of(context).colorScheme.primary;
      text = 'PIN';
    } else {
      return Container();
    }

    return Container(
      alignment: isStartToEnd ? Alignment.centerLeft : Alignment.centerRight,
      padding: isStartToEnd
          ? const EdgeInsets.only(left: 20)
          : const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaledIcon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(
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
