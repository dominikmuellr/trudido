package com.trudido.app

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters

/**
 * Worker invoked for non time-critical reminders that were scheduled >24h out.
 * It re-evaluates how far in the future the target time still is:
 *  - If now within 24h horizon -> hands off to AlarmManager exact/inexact path.
 *  - If still far (>24h due to device being off or reschedule drift) -> re-enqueue itself.
 */
class DeferredReminderWorker(
    appContext: Context,
    params: WorkerParameters
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        val scheduleKey = inputData.getString(KEY_SCHEDULE_KEY)
        val taskId = inputData.getString(KEY_TASK_ID) ?: return Result.failure()
        val title = inputData.getString(KEY_TITLE) ?: "Task Reminder"
        val body = inputData.getString(KEY_BODY) ?: ""
        val triggerAt = inputData.getLong(KEY_TRIGGER_AT, -1L)
        val persistent = inputData.getBoolean(KEY_PERSISTENT, false)
        val effectiveKey = scheduleKey ?: taskId
        if (triggerAt <= 0) return Result.failure()
        val now = System.currentTimeMillis()
        val remaining = triggerAt - now
        Log.d(TAG, "Worker run key=$effectiveKey taskId=$taskId remainingMs=$remaining")
        if (remaining <= 0) {
            // Time passed while deferred – show immediately
            NotificationScheduler.showNow(applicationContext, taskId, title, body, persistent)
            ScheduledNotificationsStore.remove(applicationContext, effectiveKey)
            return Result.success()
        }
        val DAY_MS = 24 * 60 * 60 * 1000L
        if (remaining <= DAY_MS) {
            // Move to regular alarm scheduling path
            val requestCode = effectiveKey.hashCode()
            NotificationScheduler.scheduleExact(
                applicationContext,
                taskId,
                title,
                body,
                triggerAt,
                requestCode,
                persistent,
                effectiveKey
            )
            return Result.success()
        }
        // Still far out; re-enqueue self for another checkpoint just before next 24h boundary.
        val delay = (remaining - DAY_MS).coerceAtLeast(DAY_MS / 2) // wake up midway if extremely far
        DeferredReminderWork.enqueue(
            applicationContext,
            effectiveKey,
            taskId,
            title,
            body,
            triggerAt,
            delay,
            persistent
        )
        return Result.success()
    }

    companion object {
        const val TAG = "DeferredReminderWorker"
        const val KEY_SCHEDULE_KEY = "scheduleKey"
        const val KEY_TASK_ID = "taskId"
        const val KEY_TITLE = "title"
        const val KEY_BODY = "body"
        const val KEY_TRIGGER_AT = "triggerAt"
        const val KEY_PERSISTENT = "persistent"
    }
}
