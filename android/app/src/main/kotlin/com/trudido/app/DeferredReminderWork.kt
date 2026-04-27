package com.trudido.app

import android.content.Context
import android.util.Log
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

/** Schedules WorkManager checkpoint for far-future reminders so we avoid holding long-lived exact alarms. */
object DeferredReminderWork {
    private const val UNIQUE_PREFIX = "deferred_reminder_"

    fun enqueue(
        context: Context,
        scheduleKey: String,
        taskId: String,
        title: String,
        body: String,
        triggerAt: Long,
        delayMs: Long,
        persistent: Boolean = false
    ) {
        val wm = WorkManager.getInstance(context)
        val data = Data.Builder()
            .putString(DeferredReminderWorker.KEY_SCHEDULE_KEY, scheduleKey)
            .putString(DeferredReminderWorker.KEY_TASK_ID, taskId)
            .putString(DeferredReminderWorker.KEY_TITLE, title)
            .putString(DeferredReminderWorker.KEY_BODY, body)
            .putLong(DeferredReminderWorker.KEY_TRIGGER_AT, triggerAt)
            .putBoolean(DeferredReminderWorker.KEY_PERSISTENT, persistent)
            .build()
        val req = OneTimeWorkRequestBuilder<DeferredReminderWorker>()
            .setInitialDelay(delayMs, TimeUnit.MILLISECONDS)
            .setInputData(data)
            .addTag(uniqueTag(scheduleKey))
            .build()
        wm.enqueueUniqueWork(uniqueName(scheduleKey), ExistingWorkPolicy.REPLACE, req)
        Log.d(
            "DeferredReminderWork",
            "Enqueued key=$scheduleKey taskId=$taskId delayMs=$delayMs triggerAt=$triggerAt"
        )
    }

    fun cancel(context: Context, scheduleKey: String) {
        WorkManager.getInstance(context).cancelUniqueWork(uniqueName(scheduleKey))
    }

    private fun uniqueName(scheduleKey: String) = UNIQUE_PREFIX + scheduleKey
    private fun uniqueTag(scheduleKey: String) = UNIQUE_PREFIX + scheduleKey
}
