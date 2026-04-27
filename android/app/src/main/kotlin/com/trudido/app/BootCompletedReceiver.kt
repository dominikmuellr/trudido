package com.trudido.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/** Restores scheduled notifications after device reboot. */
class BootCompletedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return
        val now = System.currentTimeMillis()
        val items = ScheduledNotificationsStore.all(context)
        val persistent = PersistentNotificationPref.isEnabled(context)
        var restored = 0
        for (item in items) {
            // Skip past-due > 30 min; show immediately if within 30 min grace
            val delta = item.triggerTime - now
            if (delta <= 0) {
                if (now - item.triggerTime <= 30 * 60 * 1000) {
                    NotificationScheduler.showNow(context, item.taskId, item.title, item.body, persistent)
                    ScheduledNotificationsStore.remove(context, item.key)
                } else {
                    // Drop very old reminder
                    ScheduledNotificationsStore.remove(context, item.key)
                }
            } else {
                val requestCode = item.key.hashCode()
                NotificationScheduler.scheduleExact(
                    context,
                    item.taskId,
                    item.title,
                    item.body,
                    item.triggerTime,
                    requestCode,
                    persistent,
                    item.key
                )
                restored++
            }
        }
        Log.i("BootCompletedReceiver", "Processed reboot restore items=${items.size} restored=$restored")
    }
}