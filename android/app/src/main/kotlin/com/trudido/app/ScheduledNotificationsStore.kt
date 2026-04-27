package com.trudido.app

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** Simple persistence layer (SharedPreferences JSON) for scheduled notifications so we can restore after reboot. */
object ScheduledNotificationsStore {
    private const val PREFS = "scheduled_notifications_store"
    private const val KEY = "items"

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun upsert(
        ctx: Context,
        scheduleKey: String,
        taskId: String,
        title: String,
        body: String,
        triggerTime: Long
    ) {
        val arr = loadArray(ctx)
        // Remove existing entry with same schedule key
        val filtered = JSONArray()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            val existingKey = o.optString("key").ifBlank { o.optString("taskId") }
            if (existingKey != scheduleKey) filtered.put(o)
        }
        val obj = JSONObject().apply {
            put("key", scheduleKey)
            put("taskId", taskId)
            put("title", title)
            put("body", body)
            put("triggerTime", triggerTime)
        }
        filtered.put(obj)
        saveArray(ctx, filtered)
    }

    fun remove(ctx: Context, scheduleKey: String) {
        val arr = loadArray(ctx)
        val filtered = JSONArray()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            val existingKey = o.optString("key").ifBlank { o.optString("taskId") }
            if (existingKey != scheduleKey) filtered.put(o)
        }
        saveArray(ctx, filtered)
    }

    fun removeByTaskId(ctx: Context, taskId: String) {
        val arr = loadArray(ctx)
        val filtered = JSONArray()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            if (o.optString("taskId") != taskId) filtered.put(o)
        }
        saveArray(ctx, filtered)
    }

    fun allForTask(ctx: Context, taskId: String): List<ScheduledItem> {
        return all(ctx).filter { it.taskId == taskId }
    }

    fun all(ctx: Context): List<ScheduledItem> {
        val arr = loadArray(ctx)
        val out = mutableListOf<ScheduledItem>()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            val taskId = o.optString("taskId")
            val scheduleKey = o.optString("key").ifBlank { taskId }
            out.add(
                ScheduledItem(
                    scheduleKey,
                    taskId,
                    o.optString("title"),
                    o.optString("body"),
                    o.optLong("triggerTime")
                )
            )
        }
        return out
    }

    private fun loadArray(ctx: Context): JSONArray {
        val raw = prefs(ctx).getString(KEY, null) ?: return JSONArray()
        return try { JSONArray(raw) } catch (_: Exception) { JSONArray() }
    }

    private fun saveArray(ctx: Context, arr: JSONArray) {
        prefs(ctx).edit().putString(KEY, arr.toString()).apply()
    }

    data class ScheduledItem(
        val key: String,
        val taskId: String,
        val title: String,
        val body: String,
        val triggerTime: Long
    )
}