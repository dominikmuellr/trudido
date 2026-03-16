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
import '../models/event.dart';
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

/// Unified Event Editor Screen
/// Handles both creating new events and editing existing ones
/// Full-screen Material Design 3 interface
class EventEditorScreen extends ConsumerStatefulWidget {
  final Event? event;
  final Function(Event) onSave;
  final DateTime? presetDate;
  final String? presetTitle;

  const EventEditorScreen({
    super.key,
    this.event,
    required this.onSave,
    this.presetDate,
    this.presetTitle,
  });

  @override
  ConsumerState<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends ConsumerState<EventEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late MentionTextEditingController _notesController;
  final _formKey = GlobalKey<FormState>();

  // Core event data
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  bool _isAllDay = true;
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
      text: widget.event?.text ?? widget.presetTitle ?? '',
    );
    _locationController = TextEditingController(
      text: widget.event?.location ?? '',
    );
    _notesController = MentionTextEditingController(
      text: widget.event?.notes ?? '',
    );
    _notesController.onMentionTap = (mention) {
      _mentionPopup?.hide();
      MentionNavigator.navigateToMention(context, ref, mention);
    };
    _notesController.addListener(_onNotesChanged);

    // Initialize from existing event if editing
    if (widget.event != null) {
      final e = widget.event!;
      _startDate = DateTime(
        e.startDateTime.year,
        e.startDateTime.month,
        e.startDateTime.day,
      );
      _endDate = DateTime(
        e.endDateTime.year,
        e.endDateTime.month,
        e.endDateTime.day,
      );
      _isAllDay = e.isAllDay;
      if (!_isAllDay) {
        _startTime = TimeOfDay.fromDateTime(e.startDateTime);
        _endTime = TimeOfDay.fromDateTime(e.endDateTime);
      }
      _priority = e.priority;
      _reminderOffsetsMinutes = List<int>.from(e.reminderOffsetsMinutes);
      _repeatType = e.repeatType;
      _repeatInterval = e.repeatInterval ?? 1;
      _repeatDays = e.repeatDays != null ? List<int>.from(e.repeatDays!) : [];
      _repeatEndDate = e.repeatEndDate;
    } else {
      // Creating new event
      final preset = widget.presetDate;
      final now = DateTime.now();
      _startDate = preset ?? DateTime(now.year, now.month, now.day);
      _endDate = _startDate;
    }

    _initializeFolderSelection();
  }

  Future<void> _initializeFolderSelection() async {
    if (widget.event?.folderId != null) {
      _selectedFolderId = widget.event!.folderId!;
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
        excludeId: widget.event?.id,
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
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event == null ? 'New Event' : 'Edit Event'),
        backgroundColor: colorScheme.tertiaryContainer,
        foregroundColor: colorScheme.onTertiaryContainer,
        elevation: 0,
        actions: [
          ExpressiveTextButton(
            onPressed: _isLoading ? null : _saveEvent,
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

              // Advanced options
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
        labelText: 'Event title',
        hintText: 'What\'s happening?',
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        prefixIcon: ScaledIcon(Icons.event),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter an event name';
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
          'Date & Time',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface.withValues(alpha: 0.9),
          ),
        ),
        SpacingGap.gapV12,

        // Start date
        _buildQuickActionChip(
          icon: Icons.event_outlined,
          label: _getStartDateLabel(),
          isSelected: _startDate != null,
          onTap: _selectStartDate,
          onClear: null, // Start date is required
          theme: theme,
          colorScheme: colorScheme,
        ),
        SpacingGap.gapV12,

        // End date
        _buildQuickActionChip(
          icon: Icons.event_outlined,
          label: _getEndDateLabel(),
          isSelected: _endDate != null && _endDate != _startDate,
          onTap: _selectEndDate,
          onClear: _endDate != null && _endDate != _startDate
              ? () => setState(() => _endDate = _startDate)
              : null,
          theme: theme,
          colorScheme: colorScheme,
        ),
        SpacingGap.gapV12,

        // All-day toggle
        _buildQuickActionChip(
          icon: _isAllDay ? Icons.wb_sunny_outlined : Icons.schedule_outlined,
          label: _isAllDay ? 'All day' : 'Timed event',
          isSelected: !_isAllDay,
          onTap: () => setState(() {
            _isAllDay = !_isAllDay;
            if (_isAllDay) {
              _startTime = null;
              _endTime = null;
            }
          }),
          onClear: null,
          theme: theme,
          colorScheme: colorScheme,
        ),
        SpacingGap.gapV12,

        // Start time (only if not all-day)
        if (!_isAllDay) ...[
          _buildQuickActionChip(
            icon: Icons.schedule_outlined,
            label: _getStartTimeLabel(),
            isSelected: _startTime != null,
            onTap: _selectStartTime,
            onClear: _startTime != null
                ? () => setState(() => _startTime = null)
                : null,
            theme: theme,
            colorScheme: colorScheme,
          ),
          SpacingGap.gapV12,

          // End time (only if not all-day)
          _buildQuickActionChip(
            icon: Icons.schedule_outlined,
            label: _getEndTimeLabel(),
            isSelected: _endTime != null,
            onTap: _selectEndTime,
            onClear: _endTime != null
                ? () => setState(() => _endTime = null)
                : null,
            theme: theme,
            colorScheme: colorScheme,
          ),
          SpacingGap.gapV12,
        ],

        SpacingGap.gapV8,
        Text(
          'Options',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface.withValues(alpha: 0.9),
          ),
        ),
        SpacingGap.gapV12,

        // Location
        _buildQuickActionChip(
          icon: Icons.location_on_outlined,
          label: _locationController.text.isNotEmpty
              ? _locationController.text
              : 'Add location',
          isSelected: _locationController.text.isNotEmpty,
          onTap: _showLocationDialog,
          onClear: _locationController.text.isNotEmpty
              ? () {
                  setState(() => _locationController.clear());
                }
              : null,
          theme: theme,
          colorScheme: colorScheme,
        ),
        SpacingGap.gapV12,

        // Priority
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

        // Reminder
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

        // Repeat
        _buildQuickActionChip(
          icon: Icons.repeat_outlined,
          label: _getRepeatLabel(),
          isSelected: _repeatType != 'none',
          onTap: _showRepeatSelector,
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
        ),
      ],
    );
  }

  // --- Label helpers ---

  String _getStartDateLabel() {
    final now = ref.read(clockProvider).now();
    if (_startDate == null) return 'Select start date';
    return 'Start: ${DateFormatters.formatSmart(_startDate!, now: now, includeTime: false)}';
  }

  String _getEndDateLabel() {
    final now = ref.read(clockProvider).now();
    if (_endDate == null || _endDate == _startDate)
      return 'Same day (tap to set end date)';
    return 'End: ${DateFormatters.formatSmart(_endDate!, now: now, includeTime: false)}';
  }

  String _getStartTimeLabel() {
    if (_startTime == null) return 'Set start time';
    final prefs = ref.read(preferencesStateProvider);
    final use24Hour = prefs.resolveUse24Hour(
      MediaQuery.of(context).alwaysUse24HourFormat,
    );
    return 'Start: ${DateFormatters.formatTimeOfDay(_startTime!.hour, _startTime!.minute, use24Hour: use24Hour)}';
  }

  String _getEndTimeLabel() {
    if (_endTime == null) return 'Set end time';
    final prefs = ref.read(preferencesStateProvider);
    final use24Hour = prefs.resolveUse24Hour(
      MediaQuery.of(context).alwaysUse24HourFormat,
    );
    return 'End: ${DateFormatters.formatTimeOfDay(_endTime!.hour, _endTime!.minute, use24Hour: use24Hour)}';
  }

  String _getReminderLabel() {
    if (_reminderOffsetsMinutes.isEmpty) return 'Add reminders';
    if (_reminderOffsetsMinutes.length == 1) return '1 reminder set';
    return '${_reminderOffsetsMinutes.length} reminders set';
  }

  String _getRepeatLabel() {
    switch (_repeatType) {
      case 'daily':
        if (_repeatInterval == 1) return 'Repeats daily';
        return 'Repeats every $_repeatInterval days';
      case 'weekly':
        if (_repeatInterval == 1) return 'Repeats weekly';
        return 'Repeats every $_repeatInterval weeks';
      case 'monthly':
        if (_repeatInterval == 1) return 'Repeats monthly';
        return 'Repeats every $_repeatInterval months';
      case 'yearly':
        if (_repeatInterval == 1) return 'Repeats yearly';
        return 'Repeats every $_repeatInterval years';
      case 'custom':
        return 'Custom repeat';
      default:
        return 'Does not repeat';
    }
  }

  // --- Quick action chip ---

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

  // --- Advanced options ---

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

        // Backlinks
        if (widget.event != null)
          BacklinksSection(itemId: widget.event!.id, itemType: 'event'),

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
                    FilterChip(
                      label: Text('NONE'),
                      selected: _selectedFolderId.isEmpty,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedFolderId = '');
                        }
                      },
                    ),
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

  // --- Dialogs ---

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
      ref.read(folderNotifierProvider.notifier).loadFolders();
    }
  }

  void _showLocationDialog() async {
    final controller = TextEditingController(text: _locationController.text);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter location',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ExpressiveTextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => _locationController.text = result);
    }
  }

  // --- Pickers ---

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
                padding: SpacingEdgeInsets.insets16,
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
        setState(() => _priority = value);
        Navigator.pop(context);
      },
    );
  }

  Future<void> _selectStartDate() async {
    final now = ref.read(clockProvider).now();
    final firstDayOfWeek = ref.read(preferencesStateProvider).firstDayOfWeek;

    final picked = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 1825)),
      initialDate: _startDate ?? now,
      helpText: 'Select start date',
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
        // Auto-adjust end date if it's before start date
        if (_endDate == null || _endDate!.isBefore(_startDate!)) {
          _endDate = _startDate;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final now = ref.read(clockProvider).now();
    final firstDayOfWeek = ref.read(preferencesStateProvider).firstDayOfWeek;

    final picked = await showDatePicker(
      context: context,
      firstDate: _startDate ?? now,
      lastDate: (_startDate ?? now).add(const Duration(days: 1825)),
      initialDate: _endDate ?? _startDate ?? now,
      helpText: 'Select end date',
      builder: (context, child) {
        return WeekStartOverride(
          firstDayOfWeekIndex: firstDayOfWeek,
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _selectStartTime() async {
    final prefs = ref.read(preferencesStateProvider);
    final use24Hour = prefs.resolveUse24Hour(
      MediaQuery.of(context).alwaysUse24HourFormat,
    );
    final time = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
      helpText: 'Select start time',
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
      setState(() {
        _startTime = time;
        // Auto-set end time 1 hour after start if not set
        if (_endTime == null) {
          final endHour = (time.hour + 1) % 24;
          _endTime = TimeOfDay(hour: endHour, minute: time.minute);
        }
      });
    }
  }

  Future<void> _selectEndTime() async {
    final prefs = ref.read(preferencesStateProvider);
    final use24Hour = prefs.resolveUse24Hour(
      MediaQuery.of(context).alwaysUse24HourFormat,
    );
    final time = await showTimePicker(
      context: context,
      initialTime: _endTime ?? _startTime ?? TimeOfDay.now(),
      helpText: 'Select end time',
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
      setState(() => _endTime = time);
    }
  }

  void _showRepeatSelector() {
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
                      Padding(
                        padding: SpacingEdgeInsets.insets16,
                        child: Text(
                          'Repeat',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Divider(height: 1),
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
                        'yearly',
                        'Yearly',
                        Icons.calendar_today,
                        setModalState,
                      ),
                      _buildRepeatOption(
                        'custom',
                        'Custom...',
                        Icons.tune,
                        setModalState,
                      ),
                      if (_repeatType == 'custom') ...[
                        const Divider(height: 1),
                        _buildCustomRepeatOptions(setModalState, colorScheme),
                      ],
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
                              firstDate: _startDate ?? now,
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
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
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
                  if (value == 'days') {
                    setModalState(() => _repeatDays = []);
                    setState(() => _repeatDays = []);
                  } else if (value == 'weeks' && _repeatDays.isEmpty) {
                    final currentDay =
                        _startDate?.weekday ??
                        ref.read(clockProvider).now().weekday;
                    setModalState(() => _repeatDays = [currentDay]);
                    setState(() => _repeatDays = [currentDay]);
                  }
                },
              ),
            ],
          ),
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

  // --- Save ---

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final now = ref.read(clockProvider).now();

      // Build start and end DateTimes
      DateTime startDateTime;
      DateTime endDateTime;

      final startDate = _startDate ?? DateTime(now.year, now.month, now.day);
      final endDate = _endDate ?? startDate;

      if (_isAllDay) {
        // All-day event: midnight to midnight
        startDateTime = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
        );
        endDateTime = DateTime(endDate.year, endDate.month, endDate.day);
      } else {
        final sTime = _startTime ?? const TimeOfDay(hour: 9, minute: 0);
        final eTime =
            _endTime ??
            TimeOfDay(hour: (sTime.hour + 1) % 24, minute: sTime.minute);

        startDateTime = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
          sTime.hour,
          sTime.minute,
        );
        endDateTime = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          eTime.hour,
          eTime.minute,
        );
      }

      // Ensure end is not before start
      if (endDateTime.isBefore(startDateTime)) {
        endDateTime = startDateTime.add(const Duration(hours: 1));
      }

      // Default reminder for new events with a start time
      final reminders =
          _reminderOffsetsMinutes.isEmpty && !_isAllDay && widget.event == null
          ? [0]
          : _reminderOffsetsMinutes;

      final event = Event(
        id: widget.event?.id ?? now.millisecondsSinceEpoch.toString(),
        text: _titleController.text.trim(),
        notes: _notesController.toStorageText().trim().isEmpty
            ? null
            : _notesController.toStorageText().trim(),
        startDateTime: startDateTime,
        endDateTime: endDateTime,
        priority: _priority,
        folderId: _selectedFolderId.isEmpty ? null : _selectedFolderId,
        reminderOffsetsMinutes: reminders,
        repeatType: _repeatType,
        repeatInterval: _repeatType != 'none' ? _repeatInterval : null,
        repeatDays: _repeatDays.isNotEmpty ? _repeatDays : null,
        repeatEndDate: _repeatEndDate,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        isCompleted: widget.event?.isCompleted ?? false,
        createdAt: widget.event?.createdAt ?? now,
        completedAt: widget.event?.completedAt,
        uid: widget.event?.uid ?? '',
        color: widget.event?.color,
        parentRecurringEventId: widget.event?.parentRecurringEventId,
      );

      widget.onSave(event);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving event: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
