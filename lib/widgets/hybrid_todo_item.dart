// Trudido - A privacy-focused todo and notes app
// Copyright (C) 2026 Dominik Müller
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/preferences_state.dart';
import '../models/todo.dart';
import '../providers/app_providers.dart';
import '../utils/responsive_size.dart';
import '../utils/date_formatters.dart';
import '../theme/spacing_tokens.dart';
import '../widgets/common/common.dart';

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
  final String? searchHighlight;

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
    this.searchHighlight,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesStateProvider);
    final spacing = ref.watch(adaptiveSpacingProvider);

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
        spacing,
      ),
      secondaryBackground: _buildSwipeBackground(
        context,
        DismissDirection.endToStart,
        preferences,
        spacing,
      ),
      child: ExpressiveGestureDetector(
        onTap: selectable ? onSelectToggle : onEdit,
        onLongPress: selectable ? null : onSelectToggle,
        child: Card(
          margin: EdgeInsets.symmetric(
            horizontal: spacing.s8,
            vertical: spacing.isCompact ? spacing.s2 : spacing.s4,
          ),
          elevation: 0, // Modern MD3: flat design with no shadow
          shape: RoundedRectangleBorder(borderRadius: SpacingBorderRadius.md),
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : (Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest // Lighter surface in dark mode
                    : Theme.of(context)
                          .colorScheme
                          .surfaceContainer), // Balanced elevation in light mode
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: spacing.insets16,
              child: Row(
                children: [
                  // Checkbox on the left (completion or selection)
                  if (!selectable)
                    Checkbox(
                      value: todo.isCompleted,
                      onChanged: (value) => onToggle(),
                    )
                  else
                    Checkbox(
                      value: selected,
                      onChanged: (v) => onSelectToggle(),
                    ),
                  spacing.gapH8,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        searchHighlight != null && searchHighlight!.isNotEmpty
                            ? RichText(
                                text: _buildHighlightedText(
                                  todo.text,
                                  searchHighlight!,
                                  context,
                                  isCompleted: todo.isCompleted,
                                ),
                              )
                            : Text(
                                todo.text,
                                style: TextStyle(
                                  decoration: todo.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: todo.isCompleted
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant
                                      : Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                ),
                              ),
                        SizedBox(height: spacing.s6),
                        // Show priority and due date/time in a row
                        Wrap(
                          spacing: spacing.s12,
                          runSpacing: spacing.s4,
                          children: [
                            // Calendar source color indicator (for imported tasks)
                            if (todo.sourceCalendarColor != null)
                              _buildCalendarSourceChip(context, spacing),
                            // Priority indicator (only show if not 'none')
                            if (todo.priority != 'none')
                              _buildPriorityChip(context, spacing),
                            // Due date and time
                            if (todo.dueDate != null)
                              _buildDueDateChip(
                                context,
                                preferences.resolveUse24Hour(
                                  MediaQuery.of(context).alwaysUse24HourFormat,
                                ),
                                spacing,
                              ),
                            // Duration indicator
                            if (todo.durationMinutes != null)
                              _buildDurationChip(context, spacing),
                            // Repeat indicator
                            if (todo.isRecurring)
                              _buildRepeatChip(context, spacing),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarSourceChip(
    BuildContext context,
    AdaptiveSpacing spacing,
  ) {
    final color = Color(todo.sourceCalendarColor!);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.s6,
        vertical: spacing.s4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: SpacingBorderRadius.md,
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
          SizedBox(width: spacing.s4),
          Icon(Icons.event, size: 12, color: color),
        ],
      ),
    );
  }

  Widget _buildPriorityChip(BuildContext context, AdaptiveSpacing spacing) {
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
      padding: EdgeInsets.symmetric(
        horizontal: spacing.s8,
        vertical: spacing.s4,
      ),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: SpacingBorderRadius.md,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          SizedBox(width: spacing.s4),
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

  Widget _buildDueDateChip(
    BuildContext context,
    bool use24Hour,
    AdaptiveSpacing spacing,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final dueDate = todo.dueDate!;

    // Format the date
    final dateFormat = DateFormat('MMM d, yyyy');

    // Check if time is set (not midnight)
    final hasTime = dueDate.hour != 0 || dueDate.minute != 0;

    String dateTimeText;
    if (hasTime) {
      dateTimeText =
          '${dateFormat.format(dueDate)} at ${DateFormatters.formatTime(dueDate, use24Hour: use24Hour)}';
    } else {
      dateTimeText = dateFormat.format(dueDate);
    }

    // Check if overdue
    final now = DateTime.now();
    final isOverdue = dueDate.isBefore(now) && !todo.isCompleted;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.s8,
        vertical: spacing.s4,
      ),
      decoration: BoxDecoration(
        color: isOverdue
            ? colorScheme.errorContainer
            : colorScheme.tertiaryContainer,
        borderRadius: SpacingBorderRadius.md,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasTime ? Icons.schedule : Icons.calendar_today,
            size: 14,
            color: isOverdue
                ? colorScheme.onErrorContainer
                : colorScheme.onTertiaryContainer,
          ),
          SizedBox(width: spacing.s4),
          Text(
            dateTimeText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isOverdue
                  ? colorScheme.onErrorContainer
                  : colorScheme.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationChip(BuildContext context, AdaptiveSpacing spacing) {
    final colorScheme = Theme.of(context).colorScheme;
    final durationMinutes = todo.durationMinutes!;

    // Format duration
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    String durationText;
    if (hours == 0) {
      durationText = '${mins}m';
    } else if (mins == 0) {
      durationText = '${hours}h';
    } else {
      durationText = '${hours}h ${mins}m';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.s8,
        vertical: spacing.s4,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: SpacingBorderRadius.md,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 14,
            color: colorScheme.onPrimaryContainer,
          ),
          SizedBox(width: spacing.s4),
          Text(
            durationText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepeatChip(BuildContext context, AdaptiveSpacing spacing) {
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
      padding: EdgeInsets.symmetric(
        horizontal: spacing.s8,
        vertical: spacing.s4,
      ),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: SpacingBorderRadius.md,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.repeat, size: 14, color: colorScheme.onTertiaryContainer),
          SizedBox(width: spacing.s4),
          Text(
            repeatText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colorScheme.onTertiaryContainer,
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
    AdaptiveSpacing spacing,
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
          ? EdgeInsets.only(left: spacing.s20)
          : EdgeInsets.only(right: spacing.s20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: SpacingBorderRadius.md,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaledIcon(icon, color: Colors.white, size: 28),
          SizedBox(height: spacing.s4),
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

  TextSpan _buildHighlightedText(
    String text,
    String highlight,
    BuildContext context, {
    bool isCompleted = false,
  }) {
    if (highlight.isEmpty) {
      return TextSpan(
        text: text,
        style: TextStyle(
          decoration: isCompleted ? TextDecoration.lineThrough : null,
          color: isCompleted
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
      );
    }

    final lowerText = text.toLowerCase();
    final lowerHighlight = highlight.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerHighlight, start);
      if (index == -1) {
        // Add remaining text
        if (start < text.length) {
          spans.add(
            TextSpan(
              text: text.substring(start),
              style: TextStyle(
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          );
        }
        break;
      }

      // Add text before match
      if (index > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, index),
            style: TextStyle(
              decoration: isCompleted ? TextDecoration.lineThrough : null,
              color: isCompleted
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
        );
      }

      // Add highlighted match
      spans.add(
        TextSpan(
          text: text.substring(index, index + highlight.length),
          style: TextStyle(
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      );

      start = index + highlight.length;
    }

    return TextSpan(children: spans);
  }
}
