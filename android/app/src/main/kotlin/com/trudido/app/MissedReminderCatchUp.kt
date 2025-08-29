package com.trudido.app

import android.content.Context
import android.util.Log

/** Scans persisted scheduled notifications and reconciles any that are past-due. */
object MissedReminderCatchUp {
    private const val GRACE_MS = 30 * 60 * 1000L // 30 minutes show-now grace
    private const val MAX_STALE_MS = 12 * 60 * 60 * 1000L // drop if older than 12h

    fun run(context: Context) {
        val now = System.currentTimeMillis()
        val items = ScheduledNotificationsStore.all(context)
        var shown = 0
        var dropped = 0
        for (item in items) {
            val delta = item.triggerTime - now
            if (delta <= 0) {
                val age = now - item.triggerTime
                if (age <= GRACE_MS) {
                    NotificationScheduler.showNow(context, item.taskId, item.title, item.body)
                    ScheduledNotificationsStore.remove(context, item.taskId)
                    shown++
                } else if (age > MAX_STALE_MS) {
                    ScheduledNotificationsStore.remove(context, item.taskId)
                    dropped++
                } else {
                    // Keep for potential manual review (still future catch-up logic); no action
                }
            }
        }
        if (shown > 0 || dropped > 0) {
            Log.i("MissedReminderCatchUp", "shown=$shown dropped=$dropped total=${items.size}")
        }
    }
}