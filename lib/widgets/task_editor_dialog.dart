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
import '../models/todo.dart';
import '../services/storage_service.dart';
import '../providers/clock.dart';
import '../providers/app_providers.dart';
import '../utils/week_start_utils.dart';
import '../utils/date_formatters.dart';
import '../widgets/mention_text.dart';
import '../widgets/common/common.dart';

class TaskEditorDialog extends ConsumerStatefulWidget {
  final Todo? todo;
  final Function(Todo) onAdd;

  const TaskEditorDialog({super.key, this.todo, required this.onAdd});

  @override
  ConsumerState<TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends ConsumerState<TaskEditorDialog> {
  late TextEditingController _titleController;
  late MentionTextEditingController _notesController;
  final _formKey = GlobalKey<FormState>();

  DateTime? _startDate;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  int? _durationMinutes;
  bool _isMultiDay = false;
  String _priority = 'none';
  String _selectedFolderId = '';
  List<int> _reminderOffsetsMinutes = [];

  bool _showAdvancedOptions = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.todo?.text ?? '');
    _notesController = MentionTextEditingController(
      text: widget.todo?.notes ?? '',
    );

    if (widget.todo != null) {
      _startDate = widget.todo!.startDate;
      _dueDate = widget.todo!.dueDate;
      _isMultiDay = _startDate != null && _dueDate != null;
      if (_dueDate != null) {
        _dueTime = TimeOfDay.fromDateTime(_dueDate!);
      }
      _durationMinutes = widget.todo!.durationMinutes;
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
            _buildHeader(theme, colorScheme),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitleInput(theme),
                      const SizedBox(height: 20),

                      _buildQuickActions(theme, colorScheme),
                      const SizedBox(height: 20),

                      if (_showAdvancedOptions) ...[
                        _buildAdvancedOptions(theme, colorScheme),
                        const SizedBox(height: 20),
                      ],

                      _buildAdvancedToggle(theme),
                    ],
                  ),
                ),
              ),
            ),

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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.add_task, color: colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 16),

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
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),

          ExpressiveIconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close),
            style: ExpressiveIconButton.styleFrom(
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
            color: colorScheme.onSurface.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 12),

        _buildQuickActionChip(
          icon: Icons.event,
          label: _getDueDateLabel(),
          isSelected: _dueDate != null,
          onTap: _selectDueDate,
          onClear: _dueDate != null
              ? () => setState(() {
                  _dueDate = null;
                  _dueTime = null;
                  _durationMinutes = null;
                  _startDate = null;
                  _isMultiDay = false;
                  _reminderOffsetsMinutes = [];
                })
              : null,
          theme: theme,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 12),

        if (_dueDate != null) ...[
          _buildQuickActionChip(
            icon: Icons.schedule,
            label: _getTimeLabel(),
            isSelected: _dueTime != null,
            onTap: _selectTime,
            onClear: _dueTime != null
                ? () => setState(() {
                    _dueTime = null;
                    _durationMinutes = null;
                  })
                : null,
            theme: theme,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 12),
        ],

        // Duration selection (only show if time is set)
        if (_dueDate != null && _dueTime != null) ...[
          _buildQuickActionChip(
            icon: Icons.timelapse_outlined,
            label: _getDurationLabel(),
            isSelected: _durationMinutes != null,
            onTap: _selectDuration,
            onClear: _durationMinutes != null
                ? () => setState(() => _durationMinutes = null)
                : null,
            theme: theme,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 12),
        ],

        _buildQuickActionChip(
          icon: _getPriorityIcon(_priority),
          label: 'Priority: ${_priority.toUpperCase()}',
          isSelected: _priority != 'none',
          onTap: _showPrioritySelector,
          onClear: _priority != 'none'
              ? () => setState(() => _priority = 'none')
              : null,
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
      return '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d').format(_dueDate!)}';
    } else {
      return DateFormat('MMM d, yyyy').format(_dueDate!);
    }
  }

  String _getTimeLabel() {
    if (_dueTime == null) {
      return 'All day';
    } else {
      final prefs = ref.read(preferencesStateProvider);
      final use24Hour = prefs.resolveUse24Hour(
        MediaQuery.of(context).alwaysUse24HourFormat,
      );
      return DateFormatters.formatTimeOfDay(
        _dueTime!.hour,
        _dueTime!.minute,
        use24Hour: use24Hour,
      );
    }
  }

  String _getDurationLabel() {
    if (_durationMinutes == null) {
      return 'Set duration';
    } else {
      final hours = _durationMinutes! ~/ 60;
      final minutes = _durationMinutes! % 60;
      if (hours == 0) {
        return '$minutes min';
      } else if (minutes == 0) {
        return '$hours ${hours == 1 ? 'hour' : 'hours'}';
      } else {
        return '$hours h $minutes min';
      }
    }
  }

  Widget _buildQuickActionChip({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
    required ColorScheme colorScheme,
    VoidCallback? onClear,
  }) {
    final chipColor = isSelected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;
    return Material(
      color: Colors.transparent,
      child: ExpressiveInkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.only(
            top: 12,
            bottom: 12,
            left: 16,
            right: (isSelected && onClear != null) ? 4 : 16,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: chipColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: chipColor,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSelected && onClear != null) ...[
                const SizedBox(width: 4),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: onClear,
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: chipColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ),
              ],
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
            color: colorScheme.onSurface.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 16),

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
    return ExpressiveTextButton.icon(
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
          Expanded(
            child: ExpressiveOutlinedButton(
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 16),

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

  IconData _getPriorityIcon(String priority) {
    switch (priority) {
      case 'high':
        return Icons.keyboard_arrow_up;
      case 'low':
        return Icons.keyboard_arrow_down;
      case 'medium':
        return Icons.remove;
      default:
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
        child: Icon(icon, color: textColor, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: colorScheme.primary)
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
    final now = ref.read(clockProvider).now();
    final firstDayOfWeek = ref.read(preferencesStateProvider).firstDayOfWeek;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _dueDate != null
          ? DateTimeRange(start: _startDate!, end: _dueDate!)
          : null,
      helpText: 'Select date or date range',
      saveText: 'Done',
      builder: (context, child) {
        return WeekStartOverride(
          firstDayOfWeekIndex: firstDayOfWeek,
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _dueDate = picked.end;
        _isMultiDay = picked.start != picked.end;
      });
    }
  }

  Future<void> _selectTime() async {
    if (_dueDate == null) return;
    final prefs = ref.read(preferencesStateProvider);
    final use24Hour = prefs.resolveUse24Hour(
      MediaQuery.of(context).alwaysUse24HourFormat,
    );
    final time = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
      helpText: 'Select time',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(alwaysUse24HourFormat: use24Hour),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() => _dueTime = time);
    }
  }

  Future<void> _selectDuration() async {
    final durations = <int, String>{
      15: '15 min',
      30: '30 min',
      45: '45 min',
      60: '1 hour',
      90: '1.5 hours',
      120: '2 hours',
      180: '3 hours',
      240: '4 hours',
    };

    // Calculate end times if we have a start time
    DateTime? startTime;
    if (_dueDate != null && _dueTime != null) {
      startTime = DateTime(
        _dueDate!.year,
        _dueDate!.month,
        _dueDate!.day,
        _dueTime!.hour,
        _dueTime!.minute,
      );
    }

    await showModalBottomSheet(
      context: context,
      builder: (context) {
        final prefs = ref.read(preferencesStateProvider);
        final use24Hour = prefs.resolveUse24Hour(
          MediaQuery.of(context).alwaysUse24HourFormat,
        );

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Duration',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Divider(height: 1),
              ...durations.entries.map((entry) {
                // Calculate end time for this duration
                String? endTimeText;
                if (startTime != null) {
                  final endTime = startTime.add(Duration(minutes: entry.key));
                  endTimeText = DateFormatters.formatTime(
                    endTime,
                    use24Hour: use24Hour,
                  );
                }

                return ListTile(
                  leading: _durationMinutes == entry.key
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : const SizedBox(width: 24),
                  title: Text(
                    endTimeText != null
                        ? '${entry.value} (ends $endTimeText)'
                        : entry.value,
                  ),
                  selected: _durationMinutes == entry.key,
                  onTap: () {
                    setState(() => _durationMinutes = entry.key);
                    Navigator.pop(context);
                  },
                );
              }),
              ListTile(
                leading: const Icon(Icons.clear),
                title: const Text('No duration'),
                onTap: () {
                  setState(() => _durationMinutes = null);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveTodo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
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
        id:
            widget.todo?.id ??
            ref.read(clockProvider).now().millisecondsSinceEpoch.toString(),
        text: _titleController.text.trim(),
        notes: _notesController.toStorageText().trim().isEmpty
            ? null
            : _notesController.toStorageText().trim(),
        startDate: _isMultiDay ? _startDate : null,
        dueDate: finalDueDate,
        priority: _priority,
        folderId: _selectedFolderId.isEmpty ? null : _selectedFolderId,
        reminderOffsetsMinutes: _reminderOffsetsMinutes,
        durationMinutes: _durationMinutes,
        isCompleted: widget.todo?.isCompleted ?? false,
        createdAt: widget.todo?.createdAt ?? ref.read(clockProvider).now(),
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
