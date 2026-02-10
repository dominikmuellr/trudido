// Trudido - A privacy-focused todo and notes app
// Copyright (C) 2025 Dominik Müller
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
import '../utils/formatters.dart';
import '../widgets/common/common.dart';

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
      trailing: ExpressiveIconButton(
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
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: ActionChip(
        avatar: Icon(
          Icons.add,
          color: colorScheme.onTertiaryContainer,
          size: 18,
        ),
        label: Text(
          'Add Reminder',
          style: TextStyle(color: colorScheme.onTertiaryContainer),
        ),
        backgroundColor: colorScheme.tertiaryContainer,
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
