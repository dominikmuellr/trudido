import 'package:flutter/material.dart';
import '../utils/formatters.dart';

class ReminderChip extends StatelessWidget {
  final int minutes;
  final VoidCallback onDelete;

  const ReminderChip({
    super.key,
    required this.minutes,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.notifications_active_outlined, size: 20),
      title: Text(formatMinutesReadable(minutes)),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 20),
        onPressed: onDelete,
      ),
    );
  }
}

class AddReminderChip extends StatelessWidget {
  final VoidCallback onPressed;

  const AddReminderChip({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ActionChip(
        avatar: const Icon(Icons.add),
        label: const Text('Add Reminder'),
        onPressed: onPressed,
      ),
    );
  }
}

class RemindersSection extends StatelessWidget {
  final List<int> reminderOffsets;
  final Function(int) onRemoveReminder;
  final VoidCallback onAddReminder;

  const RemindersSection({
    super.key,
    required this.reminderOffsets,
    required this.onRemoveReminder,
    required this.onAddReminder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Reminders',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ...reminderOffsets.map((minutes) {
          return ReminderChip(
            minutes: minutes,
            onDelete: () => onRemoveReminder(minutes),
          );
        }),
        AddReminderChip(onPressed: onAddReminder),
      ],
    );
  }
}
