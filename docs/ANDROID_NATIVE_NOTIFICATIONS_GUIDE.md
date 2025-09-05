# Android Native Notification System Implementation Guide

## Overview

This implementation provides a robust Android-native notification system that follows Android best practices for interactive notification buttons. It uses native Android components with proper PendingIntents and BroadcastReceiver patterns.

## Architecture Components

### 1. Android Native Components

#### **NotificationHelper.kt**
- **Purpose**: Creates notifications using Android's native `NotificationCompat.Builder`
- **Key Features**:
  - Proper notification channel creation for Android 8.0+
  - PendingIntent creation with unique request codes
  - Action buttons with drawable icons
  - Proper flags for Android 12+ compatibility

```kotlin
// Creates PendingIntent with proper flags
val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
} else {
    PendingIntent.FLAG_UPDATE_CURRENT
}
```

#### **NotificationActionReceiver.kt**
- **Purpose**: BroadcastReceiver that handles notification action button clicks
- **Key Features**:
  - Processes action intents with task ID and notification ID
  - Communicates with Flutter via EventChannel
  - Stores actions when Flutter is not connected
  - Comprehensive logging for debugging

```kotlin
// Action constants
const val ACTION_MARK_COMPLETE = "com.trudido.app.MARK_COMPLETE"
const val ACTION_SNOOZE = "com.trudido.app.SNOOZE"
const val ACTION_OPEN_TASK = "com.trudido.app.OPEN_TASK"
```

#### **MainActivity.kt**
- **Purpose**: Manages Flutter-Android communication
- **Key Features**:
  - MethodChannel for Flutter → Android calls
  - EventChannel for Android → Flutter events
  - Processes stored actions when Flutter reconnects
  - Error handling and logging

### 2. Flutter Integration Components

#### **AndroidNativeNotificationService.dart**
- **Purpose**: Flutter interface to Android native notifications
- **Key Features**:
  - Platform channel communication
  - Stream handling for notification actions
  - Task-based notification scheduling
  - Consistent notification ID generation

#### **UnifiedNotificationService.dart**
- **Purpose**: Unified interface that chooses the best implementation
- **Key Features**:
  - Automatically selects Android native or Flutter implementation
  - Unified action event stream
  - Backward compatibility
  - Enhanced cancellation support

## Android Manifest Configuration

```xml
<!-- Custom BroadcastReceiver for notification action buttons -->
<receiver 
    android:name=".NotificationActionReceiver"
    android:exported="false"
    android:enabled="true">
    <intent-filter>
    <action android:name="com.trudido.app.MARK_COMPLETE" />
    <action android:name="com.trudido.app.SNOOZE" />
    <action android:name="com.trudido.app.OPEN_TASK" />
    </intent-filter>
</receiver>
```

## Communication Flow

### 1. Notification Creation Flow
```
Flutter → MethodChannel → MainActivity → NotificationHelper → Android System
```

1. Flutter calls `showTaskNotification()` via MethodChannel
2. MainActivity receives call and validates parameters
3. NotificationHelper creates notification with action buttons
4. PendingIntents are created for each action button
5. Notification is displayed by Android system

### 2. Action Button Response Flow
```
User Tap → BroadcastReceiver → EventChannel → Flutter
```

1. User taps notification action button
2. Android triggers PendingIntent
3. NotificationActionReceiver receives broadcast
4. Receiver extracts task ID and action from Intent
5. Action is sent to Flutter via EventChannel
6. Flutter updates task state and UI

### 3. Background Action Handling
```
Action → SharedPreferences → EventChannel (when Flutter reconnects)
```

1. If Flutter is not connected, action is stored in SharedPreferences
2. When Flutter reconnects, stored actions are processed
3. Ensures no actions are lost when app is backgrounded

## Key Implementation Details

### PendingIntent Best Practices

```kotlin
private fun createActionPendingIntent(
    action: String,
    taskId: String,
    notificationId: Int,
    requestCode: Int
): PendingIntent {
    val intent = Intent(context, NotificationActionReceiver::class.java).apply {
        this.action = action
        putExtra(EXTRA_TASK_ID, taskId)
        putExtra(EXTRA_NOTIFICATION_ID, notificationId)
    }
    
    // Use FLAG_IMMUTABLE for Android 12+ security requirements
    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    } else {
        PendingIntent.FLAG_UPDATE_CURRENT
    }
    
    return PendingIntent.getBroadcast(
        context,
        requestCode + notificationId, // Unique request code
        intent,
        flags
    )
}
```

### Notification Channel Creation

```kotlin
private fun createNotificationChannel() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = CHANNEL_DESCRIPTION
            enableVibration(true)
            enableLights(true)
            setShowBadge(true)
        }
        
        notificationManager.createNotificationChannel(channel)
    }
}
```

### Flutter-Android Communication

```dart
// Method channel for Flutter → Android
static const MethodChannel _methodChannel = 
    MethodChannel('com.trudido.app/notifications');

// Event channel for Android → Flutter
static const EventChannel _eventChannel = 
    EventChannel('com.trudido.app/notification_actions');
```

## Usage Example

### 1. Initialize the Service
```dart
await UnifiedNotificationService.instance.initialize(preferAndroidNative: true);
```

### 2. Schedule Notifications
```dart
await UnifiedNotificationService.instance.scheduleNotificationsForTask(task);
```

### 3. Listen for Actions
```dart
UnifiedNotificationService.instance.onNotificationAction.listen((action) {
  switch (action.action) {
    case 'mark_complete':
      // Handle task completion
      break;
    case 'snooze':
      // Handle task snoozing
      break;
  }
});
```

## Testing and Debugging

### Debug Features
1. **Comprehensive Logging**: All components include detailed logging
2. **Test Notifications**: Use debug settings to send test notifications
3. **Action Storage**: Actions are preserved when app is backgrounded
4. **Error Handling**: Graceful degradation with fallback to Flutter implementation

### Debug Logs
```
🔧 Configuring unified notification handling...
✅ Using Android Native Notifications
📱 Android notification shown: Task Due (ID: 12345)
🔔 Notification action received: mark_complete | task_123
✅ Task marked as complete via androidNative
```

## Advantages of This Implementation

### 1. **Native Android Integration**
- Uses Android's native notification APIs
- Follows Android design guidelines
- Better performance and reliability

### 2. **Robust Action Handling**
- PendingIntents ensure reliable action delivery
- BroadcastReceiver handles actions even when app is backgrounded
- Action persistence prevents data loss

### 3. **Backward Compatibility**
- Graceful fallback to Flutter implementation
- Maintains existing functionality
- Works on all Android versions

### 4. **Best Practices Compliance**
- Proper permission handling
- Security-compliant PendingIntent flags
- Notification channel management
- Error handling and logging

## Required Permissions

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
```

## Icons Required

The implementation requires these drawable resources:
- `ic_notification.xml` - Main notification icon
- `ic_check.xml` - Mark complete action icon  
- `ic_snooze.xml` - Snooze action icon

## Conclusion

This Android-native notification system provides a robust, standards-compliant implementation that properly handles interactive notification buttons. It follows Android best practices while maintaining seamless integration with your Flutter todo app.

The unified service architecture allows for easy switching between implementations and ensures your app works reliably across different Android versions and scenarios.
