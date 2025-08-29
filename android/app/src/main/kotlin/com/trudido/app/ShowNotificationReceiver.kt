package com.trudido.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class ShowNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val taskId = intent.getStringExtra("taskId") ?: return
        val title = intent.getStringExtra("title") ?: "Task Reminder"
        val body = intent.getStringExtra("body") ?: ""
    val scheduledAt = intent.getLongExtra("scheduledAt", 0L)
    if (scheduledAt > 0) LateAlarmTracker.recordFire(context, scheduledAt)
        val notif = NotificationScheduler.buildNotification(context, taskId, title, body)
        androidx.core.app.NotificationManagerCompat.from(context).notify(taskId.hashCode(), notif)
    // Update group summary after posting
    NotificationScheduler.updateGroupSummary(context)
    }
}
