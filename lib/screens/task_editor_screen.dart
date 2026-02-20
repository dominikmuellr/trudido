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
import 'package:trudido/utils/responsive_size.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/todo.dart';
import '../services/storage_service.dart';
import '../services/folder_provider.dart';
import '../providers/clock.dart';
import '../providers/app_providers.dart';
import '../widgets/add_reminder_dialog.dart';
import '../widgets/create_folder_dialog.dart';
import '../widgets/mention_autocomplete_popup.dart';
import '../widgets/mention_text.dart';
import '../widgets/backlinks_section.dart';
import '../utils/date_formatters.dart';
import '../utils/week_start_utils.dart';
import '../utils/mention_parser.dart';
import '../utils/mention_navigator.dart';
import '../theme/spacing_tokens.dart';
import '../widgets/common/common.dart';

/// Unified Task Editor Screen
/// Handles both creating new tasks and editing existing ones
/// Full-screen Material Design 3 interface
class TaskEditorScreen extends ConsumerStatefulWidget {
  final Todo? todo;
  final Function(Todo) onSave;
  final DateTime? presetDueDate;
  final String? presetTitle;

  const TaskEditorScreen({
    super.key,
    this.todo,
    required this.onSave,
    this.presetDueDate,
    this.presetTitle,
  });

  @override
  ConsumerState<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends ConsumerState<TaskEditorScreen> {
  late TextEditingController _titleController;
  late MentionTextEditingController _notesController;
  final _formKey = GlobalKey<FormState>();

  // Core task data
  DateTime? _startDate;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  int? _durationMinutes; // Duration in minutes
  bool _isMultiDay = false;
  String _priority = 'none';
  String _selectedFolderId = '';
  List<int> _reminderOffsetsMinutes = [];

  // Repeat settings
  String _repeatType = 'none';
  int _repeatInterval = 1;
  List<int> _repeatDays = [];
  DateTime? _repeatEndDate;

  // UI state
  bool _isLoading = false;

  // Mention autocomplete
  MentionAutocompletePopup? _mentionPopup;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.todo?.text ?? widget.presetTitle ?? '',
    );
    _notesController = MentionTextEditingController(
      text: widget.todo?.notes ?? '',
    );
    _notesController.onMentionTap = (mention) {
      _mentionPopup?.hide();
      MentionNavigator.navigateToMention(context, ref, mention);
    };
    _notesController.addListener(_onNotesChanged);

    // Initialize from existing todo if editing
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
      _repeatType = widget.todo!.repeatType;
      _repeatInterval = widget.todo!.repeatInterval ?? 1;
      _repeatDays = widget.todo!.repeatDays != null
          ? List<int>.from(widget.todo!.repeatDays!)
          : [];
      _repeatEndDate = widget.todo!.repeatEndDate;
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

  void _onNotesChanged() {
    final text = _notesController.text;
    final cursor = _notesController.selection.baseOffset;

    // Suppress popup when cursor sits at a mention boundary
    if (_notesController.mentionAtCursor(cursor) != null) {
      _mentionPopup?.hide();
      return;
    }

    final query = MentionParser.detectMentionTrigger(text, cursor);

    if (query != null) {
      _mentionPopup ??= MentionAutocompletePopup(
        context: context,
        ref: ref,
        onItemSelected: _onMentionSelected,
        excludeId: widget.todo?.id,
      );
      _mentionPopup!.show(query);
    } else {
      _mentionPopup?.hide();
    }
  }

  void _onMentionSelected(MentionSearchItem item) {
    final mentionLink = MentionLink(
      title: item.title,
      type: item.type,
      id: item.id,
      start: 0,
      end: 0,
    );

    final range = MentionParser.getMentionTriggerRange(
      _notesController.text,
      _notesController.selection.baseOffset,
    );
    if (range == null) return;

    _notesController.removeListener(_onNotesChanged);
    _notesController.insertMention(mentionLink, range.start, range.end);
    _notesController.addListener(_onNotesChanged);
  }

  @override
  void dispose() {
    _notesController.removeListener(_onNotesChanged);
    _mentionPopup?.hide();
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
          ExpressiveTextButton(
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
          SpacingGap.gapH8,
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: SpacingEdgeInsets.insets24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title input
              _buildTitleInput(theme),
              SpacingGap.gapV24,

              // Quick actions
              _buildQuickActions(theme, colorScheme),
              SpacingGap.gapV24,

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
            color: colorScheme.onSurface.withValues(alpha: 0.9),
          ),
        ),
        SpacingGap.gapV12,
        // Date selection (full width for better display of ranges)
        _buildQuickActionChip(
          icon: Icons.event_outlined,
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
                  _repeatType = 'none';
                  _repeatInterval = 1;
                  _repeatDays = [];
                  _repeatEndDate = null;
                  _reminderOffsetsMinutes = [];
                })
              : null,
          theme: theme,
          colorScheme: colorScheme,
        ),
        SpacingGap.gapV12,

        // Multi-day toggle (only show if date is selected)
        if (_dueDate != null) ...[
          _buildQuickActionChip(
            icon: Icons.date_range_outlined,
            label: _isMultiDay && _startDate != null
                ? 'End: ${DateFormatters.formatSmart(_startDate!, now: ref.read(clockProvider).now(), includeTime: false)}'
                : 'Make multi-day',
            isSelected: _isMultiDay,
            onTap: _toggleMultiDay,
            onClear: _isMultiDay
                ? () => setState(() {
                    _isMultiDay = false;
                    _startDate = null;
                  })
                : null,
            theme: theme,
            colorScheme: colorScheme,
          ),
          SpacingGap.gapV12,
        ],

        // Time selection (only show if date is selected)
        if (_dueDate != null) ...[
          _buildQuickActionChip(
            icon: Icons.schedule_outlined,
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
          SpacingGap.gapV12,
        ],

        // Duration selection (only show if time is selected)
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
          SpacingGap.gapV12,
        ],

        // Priority selection
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
        SpacingGap.gapV12,

        // Reminder selection
        _buildQuickActionChip(
          icon: Icons.notifications_outlined,
          label: _getReminderLabel(),
          isSelected: _reminderOffsetsMinutes.isNotEmpty,
          onTap: _showAddReminderDialog,
          onClear: _reminderOffsetsMinutes.isNotEmpty
              ? () => setState(() => _reminderOffsetsMinutes = [])
              : null,
          theme: theme,
          colorScheme: colorScheme,
        ),
        SpacingGap.gapV12,

        // Repeat selection (disabled if no due date)
        _buildQuickActionChip(
          icon: Icons.repeat_outlined,
          label: _getRepeatLabel(),
          isSelected: _repeatType != 'none',
          onTap: _dueDate != null ? _showRepeatSelector : null,
          onClear: _repeatType != 'none'
              ? () => setState(() {
                  _repeatType = 'none';
                  _repeatInterval = 1;
                  _repeatDays = [];
                  _repeatEndDate = null;
                })
              : null,
          theme: theme,
          colorScheme: colorScheme,
          isDisabled: _dueDate == null,
        ),
      ],
    );
  }

  String _getDueDateLabel() {
    final now = ref.read(clockProvider).now();
    if (_dueDate == null) {
      return 'Select due date';
    } else if (_isMultiDay && _startDate != null) {
      // Multi-day: show "Due: [date] (ends [end date])"
      return 'Due: ${DateFormatters.formatSmart(_dueDate!, now: now, includeTime: false)}';
    } else {
      // Single day: show smart date
      return DateFormatters.formatSmart(
        _dueDate!,
        now: now,
        includeTime: false,
      );
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

  String _getReminderLabel() {
    if (_reminderOffsetsMinutes.isEmpty) {
      return 'Add reminders';
    } else if (_reminderOffsetsMinutes.length == 1) {
      return '1 reminder set';
    } else {
      return '${_reminderOffsetsMinutes.length} reminders set';
    }
  }

  String _getRepeatLabel() {
    if (_dueDate == null) {
      return 'Set due date to enable repeat';
    }

    switch (_repeatType) {
      case 'daily':
        if (_repeatInterval == 1) return 'Repeats daily';
        return 'Repeats every $_repeatInterval days';
      case 'weekly':
        if (_repeatInterval == 1) {
          if (_repeatDays.isEmpty) return 'Repeats weekly';
          return 'Repeats weekly';
        }
        return 'Repeats every $_repeatInterval weeks';
      case 'monthly':
        if (_repeatInterval == 1) return 'Repeats monthly';
        return 'Repeats every $_repeatInterval months';
      case 'custom':
        return 'Custom repeat';
      default:
        return 'Does not repeat';
    }
  }

  Widget _buildQuickActionChip({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback? onTap,
    required ThemeData theme,
    required ColorScheme colorScheme,
    bool isDisabled = false,
    VoidCallback? onClear,
  }) {
    final chipColor = isSelected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;
    return Material(
      color: Colors.transparent,
      child: ExpressiveInkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: SpacingBorderRadius.md,
        child: Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
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
              borderRadius: SpacingBorderRadius.md,
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary.withValues(alpha: 0.3)
                    : colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaledIcon(icon, size: 18, color: chipColor),
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
        SpacingGap.gapV16,

        // Notes input
        Listener(
          onPointerUp: (_) => _notesController.notifyPointerUp(),
          child: TextFormField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'Add details... (type @ to link a task or note)',
              filled: true,
              border: OutlineInputBorder(borderRadius: SpacingBorderRadius.lg),
              prefixIcon: ScaledIcon(Icons.notes_outlined),
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
        SpacingGap.gapV16,

        // Backlinks (items that reference this task)
        if (widget.todo != null)
          BacklinksSection(itemId: widget.todo!.id, itemType: 'task'),

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
                SpacingGap.gapV8,
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
                      );
                    }),
                    // Add folder chip
                    ActionChip(
                      label: const Text('ADD FOLDER'),
                      avatar: const Icon(Icons.add, size: 14),
                      onPressed: () => _showCreateFolderDialog(),
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

  void _showRepeatSelector() {
    // Ensure there's a due date before showing repeat options
    if (_dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a due date before setting up repeat'),
          duration: Duration(milliseconds: 1500),
        ),
      );
      return;
    }

    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Padding(
                        padding: SpacingEdgeInsets.insets16,
                        child: Text(
                          'Repeat',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Divider(height: 1),

                      // Repeat options
                      _buildRepeatOption(
                        'none',
                        'Does not repeat',
                        Icons.block,
                        setModalState,
                      ),
                      _buildRepeatOption(
                        'daily',
                        'Daily',
                        Icons.today,
                        setModalState,
                      ),
                      _buildRepeatOption(
                        'weekly',
                        'Weekly',
                        Icons.view_week,
                        setModalState,
                      ),
                      _buildRepeatOption(
                        'monthly',
                        'Monthly',
                        Icons.calendar_month,
                        setModalState,
                      ),
                      _buildRepeatOption(
                        'custom',
                        'Custom...',
                        Icons.tune,
                        setModalState,
                      ),

                      // Show custom options if custom is selected
                      if (_repeatType == 'custom') ...[
                        const Divider(height: 1),
                        _buildCustomRepeatOptions(setModalState, colorScheme),
                      ],

                      // End date option (for all repeat types except 'none')
                      if (_repeatType != 'none') ...[
                        const Divider(height: 1),
                        ListTile(
                          leading: ScaledIcon(Icons.event_busy, size: 20),
                          title: Text(
                            _repeatEndDate == null
                                ? 'No end date'
                                : 'Ends ${DateFormatters.formatSmart(_repeatEndDate!, now: ref.read(clockProvider).now(), includeTime: false)}',
                          ),
                          trailing: _repeatEndDate != null
                              ? ExpressiveIconButton(
                                  icon: ScaledIcon(Icons.clear, size: 18),
                                  onPressed: () {
                                    setModalState(() => _repeatEndDate = null);
                                    setState(() => _repeatEndDate = null);
                                  },
                                )
                              : null,
                          onTap: () async {
                            final now = ref.read(clockProvider).now();
                            final firstDayOfWeek = ref
                                .read(preferencesStateProvider)
                                .firstDayOfWeek;
                            final picked = await showDatePicker(
                              context: context,
                              initialDate:
                                  _repeatEndDate ??
                                  now.add(const Duration(days: 30)),
                              firstDate: _dueDate ?? now,
                              lastDate: now.add(const Duration(days: 1825)),
                              helpText: 'Select end date',
                              builder: (context, child) {
                                return WeekStartOverride(
                                  firstDayOfWeekIndex: firstDayOfWeek,
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setModalState(() => _repeatEndDate = picked);
                              setState(() => _repeatEndDate = picked);
                            }
                          },
                        ),
                      ],

                      SpacingGap.gapV16,

                      // Done button
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ), // Custom asymmetric padding
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Done'),
                          ),
                        ),
                      ),
                      SpacingGap.gapV8,
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRepeatOption(
    String value,
    String label,
    IconData icon,
    StateSetter setModalState,
  ) {
    final isSelected = _repeatType == value;
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: ScaledIcon(icon, size: 20),
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
        setModalState(() => _repeatType = value);
        setState(() {
          _repeatType = value;
          // Reset to defaults when changing type
          if (value != 'custom') {
            _repeatInterval = 1;
            _repeatDays = [];
          }
        });
      },
    );
  }

  Widget _buildCustomRepeatOptions(
    StateSetter setModalState,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: SpacingEdgeInsets.insets16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Custom Repeat Options',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          SpacingGap.gapV16,

          // Interval selector
          Row(
            children: [
              Text('Repeat every'),
              SpacingGap.gapH12,
              SizedBox(
                width: 70,
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  controller:
                      TextEditingController(text: _repeatInterval.toString())
                        ..selection = TextSelection.fromPosition(
                          TextPosition(
                            offset: _repeatInterval.toString().length,
                          ),
                        ),
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null && parsed > 0) {
                      setModalState(() => _repeatInterval = parsed);
                      setState(() => _repeatInterval = parsed);
                    }
                  },
                ),
              ),
              SpacingGap.gapH12,
              DropdownButton<String>(
                value: _repeatDays.isEmpty ? 'days' : 'weeks',
                items: const [
                  DropdownMenuItem(value: 'days', child: Text('days')),
                  DropdownMenuItem(value: 'weeks', child: Text('weeks')),
                ],
                onChanged: (value) {
                  // Switching between days and weeks mode
                  if (value == 'days') {
                    setModalState(() => _repeatDays = []);
                    setState(() => _repeatDays = []);
                  } else if (value == 'weeks' && _repeatDays.isEmpty) {
                    // Default to current day of week if switching to weekly
                    final currentDay =
                        _dueDate?.weekday ??
                        ref.read(clockProvider).now().weekday;
                    setModalState(() => _repeatDays = [currentDay]);
                    setState(() => _repeatDays = [currentDay]);
                  }
                },
              ),
            ],
          ),

          // Day selection for weekly custom repeat
          if (_repeatDays.isNotEmpty) ...[
            SpacingGap.gapV16,
            Text(
              'Repeat on',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            SpacingGap.gapV8,
            Wrap(
              spacing: 8,
              children: [
                for (int i = 1; i <= 7; i++)
                  FilterChip(
                    label: Text(_getDayAbbreviation(i)),
                    selected: _repeatDays.contains(i),
                    onSelected: (selected) {
                      setModalState(() {
                        if (selected) {
                          _repeatDays.add(i);
                          _repeatDays.sort();
                        } else {
                          _repeatDays.remove(i);
                        }
                      });
                      setState(() {
                        if (selected) {
                          _repeatDays.add(i);
                          _repeatDays.sort();
                        } else {
                          _repeatDays.remove(i);
                        }
                      });
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _getDayAbbreviation(int weekday) {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
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
                padding: SpacingEdgeInsets.insets16,
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

              SpacingGap.gapV8,
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
        padding: SpacingEdgeInsets.insets8,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: SpacingBorderRadius.sm,
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
    final now = ref.read(clockProvider).now();
    final firstDayOfWeek = ref.read(preferencesStateProvider).firstDayOfWeek;

    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _dueDate ?? now,
      helpText: 'Select due date',
      builder: (context, child) {
        return WeekStartOverride(
          firstDayOfWeekIndex: firstDayOfWeek,
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dueDate = picked;
        if (!_isMultiDay) {
          _startDate = null;
        }
      });
    }
  }

  Future<void> _toggleMultiDay() async {
    if (_isMultiDay) {
      // Disable multi-day mode
      setState(() {
        _isMultiDay = false;
        _startDate = null;
      });
    } else {
      // Enable multi-day mode - ask for end date
      final now = ref.read(clockProvider).now();
      final firstDayOfWeek = ref.read(preferencesStateProvider).firstDayOfWeek;

      final picked = await showDatePicker(
        context: context,
        firstDate: _dueDate ?? now,
        lastDate: (_dueDate ?? now).add(const Duration(days: 365)),
        initialDate: _dueDate ?? now,
        helpText: 'Select end date',
        builder: (context, child) {
          return WeekStartOverride(
            firstDayOfWeekIndex: firstDayOfWeek,
            child: child!,
          );
        },
      );

      if (picked != null) {
        setState(() {
          _startDate = picked;
          _isMultiDay = true;
        });
      }
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
    // Common duration presets in minutes
    final durations = <int, String>{
      15: '15 min',
      30: '30 min',
      45: '45 min',
      60: '1 hour',
      90: '1.5 hours',
      120: '2 hours',
      180: '3 hours',
      240: '4 hours',
      480: '8 hours',
      0: 'Custom...', // Placeholder for custom selection
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
      isScrollControlled: true,
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
                if (entry.key == 0) {
                  // Custom duration option
                  return ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: Text(entry.value),
                    onTap: () {
                      Navigator.pop(context);
                      _showCustomDurationDialog();
                    },
                  );
                } else {
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
                }
              }),
              // Clear duration option
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

  Future<void> _showCustomDurationDialog() async {
    final result = await showDialog<int?>(
      context: context,
      builder: (context) =>
          _CustomDurationDialog(initialMinutes: _durationMinutes),
    );

    if (result != null) {
      setState(() => _durationMinutes = result);
    }
  }

  // Remove the old _askForTime method since we now have separate time selection

  Future<void> _saveTodo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Combine date and time for the final due date
      DateTime? finalDueDate;
      DateTime? finalStartDate;

      if (_isMultiDay && _dueDate != null && _startDate != null) {
        // Multi-day task: _dueDate is start, _startDate is end
        finalStartDate = _dueDate; // Start date (without time)

        // End date with optional time
        if (_dueTime != null) {
          finalDueDate = DateTime(
            _startDate!.year,
            _startDate!.month,
            _startDate!.day,
            _dueTime!.hour,
            _dueTime!.minute,
          );
        } else {
          finalDueDate = _startDate;
        }
      } else if (_dueDate != null) {
        // Single day task
        finalStartDate = null;
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

      // If creating a new task with a due date and no reminders set, use default [0]
      final reminders =
          _reminderOffsetsMinutes.isEmpty &&
              finalDueDate != null &&
              widget.todo == null
          ? [0]
          : _reminderOffsetsMinutes;

      final todo = Todo(
        id:
            widget.todo?.id ??
            ref.read(clockProvider).now().millisecondsSinceEpoch.toString(),
        text: _titleController.text.trim(),
        notes: _notesController.toStorageText().trim().isEmpty
            ? null
            : _notesController.toStorageText().trim(),
        startDate: finalStartDate,
        dueDate: finalDueDate,
        priority: _priority,
        folderId: _selectedFolderId.isEmpty ? null : _selectedFolderId,
        reminderOffsetsMinutes: reminders,
        repeatType: _repeatType,
        repeatInterval: _repeatType != 'none' ? _repeatInterval : null,
        repeatDays: _repeatDays.isNotEmpty ? _repeatDays : null,
        repeatEndDate: _repeatEndDate,
        durationMinutes: _durationMinutes,
        isCompleted: widget.todo?.isCompleted ?? false,
        createdAt: widget.todo?.createdAt ?? ref.read(clockProvider).now(),
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

class _CustomDurationDialog extends StatefulWidget {
  final int? initialMinutes;

  const _CustomDurationDialog({this.initialMinutes});

  @override
  State<_CustomDurationDialog> createState() => _CustomDurationDialogState();
}

class _CustomDurationDialogState extends State<_CustomDurationDialog> {
  late TextEditingController _hoursController;
  late TextEditingController _minutesController;

  @override
  void initState() {
    super.initState();
    _hoursController = TextEditingController(
      text: widget.initialMinutes != null
          ? (widget.initialMinutes! ~/ 60).toString()
          : '0',
    );
    _minutesController = TextEditingController(
      text: widget.initialMinutes != null
          ? (widget.initialMinutes! % 60).toString()
          : '0',
    );
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Custom Duration'),
      content: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _hoursController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Hours',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _minutesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minutes',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
      actions: [
        ExpressiveTextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ExpressiveTextButton(
          onPressed: () {
            final hours = int.tryParse(_hoursController.text) ?? 0;
            final minutes = int.tryParse(_minutesController.text) ?? 0;
            final totalMinutes = hours * 60 + minutes;
            Navigator.pop(context, totalMinutes > 0 ? totalMinutes : null);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
