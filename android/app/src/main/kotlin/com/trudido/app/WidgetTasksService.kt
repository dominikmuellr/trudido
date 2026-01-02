package com.trudido.app

import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

/**
 * RemoteViewsService for the widget ListView.
 * Provides the factory that creates RemoteViews for each task item.
 */
class WidgetTasksService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return WidgetTasksFactory(applicationContext)
    }
}

/**
 * Factory that creates RemoteViews for each task in the widget list.
 */
class WidgetTasksFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {

    companion object {
        private const val TAG = "WidgetTasksFactory"
        private const val WIDGET_CACHE_FILE = "widget_tasks.json"
    }

    private var tasks: List<WidgetTask> = emptyList()

    override fun onCreate() {
        Log.d(TAG, "onCreate")
    }

    override fun onDataSetChanged() {
        Log.d(TAG, "onDataSetChanged")
        tasks = loadTasksFromCache()
        Log.d(TAG, "Loaded ${tasks.size} tasks")
    }

    override fun onDestroy() {
        tasks = emptyList()
    }

    override fun getCount(): Int = tasks.size

    override fun getViewAt(position: Int): RemoteViews {
        if (position < 0 || position >= tasks.size) {
            return RemoteViews(context.packageName, R.layout.widget_task_item)
        }

        val task = tasks[position]
        val views = RemoteViews(context.packageName, R.layout.widget_task_item)

        // Set task title
        views.setTextViewText(R.id.task_title, task.title)

        // Set checkbox icon (always unchecked since we show incomplete tasks)
        views.setImageViewResource(R.id.task_checkbox, R.drawable.ic_checkbox_unchecked)

        // Set date/time in European format
        if (task.dateTimeDisplay.isNotEmpty()) {
            views.setTextViewText(R.id.task_datetime, task.dateTimeDisplay)
            views.setViewVisibility(R.id.task_meta_row, android.view.View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.task_meta_row, android.view.View.GONE)
        }

        // Set recurring indicator
        if (task.isRecurring) {
            views.setViewVisibility(R.id.task_recurring, android.view.View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.task_recurring, android.view.View.GONE)
        }

        // Set fill-in intent for toggle action
        val fillInIntent = Intent().apply {
            putExtra(TodoAppWidgetProvider.EXTRA_TASK_ID, task.id)
        }
        views.setOnClickFillInIntent(R.id.task_item_container, fillInIntent)

        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = false

    /**
     * Load tasks from the cache file written by Dart.
     */
    private fun loadTasksFromCache(): List<WidgetTask> {
        return try {
            val cacheFile = File(context.filesDir, WIDGET_CACHE_FILE)
            if (!cacheFile.exists()) {
                Log.d(TAG, "Cache file does not exist")
                return emptyList()
            }

            val json = cacheFile.readText()
            val tasksArray = JSONArray(json)
            val result = mutableListOf<WidgetTask>()

            for (i in 0 until tasksArray.length()) {
                val taskJson = tasksArray.getJSONObject(i)
                result.add(parseTask(taskJson))
            }

            // Sort by due date (tasks with due date first, then by date)
            result.sortedWith(compareBy(
                { it.dueDateMillis == null },
                { it.dueDateMillis ?: Long.MAX_VALUE }
            ))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load tasks from cache", e)
            emptyList()
        }
    }

    private fun parseTask(json: JSONObject): WidgetTask {
        val id = json.getString("id")
        val title = json.getString("title")
        val dueDateMillis = if (json.has("dueDate") && !json.isNull("dueDate")) {
            json.getLong("dueDate")
        } else null
        val repeatType = json.optString("repeatType", "none")
        val isRecurring = repeatType != "none" && repeatType.isNotEmpty()

        val dateTimeDisplay = formatDateTime(dueDateMillis)

        return WidgetTask(
            id = id,
            title = title,
            dueDateMillis = dueDateMillis,
            dateTimeDisplay = dateTimeDisplay,
            isRecurring = isRecurring
        )
    }

    /**
     * Format date/time in European format: "2 Jan, 14:00" or "Heute, 14:00" (Today)
     */
    private fun formatDateTime(millis: Long?): String {
        if (millis == null) return ""

        val date = Date(millis)
        val now = Calendar.getInstance()
        val taskCal = Calendar.getInstance().apply { time = date }

        val isToday = now.get(Calendar.YEAR) == taskCal.get(Calendar.YEAR) &&
                now.get(Calendar.DAY_OF_YEAR) == taskCal.get(Calendar.DAY_OF_YEAR)

        val isTomorrow = run {
            val tomorrow = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 1) }
            tomorrow.get(Calendar.YEAR) == taskCal.get(Calendar.YEAR) &&
                    tomorrow.get(Calendar.DAY_OF_YEAR) == taskCal.get(Calendar.DAY_OF_YEAR)
        }

        val isOverdue = millis < System.currentTimeMillis()

        val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
        val dateFormat = SimpleDateFormat("d MMM", Locale.getDefault())

        val timeStr = timeFormat.format(date)
        
        // Check if time is midnight (00:00) - means no specific time set
        val hasTime = taskCal.get(Calendar.HOUR_OF_DAY) != 0 || taskCal.get(Calendar.MINUTE) != 0

        return when {
            isToday && hasTime -> "Heute, $timeStr"
            isToday -> "Heute"
            isTomorrow && hasTime -> "Morgen, $timeStr"
            isTomorrow -> "Morgen"
            isOverdue -> {
                val daysDiff = ((System.currentTimeMillis() - millis) / (1000 * 60 * 60 * 24)).toInt()
                when {
                    daysDiff == 0 && hasTime -> "Überfällig, $timeStr"
                    daysDiff == 1 -> "Gestern"
                    else -> "Überfällig ${daysDiff}d"
                }
            }
            hasTime -> "${dateFormat.format(date)}, $timeStr"
            else -> dateFormat.format(date)
        }
    }
}

/**
 * Data class for widget task display.
 */
data class WidgetTask(
    val id: String,
    val title: String,
    val dueDateMillis: Long?,
    val dateTimeDisplay: String,
    val isRecurring: Boolean
)
