package com.trudido.app

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import android.util.Log

object PendingActionStore {
    private const val PREFS = "notification_actions"
    private const val KEY = "pending"
    fun addAction(context: Context, data: Map<String, Any?>) {
    val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val existing = prefs.getString(KEY, null)
        val arr = if (existing != null) JSONArray(existing) else JSONArray()
        val obj = JSONObject()
        data.forEach { (k, v) -> obj.put(k, v) }
        arr.put(obj)
        prefs.edit().putString(KEY, arr.toString()).apply()
    Log.d("PendingActionStore", "Added action ${data["type"]} taskId=${data["taskId"]} newSize=${arr.length()}")
    }
    fun getPendingActions(context: Context): List<Map<String, Any?>> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val existing = prefs.getString(KEY, null) ?: return emptyList()
        val arr = JSONArray(existing)
    Log.d("PendingActionStore", "getPendingActions size=${arr.length()}")
        return (0 until arr.length()).map { i ->
            val obj = arr.getJSONObject(i)
            obj.keys().asSequence().associateWith { k -> obj.get(k) }
        }
    }
    fun clear(context: Context) { context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(KEY).apply() }
}
