import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/clock.dart';

class SmartDatePicker extends ConsumerStatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final Function(DateTime? startDate, DateTime? endDate) onDateSelected;

  const SmartDatePicker({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
    required this.onDateSelected,
  });

  @override
  ConsumerState<SmartDatePicker> createState() => _SmartDatePickerState();
}

class _SmartDatePickerState extends ConsumerState<SmartDatePicker> {
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Date',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Tap once for single day, tap twice for range',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Theme(
              data: theme.copyWith(
                colorScheme: colorScheme.copyWith(
                  primary: colorScheme.primary,
                  onPrimary: colorScheme.onPrimary,
                ),
              ),
              child: CalendarDatePicker(
                initialDate: _startDate ?? ref.read(clockProvider).now(),
                firstDate: ref
                    .read(clockProvider)
                    .now()
                    .subtract(const Duration(days: 30)),
                lastDate: ref
                    .read(clockProvider)
                    .now()
                    .add(const Duration(days: 365)),
                onDateChanged: _handleDateSelection,
              ),
            ),

            const SizedBox(height: 24),

            if (_startDate != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      _endDate != null
                          ? 'Date Range Selected'
                          : 'Single Date Selected',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _endDate != null
                          ? '${DateFormat('MMM d, yyyy').format(_startDate!)} - ${DateFormat('MMM d, yyyy').format(_endDate!)}'
                          : DateFormat('MMM d, yyyy').format(_startDate!),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            Row(
              children: [
                if (_startDate != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                      });
                    },
                    child: const Text('Clear'),
                  ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _startDate != null
                      ? () {
                          widget.onDateSelected(_startDate, _endDate);
                          Navigator.of(context).pop();
                        }
                      : null,
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleDateSelection(DateTime date) {
    setState(() {
      if (_startDate == null) {
        _startDate = date;
        _endDate = null;
      } else if (_startDate == date) {
        _endDate = null;
      } else if (_endDate == null) {
        if (date.isAfter(_startDate!)) {
          _endDate = date;
        } else {
          _endDate = _startDate;
          _startDate = date;
        }
      } else {
        _startDate = date;
        _endDate = null;
      }
    });
  }
}

Future<Map<String, DateTime?>?> showSmartDatePicker({
  required BuildContext context,
  DateTime? initialStartDate,
  DateTime? initialEndDate,
}) async {
  Map<String, DateTime?>? result;

  await showDialog<void>(
    context: context,
    builder: (context) => SmartDatePicker(
      initialStartDate: initialStartDate,
      initialEndDate: initialEndDate,
      onDateSelected: (startDate, endDate) {
        result = {'startDate': startDate, 'endDate': endDate};
      },
    ),
  );

  return result;
}
