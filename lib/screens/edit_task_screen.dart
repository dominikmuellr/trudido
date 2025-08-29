import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';
import '../services/todo_provider.dart';
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
  late String _selectedCategory;
  String? _selectedFolderId;
  DateTime? _selectedDueDate;
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
      
      _selectedCategory = widget.task!.category;
      _selectedFolderId = widget.task!.folderId;
      _selectedDueDate = widget.task!.dueDate;
  _reminderOffsetsMinutes = List<int>.from(widget.task?.reminderOffsetsMinutes ?? []); // Updated
  _tags = List<String>.from(widget.task?.tags ?? []);
    } else {
      _titleController = TextEditingController();
      _notesController = TextEditingController();
      _selectedPriority = 'medium';
      _selectedCategory = 'personal';
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

    final navigator = Navigator.of(context);

    try {
      if (widget.task != null) {
        // Update existing task
        debugPrint('EditTaskScreen: Updating existing task with reminders: $_reminderOffsetsMinutes');
        final updatedTask = widget.task!.copyWith(
          text: _titleController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          priority: _selectedPriority,
          category: _selectedCategory,
          folderId: _selectedFolderId,
          dueDate: _selectedDueDate,
          reminderOffsetsMinutes: _reminderOffsetsMinutes, // Updated
          tags: _tags,
        );

        await ref.read(todosProvider.notifier).updateTodo(updatedTask);
      } else {
        // Create new task
        debugPrint('EditTaskScreen: Creating new task with reminders: $_reminderOffsetsMinutes');
        final newTask = Todo(
          text: _titleController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          priority: _selectedPriority,
          category: _selectedCategory,
          folderId: _selectedFolderId,
          dueDate: _selectedDueDate,
          reminderOffsetsMinutes: _reminderOffsetsMinutes, // Updated
          tags: _tags,
        );

        await ref.read(todosProvider.notifier).addTodo(newTask);
      }

      if (!mounted) return;
      // Return result to caller instead of showing SnackBar here
      navigator.pop({
        'success': true,
        'action': widget.task != null ? 'updated' : 'created',
        'message': widget.task != null ? 'Task updated successfully' : 'Task created successfully'
      });
    } catch (e) {
      if (!mounted) return;
      // Return error result to caller
      navigator.pop({
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
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );

    debugPrint('EditTaskScreen: Date picker result: $pickedDate');
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: _selectedDueDate != null 
            ? TimeOfDay.fromDateTime(_selectedDueDate!)
            : TimeOfDay.now(),
      );

      debugPrint('EditTaskScreen: Time picker result: $pickedTime');
      if (pickedTime != null) {
        setState(() {
          _selectedDueDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          
          debugPrint('EditTaskScreen: Combined date/time: $_selectedDueDate');
          debugPrint('EditTaskScreen: Current reminders before check: $_reminderOffsetsMinutes');
          
          // Automatically add a default reminder at due time if no reminders are set yet
          // This applies to both new tasks and existing tasks without reminders
          if (_reminderOffsetsMinutes.isEmpty) {
            debugPrint('EditTaskScreen: Adding default reminder at due time');
            _reminderOffsetsMinutes.add(0); // At the exact due time
          }
          debugPrint('EditTaskScreen: Due date set, final reminders: $_reminderOffsetsMinutes');
        });
      }
    }
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
              // Due Date ListTile
              ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Due Date'),
                subtitle: Text(
                  _selectedDueDate == null
                      ? 'Not set'
                      : DateFormat.yMMMd().add_jm().format(_selectedDueDate!),
                ),
                onTap: _selectDueDate,
                trailing: _selectedDueDate != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _selectedDueDate = null),
                      )
                    : null,
              ),

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