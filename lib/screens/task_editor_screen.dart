import 'package:flutter/material.dart';
import 'package:trudido/utils/responsive_size.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';
import '../services/storage_service.dart';
import '../services/folder_provider.dart';
import '../widgets/add_reminder_dialog.dart';
import '../widgets/create_folder_dialog.dart';

/// Unified Task Editor Screen
/// Handles both creating new tasks and editing existing ones
/// Full-screen Material Design 3 interface
class TaskEditorScreen extends ConsumerStatefulWidget {
  final Todo? todo;
  final Function(Todo) onSave;
  final DateTime? presetDueDate;

  const TaskEditorScreen({
    super.key,
    this.todo,
    required this.onSave,
    this.presetDueDate,
  });

  @override
  ConsumerState<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends ConsumerState<TaskEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  final _formKey = GlobalKey<FormState>();

  // Core task data
  DateTime? _startDate;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  bool _isMultiDay = false;
  String _priority = 'none';
  String _selectedFolderId = '';
  List<int> _reminderOffsetsMinutes = [];

  // UI state
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
    } else if (widget.presetDueDate != null) {
      // If creating a new task with a preset due date (from calendar)
      // Only set the date, not the time (let user choose time if needed)
      _dueDate = DateTime(
        widget.presetDueDate!.year,
        widget.presetDueDate!.month,
        widget.presetDueDate!.day,
      );
      // Don't set _dueTime - let it stay null so user can choose
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.todo == null ? 'New Task' : 'Edit Task'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        actions: [
          // Save button in app bar
          TextButton(
            onPressed: _isLoading ? null : _saveTodo,
            child: _isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                    ),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title input
              _buildTitleInput(theme),
              const SizedBox(height: 24),

              // Quick actions
              _buildQuickActions(theme, colorScheme),
              const SizedBox(height: 24),

              // Advanced options (always visible)
              _buildAdvancedOptions(theme, colorScheme),
            ],
          ),
        ),
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
        prefixIcon: ScaledIcon(Icons.title),
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
          isSelected: _priority != 'none',
          onTap: _showPrioritySelector,
          theme: theme,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 12),

        // Reminder selection
        _buildQuickActionChip(
          icon: Icons.notifications,
          label: _getReminderLabel(),
          isSelected: _reminderOffsetsMinutes.isNotEmpty,
          onTap: _showAddReminderDialog,
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

  String _getReminderLabel() {
    if (_reminderOffsetsMinutes.isEmpty) {
      return 'Add reminders';
    } else if (_reminderOffsetsMinutes.length == 1) {
      return '1 reminder set';
    } else {
      return '${_reminderOffsetsMinutes.length} reminders set';
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
              ScaledIcon(
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
            prefixIcon: ScaledIcon(Icons.notes),
          ),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 16),

        // Folder selection
        _buildFolderSelection(theme, colorScheme),
      ],
    );
  }

  Widget _buildFolderSelection(ThemeData theme, ColorScheme colorScheme) {
    return Consumer(
      builder: (context, ref, child) {
        final foldersAsync = ref.watch(folderNotifierProvider);

        return foldersAsync.when(
          data: (folders) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Folder',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    // "None" option
                    FilterChip(
                      label: Text('NONE'),
                      selected: _selectedFolderId.isEmpty,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedFolderId = '');
                        }
                      },
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // Folder options
                    ...folders.map((folder) {
                      final isSelected = _selectedFolderId == folder.id;
                      return FilterChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Color(folder.color),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(folder.name.toUpperCase()),
                          ],
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedFolderId = folder.id);
                          }
                        },
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList(),
                    // Add folder chip
                    ActionChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ScaledIcon(Icons.add, size: 14, color: colorScheme.primary),
                          const SizedBox(width: 4),
                          Text('ADD FOLDER'),
                        ],
                      ),
                      onPressed: () => _showCreateFolderDialog(),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                      backgroundColor: colorScheme.primaryContainer,
                    ),
                  ],
                ),
              ],
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (error, stack) => Text('Error loading folders: $error'),
        );
      },
    );
  }

  void _showAddReminderDialog() {
    showDialog(
      context: context,
      builder: (context) => AddReminderDialog(
        existingReminders: _reminderOffsetsMinutes,
        onReminderAdded: (minutes) {
          setState(() {
            if (!_reminderOffsetsMinutes.contains(minutes)) {
              _reminderOffsetsMinutes.add(minutes);
              _reminderOffsetsMinutes.sort();
            }
          });
        },
      ),
    );
  }

  void _showCreateFolderDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const CreateFolderDialog(),
    );

    if (result == true) {
      // Folder was created successfully, refresh the folder list
      ref.read(folderNotifierProvider.notifier).loadFolders();
    }
  }

  // Helper methods
  IconData _getPriorityIcon(String priority) {
    switch (priority) {
      case 'high':
        return Icons.keyboard_arrow_up;
      case 'low':
        return Icons.keyboard_arrow_down;
      case 'medium':
        return Icons.remove;
      default: // 'none'
        return Icons.radio_button_unchecked;
    }
  }

  void _showPrioritySelector() {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Select Priority',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Divider(height: 1),

              // Priority options
              _buildPriorityOption(
                'none',
                'None',
                Icons.radio_button_unchecked,
                colorScheme.surfaceContainerHighest,
                colorScheme.onSurface,
              ),
              _buildPriorityOption(
                'low',
                'Low',
                Icons.keyboard_arrow_down,
                colorScheme.tertiaryContainer,
                colorScheme.onTertiaryContainer,
              ),
              _buildPriorityOption(
                'medium',
                'Medium',
                Icons.remove,
                colorScheme.secondaryContainer,
                colorScheme.onSecondaryContainer,
              ),
              _buildPriorityOption(
                'high',
                'High',
                Icons.keyboard_arrow_up,
                colorScheme.errorContainer,
                colorScheme.onErrorContainer,
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPriorityOption(
    String value,
    String label,
    IconData icon,
    Color backgroundColor,
    Color textColor,
  ) {
    final isSelected = _priority == value;
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ScaledIcon(icon, color: textColor, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? ScaledIcon(Icons.check, color: colorScheme.primary)
          : null,
      onTap: () {
        setState(() {
          _priority = value;
        });
        Navigator.pop(context);
      },
    );
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

      widget.onSave(todo);

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
