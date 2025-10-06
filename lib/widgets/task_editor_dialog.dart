import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';
import '../services/storage_service.dart';

/// Unified Task Editor Dialog
/// Handles both creating new tasks and editing existing ones
/// Follows Android Material Design 3 best practices
class TaskEditorDialog extends ConsumerStatefulWidget {
  final Todo? todo;
  final Function(Todo) onAdd;

  const TaskEditorDialog({super.key, this.todo, required this.onAdd});

  @override
  ConsumerState<TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends ConsumerState<TaskEditorDialog> {
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  final _formKey = GlobalKey<FormState>();

  // Core task data
  DateTime? _startDate;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  bool _isMultiDay = false;
  String _priority = 'medium';
  String _selectedFolderId = '';
  List<int> _reminderOffsetsMinutes = [];

  // UI state
  bool _showAdvancedOptions = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.todo?.text ?? '');
    _notesController = TextEditingController(text: widget.todo?.notes ?? '');

    // Initialize from existing todo if editing
    if (widget.todo != null) {
      _startDate = widget.todo!.startDate;
      _dueDate = widget.todo!.dueDate;
      _isMultiDay = _startDate != null && _dueDate != null;
      if (_dueDate != null) {
        _dueTime = TimeOfDay.fromDateTime(_dueDate!);
      }
      _priority = widget.todo!.priority;
      _reminderOffsetsMinutes = List<int>.from(
        widget.todo!.reminderOffsetsMinutes,
      );
    }

    _initializeFolderSelection();
  }

  Future<void> _initializeFolderSelection() async {
    if (widget.todo?.folderId != null) {
      _selectedFolderId = widget.todo!.folderId!;
    } else {
      try {
        _selectedFolderId = await StorageService.getDefaultFolderId();
      } catch (e) {
        _selectedFolderId = '';
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(theme, colorScheme),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title input
                      _buildTitleInput(theme),
                      const SizedBox(height: 20),

                      // Quick actions row
                      _buildQuickActions(theme, colorScheme),
                      const SizedBox(height: 20),

                      // Advanced options
                      if (_showAdvancedOptions) ...[
                        _buildAdvancedOptions(theme, colorScheme),
                        const SizedBox(height: 20),
                      ],

                      // Advanced toggle
                      _buildAdvancedToggle(theme),
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            _buildActions(theme, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 8, 16),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.add_task, color: colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 16),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.todo == null ? 'New Task' : 'Edit Task',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Add to your task list',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          // Close button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close),
            style: IconButton.styleFrom(
              foregroundColor: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleInput(ThemeData theme) {
    return TextFormField(
      controller: _titleController,
      autofocus: true,
      decoration: InputDecoration(
        labelText: 'Task title',
        hintText: 'What needs to be done?',
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        prefixIcon: Icon(Icons.title),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter a task title';
        }
        return null;
      },
      maxLines: null,
      textCapitalization: TextCapitalization.sentences,
    );
  }

  Widget _buildQuickActions(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Options',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface.withOpacity(0.9),
          ),
        ),
        const SizedBox(height: 12),
        // Date selection (full width for better display of ranges)
        _buildQuickActionChip(
          icon: Icons.event,
          label: _getDueDateLabel(),
          isSelected: _dueDate != null,
          onTap: _selectDueDate,
          theme: theme,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 12),

        // Time selection (only show if date is selected)
        if (_dueDate != null) ...[
          _buildQuickActionChip(
            icon: Icons.schedule,
            label: _getTimeLabel(),
            isSelected: _dueTime != null,
            onTap: _selectTime,
            theme: theme,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 12),
        ],

        // Priority selection
        _buildQuickActionChip(
          icon: _getPriorityIcon(_priority),
          label: 'Priority: ${_priority.toUpperCase()}',
          isSelected: _priority != 'medium',
          onTap: _cyclePriority,
          theme: theme,
          colorScheme: colorScheme,
        ),
      ],
    );
  }

  String _getDueDateLabel() {
    if (_dueDate == null) {
      return 'Select date or date range';
    } else if (_isMultiDay && _startDate != null && _startDate != _dueDate) {
      // Multi-day: show date range only if start and end are different
      return '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d').format(_dueDate!)}';
    } else {
      // Single day: show just the date (even if _isMultiDay is true but dates are same)
      return DateFormat('MMM d, yyyy').format(_dueDate!);
    }
  }

  String _getTimeLabel() {
    if (_dueTime == null) {
      return 'All day';
    } else {
      return _dueTime!.format(context);
    }
  }

  Widget _buildQuickActionChip({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary.withValues(alpha: 0.3)
                  : colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedOptions(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional Options',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface.withOpacity(0.9),
          ),
        ),
        const SizedBox(height: 16),

        // Notes input
        TextFormField(
          controller: _notesController,
          decoration: InputDecoration(
            labelText: 'Notes (optional)',
            hintText: 'Add details...',
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            prefixIcon: Icon(Icons.notes),
          ),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }

  Widget _buildAdvancedToggle(ThemeData theme) {
    return TextButton.icon(
      onPressed: () {
        setState(() => _showAdvancedOptions = !_showAdvancedOptions);
      },
      icon: Icon(_showAdvancedOptions ? Icons.expand_less : Icons.expand_more),
      label: Text(_showAdvancedOptions ? 'Less options' : 'More options'),
    );
  }

  Widget _buildActions(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          // Cancel button
          Expanded(
            child: OutlinedButton(
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 16),

          // Save button
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _isLoading ? null : _saveTodo,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.todo == null ? 'Add Task' : 'Save Changes'),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  IconData _getPriorityIcon(String priority) {
    switch (priority) {
      case 'high':
        return Icons.keyboard_arrow_up;
      case 'low':
        return Icons.keyboard_arrow_down;
      default:
        return Icons.remove;
    }
  }

  void _cyclePriority() {
    setState(() {
      switch (_priority) {
        case 'low':
          _priority = 'medium';
          break;
        case 'medium':
          _priority = 'high';
          break;
        case 'high':
          _priority = 'low';
          break;
      }
    });
  }

  Future<void> _selectDueDate() async {
    // Show Material's built-in date range picker
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _dueDate != null
          ? DateTimeRange(start: _startDate!, end: _dueDate!)
          : null,
      helpText: 'Select date or date range',
      saveText: 'Done',
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _dueDate = picked.end;
        // Only consider it multi-day if the dates are actually different
        _isMultiDay = picked.start != picked.end;
      });
    }
  }

  Future<void> _selectTime() async {
    if (_dueDate != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: _dueTime ?? TimeOfDay.now(),
        helpText: 'Select time',
      );
      if (time != null) {
        setState(() => _dueTime = time);
      }
    }
  }

  // Remove the old _askForTime method since we now have separate time selection

  Future<void> _saveTodo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Combine date and time
      DateTime? finalDueDate;
      if (_dueDate != null) {
        if (_dueTime != null) {
          finalDueDate = DateTime(
            _dueDate!.year,
            _dueDate!.month,
            _dueDate!.day,
            _dueTime!.hour,
            _dueTime!.minute,
          );
        } else {
          finalDueDate = _dueDate;
        }
      }

      final todo = Todo(
        id: widget.todo?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        text: _titleController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        startDate: _isMultiDay ? _startDate : null,
        dueDate: finalDueDate,
        priority: _priority,
        folderId: _selectedFolderId.isEmpty ? null : _selectedFolderId,
        reminderOffsetsMinutes: _reminderOffsetsMinutes,
        isCompleted: widget.todo?.isCompleted ?? false,
        createdAt: widget.todo?.createdAt ?? DateTime.now(),
        completedAt: widget.todo?.completedAt,
      );

      widget.onAdd(todo);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving task: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
