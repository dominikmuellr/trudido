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
import '../providers/app_providers.dart';
import '../providers/clock.dart';
import '../utils/date_formatters.dart';
import '../utils/week_start_utils.dart';
import '../widgets/common/common.dart';

/// Material Design 3 compliant date picker with smart suggestions
///
/// Features:
/// - Large touch targets (48dp minimum)
/// - Smart date chips (Today, Tomorrow, Next Week)
/// - Month/year quick navigation
/// - Proper MD3 styling and animations
class MD3DatePicker {
  /// Show a Material 3 styled date picker with smart suggestions
  static Future<DateTime?> showDatePicker({
    required BuildContext context,
    required WidgetRef ref,
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    String? helpText,
    bool showSmartSuggestions = true,
  }) async {
    final now = ref.read(clockProvider).now();
    final initial = initialDate ?? now;
    final first = firstDate ?? now.subtract(const Duration(days: 365));
    final last = lastDate ?? now.add(const Duration(days: 365));

    return showDialog<DateTime>(
      context: context,
      builder: (context) => _MD3DatePickerDialog(
        initialDate: initial,
        firstDate: first,
        lastDate: last,
        now: now,
        helpText: helpText,
        showSmartSuggestions: showSmartSuggestions,
        firstDayOfWeek: ref.read(preferencesStateProvider).firstDayOfWeek,
      ),
    );
  }

  /// Show a Material 3 styled date range picker
  static Future<DateTimeRange?> showDateRangePicker({
    required BuildContext context,
    required WidgetRef ref,
    DateTimeRange? initialDateRange,
    DateTime? firstDate,
    DateTime? lastDate,
    String? helpText,
  }) async {
    final now = ref.read(clockProvider).now();
    final first = firstDate ?? now.subtract(const Duration(days: 365));
    final last = lastDate ?? now.add(const Duration(days: 365));

    return showDialog<DateTimeRange>(
      context: context,
      builder: (context) => _MD3DateRangePickerDialog(
        initialDateRange: initialDateRange,
        firstDate: first,
        lastDate: last,
        now: now,
        helpText: helpText,
        firstDayOfWeek: ref.read(preferencesStateProvider).firstDayOfWeek,
      ),
    );
  }
}

class _MD3DatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime now;
  final String? helpText;
  final bool showSmartSuggestions;
  final int firstDayOfWeek;

  const _MD3DatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.now,
    this.helpText,
    this.showSmartSuggestions = true,
    this.firstDayOfWeek = 1,
  });

  @override
  State<_MD3DatePickerDialog> createState() => _MD3DatePickerDialogState();
}

class _MD3DatePickerDialogState extends State<_MD3DatePickerDialog> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.helpText ?? 'Select date',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormatters.formatSmart(
                      _selectedDate,
                      now: widget.now,
                      includeTime: false,
                    ),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Smart suggestions (if enabled)
            if (widget.showSmartSuggestions) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SmartChip(
                      label: 'Today',
                      onTap: () => _selectDate(widget.now),
                      isSelected: _isSameDay(_selectedDate, widget.now),
                    ),
                    _SmartChip(
                      label: 'Tomorrow',
                      onTap: () =>
                          _selectDate(widget.now.add(const Duration(days: 1))),
                      isSelected: _isSameDay(
                        _selectedDate,
                        widget.now.add(const Duration(days: 1)),
                      ),
                    ),
                    _SmartChip(
                      label: 'Next week',
                      onTap: () =>
                          _selectDate(widget.now.add(const Duration(days: 7))),
                      isSelected: _isSameDay(
                        _selectedDate,
                        widget.now.add(const Duration(days: 7)),
                      ),
                    ),
                    _SmartChip(
                      label: 'Next month',
                      onTap: () {
                        final nextMonth = DateTime(
                          widget.now.year,
                          widget.now.month + 1,
                          widget.now.day,
                        );
                        _selectDate(nextMonth);
                      },
                      isSelected: false,
                    ),
                  ],
                ),
              ),
              const Divider(),
            ],

            // Calendar
            Expanded(
              child: WeekStartOverride(
                firstDayOfWeekIndex: widget.firstDayOfWeek,
                child: CalendarDatePicker(
                  initialDate: _selectedDate,
                  firstDate: widget.firstDate,
                  lastDate: widget.lastDate,
                  onDateChanged: _selectDate,
                ),
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ExpressiveTextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_selectedDate),
                    child: const Text('OK'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _MD3DateRangePickerDialog extends StatefulWidget {
  final DateTimeRange? initialDateRange;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime now;
  final String? helpText;
  final int firstDayOfWeek;

  const _MD3DateRangePickerDialog({
    this.initialDateRange,
    required this.firstDate,
    required this.lastDate,
    required this.now,
    this.helpText,
    this.firstDayOfWeek = 1,
  });

  @override
  State<_MD3DateRangePickerDialog> createState() =>
      _MD3DateRangePickerDialogState();
}

class _MD3DateRangePickerDialogState extends State<_MD3DateRangePickerDialog> {
  DateTimeRange? _selectedRange;

  @override
  void initState() {
    super.initState();
    _selectedRange = widget.initialDateRange;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.helpText ?? 'Select date range',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedRange != null
                        ? DateFormatters.formatSmartRange(
                            _selectedRange!.start,
                            _selectedRange!.end,
                            now: widget.now,
                          )
                        : 'No range selected',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Smart suggestions
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SmartChip(
                    label: 'This week',
                    onTap: () {
                      final start = widget.now;
                      final end = widget.now.add(const Duration(days: 6));
                      setState(() {
                        _selectedRange = DateTimeRange(start: start, end: end);
                      });
                    },
                    isSelected: false,
                  ),
                  _SmartChip(
                    label: 'Next week',
                    onTap: () {
                      final start = widget.now.add(const Duration(days: 7));
                      final end = start.add(const Duration(days: 6));
                      setState(() {
                        _selectedRange = DateTimeRange(start: start, end: end);
                      });
                    },
                    isSelected: false,
                  ),
                  _SmartChip(
                    label: 'This month',
                    onTap: () {
                      final start = widget.now;
                      final end = DateTime(
                        widget.now.year,
                        widget.now.month + 1,
                        0,
                      );
                      setState(() {
                        _selectedRange = DateTimeRange(start: start, end: end);
                      });
                    },
                    isSelected: false,
                  ),
                ],
              ),
            ),
            const Divider(),

            // Calendar
            Expanded(
              child: _selectedRange != null
                  ? WeekStartOverride(
                      firstDayOfWeekIndex: widget.firstDayOfWeek,
                      child: CalendarDatePicker(
                        initialDate: _selectedRange!.start,
                        firstDate: widget.firstDate,
                        lastDate: widget.lastDate,
                        onDateChanged: (date) {
                          // Implement range selection logic
                          setState(() {
                            if (_selectedRange == null) {
                              _selectedRange = DateTimeRange(
                                start: date,
                                end: date,
                              );
                            } else {
                              _selectedRange = DateTimeRange(
                                start: _selectedRange!.start,
                                end: date,
                              );
                            }
                          });
                        },
                      ),
                    )
                  : Center(
                      child: Text(
                        'Tap a date to start',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ExpressiveTextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _selectedRange != null
                        ? () => Navigator.of(context).pop(_selectedRange)
                        : null,
                    child: const Text('OK'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmartChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isSelected;

  const _SmartChip({
    required this.label,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      showCheckmark: true,
      visualDensity: VisualDensity.comfortable,
    );
  }
}
