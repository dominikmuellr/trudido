package com.trudido.app

import android.content.Context

object TaskStatusStore {
    private const val PREFS = "task_status_store"
    private const val COMPLETED_SET = "completed_set"
    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    fun isCompleted(ctx: Context, taskId: String): Boolean = (prefs(ctx).getString(COMPLETED_SET, "") ?: "").split('|').contains(taskId)
    fun markCompleted(ctx: Context, taskId: String) {
        val p = prefs(ctx)
        val raw = p.getString(COMPLETED_SET, "") ?: ""
        if (raw.split('|').contains(taskId)) return
        val updated = if (raw.isBlank()) taskId else "$raw|$taskId"
        p.edit().putString(COMPLETED_SET, updated).apply()
    }
}
