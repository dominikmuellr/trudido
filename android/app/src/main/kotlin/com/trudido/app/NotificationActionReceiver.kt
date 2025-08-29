package com.trudido.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationManagerCompat
import android.util.Log

class NotificationActionReceiver : BroadcastReceiver() {
    private val SNOOZE_MINUTES = 10
    private val ACTION_COMPLETE = "com.trudido.app.ACTION_COMPLETE"
    private val ACTION_SNOOZE = "com.trudido.app.ACTION_SNOOZE"
    override fun onReceive(context: Context, intent: Intent) {
        val taskId = intent.getStringExtra("taskId") ?: return
        val action = intent.action
        Log.d("NotifActionReceiver", "onReceive action=$action taskId=$taskId processAlive=${MainActivity.methodChannel != null}")
        when (action) {
            ACTION_COMPLETE -> {
                if (!TaskStatusStore.isCompleted(context, taskId)) {
                    TaskStatusStore.markCompleted(context, taskId)
                    Log.d("NotifActionReceiver", "Marked completed + persisting pending action for $taskId")
                    PendingActionStore.addAction(context, mapOf("type" to "taskCompleted", "taskId" to taskId))
                }
                NotificationManagerCompat.from(context).cancel(taskId.hashCode())
                MainActivity.methodChannel?.invokeMethod("notificationAction", mapOf("type" to "taskCompleted", "taskId" to taskId))
            }
            ACTION_SNOOZE -> {
                NotificationManagerCompat.from(context).cancel(taskId.hashCode())
                val newTime = System.currentTimeMillis() + SNOOZE_MINUTES * 60_000
                val requestCode = (taskId + "_snooze_" + newTime).hashCode()
                NotificationScheduler.scheduleExact(context, taskId, "Task Reminder", "Reminder after snooze", newTime, requestCode)
                Log.d("NotifActionReceiver", "Snoozed $taskId newTime=$newTime persisting action")
                PendingActionStore.addAction(context, mapOf("type" to "taskSnoozed", "taskId" to taskId, "newTime" to newTime))
                MainActivity.methodChannel?.invokeMethod("notificationAction", mapOf("type" to "taskSnoozed", "taskId" to taskId, "newTime" to newTime))
            }
        }
    }
}
