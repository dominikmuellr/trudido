import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Service class for managing native Android notifications via method channels.
/// This class provides an interface to schedule, cancel, and manage notifications
/// using the native Android AlarmManager and BroadcastReceiver system.
class NativeNotificationService {
  // Updated channel to new application namespace after rename.
  static const MethodChannel _channel = MethodChannel(
    'com.trudido.app/notifications',
  );

  static const String _scheduleMethod = 'scheduleNotification';
  static const String _cancelMethod = 'cancelScheduledNotification';
  static const String _checkPermissionMethod = 'checkExactAlarmPermission';
  static const String _requestPermissionMethod = 'requestExactAlarmPermission';
  static const String _openSettingsMethod = 'openAlarmSettings';
  static const String _checkNotificationPermissionMethod =
      'checkNotificationPermission';

  /// Schedules a notification to be displayed at a specific time.
  ///
  /// [scheduledTime] - The DateTime when the notification should be displayed
  /// [title] - The notification title
  /// [message] - The notification message/body
  /// [taskId] - Unique identifier for the task (used for cancellation)
  /// [now] - Optional current time (defaults to DateTime.now(), used for testing)
  ///
  /// Returns true if scheduling was successful, false otherwise.
  static Future<bool> scheduleNotification({
    required DateTime scheduledTime,
    required String title,
    required String message,
    required String taskId,
    DateTime? now,
  }) async {
    try {
      final currentTime = now ?? DateTime.now();
      // Validate that the scheduled time is in the future
      if (scheduledTime.isBefore(currentTime)) {
        debugPrint(
          'Cannot schedule notification for past time: $scheduledTime',
        );
        return false;
      }

      final result = await _channel.invokeMethod(_scheduleMethod, {
        'triggerTime': scheduledTime.millisecondsSinceEpoch,
        'title': title,
        'message': message,
        'taskId': taskId,
      });

      debugPrint('Notification scheduled: $result');
      return true;
    } on PlatformException catch (e) {
      debugPrint('Failed to schedule notification: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Unexpected error scheduling notification: $e');
      return false;
    }
  }

  /// Cancels a previously scheduled notification.
  ///
  /// [taskId] - The task ID used when scheduling the notification
  ///
  /// Returns true if cancellation was successful, false otherwise.
  static Future<bool> cancelNotification(String taskId) async {
    try {
      final result = await _channel.invokeMethod(_cancelMethod, {
        'taskId': taskId,
      });

      debugPrint('Notification cancelled: $result');
      return true;
    } on PlatformException catch (e) {
      debugPrint('Failed to cancel notification: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Unexpected error cancelling notification: $e');
      return false;
    }
  }

  /// Checks if the app has permission to schedule exact alarms.
  /// This is required for Android 12+ devices.
  ///
  /// Returns true if permission is granted, false otherwise.
  static Future<bool> hasExactAlarmPermission() async {
    try {
      final result = await _channel.invokeMethod(_checkPermissionMethod);
      return result as bool;
    } on PlatformException catch (e) {
      debugPrint('Failed to check exact alarm permission: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Unexpected error checking permission: $e');
      return false;
    }
  }

  /// Requests exact alarm permission from the user.
  /// This will open the system settings where the user can grant permission.
  /// Only needed for Android 12+ devices.
  ///
  /// Returns true if the request was initiated successfully.
  static Future<bool> requestExactAlarmPermission() async {
    try {
      final result = await _channel.invokeMethod(_requestPermissionMethod);
      debugPrint('Exact alarm permission request: $result');
      return true;
    } on PlatformException catch (e) {
      debugPrint('Failed to request exact alarm permission: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Unexpected error requesting permission: $e');
      return false;
    }
  }

  /// Schedules a notification for a specific number of minutes from now.
  /// Convenience method for quick scheduling.
  ///
  /// [minutesFromNow] - How many minutes from now to schedule the notification
  /// [title] - The notification title
  /// [message] - The notification message/body
  /// [taskId] - Unique identifier for the task
  /// [now] - Optional current time (defaults to DateTime.now(), used for testing)
  ///
  /// Returns true if scheduling was successful, false otherwise.
  static Future<bool> scheduleNotificationInMinutes({
    required int minutesFromNow,
    required String title,
    required String message,
    required String taskId,
    DateTime? now,
  }) async {
    final currentTime = now ?? DateTime.now();
    final scheduledTime = currentTime.add(Duration(minutes: minutesFromNow));
    return scheduleNotification(
      scheduledTime: scheduledTime,
      title: title,
      message: message,
      taskId: taskId,
      now: currentTime,
    );
  }

  /// Schedules a notification for a specific number of hours from now.
  /// Convenience method for quick scheduling.
  ///
  /// [hoursFromNow] - How many hours from now to schedule the notification
  /// [title] - The notification title
  /// [message] - The notification message/body
  /// [taskId] - Unique identifier for the task
  /// [now] - Optional current time (defaults to DateTime.now(), used for testing)
  ///
  /// Returns true if scheduling was successful, false otherwise.
  static Future<bool> scheduleNotificationInHours({
    required int hoursFromNow,
    required String title,
    required String message,
    required String taskId,
    DateTime? now,
  }) async {
    final currentTime = now ?? DateTime.now();
    final scheduledTime = currentTime.add(Duration(hours: hoursFromNow));
    return scheduleNotification(
      scheduledTime: scheduledTime,
      title: title,
      message: message,
      taskId: taskId,
      now: currentTime,
    );
  }

  /// Utility method to check permissions and request if needed.
  /// This should be called before scheduling notifications on Android 12+.
  ///
  /// Returns true if permission is granted or not needed, false otherwise.
  static Future<bool> ensureExactAlarmPermission() async {
    final hasPermission = await hasExactAlarmPermission();

    if (!hasPermission) {
      debugPrint(
        'Exact alarm permission not granted. Requesting permission...',
      );
      return await requestExactAlarmPermission();
    }

    return true;
  }

  /// Opens the alarm permission settings directly.
  /// Useful when you want to guide users to the settings manually.
  ///
  /// Returns true if settings were opened successfully.
  static Future<bool> openAlarmSettings() async {
    try {
      final result = await _channel.invokeMethod(_openSettingsMethod);
      debugPrint('Alarm settings opened: $result');
      return true;
    } on PlatformException catch (e) {
      debugPrint('Failed to open alarm settings: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Unexpected error opening alarm settings: $e');
      return false;
    }
  }

  /// Checks if notification permission is granted (Android 13+).
  ///
  /// Returns true if permission is granted, false otherwise.
  static Future<bool> hasNotificationPermission() async {
    try {
      final result = await _channel.invokeMethod(
        _checkNotificationPermissionMethod,
      );
      return result as bool;
    } on PlatformException catch (e) {
      debugPrint('Failed to check notification permission: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Unexpected error checking notification permission: $e');
      return false;
    }
  }

  /// Comprehensive permission check for all required permissions.
  /// Checks both exact alarm and notification permissions.
  ///
  /// Returns a map with permission status for each type.
  static Future<Map<String, bool>> checkAllPermissions() async {
    final exactAlarm = await hasExactAlarmPermission();
    final notifications = await hasNotificationPermission();

    return {
      'exactAlarm': exactAlarm,
      'notifications': notifications,
      'allGranted': exactAlarm && notifications,
    };
  }
}

/// Example usage class demonstrating how to integrate the notification service
/// with your todo app.
class NotificationExample {
  /// Example: Schedule a reminder for a todo task
  static Future<void> scheduleTaskReminder({
    required String taskId,
    required String taskTitle,
    required DateTime dueDate,
    int reminderMinutesBefore = 60, // Default: 1 hour before due date
    DateTime? now,
  }) async {
    // Ensure we have permission first
    final hasPermission =
        await NativeNotificationService.ensureExactAlarmPermission();
    if (!hasPermission) {
      debugPrint('Cannot schedule notification: permission denied');
      return;
    }

    // Calculate reminder time
    final reminderTime = dueDate.subtract(
      Duration(minutes: reminderMinutesBefore),
    );

    final currentTime = now ?? DateTime.now();
    // Only schedule if reminder time is in the future
    if (reminderTime.isBefore(currentTime)) {
      debugPrint('Task due date is too soon to schedule reminder');
      return;
    }

    final success = await NativeNotificationService.scheduleNotification(
      scheduledTime: reminderTime,
      title: 'Task Reminder',
      message: 'Don\'t forget: $taskTitle',
      taskId: taskId,
      now: currentTime,
    );

    if (success) {
      debugPrint('Reminder scheduled for task: $taskTitle at $reminderTime');
    } else {
      debugPrint('Failed to schedule reminder for task: $taskTitle');
    }
  }

  /// Example: Cancel a reminder for a completed task
  static Future<void> cancelTaskReminder(String taskId) async {
    final success = await NativeNotificationService.cancelNotification(taskId);

    if (success) {
      debugPrint('Reminder cancelled for task: $taskId');
    } else {
      debugPrint('Failed to cancel reminder for task: $taskId');
    }
  }

  /// Example: Schedule multiple reminders for a task
  static Future<void> scheduleMultipleReminders({
    required String taskId,
    required String taskTitle,
    required DateTime dueDate,
    List<int> reminderMinutes = const [60, 15], // 1 hour and 15 minutes before
    DateTime? now,
  }) async {
    final currentTime = now ?? DateTime.now();
    for (int i = 0; i < reminderMinutes.length; i++) {
      final reminderTime = dueDate.subtract(
        Duration(minutes: reminderMinutes[i]),
      );

      if (reminderTime.isAfter(currentTime)) {
        await NativeNotificationService.scheduleNotification(
          scheduledTime: reminderTime,
          title: 'Task Reminder',
          message: '$taskTitle is due in ${reminderMinutes[i]} minutes',
          taskId: '${taskId}_reminder_$i', // Unique ID for each reminder
          now: currentTime,
        );
      }
    }
  }
}
