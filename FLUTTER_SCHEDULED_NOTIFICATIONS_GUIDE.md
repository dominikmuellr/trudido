# Complete Flutter Scheduled Notifications Guide

## The Problem: Instant vs Scheduled Notifications

When notifications appear immediately instead of at the scheduled time, it's usually because:

1. **Using `show()` instead of `zonedSchedule()`**
2. **Incorrect timezone handling**
3. **Past dates being scheduled**
4. **Missing permissions**

## Complete Working Solution

### 1. Proper Service Implementation

```dart
// Use the ScheduledNotificationService provided above
import 'package:your_app/services/scheduled_notification_service.dart';

final notificationService = ScheduledNotificationService();
```

### 2. Initialize in main.dart

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notification service
  final notificationService = ScheduledNotificationService();
  await notificationService.initialize();
  await notificationService.requestPermissions();
  
  runApp(MyApp());
}
```

### 3. Create Task with Proper Due Date

```dart
Future<void> createTaskWithReminder() async {
  // Create a task with future due date
  final task = Todo(
    id: 'task_123',
    text: 'Important Meeting',
    notes: 'Don\'t forget to prepare the presentation',
    dueDate: DateTime.now().add(Duration(minutes: 5)), // 5 minutes from now
    reminderOffsetsMinutes: [0, 15, 60], // At due time, 15 min before, 1 hour before
  );
  
  // Schedule notifications (THIS IS THE KEY METHOD)
  await notificationService.scheduleNotificationsForTask(task);
  
  // Save task to storage
  await saveTask(task);
}
```

### 4. Update Task (Cancel Old + Schedule New)

```dart
Future<void> updateTask(Todo originalTask, Todo updatedTask) async {
  // IMPORTANT: Cancel old notifications first
  await notificationService.cancelNotificationsForTaskEnhanced(
    originalTask.id, 
    originalTask.reminderOffsetsMinutes
  );
  
  // Schedule new notifications
  if (updatedTask.dueDate != null) {
    await notificationService.scheduleNotificationsForTask(updatedTask);
  }
  
  // Save updated task
  await saveTask(updatedTask);
}
```

### 5. Delete Task (Clean Cancellation)

```dart
Future<void> deleteTask(Todo task) async {
  // Cancel all notifications for this task
  await notificationService.cancelNotificationsForTask(task);
  
  // Delete from storage
  await removeTask(task.id);
}
```

### 6. Handle Notification Actions

```dart
// In your main.dart or app initialization
void setupNotificationHandling() {
  selectNotificationStream.stream.listen((NotificationResponse response) {
    if (response.actionId == null || response.actionId!.isEmpty) {
      // Main notification body tapped - navigate to task
      _navigateToTask(response.payload);
    } else {
      // Action button tapped
      _handleNotificationAction(response.actionId!, response.payload);
    }
  });
}

void _handleNotificationAction(String actionId, String? taskId) {
  switch (actionId) {
    case 'mark_as_complete':
      _markTaskAsComplete(taskId);
      break;
    case 'snooze':
      _snoozeTask(taskId);
      break;
  }
}

Future<void> _markTaskAsComplete(String? taskId) async {
  if (taskId == null) return;
  
  final task = await getTask(taskId);
  if (task != null) {
    final completedTask = task.copyWith(isCompleted: true);
    await updateTask(task, completedTask);
  }
}

Future<void> _snoozeTask(String? taskId) async {
  if (taskId == null) return;
  
  final task = await getTask(taskId);
  if (task != null && task.dueDate != null) {
    // Snooze for 15 minutes
    final snoozeTask = task.copyWith(
      dueDate: task.dueDate!.add(Duration(minutes: 15))
    );
    await updateTask(task, snoozeTask);
  }
}
```

## Key Points to Remember

### ✅ DO:
- Use `zonedSchedule()` for future notifications
- Always check if due date is in the future
- Initialize timezone data: `tz.initializeTimeZones()`
- Request notification permissions
- Cancel old notifications before updating
- Use unique notification IDs

### ❌ DON'T:
- Use `show()` for scheduled notifications (shows immediately)
- Schedule notifications for past dates
- Forget to cancel notifications when updating/deleting tasks
- Use the same notification ID for different notifications

## Debugging Tips

### 1. Check Pending Notifications
```dart
final pending = await notificationService.getPendingNotifications();
print('Pending notifications: ${pending.length}');
for (var notification in pending) {
  print('ID: ${notification.id}, Title: ${notification.title}, Scheduled: ${notification.body}');
}
```

### 2. Test with Near-Future Time
```dart
// For testing, schedule 30 seconds from now
final testTask = Todo(
  id: 'test_task',
  text: 'Test Notification',
  dueDate: DateTime.now().add(Duration(seconds: 30)),
  reminderOffsetsMinutes: [0], // Show at due time
);
await notificationService.scheduleNotificationsForTask(testTask);
```

### 3. Verify Timezone Setup
```dart
void checkTimezone() {
  final now = DateTime.now();
  final tzNow = tz.TZDateTime.now(tz.local);
  print('System time: $now');
  print('Timezone time: $tzNow');
  print('Timezone: ${tz.local.name}');
}
```

## Common Issues and Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| Notification shows immediately | Using `show()` instead of `zonedSchedule()` | Use `zonedSchedule()` with future date |
| No notification appears | Past due date or no permissions | Check date is future and permissions granted |
| Duplicate notifications | Not canceling old notifications | Cancel before scheduling new ones |
| Wrong time zone | Not initializing timezone data | Call `tz.initializeTimeZones()` |
| Action buttons don't work | Missing action handling | Implement notification response handling |

## Complete Working Example

Here's a minimal working example:

```dart
import 'package:flutter/material.dart';
import 'package:your_app/services/scheduled_notification_service.dart';

class NotificationExample extends StatefulWidget {
  @override
  _NotificationExampleState createState() => _NotificationExampleState();
}

class _NotificationExampleState extends State<NotificationExample> {
  final notificationService = ScheduledNotificationService();
  
  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }
  
  Future<void> _initializeNotifications() async {
    await notificationService.initialize();
    await notificationService.requestPermissions();
  }
  
  Future<void> _scheduleTestNotification() async {
    final task = Todo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: 'Test Task',
      notes: 'This is a test notification',
      dueDate: DateTime.now().add(Duration(minutes: 1)), // 1 minute from now
      reminderOffsetsMinutes: [0], // Show at due time
    );
    
    await notificationService.scheduleNotificationsForTask(task);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Notification scheduled for 1 minute from now!')),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Notification Test')),
      body: Center(
        child: ElevatedButton(
          onPressed: _scheduleTestNotification,
          child: Text('Schedule Test Notification'),
        ),
      ),
    );
  }
}
```

This complete solution ensures notifications appear at the correct scheduled time with proper action button functionality.
