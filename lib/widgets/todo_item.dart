import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';
import '../services/theme_service.dart';
import '../screens/task_editor_screen.dart';

class TodoItem extends StatelessWidget {
  final Todo todo;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool showDragHandle;
  final bool selectable;
  final bool selected;
  final VoidCallback? onSelectToggle;

  const TodoItem({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.showDragHandle = false,
    this.selectable = false,
    this.selected = false,
    this.onSelectToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final selectedBg = cs.surfaceContainerHighest;
    final selectedFg = cs.onSurface;
    final appOpts =
        theme.extension<AppOptions>() ??
        const AppOptions(compact: false, highContrast: false);
    final basePad = appOpts.compact ? 8.0 : 12.0;
    final gap = appOpts.compact ? 6.0 : 8.0;
    final titleSize = appOpts.compact ? 15.0 : 16.0;
    final subtitleGap = appOpts.compact ? 2.0 : 4.0;
    final controlPad = appOpts.compact ? 2.0 : 4.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Slidable(
        key: ValueKey(todo.id),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => onEdit(),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              icon: Icons.edit_outlined,
              label: 'Edit',
            ),
            SlidableAction(
              onPressed: (_) => onDelete(),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete_outline,
              label: 'Delete',
            ),
          ],
        ),
        child: Semantics(
          container: true,
          selected: selected,
          label: todo.text,
          hint: selectable
              ? (selected
                    ? 'Selected. Double tap to deselect.'
                    : 'Not selected. Double tap to select.')
              : 'Double tap to edit task. Long press to select.',
          child: Card(
            elevation: todo.isCompleted ? 0 : 1,
            color: selected
                ? selectedBg
                : (theme.brightness == Brightness.dark
                      ? cs.surfaceContainerHigh
                      : null),
            child: InkWell(
              onTap: () {
                if (selectable && onSelectToggle != null) {
                  onSelectToggle!();
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        TaskEditorScreen(todo: todo, onSave: (updatedTask) {}),
                  ),
                );
              },
              onLongPress: () {
                if (onSelectToggle != null) {
                  onSelectToggle!();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOutCubicEmphasized,
                padding: EdgeInsets.all(basePad),
                child: Row(
                  children: [
                    selectable
                        ? GestureDetector(
                            onTap: onSelectToggle,
                            child: Container(
                              padding: EdgeInsets.all(controlPad),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                curve: Curves.easeInOutCubicEmphasized,
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                    width: 2,
                                  ),
                                  color: selected
                                      ? theme.colorScheme.primary
                                      : Colors.transparent,
                                ),
                                child: selected
                                    ? Icon(
                                        Icons.check,
                                        size: 16,
                                        color: theme.colorScheme.onPrimary,
                                      )
                                    : null,
                              ),
                            ),
                          )
                        : GestureDetector(
                            onTap: onToggle,
                            child: Container(
                              padding: EdgeInsets.all(controlPad),
                              child: Checkbox(
                                value: todo.isCompleted,
                                onChanged: (_) => onToggle(),
                                shape: const CircleBorder(),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                    SizedBox(width: gap),
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
                              color: selected
                                  ? selectedFg
                                  : (todo.isCompleted
                                        ? theme.colorScheme.outline
                                        : theme.colorScheme.onSurface),
                              fontWeight: todo.isCompleted
                                  ? FontWeight.normal
                                  : FontWeight.w500,
                              fontSize: titleSize,
                              letterSpacing: appOpts.highContrast ? 0.2 : null,
                            ),
                          ),
                          if (_hasSubtitleContent()) ...[
                            SizedBox(height: subtitleGap),
                            _buildSubtitleRow(
                              context,
                              overrideColor: selected
                                  ? selectedFg.withAlpha(180)
                                  : null,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_buildTrailing(context) != null) ...[
                      SizedBox(width: gap),
                      _buildTrailing(context)!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _hasSubtitleContent() =>
      todo.dueDate != null || (todo.notes != null && todo.notes!.isNotEmpty);

  Widget _buildSubtitleRow(BuildContext context, {Color? overrideColor}) {
    final parts = <Widget>[];
    if (todo.dueDate != null) {
      final dueDateText = DateFormat('MMM dd, yyyy').format(todo.dueDate!);
      final isOverdue = todo.isOverdue;
      final isDueToday = todo.isDueToday;
      Color dateColor = overrideColor ?? Theme.of(context).colorScheme.outline;
      if (isOverdue && !todo.isCompleted) {
        dateColor = Theme.of(context).colorScheme.error;
      } else if (isDueToday && !todo.isCompleted) {
        dateColor = Theme.of(context).colorScheme.tertiary;
      }
      parts.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_outlined, size: 14, color: dateColor),
            const SizedBox(width: 4),
            Text(
              dueDateText,
              style: TextStyle(
                color: dateColor,
                fontSize: 12,
                fontWeight: isOverdue || isDueToday ? FontWeight.w600 : null,
              ),
            ),
          ],
        ),
      );
    }
    if (todo.notes != null && todo.notes!.isNotEmpty) {
      parts.add(
        Text(
          todo.notes!,
          style: TextStyle(
            color: overrideColor ?? Theme.of(context).colorScheme.outline,
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    return Wrap(spacing: 12, runSpacing: 4, children: parts);
  }

  Widget? _buildTrailing(BuildContext context) {
    final priorityColor = AppTheme.getPriorityColor(
      todo.priority,
      Theme.of(context).colorScheme,
    );
    if (showDragHandle) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: priorityColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 4),
              Icon(
                AppTheme.getPriorityIcon(todo.priority),
                size: 16,
                color: priorityColor,
              ),
            ],
          ),
          SizedBox(
            width: (Theme.of(context).extension<AppOptions>()?.compact ?? false)
                ? 4
                : 8,
          ),
          Icon(Icons.drag_handle, color: Theme.of(context).colorScheme.outline),
        ],
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: priorityColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Icon(
          AppTheme.getPriorityIcon(todo.priority),
          size: 16,
          color: priorityColor,
        ),
      ],
    );
  }
}
