// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/todo.dart';
import '../controllers/task_controller.dart';
import '../providers/clock.dart';
import '../widgets/reminder_components.dart';
import '../widgets/add_reminder_dialog.dart';
import '../utils/date_formatters.dart';

class EditTaskScreen extends ConsumerStatefulWidget {
  final Todo? task;

  const EditTaskScreen({super.key, this.task});

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
      _multiDay =
          widget.task!.startDate != null &&
          widget.task!.dueDate != null &&
          !widget.task!.dueDate!.isBefore(widget.task!.startDate!);
      _reminderOffsetsMinutes = List<int>.from(
        widget.task?.reminderOffsetsMinutes ?? [],
      ); // Updated
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

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.task != null) {
        // Update existing task
        debugPrint(
          'EditTaskScreen: Updating existing task with reminders: $_reminderOffsetsMinutes',
        );
        final updatedTask = widget.task!.copyWith(
          text: _titleController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
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
        debugPrint(
          'EditTaskScreen: Creating new task with reminders: $_reminderOffsetsMinutes',
        );
        final newTask = Todo(
          text: _titleController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
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
        'message': widget.task != null
            ? 'Task updated successfully'
            : 'Task created successfully',
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop({
        'success': false,
        'error': e.toString(),
        'message': 'Error saving task: $e',
      });
    } finally {
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
    final now = ref.read(clockProvider).now();
    final initialDate = _selectedDueDate ?? now;
    final DateTime? pickedDate = await showDatePicker(
      context: localContext,
      initialDate: initialDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
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
    final now = ref.read(clockProvider).now();
    final initialStart = _selectedStartDate ?? _selectedDueDate ?? now;
    final initialEnd = _selectedDueDate ?? initialStart;
    final range = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
      initialDateRange: DateTimeRange(
        start: initialStart,
        end: initialEnd.isBefore(initialStart) ? initialStart : initialEnd,
      ),
    );
    if (!mounted || range == null) return;
    setState(() {
      _selectedStartDate = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      _selectedDueDate = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
        _selectedDueDate?.hour ?? 23,
        _selectedDueDate?.minute ?? 59,
      );
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
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      color: Colors.white,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.save_outlined),
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
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_outlined,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Schedule',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                          ),
                          const Spacer(),
                          if (_selectedDueDate != null ||
                              _selectedStartDate != null)
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              tooltip: 'Clear schedule',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setState(() {
                                _selectedDueDate = null;
                                _selectedStartDate = null;
                                _multiDay = false;
                              }),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: SegmentedButton<bool>(
                        style: SegmentedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('Single'),
                            icon: Icon(Icons.event, size: 16),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('Range'),
                            icon: Icon(Icons.date_range, size: 16),
                          ),
                        ],
                        selected: {_multiDay},
                        onSelectionChanged: (s) {
                          final v = s.first;
                          setState(() {
                            _multiDay = v;
                            if (v) {
                              _selectedStartDate ??=
                                  _selectedDueDate ??
                                  ref.read(clockProvider).now();
                            } else {
                              _selectedStartDate = null;
                            }
                          });
                        },
                      ),
                    ),
                    InkWell(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(12),
                      ),
                      onTap: () async {
                        if (_multiDay) {
                          await _selectRange();
                        } else {
                          await _selectDueDate();
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _multiDay
                                        ? (_selectedStartDate == null ||
                                                  _selectedDueDate == null
                                              ? 'Select date range'
                                              : DateFormatters.formatSmartRange(
                                                  _selectedStartDate!,
                                                  _selectedDueDate!,
                                                  now: ref
                                                      .read(clockProvider)
                                                      .now(),
                                                ))
                                        : (_selectedDueDate == null
                                              ? 'Set due date (optional)'
                                              : DateFormatters.formatSmart(
                                                  _selectedDueDate!,
                                                  now: ref
                                                      .read(clockProvider)
                                                      .now(),
                                                )),
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _multiDay &&
                                            _selectedStartDate != null &&
                                            _selectedDueDate != null
                                        ? '${_selectedDueDate!.difference(_selectedStartDate!).inDays + 1} day${_selectedDueDate!.difference(_selectedStartDate!).inDays + 1 > 1 ? 's' : ''}'
                                        : (_selectedDueDate == null
                                              ? 'No deadline set'
                                              : 'Tap to change'),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              _selectedDueDate != null ||
                                      _selectedStartDate != null
                                  ? Icons.edit_calendar_outlined
                                  : Icons.add_box_outlined,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Show date chips for better visual feedback
                    if (_selectedDueDate != null || _selectedStartDate != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (_multiDay && _selectedStartDate != null)
                              Chip(
                                avatar: Icon(
                                  Icons.play_arrow_outlined,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                label: Text(
                                  DateFormatters.formatChip(
                                    _selectedStartDate!,
                                    now: ref.read(clockProvider).now(),
                                  ),
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            if (_selectedDueDate != null)
                              Chip(
                                avatar: Icon(
                                  _multiDay
                                      ? Icons.stop_outlined
                                      : Icons.event_outlined,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                label: Text(
                                  DateFormatters.formatChip(
                                    _selectedDueDate!,
                                    now: ref.read(clockProvider).now(),
                                  ),
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
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
