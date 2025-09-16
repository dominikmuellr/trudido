// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';
import '../controllers/task_controller.dart';
import '../widgets/reminder_components.dart';
import '../widgets/add_reminder_dialog.dart';

class EditTaskScreen extends ConsumerStatefulWidget {
  final Todo? task;

  const EditTaskScreen({
    super.key,
    this.task,
  });

  @override
  ConsumerState<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends ConsumerState<EditTaskScreen> {
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late String _selectedPriority;
  String? _selectedFolderId;
  DateTime? _selectedDueDate;
  DateTime? _selectedStartDate; // new for multi-day
  bool _multiDay = false;
  List<int> _reminderOffsetsMinutes = []; // Updated for multiple reminders
  List<String> _tags = [];
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    if (widget.task != null) {
      _titleController = TextEditingController(text: widget.task!.text);
      _notesController = TextEditingController(text: widget.task!.notes ?? '');
      
      // Ensure priority is valid
      const validPriorities = ['low', 'medium', 'high'];
      _selectedPriority = validPriorities.contains(widget.task!.priority) 
          ? widget.task!.priority 
          : 'medium';
      
      _selectedFolderId = widget.task!.folderId;
  _selectedDueDate = widget.task!.dueDate;
  _selectedStartDate = widget.task!.startDate;
  _multiDay = widget.task!.startDate != null && widget.task!.dueDate != null && !widget.task!.dueDate!.isBefore(widget.task!.startDate!);
  _reminderOffsetsMinutes = List<int>.from(widget.task?.reminderOffsetsMinutes ?? []); // Updated
  _tags = List<String>.from(widget.task?.tags ?? []);
    } else {
      _titleController = TextEditingController();
      _notesController = TextEditingController();
      _selectedPriority = 'medium';
      _reminderOffsetsMinutes = [];
      _tags = [];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

  setState(() { _isLoading = true; });

    try {
  if (widget.task != null) {
        // Update existing task
        debugPrint('EditTaskScreen: Updating existing task with reminders: $_reminderOffsetsMinutes');
        final updatedTask = widget.task!.copyWith(
          text: _titleController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          priority: _selectedPriority,
          folderId: _selectedFolderId,
          dueDate: _selectedDueDate,
          startDate: _multiDay ? _selectedStartDate : null,
          reminderOffsetsMinutes: _reminderOffsetsMinutes, // Updated
          tags: _tags,
        );

  await ref.read(taskControllerProvider.notifier).update(updatedTask);
      } else {
        // Create new task
        debugPrint('EditTaskScreen: Creating new task with reminders: $_reminderOffsetsMinutes');
        final newTask = Todo(
          text: _titleController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          priority: _selectedPriority,
          folderId: _selectedFolderId,
          dueDate: _selectedDueDate,
          startDate: _multiDay ? _selectedStartDate : null,
          reminderOffsetsMinutes: _reminderOffsetsMinutes, // Updated
          tags: _tags,
        );

  await ref.read(taskControllerProvider.notifier).add(newTask);
      }

  if (!mounted) return;
  Navigator.of(context).pop({
        'success': true,
        'action': widget.task != null ? 'updated' : 'created',
        'message': widget.task != null ? 'Task updated successfully' : 'Task created successfully'
      });
    } catch (e) {
  if (!mounted) return;
  Navigator.of(context).pop({
        'success': false,
        'error': e.toString(),
        'message': 'Error saving task: $e'
      });
    }
    finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDueDate() async {
    debugPrint('EditTaskScreen: _selectDueDate() called');
    final localContext = context; // capture for immediate use only
    final initialDate = _selectedDueDate ?? DateTime.now();
  final DateTime? pickedDate = await showDatePicker(
      context: localContext,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (!mounted) return; // do not use context unless still mounted
    debugPrint('EditTaskScreen: Date picker result: $pickedDate');
    if (pickedDate == null) return;
  final TimeOfDay? pickedTime = await showTimePicker(
      context: localContext,
      initialTime: _selectedDueDate != null
          ? TimeOfDay.fromDateTime(_selectedDueDate!)
          : TimeOfDay.now(),
    );
    if (!mounted) return;
    debugPrint('EditTaskScreen: Time picker result: $pickedTime');
    if (pickedTime == null) return;
    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    setState(() {
      _selectedDueDate = combined;
      if (_reminderOffsetsMinutes.isEmpty) {
        _reminderOffsetsMinutes.add(0); // default at due time
      }
    });
    debugPrint('EditTaskScreen: Combined date/time: $_selectedDueDate');
    debugPrint('EditTaskScreen: Reminders: $_reminderOffsetsMinutes');
  }

  Future<void> _selectRange() async {
    final now = DateTime.now();
    final initialStart = _selectedStartDate ?? _selectedDueDate ?? now;
    final initialEnd = _selectedDueDate ?? initialStart;
    final range = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd.isBefore(initialStart) ? initialStart : initialEnd),
    );
    if (!mounted || range == null) return;
    setState(() {
      _selectedStartDate = DateTime(range.start.year, range.start.month, range.start.day);
      _selectedDueDate = DateTime(range.end.year, range.end.month, range.end.day, _selectedDueDate?.hour ?? 23, _selectedDueDate?.minute ?? 59);
      _multiDay = true;
      if (_reminderOffsetsMinutes.isEmpty) {
        _reminderOffsetsMinutes.add(0);
      }
    });
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'New Task' : 'Edit Task'),
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: _isLoading ? null : _saveTask,
                  tooltip: 'Save',
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Task Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a task title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // --- Schedule Section (polished) ---
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outline.withAlpha(77)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Text('Schedule', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          if (_selectedDueDate != null || _selectedStartDate != null)
                            IconButton(
                              icon: const Icon(Icons.close),
                              tooltip: 'Clear',
                              onPressed: () => setState(() {
                                _selectedDueDate = null; _selectedStartDate = null; _multiDay = false;
                              }),
                            )
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
                              _selectedStartDate ??= _selectedDueDate ?? DateTime.now();
                            } else {
                              _selectedStartDate = null;
                            }
                          });
                        },
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        if (_multiDay) {
                          await _selectRange();
                        } else {
                          await _selectDueDate();
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _multiDay
                                        ? (_selectedStartDate == null || _selectedDueDate == null
                                            ? 'Select date range'
                                            : '${DateFormat('MMM d, yyyy').format(_selectedStartDate!)} → ${DateFormat('MMM d, yyyy').format(_selectedDueDate!)}')
                                        : (_selectedDueDate == null
                                            ? 'Set due date (optional)'
                                            : DateFormat('EEE, MMM d, yyyy • HH:mm').format(_selectedDueDate!)),
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _multiDay && _selectedStartDate != null && _selectedDueDate != null
                                        ? '${_selectedDueDate!.difference(_selectedStartDate!).inDays + 1} day span'
                                        : (_selectedDueDate == null ? 'No schedule' : 'Tap to change'),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(_multiDay ? Icons.date_range : Icons.event, color: Theme.of(context).colorScheme.primary),
                          ],
                        ),
                      ),
                    ),
                    if (!_multiDay && _selectedDueDate != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Row(
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.access_time),
                              label: const Text('Adjust time'),
                              onPressed: _selectDueDate,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // --- End Schedule Section ---

              // --- New Reminder UI Section ---
              if (_selectedDueDate != null) ...[
                RemindersSection(
                  reminderOffsets: _reminderOffsetsMinutes,
                  onRemoveReminder: _removeReminder,
                  onAddReminder: _showAddReminderDialog,
                ),
              ],
              // --- End of New Reminder UI ---

              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                minLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}