package com.trudido.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Fired via deleteIntent when the user swipes away or clears a persistent notification.
 * Immediately re-posts the same notification so it stays visible until Done or Snooze.
 *
 * deleteIntent does NOT fire when the app cancels the notification programmatically
 * (e.g. after Done/Snooze in NotificationActionReceiver), so this won't cause loops.
 */
class NotificationRestoreReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val taskId = intent.getStringExtra("taskId") ?: return
        val title = intent.getStringExtra("title") ?: "Task Reminder"
        val body = intent.getStringExtra("body") ?: ""
        // Only re-post if the setting is still enabled (user may have toggled it off)
        if (!PersistentNotificationPref.isEnabled(context)) {
            Log.d("NotifRestoreReceiver", "Setting now off, not restoring taskId=$taskId")
            return
        }
        Log.d("NotifRestoreReceiver", "Re-posting dismissed persistent notification taskId=$taskId")
        NotificationScheduler.showNow(context, taskId, title, body, persistent = true)
    }
}
