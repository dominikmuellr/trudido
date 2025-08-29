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

    fun enqueue(context: Context, taskId: String, title: String, body: String, triggerAt: Long, delayMs: Long) {
        val wm = WorkManager.getInstance(context)
        val data = Data.Builder()
            .putString(DeferredReminderWorker.KEY_TASK_ID, taskId)
            .putString(DeferredReminderWorker.KEY_TITLE, title)
            .putString(DeferredReminderWorker.KEY_BODY, body)
            .putLong(DeferredReminderWorker.KEY_TRIGGER_AT, triggerAt)
            .build()
        val req = OneTimeWorkRequestBuilder<DeferredReminderWorker>()
            .setInitialDelay(delayMs, TimeUnit.MILLISECONDS)
            .setInputData(data)
            .addTag(uniqueTag(taskId))
            .build()
        wm.enqueueUniqueWork(uniqueName(taskId), ExistingWorkPolicy.REPLACE, req)
        Log.d("DeferredReminderWork", "Enqueued taskId=$taskId delayMs=$delayMs triggerAt=$triggerAt")
    }

    fun cancel(context: Context, taskId: String) {
        WorkManager.getInstance(context).cancelUniqueWork(uniqueName(taskId))
    }

    private fun uniqueName(taskId: String) = UNIQUE_PREFIX + taskId
    private fun uniqueTag(taskId: String) = UNIQUE_PREFIX + taskId
}
