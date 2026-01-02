package com.trudido.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * App Widget Provider for Trudido task list widget.
 * Displays incomplete tasks with checkbox, title, date/time, and recurring indicator.
 */
class TodoAppWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "TodoAppWidgetProvider"
        const val ACTION_TOGGLE_TASK = "com.trudido.app.WIDGET_TOGGLE_TASK"
        const val ACTION_ADD_TASK = "com.trudido.app.WIDGET_ADD_TASK"
        const val ACTION_REFRESH = "com.trudido.app.WIDGET_REFRESH"
        const val EXTRA_TASK_ID = "extra_task_id"
        
        // Cache file for widget data (shared with Dart side)
        private const val WIDGET_CACHE_FILE = "widget_tasks.json"

        /**
         * Trigger widget update from anywhere (e.g., after task changes)
         */
        fun triggerUpdate(context: Context) {
            val intent = Intent(context, TodoAppWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            }
            val widgetManager = AppWidgetManager.getInstance(context)
            val ids = widgetManager.getAppWidgetIds(
                ComponentName(context, TodoAppWidgetProvider::class.java)
            )
            intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            context.sendBroadcast(intent)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d(TAG, "onUpdate: updating ${appWidgetIds.size} widgets")
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        when (intent.action) {
            ACTION_TOGGLE_TASK -> {
                val taskId = intent.getStringExtra(EXTRA_TASK_ID)
                Log.d(TAG, "Toggle task: $taskId")
                if (taskId != null) {
                    handleToggleTask(context, taskId)
                }
            }
            ACTION_ADD_TASK -> {
                Log.d(TAG, "Add task clicked")
                launchAppForNewTask(context)
            }
            ACTION_REFRESH -> {
                Log.d(TAG, "Refresh requested")
                triggerUpdate(context)
            }
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.app_widget)

        // Set up the intent that starts the WidgetTasksService for the ListView
        val serviceIntent = Intent(context, WidgetTasksService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            // Unique data URI to ensure separate instances
            data = Uri.parse("widget://$appWidgetId")
        }
        views.setRemoteAdapter(R.id.task_list, serviceIntent)
        views.setEmptyView(R.id.task_list, R.id.empty_view)

        // Set up the pending intent template for list item clicks (toggle task)
        val toggleIntent = Intent(context, TodoAppWidgetProvider::class.java).apply {
            action = ACTION_TOGGLE_TASK
        }
        val togglePendingIntent = PendingIntent.getBroadcast(
            context, 0, toggleIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )
        views.setPendingIntentTemplate(R.id.task_list, togglePendingIntent)

        // Set up the add task button
        val addIntent = Intent(context, TodoAppWidgetProvider::class.java).apply {
            action = ACTION_ADD_TASK
        }
        val addPendingIntent = PendingIntent.getBroadcast(
            context, 1, addIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.btn_add_task, addPendingIntent)

        // Update widget
        appWidgetManager.updateAppWidget(appWidgetId, views)
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.task_list)
    }

    private fun handleToggleTask(context: Context, taskId: String) {
        // Store the toggle request for the Dart side to process
        val prefs = context.getSharedPreferences("widget_actions", Context.MODE_PRIVATE)
        val pendingToggles = prefs.getStringSet("pending_toggles", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
        pendingToggles.add(taskId)
        prefs.edit().putStringSet("pending_toggles", pendingToggles).apply()

        // Update cache immediately for responsive UI
        updateCacheForToggle(context, taskId)

        // Refresh widget to show updated state
        triggerUpdate(context)

        // Try to notify the Flutter app if it's running
        try {
            MainActivity.widgetChannel?.invokeMethod("widgetToggleTask", taskId)
        } catch (e: Exception) {
            Log.d(TAG, "Flutter not running, toggle stored for later: $taskId")
        }
    }

    private fun updateCacheForToggle(context: Context, taskId: String) {
        try {
            val cacheFile = File(context.filesDir, WIDGET_CACHE_FILE)
            if (!cacheFile.exists()) return

            val json = cacheFile.readText()
            val tasksArray = JSONArray(json)
            val newArray = JSONArray()

            for (i in 0 until tasksArray.length()) {
                val task = tasksArray.getJSONObject(i)
                if (task.getString("id") != taskId) {
                    newArray.put(task)
                }
                // Skip the toggled task (it's now completed, so remove from incomplete list)
            }

            cacheFile.writeText(newArray.toString())
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update cache for toggle", e)
        }
    }

    private fun launchAppForNewTask(context: Context) {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("action", "create_task")
        }
        context.startActivity(intent)
    }

    override fun onEnabled(context: Context) {
        Log.d(TAG, "Widget enabled")
    }

    override fun onDisabled(context: Context) {
        Log.d(TAG, "Widget disabled")
    }
}
