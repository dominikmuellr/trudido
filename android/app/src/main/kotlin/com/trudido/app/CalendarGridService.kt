package com.trudido.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.util.Log
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import java.io.File
import java.util.*

class CalendarGridService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        val appWidgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        )
        return CalendarGridFactory(applicationContext, appWidgetId)
    }
}

class CalendarGridFactory(
    private val context: Context,
    private val appWidgetId: Int
) : RemoteViewsService.RemoteViewsFactory {

    companion object {
        private const val TAG = "CalendarGridFactory"
        private const val PREFS_NAME = "com.trudido.app.calendar_widget_prefs"
        private const val WIDGET_CACHE_FILE = "widget_tasks.json"
    }

    private var days: List<DayInfo> = emptyList()
    private var selectedDateMillis: Long = 0
    private val todayMillis = Calendar.getInstance().timeInMillis

    data class DayInfo(
        val dayNumber: Int,
        val dateMillis: Long,
        val hasTasks: Boolean,
        val isCurrentMonth: Boolean
    )

    override fun onCreate() {
        Log.d(TAG, "onCreate")
    }

    override fun onDataSetChanged() {
        Log.d(TAG, "onDataSetChanged for widget $appWidgetId")
        
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val calendar = Calendar.getInstance()
        
        val currentMonth = prefs.getInt("widget_${appWidgetId}_month", calendar.get(Calendar.MONTH))
        val currentYear = prefs.getInt("widget_${appWidgetId}_year", calendar.get(Calendar.YEAR))
        selectedDateMillis = prefs.getLong("widget_${appWidgetId}_selected_date", calendar.timeInMillis)

        // Load task dates from cache
        val taskDates = loadTaskDates()

        // Build calendar grid
        days = buildCalendarGrid(currentYear, currentMonth, taskDates)
        Log.d(TAG, "Built grid with ${days.size} days")
    }

    private fun buildCalendarGrid(year: Int, month: Int, taskDates: Set<String>): List<DayInfo> {
        val result = mutableListOf<DayInfo>()
        val calendar = Calendar.getInstance().apply {
            set(Calendar.YEAR, year)
            set(Calendar.MONTH, month)
            set(Calendar.DAY_OF_MONTH, 1)
            set(Calendar.HOUR_OF_DAY, 12)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }

        // Find the first day of the week for this month (Monday = 0)
        val firstDayOfWeek = when (calendar.get(Calendar.DAY_OF_WEEK)) {
            Calendar.MONDAY -> 0
            Calendar.TUESDAY -> 1
            Calendar.WEDNESDAY -> 2
            Calendar.THURSDAY -> 3
            Calendar.FRIDAY -> 4
            Calendar.SATURDAY -> 5
            Calendar.SUNDAY -> 6
            else -> 0
        }

        // Add previous month's trailing days
        val prevMonthCalendar = calendar.clone() as Calendar
        prevMonthCalendar.add(Calendar.MONTH, -1)
        val prevMonthDays = prevMonthCalendar.getActualMaximum(Calendar.DAY_OF_MONTH)
        
        for (i in (prevMonthDays - firstDayOfWeek + 1)..prevMonthDays) {
            prevMonthCalendar.set(Calendar.DAY_OF_MONTH, i)
            result.add(
                DayInfo(
                    dayNumber = i,
                    dateMillis = prevMonthCalendar.timeInMillis,
                    hasTasks = taskDates.contains(formatDate(prevMonthCalendar)),
                    isCurrentMonth = false
                )
            )
        }

        // Add current month's days
        val daysInMonth = calendar.getActualMaximum(Calendar.DAY_OF_MONTH)
        for (day in 1..daysInMonth) {
            calendar.set(Calendar.DAY_OF_MONTH, day)
            result.add(
                DayInfo(
                    dayNumber = day,
                    dateMillis = calendar.timeInMillis,
                    hasTasks = taskDates.contains(formatDate(calendar)),
                    isCurrentMonth = true
                )
            )
        }

        // Add next month's leading days to fill the grid (up to 42 cells = 6 weeks)
        val nextMonthCalendar = calendar.clone() as Calendar
        nextMonthCalendar.add(Calendar.MONTH, 1)
        nextMonthCalendar.set(Calendar.DAY_OF_MONTH, 1)
        
        var day = 1
        while (result.size < 42) {
            nextMonthCalendar.set(Calendar.DAY_OF_MONTH, day)
            result.add(
                DayInfo(
                    dayNumber = day,
                    dateMillis = nextMonthCalendar.timeInMillis,
                    hasTasks = taskDates.contains(formatDate(nextMonthCalendar)),
                    isCurrentMonth = false
                )
            )
            day++
        }

        return result
    }

    private fun loadTaskDates(): Set<String> {
        return try {
            val cacheFile = File(context.filesDir, WIDGET_CACHE_FILE)
            if (!cacheFile.exists()) return emptySet()

            val json = cacheFile.readText()
            val tasksArray = JSONArray(json)
            val dates = mutableSetOf<String>()

            for (i in 0 until tasksArray.length()) {
                val task = tasksArray.getJSONObject(i)
                val dueDate = task.optLong("dueDate", 0)
                if (dueDate > 0) {
                    val calendar = Calendar.getInstance().apply { timeInMillis = dueDate }
                    dates.add(formatDate(calendar))
                }
            }
            dates
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load task dates", e)
            emptySet()
        }
    }

    private fun formatDate(calendar: Calendar): String {
        return String.format(
            "%04d-%02d-%02d",
            calendar.get(Calendar.YEAR),
            calendar.get(Calendar.MONTH) + 1,
            calendar.get(Calendar.DAY_OF_MONTH)
        )
    }

    private fun isSameDay(millis1: Long, millis2: Long): Boolean {
        val cal1 = Calendar.getInstance().apply { timeInMillis = millis1 }
        val cal2 = Calendar.getInstance().apply { timeInMillis = millis2 }
        return cal1.get(Calendar.YEAR) == cal2.get(Calendar.YEAR) &&
               cal1.get(Calendar.DAY_OF_YEAR) == cal2.get(Calendar.DAY_OF_YEAR)
    }

    override fun getViewAt(position: Int): RemoteViews {
        if (position < 0 || position >= days.size) {
            return RemoteViews(context.packageName, R.layout.item_calendar_day)
        }

        val day = days[position]
        val views = RemoteViews(context.packageName, R.layout.item_calendar_day)

        // Set day number
        views.setTextViewText(R.id.day_text, day.dayNumber.toString())

        // Check selection and today states
        val isSelected = isSameDay(day.dateMillis, selectedDateMillis)
        val isToday = isSameDay(day.dateMillis, todayMillis)

        // Get Material You accent color (or fallback)
        val accentColor = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            context.getColor(android.R.color.system_accent1_500)
        } else {
            Color.parseColor("#4285F4")
        }

        // Set text color and background based on state
        when {
            isSelected -> {
                views.setInt(R.id.day_text, "setBackgroundResource", R.drawable.calendar_day_selected)
                views.setTextColor(R.id.day_text, Color.WHITE)
            }
            isToday -> {
                views.setInt(R.id.day_text, "setBackgroundResource", 0)
                views.setTextColor(R.id.day_text, accentColor)
            }
            day.isCurrentMonth -> {
                views.setInt(R.id.day_text, "setBackgroundResource", 0)
                views.setTextColor(R.id.day_text, context.getColor(R.color.widget_text_primary))
            }
            else -> {
                views.setInt(R.id.day_text, "setBackgroundResource", 0)
                views.setTextColor(R.id.day_text, context.getColor(R.color.widget_text_secondary))
            }
        }

        // Show dot if tasks exist
        if (day.hasTasks && !isSelected) {
            views.setViewVisibility(R.id.dot_indicator, android.view.View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.dot_indicator, android.view.View.GONE)
        }

        // Set fill-in intent for date selection
        val fillInIntent = Intent().apply {
            putExtra(CalendarWidgetProvider.EXTRA_SELECTED_DATE, day.dateMillis)
        }
        views.setOnClickFillInIntent(R.id.day_container, fillInIntent)

        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getCount(): Int = days.size

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = false

    override fun onDestroy() {
        days = emptyList()
    }
}
