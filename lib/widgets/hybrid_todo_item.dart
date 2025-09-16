import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';
import '../services/theme_service.dart';
import '../services/folder_provider.dart';
import '../screens/task_editor_screen.dart';

/// Unified task display component that works consistently across list and calendar views
class HybridTodoItem extends ConsumerWidget {
  final Todo todo;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  
  // Display mode configuration
  final bool compact; // For calendar view or compact list mode
  final bool showDragHandle;
  final bool enableSlidable; // Enable slide actions (typically for list view)
  
  // Selection mode
  final bool selectable;
  final bool selected;
  final VoidCallback? onSelectToggle;
  
  // Calendar-specific
  final bool showTimeInfo; // Show time info instead of due date

  const HybridTodoItem({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.compact = false,
    this.showDragHandle = false,
    this.enableSlidable = true,
    this.selectable = false,
    this.selected = false,
    this.onSelectToggle,
    this.showTimeInfo = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selectedBg = cs.secondaryContainer;
    final selectedFg = cs.onSecondaryContainer;
    final appOpts = theme.extension<AppOptions>() ?? const AppOptions(compact: false, highContrast: false);
    
    // Get folder data for this todo if it has a folder
    final foldersAsync = ref.watch(folderNotifierProvider);
    final currentFolder = todo.folderId != null 
        ? foldersAsync.whenOrNull(data: (folders) => folders.where((f) => f.id == todo.folderId).firstOrNull)
        : null;
    
    // Adapt spacing based on compact mode
    final actualCompact = compact || appOpts.compact;
    final basePad = actualCompact ? 8.0 : 12.0;
    final gap = actualCompact ? 6.0 : 8.0;
    final titleSize = actualCompact ? 14.0 : 16.0;
    final subtitleGap = actualCompact ? 2.0 : 4.0;
    final controlPad = actualCompact ? 2.0 : 4.0;

    Widget content = _buildItemContent(context, ref, theme, cs, selectedBg, selectedFg, appOpts, basePad, gap, titleSize, subtitleGap, controlPad, currentFolder);

    // Wrap with slidable if enabled (typically for list view)
    if (enableSlidable) {
      content = Slidable(
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
        child: content,
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 4 : 8),
      child: content,
    );
  }

  Widget _buildItemContent(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ColorScheme cs,
    Color selectedBg,
    Color selectedFg,
    AppOptions appOpts,
    double basePad,
    double gap,
    double titleSize,
    double subtitleGap,
    double controlPad,
    dynamic currentFolder, // Add folder parameter
  ) {
    return Semantics(
      container: true,
      selected: selected,
      label: todo.text,
      hint: selectable
          ? (selected ? 'Selected. Double tap to deselect.' : 'Not selected. Double tap to select.')
          : 'Double tap to edit task. Long press to select.',
      child: Card(
        elevation: compact ? 0 : (todo.isCompleted ? 1 : 2),
        color: compact 
            ? (selected ? selectedBg : cs.surfaceContainerHighest)
            : (selected ? selectedBg : null),
        child: InkWell(
          onTap: () {
            if (selectable && onSelectToggle != null) {
              onSelectToggle!();
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TaskEditorScreen(
                  todo: todo,
                  onSave: (updatedTask) {
                    // The save will be handled by the TaskEditorScreen automatically
                    // via the task controller, so we don't need to do anything here
                  },
                ),
              ),
            );
          },
          onLongPress: () {
            if (onSelectToggle != null) {
              onSelectToggle!();
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            padding: EdgeInsets.all(basePad),
            child: Row(
              children: [
                _buildCheckbox(context, theme, cs, controlPad),
                SizedBox(width: gap),
                Expanded(
                  child: _buildTaskContent(context, ref, theme, cs, selectedFg, titleSize, subtitleGap, currentFolder),
                ),
                if (_buildTrailing(context, ref, theme, cs, currentFolder) != null) ...[
                  SizedBox(width: gap),
                  _buildTrailing(context, ref, theme, cs, currentFolder)!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(BuildContext context, ThemeData theme, ColorScheme cs, double controlPad) {
    if (selectable) {
      return GestureDetector(
        onTap: onSelectToggle,
        child: Container(
          padding: EdgeInsets.all(controlPad),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? cs.primary : cs.outline,
                width: 2,
              ),
              color: selected ? cs.primary : Colors.transparent,
            ),
            child: selected
                ? Icon(PhosphorIcons.check(), size: 16, color: cs.onPrimary)
                : null,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: EdgeInsets.all(controlPad),
        child: Checkbox(
          value: todo.isCompleted,
          onChanged: (_) => onToggle(),
          shape: const CircleBorder(), // Consistent circular checkboxes
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  Widget _buildTaskContent(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ColorScheme cs,
    Color selectedFg,
    double titleSize,
    double subtitleGap,
    dynamic currentFolder,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          todo.text,
          style: TextStyle(
            decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
            color: selected
                ? selectedFg
                : (todo.isCompleted ? cs.outline : cs.onSurface),
            fontWeight: todo.isCompleted ? FontWeight.normal : FontWeight.w500,
            fontSize: titleSize,
            letterSpacing: theme.extension<AppOptions>()?.highContrast == true ? 0.2 : null,
          ),
        ),
        if (_hasSubtitleContent()) ...[
          SizedBox(height: subtitleGap),
          _buildSubtitleRow(context, ref, currentFolder, overrideColor: selected ? selectedFg.withAlpha(180) : null),
        ],
      ],
    );
  }

  bool _hasSubtitleContent() {
    return todo.dueDate != null || (todo.notes != null && todo.notes!.isNotEmpty) || todo.folderId != null;
  }

  Widget _buildSubtitleRow(BuildContext context, WidgetRef ref, dynamic currentFolder, {Color? overrideColor}) {
    final parts = <Widget>[];
    
    // Date/Time information
    if (todo.dueDate != null) {
      if (showTimeInfo) {
        // Calendar view - show time info (including "All day")
        final timeText = _formatTaskTime(todo, context);
        parts.add(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIcons.clock(), size: 14, color: overrideColor ?? Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              timeText,
              style: TextStyle(
                color: overrideColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ));
      } else {
        // List view - show due date with status colors AND "All day" indicator
        final dueDateText = DateFormat('MMM dd, yyyy').format(todo.dueDate!);
        final isOverdue = todo.isOverdue;
        final isDueToday = todo.isDueToday;
        final isAllDay = _isAllDayTask(todo);
        
        Color dateColor = overrideColor ?? Theme.of(context).colorScheme.outline;
        if (isOverdue && !todo.isCompleted) {
          dateColor = Colors.red;
        } else if (isDueToday && !todo.isCompleted) {
          dateColor = Colors.orange;
        }
        
        parts.add(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIcons.calendar(), size: 14, color: dateColor),
            const SizedBox(width: 4),
            Text(
              isAllDay ? '$dueDateText (All day)' : dueDateText,
              style: TextStyle(
                color: dateColor,
                fontSize: 12,
                fontWeight: isOverdue || isDueToday ? FontWeight.w600 : null,
              ),
            ),
          ],
        ));
      }
    }

    // Folder information (show in BOTH views with folder name and color)
    if (currentFolder != null) {
      parts.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIcons.folder(),
            size: 14,
            color: Color(currentFolder.color),
          ),
          const SizedBox(width: 4),
          Text(
            currentFolder.name.toUpperCase(),
            style: TextStyle(
              color: overrideColor ?? Color(currentFolder.color),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ));
    }

    // Notes
    if (todo.notes != null && todo.notes!.isNotEmpty) {
      parts.add(Text(
        todo.notes!,
        style: TextStyle(
          color: overrideColor ?? Theme.of(context).colorScheme.outline,
          fontSize: 12,
        ),
        maxLines: compact ? 1 : 2,
        overflow: TextOverflow.ellipsis,
      ));
    }

    return Wrap(spacing: 12, runSpacing: 4, children: parts);
  }

  String _formatTaskTime(Todo task, BuildContext context) {
    if (task.startDate != null && task.dueDate != null) {
      // Multi-day task
      if (isSameDay(task.startDate!, task.dueDate!)) {
        return 'All day';
      } else {
        return '${DateFormat('MMM d').format(task.startDate!)} - ${DateFormat('MMM d').format(task.dueDate!)}';
      }
    } else if (task.dueDate != null) {
      // Single day with possible time
      final time = TimeOfDay.fromDateTime(task.dueDate!);
      if (time.hour == 0 && time.minute == 0) {
        return 'All day';
      } else {
        return time.format(context);
      }
    }
    return '';
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  bool _isAllDayTask(Todo task) {
    if (task.dueDate == null) return false;
    final time = TimeOfDay.fromDateTime(task.dueDate!);
    return time.hour == 0 && time.minute == 0;
  }

  Widget? _buildTrailing(BuildContext context, WidgetRef ref, ThemeData theme, ColorScheme cs, dynamic currentFolder) {
    final priorityColor = AppTheme.getPriorityColor(
      todo.priority,
      isDark: theme.brightness == Brightness.dark,
    );

    // Get folder color if available
    Color? folderColor;
    if (currentFolder != null) {
      folderColor = Color(currentFolder.color);
    }

    if (showDragHandle) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIndicators(priorityColor, folderColor, theme),
          SizedBox(width: (theme.extension<AppOptions>()?.compact ?? false) ? 4 : 8),
          Icon(PhosphorIcons.dotsSixVertical(), color: cs.outline),
        ],
      );
    }

    return _buildIndicators(priorityColor, folderColor, theme);
  }

  Widget _buildIndicators(Color priorityColor, Color? folderColor, ThemeData theme) {
    // Always use consistent dot + icon approach (no more folder dots, just priority)
    // Make the indicators expand to the available height so centering works
    return SizedBox(
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          // Priority indicator (consistent across both views)
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
          // No folder indicator here since folder name shows in subtitle
        ],
      ),
    );
  }
}
