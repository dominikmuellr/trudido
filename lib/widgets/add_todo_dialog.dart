import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';
import '../services/folder_provider.dart';
import '../services/storage_service.dart';
import 'add_reminder_dialog.dart';
import 'reminder_components.dart';

class AddTodoDialog extends ConsumerStatefulWidget {
  final Todo? todo;
  final Function(Todo) onAdd;

  const AddTodoDialog({
    super.key,
    this.todo,
    required this.onAdd,
  });

  @override
  ConsumerState<AddTodoDialog> createState() => _AddTodoDialogState();
}

class _AddTodoDialogState extends ConsumerState<AddTodoDialog> {
  late TextEditingController _textController;
  late TextEditingController _notesController;
  late TextEditingController _timeController;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  // Add start date + multi-day toggle
  DateTime? _startDate; // new
  bool _multiDay = false; // new
  String _priority = 'medium';
  String _category = 'personal';
  String _selectedFolderId = '';
  
  // --- New state variable for multiple reminders ---
  List<int> _reminderOffsetsMinutes = [];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.todo?.text ?? '');
    _notesController = TextEditingController(text: widget.todo?.notes ?? '');
    _timeController = TextEditingController();
    _dueDate = widget.todo?.dueDate;
    _startDate = widget.todo?.startDate; // init
    // Determine multi-day
    if (_startDate != null && _dueDate != null && !_dueDate!.isBefore(_startDate!)) {
      _multiDay = true;
    }
    // Extract time from existing dueDate if available
    if (_dueDate != null) {
      _dueTime = TimeOfDay.fromDateTime(_dueDate!);
      _updateTimeController();
    }
    
    _priority = widget.todo?.priority ?? 'medium';
    _category = widget.todo?.category ?? 'personal';
    
    // --- Initialize reminders from existing todo ---
  _reminderOffsetsMinutes = List<int>.from(widget.todo?.reminderOffsetsMinutes ?? []);
    
    // Initialize folder selection
    _initializeFolderSelection();
  }

  Future<void> _initializeFolderSelection() async {
    if (widget.todo?.folderId != null) {
      // If editing existing todo, use its folder
      _selectedFolderId = widget.todo!.folderId!;
    } else {
      // For new todos, get default folder
      try {
        _selectedFolderId = await StorageService.getDefaultFolderId();
      } catch (e) {
        // Fallback - will be handled when folders load
        _selectedFolderId = '';
      }
    }
    
    if (mounted) {
      setState(() {
        // Folder selection initialized
      });
    }
  }

  void _updateTimeController() {
    if (_dueTime != null) {
      _timeController.text = _formatTime(_dueTime!);
    } else {
      _timeController.clear();
    }
  }

  String _formatTime(TimeOfDay time) {
    final use24HourFormat = MediaQuery.of(context).alwaysUse24HourFormat;
    
    if (use24HourFormat) {
      // 24-hour format: "14:30"
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      // 12-hour format with AM/PM: "2:30 PM"
      final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
      final minute = time.minute.toString().padLeft(2, '0');
      final period = time.period == DayPeriod.am ? 'AM' : 'PM';
      return '$hour:$minute $period';
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _notesController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  // --- New Methods for Multiple Reminders ---

  void _showAddReminderDialog() {
    showDialog(
      context: context,
      builder: (context) => AddReminderDialog(
        onReminderAdded: _addReminder,
        existingReminders: _reminderOffsetsMinutes,
      ),
    );
  }

  void _addReminder(int minutes) {
    setState(() {
      if (!_reminderOffsetsMinutes.contains(minutes)) {
        _reminderOffsetsMinutes.add(minutes);
        _reminderOffsetsMinutes.sort(); // Keep sorted
      }
    });
  }

  void _removeReminder(int minutes) {
    setState(() {
      _reminderOffsetsMinutes.remove(minutes);
    });
  }

  // --- End of New Methods ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final folders = ref.watch(folderNotifierProvider);
    
    return AlertDialog(
      title: Text(
        widget.todo == null ? 'Add Todo' : 'Edit Todo',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Task Title
              TextField(
                controller: _textController,
                decoration: InputDecoration(
                  labelText: 'Task',
                  hintText: 'What needs to be done?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(
                    PhosphorIcons.textT(PhosphorIconsStyle.regular),
                    color: theme.colorScheme.primary,
                  ),
                ),
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // Due Date Section
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline.withAlpha(77)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        children: [
                          Icon(PhosphorIcons.calendar(PhosphorIconsStyle.regular), color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Text('Schedule', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          if (_dueDate != null || _startDate != null)
                            IconButton(
                              icon: const Icon(Icons.close),
                              tooltip: 'Clear',
                              onPressed: () => setState(() { _dueDate = null; _startDate = null; _multiDay = false; _dueTime = null; }),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('Single Day')),
                          ButtonSegment(value: true, label: Text('Multi-Day')),
                        ],
                        selected: {_multiDay},
                        onSelectionChanged: (s) {
                          final v = s.first;
                          setState(() {
                            _multiDay = v;
                            if (v) {
                              _startDate ??= _dueDate ?? DateTime.now();
                            } else {
                              _startDate = null;
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        if (_multiDay) {
                          await _pickRange();
                        } else {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dueDate ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                          );
                          if (picked != null) {
                            setState(() { _dueDate = picked; });
                          }
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _multiDay
                                      ? (_startDate == null || _dueDate == null
                                          ? 'Select date range'
                                          : '${DateFormat('MMM d, yyyy').format(_startDate!)} → ${DateFormat('MMM d, yyyy').format(_dueDate!)}')
                                      : (_dueDate == null
                                          ? 'Set due date (optional)'
                                          : DateFormat('EEE, MMM d, yyyy').format(_dueDate!)),
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _multiDay && _startDate != null && _dueDate != null
                                      ? '${_dueDate!.difference(_startDate!).inDays + 1} day span'
                                      : (!_multiDay && _dueDate != null
                                          ? (_dueTime == null ? 'Add time' : 'Time: ${_formatTime(_dueTime!)}')
                                          : 'No schedule'),
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(_multiDay ? Icons.date_range : Icons.calendar_today, color: theme.colorScheme.primary),
                          ],
                        ),
                      ),
                    ),
                    if (!_multiDay && _dueDate != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Row(
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.access_time),
                              label: Text(_dueTime == null ? 'Add time' : _formatTime(_dueTime!)),
                              onPressed: _selectTime,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // --- New Reminder UI Section ---
              if (_dueDate != null) ...[
                const SizedBox(height: 16),
                RemindersSection(
                  reminderOffsets: _reminderOffsetsMinutes,
                  onRemoveReminder: _removeReminder,
                  onAddReminder: _showAddReminderDialog,
                ),
              ],
              // --- End of New Reminder UI ---

              const SizedBox(height: 16),

              // Notes
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Add additional details...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(
                    PhosphorIcons.notepad(PhosphorIconsStyle.regular),
                    color: theme.colorScheme.primary,
                  ),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                minLines: 1,
              ),
              const SizedBox(height: 16),

              // Priority Selection
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Priority',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _PriorityChip(
                          label: 'Low',
                          isSelected: _priority == 'low',
                          color: Colors.green,
                          onTap: () => setState(() => _priority = 'low'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PriorityChip(
                          label: 'Medium',
                          isSelected: _priority == 'medium',
                          color: Colors.orange,
                          onTap: () => setState(() => _priority = 'medium'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PriorityChip(
                          label: 'High',
                          isSelected: _priority == 'high',
                          color: Colors.red,
                          onTap: () => setState(() => _priority = 'high'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Category Selection
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _CategoryChip(
                        label: 'Personal',
                        isSelected: _category == 'personal',
                        onTap: () => setState(() => _category = 'personal'),
                      ),
                      _CategoryChip(
                        label: 'Work',
                        isSelected: _category == 'work',
                        onTap: () => setState(() => _category = 'work'),
                      ),
                      _CategoryChip(
                        label: 'Health',
                        isSelected: _category == 'health',
                        onTap: () => setState(() => _category = 'health'),
                      ),
                      _CategoryChip(
                        label: 'Education',
                        isSelected: _category == 'education',
                        onTap: () => setState(() => _category = 'education'),
                      ),
                      _CategoryChip(
                        label: 'Shopping',
                        isSelected: _category == 'shopping',
                        onTap: () => setState(() => _category = 'shopping'),
                      ),
                      _CategoryChip(
                        label: 'Other',
                        isSelected: _category == 'other',
                        onTap: () => setState(() => _category = 'other'),
                      ),
                    ],
                  ),
                ],
              ),

              // Folder Selection
              folders.when(
                data: (folderList) => folderList.isNotEmpty ? Column(
                  children: [
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Folder',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedFolderId.isEmpty ? null : _selectedFolderId,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: Icon(
                              PhosphorIcons.folderOpen(PhosphorIconsStyle.regular),
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          hint: const Text('Select folder (optional)'),
                          items: [
                            const DropdownMenuItem<String>(
                              value: '',
                              child: Text('No folder'),
                            ),
                            ...folderList.map((folder) => DropdownMenuItem<String>(
                              value: folder.id,
                              child: Row(
                                children: [
                                  Icon(_getFolderIcon(folder.icon), size: 16),
                                  const SizedBox(width: 8),
                                  Text(folder.name),
                                ],
                              ),
                            )),
                          ],
                          onChanged: (value) => setState(() => _selectedFolderId = value ?? ''),
                        ),
                      ],
                    ),
                  ],
                ) : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (error, stack) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _textController.text.trim().isNotEmpty ? _saveTodo : null,
          child: Text(widget.todo == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }

  // Add range picker helper
  Future<void> _pickRange() async {
    final now = DateTime.now();
    final initialStart = _startDate ?? _dueDate ?? now;
    final initialEnd = _dueDate ?? initialStart;
    final range = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd.isBefore(initialStart) ? initialStart : initialEnd),
    );
    if (range == null) return;
    setState(() {
      _startDate = DateTime(range.start.year, range.start.month, range.start.day);
      // keep any existing time on due date if present
      final existing = _dueDate;
      _dueDate = DateTime(range.end.year, range.end.month, range.end.day, existing?.hour ?? 23, existing?.minute ?? 59);
      _multiDay = true;
    });
  }

  Future<void> _selectTime() async {
  debugPrint('AddTodoDialog: _selectTime() called');
    final time = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
    );
  debugPrint('AddTodoDialog: Time picker result: $time');
    if (time != null) {
      setState(() {
        _dueTime = time;
        _updateTimeController();
        // Add default reminder if due date is set and no reminders exist
        if (_dueDate != null && _reminderOffsetsMinutes.isEmpty) {
          debugPrint('AddTodoDialog: Adding default reminder at due time (from time selection)');
          _reminderOffsetsMinutes.add(0); // At due time
        }
  debugPrint('AddTodoDialog: Time set, current reminders: $_reminderOffsetsMinutes');
      });
    }
  }

  void _saveTodo() {
    DateTime? finalDueDate = _dueDate;
    
    // Combine date and time if both are set
    if (_dueDate != null && _dueTime != null) {
      finalDueDate = DateTime(
        _dueDate!.year,
        _dueDate!.month,
        _dueDate!.day,
        _dueTime!.hour,
        _dueTime!.minute,
      );
    }

    // Ensure there's a default reminder if due date is set but no reminders exist
    if (finalDueDate != null && _reminderOffsetsMinutes.isEmpty) {
  debugPrint('AddTodoDialog: Adding default reminder in _saveTodo - due date set but no reminders');
      _reminderOffsetsMinutes.add(0); // At due time
    }
    
  debugPrint('AddTodoDialog: _saveTodo - Due date: $finalDueDate, Reminders: $_reminderOffsetsMinutes');

    final todo = widget.todo?.copyWith(
      text: _textController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      dueDate: finalDueDate,
      startDate: _multiDay ? _startDate : null, // new
      priority: _priority,
      category: _category,
      folderId: _selectedFolderId.isNotEmpty ? _selectedFolderId : null,
      // --- Add the reminders to the updated task ---
      reminderOffsetsMinutes: _reminderOffsetsMinutes,
    ) ?? Todo(
      text: _textController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      dueDate: finalDueDate,
      startDate: _multiDay ? _startDate : null, // new
      priority: _priority,
      category: _category,
      folderId: _selectedFolderId.isNotEmpty ? _selectedFolderId : null,
      // --- Add the reminders to the new task ---
      reminderOffsetsMinutes: _reminderOffsetsMinutes,
    );

    widget.onAdd(todo);
    Navigator.of(context).pop();
  }

  IconData _getFolderIcon(String? iconName) {
    switch (iconName) {
      case 'work':
        return PhosphorIcons.briefcase(PhosphorIconsStyle.regular);
      case 'personal':
        return PhosphorIcons.house(PhosphorIconsStyle.regular);
      case 'education':
        return PhosphorIcons.graduationCap(PhosphorIconsStyle.regular);
      case 'health':
        return PhosphorIcons.heartbeat(PhosphorIconsStyle.regular);
      case 'shopping':
        return PhosphorIcons.shoppingCart(PhosphorIconsStyle.regular);
      case 'travel':
        return PhosphorIcons.airplane(PhosphorIconsStyle.regular);
      case 'finance':
        return PhosphorIcons.currencyDollar(PhosphorIconsStyle.regular);
      case 'home':
        return PhosphorIcons.house(PhosphorIconsStyle.regular);
      case 'car':
        return PhosphorIcons.car(PhosphorIconsStyle.regular);
      case 'music':
        return PhosphorIcons.musicNote(PhosphorIconsStyle.regular);
      case 'sport':
        return PhosphorIcons.basketball(PhosphorIconsStyle.regular);
      case 'book':
        return PhosphorIcons.book(PhosphorIconsStyle.regular);
      default:
        return PhosphorIcons.folder(PhosphorIconsStyle.regular);
    }
  }
}

// Priority Chip Widget
class _PriorityChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _PriorityChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(38) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : theme.colorScheme.outline.withAlpha(77),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isSelected ? color : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Category Chip Widget
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? theme.colorScheme.primary 
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? theme.colorScheme.primary 
                : theme.colorScheme.outline.withAlpha(77),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isSelected 
                ? theme.colorScheme.onPrimary 
                : theme.colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}


