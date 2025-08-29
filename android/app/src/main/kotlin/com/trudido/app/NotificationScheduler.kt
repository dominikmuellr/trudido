package com.trudido.app

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import android.util.Log

object NotificationScheduler {
    private const val CHANNEL_ID = "task_channel"
    private const val CHANNEL_LOW_ID = "task_channel_low"
    private const val GROUP_TASKS = "com.trudido.app.TASKS"
    private const val SUMMARY_ID = 42000
    private const val ACTION_COMPLETE = "com.trudido.app.ACTION_COMPLETE"
    private const val ACTION_SNOOZE = "com.trudido.app.ACTION_SNOOZE"

    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                val high = NotificationChannel(
                    CHANNEL_ID,
                    "Task Reminders",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply { description = "Time-sensitive task reminders" }
                manager.createNotificationChannel(high)
            }
            if (manager.getNotificationChannel(CHANNEL_LOW_ID) == null) {
                val low = NotificationChannel(
                    CHANNEL_LOW_ID,
                    "Background Task Info",
                    NotificationManager.IMPORTANCE_MIN
                ).apply { description = "Summary & background task status" }
                manager.createNotificationChannel(low)
            }
        }
    }

    fun scheduleExact(context: Context, taskId: String, title: String, body: String, triggerAtMillis: Long, requestCode: Int) {
        createChannel(context)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = buildShowIntent(context, taskId, title, body, requestCode)
        Log.d("NotificationScheduler", "scheduleExact taskId=$taskId at=$triggerAtMillis now=${System.currentTimeMillis()} requestCode=$requestCode")
        // Persist for reboot restoration
        ScheduledNotificationsStore.upsert(context, taskId, title, body, triggerAtMillis)
        // WorkManager fallback for far-future (non time-critical) reminders to save battery / quota.
        val DAY_MS = 24 * 60 * 60 * 1000L
        val nowCheck = System.currentTimeMillis()
        val farFuture = triggerAtMillis - nowCheck > DAY_MS
        if (farFuture) {
            // Use a checkpoint: wake up when within ~24h window (or sooner if extremely far out)
            val remaining = triggerAtMillis - nowCheck
            val delayMs = (remaining - DAY_MS).coerceAtLeast(DAY_MS / 2) // if >48h away wake mid-way
            DeferredReminderWork.enqueue(context, taskId, title, body, triggerAtMillis, delayMs)
            Log.d("NotificationScheduler", "Deferring via WorkManager taskId=$taskId remainingMs=$remaining delayMs=$delayMs")
            return
        }
        val now = System.currentTimeMillis()
        val delta = triggerAtMillis - now
        val canExact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) alarmManager.canScheduleExactAlarms() else true
        if (canExact) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
            }
            Log.d("NotificationScheduler", "Exact alarm scheduled deltaMs=$delta")
        } else {
            if (delta > 3 * 60 * 1000) {
                val windowLen = (delta * 0.1).coerceAtLeast(60_000.0).toLong().coerceAtMost(5 * 60 * 1000)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                    alarmManager.setWindow(AlarmManager.RTC_WAKEUP, triggerAtMillis, windowLen, pendingIntent)
                    Log.w("NotificationScheduler", "Inexact window scheduled deltaMs=$delta windowMs=$windowLen")
                } else {
                    alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                }
            } else {
                Log.w("NotificationScheduler", "Exact not allowed & near-term; showing immediately")
                showNow(context, taskId, title, body)
                return
            }
        }
    }

    private fun buildShowIntent(context: Context, taskId: String, title: String, body: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, ShowNotificationReceiver::class.java).apply {
            putExtra("taskId", taskId)
            putExtra("title", title)
            putExtra("body", body)
            putExtra("scheduledAt", System.currentTimeMillis())
        }
        return PendingIntent.getBroadcast(context, requestCode, intent, PendingIntent.FLAG_UPDATE_CURRENT or flagImmutable())
    }
    private fun flagImmutable(): Int = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0

    fun cancel(context: Context, key: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = buildShowIntent(context, key, "", "", key.hashCode())
        alarmManager.cancel(pi)
        NotificationManagerCompat.from(context).cancel(key.hashCode())
    ScheduledNotificationsStore.remove(context, key)
    // Cancel deferred work if present
    DeferredReminderWork.cancel(context, key)
        updateGroupSummary(context)
    }

    fun showNow(context: Context, taskId: String, title: String, body: String) {
        createChannel(context)
        val notification = buildNotification(context, taskId, title, body)
        Log.d("NotificationScheduler", "showNow immediate notification for taskId=$taskId")
        NotificationManagerCompat.from(context).notify(taskId.hashCode(), notification)
        updateGroupSummary(context)
    }

    fun buildNotification(context: Context, taskId: String, title: String, body: String): Notification {
        val completeIntent = Intent(context, NotificationActionReceiver::class.java).apply {
            action = ACTION_COMPLETE
            putExtra("taskId", taskId)
        }
        val snoozeIntent = Intent(context, NotificationActionReceiver::class.java).apply {
            action = ACTION_SNOOZE
            putExtra("taskId", taskId)
        }
        val completePi = PendingIntent.getBroadcast(context, (taskId + "_c").hashCode(), completeIntent, PendingIntent.FLAG_UPDATE_CURRENT or flagImmutable())
        val snoozePi = PendingIntent.getBroadcast(context, (taskId + "_s").hashCode(), snoozeIntent, PendingIntent.FLAG_UPDATE_CURRENT or flagImmutable())
        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setGroup(GROUP_TASKS)
            .addAction(0, "Done", completePi)
            .addAction(0, "Snooze", snoozePi)
            .build()
    }

    fun updateGroupSummary(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val active = nm.activeNotifications.filter { it.notification.group == GROUP_TASKS && (it.id != SUMMARY_ID) }
        if (active.size <= 1) {
            nm.cancel(SUMMARY_ID)
            return
        }
        val lines = active.take(5).map { it.notification.extras.getString(Notification.EXTRA_TITLE) ?: "Task" }
        val summary = NotificationCompat.Builder(context, CHANNEL_LOW_ID)
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle("${active.size} task reminders")
            .setStyle(NotificationCompat.InboxStyle().also { style -> lines.forEach { style.addLine(it) } })
            .setGroup(GROUP_TASKS)
            .setGroupSummary(true)
            .setAutoCancel(false)
            .setOngoing(false)
            .setOnlyAlertOnce(true)
            .build()
        nm.notify(SUMMARY_ID, summary)
        // Optional delayed re-check to collapse summary after rapid sequential cancels
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    val again = nm.activeNotifications.filter { it.notification.group == GROUP_TASKS && (it.id != SUMMARY_ID) }
                    if (again.size <= 1) nm.cancel(SUMMARY_ID)
                }, 350)
            } catch (_: Exception) {}
        }
    }

    fun ensurePermissionRequested(activity: Activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val nm = activity.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (!nm.areNotificationsEnabled()) {
                activity.requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 1001)
            }
        }
    }
}
