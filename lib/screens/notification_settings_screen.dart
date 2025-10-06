import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bridge = NotificationBridge.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Testing'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Test & Manage Notifications',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.science),
                  title: const Text('Schedule Test (10s)'),
                  subtitle: const Text(
                    'Schedules a notification 10 seconds from now.',
                  ),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      final dt = DateTime.now().add(
                        const Duration(seconds: 10),
                      );
                      await bridge.scheduleTaskNotification(
                        taskId: 'test-10s',
                        title: 'Test Notification',
                        body: 'Fires after 10 seconds',
                        scheduledTime: dt,
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Scheduled test notification for 10s'),
                        ),
                      );
                    },
                    child: const Text('Schedule'),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: const Text('Cancel Test Notification'),
                  subtitle: const Text(
                    'Cancels the test notification if pending.',
                  ),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[100],
                      foregroundColor: Colors.red[800],
                    ),
                    onPressed: () async {
                      await bridge.cancelTaskNotification('test-10s');
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cancelled test notification'),
                        ),
                      );
                    },
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer.withAlpha(77),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'How Notifications Work',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• Notifications are automatically scheduled when you create a task with a due date.\n'
                    '• They are sent at the exact time you specified.\n'
                    '• Notifications are canceled when you complete or delete a task.',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(204),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // legacy test helpers removed with new native system
}
