import 'package:flutter/material.dart';
import '../utils/formatters.dart';

/// Reusable dialog for adding reminders with presets and custom input
class AddReminderDialog extends StatefulWidget {
  final Function(int) onReminderAdded;
  final List<int> existingReminders;

  const AddReminderDialog({
    super.key,
    required this.onReminderAdded,
    required this.existingReminders,
  });

  @override
  State<AddReminderDialog> createState() => _AddReminderDialogState();
}

class _AddReminderDialogState extends State<AddReminderDialog> {
  final TextEditingController _customController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Common reminder presets in minutes
  static const List<int> _presets = [
    0, // At due time
    5, // 5 minutes before
    15, // 15 minutes before
    30, // 30 minutes before
    60, // 1 hour before
    120, // 2 hours before
    1440, // 1 day before
    2880, // 2 days before
    10080, // 1 week before
  ];

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _addCustomReminder() {
    if (!_formKey.currentState!.validate()) return;

    final text = _customController.text.trim();
    final int minutes = int.parse(
      text,
    ); // Safe because validator ensures it's valid
    widget.onReminderAdded(minutes);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Reminder'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose from presets:'),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: ListView(
                shrinkWrap: true,
                children: _presets
                    .where(
                      (preset) => !widget.existingReminders.contains(preset),
                    )
                    .map((minutes) {
                      return ListTile(
                        title: Text(formatMinutesReadable(minutes)),
                        onTap: () {
                          widget.onReminderAdded(minutes);
                          Navigator.of(context).pop();
                        },
                      );
                    })
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Or enter custom minutes:'),
            const SizedBox(height: 8),
            Form(
              key: _formKey,
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _customController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Minutes before due date',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a number';
                        }
                        final int? minutes = int.tryParse(value.trim());
                        if (minutes == null) {
                          return 'Please enter a valid number';
                        }
                        if (minutes < 0) {
                          return 'Minutes cannot be negative';
                        }
                        if (minutes > 525600) {
                          // Max 1 year in minutes
                          return 'Maximum 525600 minutes (1 year)';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _addCustomReminder,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
