package com.trudido.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

class CalendarTaskService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        val appWidgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        )
        return CalendarTaskFactory(applicationContext, appWidgetId)
    }
}

class CalendarTaskFactory(
    private val context: Context,
    private val appWidgetId: Int
) : RemoteViewsService.RemoteViewsFactory {

    companion object {
        private const val TAG = "CalendarTaskFactory"
        private const val PREFS_NAME = "com.trudido.app.calendar_widget_prefs"
        private const val WIDGET_CACHE_FILE = "widget_tasks.json"
    }

    private var tasks: List<WidgetTask> = emptyList()

    override fun onCreate() {
        Log.d(TAG, "onCreate for widget $appWidgetId")
    }

    override fun onDataSetChanged() {
        Log.d(TAG, "onDataSetChanged for widget $appWidgetId")
        
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val selectedDate = prefs.getLong(
            "widget_${appWidgetId}_selected_date",
            Calendar.getInstance().timeInMillis
        )

        tasks = loadTasksForDate(selectedDate)
        Log.d(TAG, "Loaded ${tasks.size} tasks for selected date")
    }

    private fun loadTasksForDate(dateMillis: Long): List<WidgetTask> {
        return try {
            val cacheFile = File(context.filesDir, WIDGET_CACHE_FILE)
            if (!cacheFile.exists()) return emptyList()

            val json = cacheFile.readText()
            val tasksArray = JSONArray(json)
            val result = mutableListOf<WidgetTask>()

            val selectedCal = Calendar.getInstance().apply { timeInMillis = dateMillis }

            for (i in 0 until tasksArray.length()) {
                val task = tasksArray.getJSONObject(i)
                val taskId = task.getString("id")
                val title = task.getString("title")
                val dueDate = task.optLong("dueDate", 0)
                val startDate = task.optLong("startDate", 0)
                val repeatType = task.optString("repeatType", "")

                // Check if task is active on selected date
                if (isTaskActiveOnDate(dueDate, startDate, selectedCal)) {
                    val dateTimeDisplay = formatTime(dueDate)
                    result.add(
                        WidgetTask(
                            id = taskId,
                            title = title,
                            dueDateMillis = if (dueDate > 0) dueDate else null,
                            dateTimeDisplay = dateTimeDisplay,
                            isRecurring = repeatType.isNotEmpty()
                        )
                    )
                }
            }
            result
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load tasks", e)
            emptyList()
        }
    }

    private fun isTaskActiveOnDate(
        dueDate: Long,
        startDate: Long,
        selectedDate: Calendar
    ): Boolean {
        if (dueDate > 0) {
            val dueCal = Calendar.getInstance().apply { timeInMillis = dueDate }
            if (isSameDay(dueCal, selectedDate)) return true
        }

        if (startDate > 0 && dueDate > 0) {
            // Check if selected date is within start-due range
            val startCal = Calendar.getInstance().apply {
                timeInMillis = startDate
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val dueCal = Calendar.getInstance().apply {
                timeInMillis = dueDate
                set(Calendar.HOUR_OF_DAY, 23)
                set(Calendar.MINUTE, 59)
                set(Calendar.SECOND, 59)
            }
            val selectedNormalized = Calendar.getInstance().apply {
                timeInMillis = selectedDate.timeInMillis
                set(Calendar.HOUR_OF_DAY, 12)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
            }
            
            if (selectedNormalized.timeInMillis >= startCal.timeInMillis && 
                selectedNormalized.timeInMillis <= dueCal.timeInMillis) {
                return true
            }
        }

        return false
    }

    private fun isSameDay(cal1: Calendar, cal2: Calendar): Boolean {
        return cal1.get(Calendar.YEAR) == cal2.get(Calendar.YEAR) &&
               cal1.get(Calendar.DAY_OF_YEAR) == cal2.get(Calendar.DAY_OF_YEAR)
    }

    private fun formatTime(dueDate: Long): String {
        if (dueDate <= 0) return ""

        val calendar = Calendar.getInstance().apply { timeInMillis = dueDate }
        val hasTime = calendar.get(Calendar.HOUR_OF_DAY) != 0 || 
                     calendar.get(Calendar.MINUTE) != 0

        return if (hasTime) {
            val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
            timeFormat.format(calendar.time)
        } else {
            ""
        }
    }

    override fun getViewAt(position: Int): RemoteViews {
        if (position < 0 || position >= tasks.size) {
            return RemoteViews(context.packageName, R.layout.widget_task_item)
        }

        val task = tasks[position]
        val views = RemoteViews(context.packageName, R.layout.widget_task_item)

        views.setTextViewText(R.id.task_title, task.title)
        views.setImageViewResource(R.id.task_checkbox, R.drawable.ic_checkbox_unchecked)

        if (task.dateTimeDisplay.isNotEmpty()) {
            views.setTextViewText(R.id.task_datetime, task.dateTimeDisplay)
            views.setViewVisibility(R.id.task_meta_row, android.view.View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.task_meta_row, android.view.View.GONE)
        }

        if (task.isRecurring) {
            views.setViewVisibility(R.id.task_recurring, android.view.View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.task_recurring, android.view.View.GONE)
        }

        // Set fill-in intent for toggle action (reuse from main widget)
        val fillInIntent = Intent().apply {
            putExtra(TodoAppWidgetProvider.EXTRA_TASK_ID, task.id)
        }
        views.setOnClickFillInIntent(R.id.task_item_container, fillInIntent)

        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getCount(): Int = tasks.size

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = false

    override fun onDestroy() {
        tasks = emptyList()
    }
}
