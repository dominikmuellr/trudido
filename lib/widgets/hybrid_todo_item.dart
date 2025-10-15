import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';
import '../models/preferences_state.dart';
import '../providers/app_providers.dart';

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
      child: Card(
        elevation: 0,
        color: selected
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: InkWell(
          onTap: selectable ? onSelectToggle : onEdit,
          onLongPress: selectable ? null : onSelectToggle,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (selectable) ...[
                  Checkbox(value: selected, onChanged: (v) => onSelectToggle()),
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
                          // Priority indicator (only show if not 'none')
                          if (todo.priority != 'none')
                            _buildPriorityChip(context),
                          // Due date and time
                          if (todo.dueDate != null) _buildDueDateChip(context),
                        ],
                      ),
                    ],
                  ),
                ),
                Checkbox(
                  value: todo.isCompleted,
                  onChanged: (value) => onToggle(),
                ),
              ],
            ),
          ),
        ),
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

    IconData icon;
    Color color;
    String text;

    if (action == 'delete') {
      icon = Icons.delete_outline;
      color = Theme.of(context).colorScheme.errorContainer;
      text = 'Delete';
    } else if (action == 'pin') {
      icon = Icons.push_pin_outlined;
      color = Theme.of(context).colorScheme.tertiaryContainer;
      text = 'Pin';
    } else {
      // 'none' or unknown
      return Container(); // No background for 'none'
    }

    return Container(
      color: color,
      alignment: isStartToEnd ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: isStartToEnd
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }
}
