# Notification Testing Guide

## How to Test the New Android Native Notification System

### Prerequisites
- Android device or emulator running
- App installed and notification permissions granted

### Test Scenario 1: Basic Notification Creation
1. **Open the app**
2. **Go to Settings** (gear icon)
3. **Tap "Test Notification"** - You should see:
   - Success message: "✅ Test notification sent successfully!"
   - A notification appears with "Mark as Done" and "Snooze" buttons

### Test Scenario 2: Task Due Date Notifications
1. **Create a new task**:
   - Tap the "+" button
   - Enter task title (e.g., "Test notification task")
   - Set a due date/time within the next few minutes
   - Save the task

2. **Wait for the notification**:
   - When the due time arrives, you should receive a notification
   - The notification should have "Mark as Done" and "Snooze" buttons

### Test Scenario 3: Action Button Testing
1. **Test "Mark as Done" button**:
   - When notification appears, tap "Mark as Done"
   - The notification should disappear
   - Open the app - the task should be marked as completed ✅
   - Check console logs for: "📝 Received notification action: mark_done"

2. **Test "Snooze" button**:
   - Create another task with near-future due date
   - When notification appears, tap "Snooze"
   - The notification should disappear
   - Check console logs for: "📝 Received notification action: snooze"
   - A new notification should appear after the snooze period (10 minutes)

### Debug Information to Look For

#### Console Logs (in VS Code Debug Console):
```
🔔 Initializing Android Native Notification Service
✅ Android native notification service initialized successfully
📝 Received notification action: mark_done for task: [task-id]
📝 Received notification action: snooze for task: [task-id]
```

#### Expected Behaviors:
- ✅ Notifications appear with custom icon
- ✅ Action buttons are clearly visible
- ✅ Tapping buttons dismisses notification
- ✅ App state updates correctly (task completion/snooze)
- ✅ Background actions work when app is closed

### Troubleshooting

#### If notifications don't appear:
1. Check notification permissions in Android Settings
2. Ensure the app isn't in battery optimization/power saving mode
3. Look for initialization logs in debug console

#### If action buttons don't work:
1. Check console for action reception logs
2. Verify AndroidManifest.xml has the BroadcastReceiver
3. Ensure the app isn't killed by the system

#### If actions don't update app state:
1. Check if EventChannel is properly connected
2. Look for action processing logs in debug console
3. Verify UnifiedNotificationService is handling actions

### Success Criteria
- [ ] Test notification creates successfully
- [ ] Task due date notifications appear on time
- [ ] "Mark as Done" button marks task as completed
- [ ] "Snooze" button reschedules notification
- [ ] Actions work when app is in background
- [ ] No crashes or error messages
- [ ] All console debug logs appear as expected

## Implementation Details

### What's New:
- **Android Native System**: Uses Android's native notification APIs instead of Flutter plugin
- **BroadcastReceiver**: Handles button actions at OS level
- **PendingIntent**: Proper Android 12+ compatible implementation
- **Unified Service**: Automatically chooses best implementation for the platform

### Technical Features:
- ✅ Android 12+ compatibility with FLAG_IMMUTABLE
- ✅ Proper notification channels and importance levels
- ✅ Action persistence for background scenarios
- ✅ Fallback to flutter_local_notifications if needed
- ✅ Comprehensive logging for debugging
