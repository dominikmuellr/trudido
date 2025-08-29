import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';
import '../services/theme_service.dart';
import '../screens/edit_task_screen.dart';

class TodoItem extends StatelessWidget {
  final Todo todo;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool showDragHandle;

  const TodoItem({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.showDragHandle = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
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
              icon: PhosphorIcons.pencil(),
              label: 'Edit',
            ),
            SlidableAction(
              onPressed: (_) => onDelete(),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: PhosphorIcons.trash(),
              label: 'Delete',
            ),
          ],
        ),
        child: Card(
          elevation: todo.isCompleted ? 1 : 2,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditTaskScreen(task: todo),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Checkbox for completion toggle
                  GestureDetector(
                    onTap: onToggle,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Checkbox(
                        value: todo.isCompleted,
                        onChanged: (_) => onToggle(),
                        shape: const CircleBorder(),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Task content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          todo.text,
                          style: TextStyle(
                            decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                            color: todo.isCompleted 
                                ? theme.colorScheme.outline 
                                : theme.colorScheme.onSurface,
                            fontWeight: todo.isCompleted ? FontWeight.normal : FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                        if (_hasSubtitleContent()) ...[
                          const SizedBox(height: 4),
                          _buildSubtitleRow(context),
                        ],
                      ],
                    ),
                  ),
                  
                  // Trailing elements
                  if (_buildTrailing(context) != null) ...[
                    const SizedBox(width: 8),
                    _buildTrailing(context)!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _hasSubtitleContent() {
    return todo.dueDate != null || 
           (todo.notes != null && todo.notes!.isNotEmpty) ||
           todo.category != 'personal';
  }

  Widget _buildSubtitleRow(BuildContext context) {
    final parts = <Widget>[];
    
    // Add due date if exists
    if (todo.dueDate != null) {
      final dueDateText = DateFormat('MMM dd, yyyy').format(todo.dueDate!);
      final isOverdue = todo.isOverdue;
      final isDueToday = todo.isDueToday;
      
      Color dateColor = Theme.of(context).colorScheme.outline;
      if (isOverdue && !todo.isCompleted) {
        dateColor = Colors.red;
      } else if (isDueToday && !todo.isCompleted) {
        dateColor = Colors.orange;
      }
      
      parts.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIcons.calendar(),
              size: 14,
              color: dateColor,
            ),
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
    
    // Add category if not default
    if (todo.category != 'personal') {
      parts.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIcons.folder(),
              size: 14,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(width: 4),
            Text(
              todo.category.toUpperCase(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    
    // Add notes if exists
    if (todo.notes != null && todo.notes!.isNotEmpty) {
      parts.add(
        Text(
          todo.notes!,
          style: TextStyle(
            color: Theme.of(context).colorScheme.outline,
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: parts,
    );
  }

  Widget? _buildTrailing(BuildContext context) {
    final priorityColor = AppTheme.getPriorityColor(
      todo.priority,
      isDark: Theme.of(context).brightness == Brightness.dark,
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
          const SizedBox(width: 8),
          Icon(
            PhosphorIcons.dotsSixVertical(),
            color: Theme.of(context).colorScheme.outline,
          ),
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
