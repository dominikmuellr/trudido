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
import java.text.SimpleDateFormat
import java.util.*

class CalendarWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "CalendarWidgetProvider"
        const val ACTION_PREVIOUS_MONTH = "com.trudido.app.ACTION_PREVIOUS_MONTH"
        const val ACTION_NEXT_MONTH = "com.trudido.app.ACTION_NEXT_MONTH"
        const val ACTION_SELECT_DATE = "com.trudido.app.ACTION_SELECT_DATE"
        const val ACTION_ADD_TASK_CALENDAR = "com.trudido.app.ACTION_ADD_TASK_CALENDAR"
        const val EXTRA_SELECTED_DATE = "extra_selected_date"
        private const val PREFS_NAME = "com.trudido.app.calendar_widget_prefs"

        fun triggerUpdate(context: Context) {
            val intent = Intent(context, CalendarWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            }
            val widgetManager = AppWidgetManager.getInstance(context)
            val ids = widgetManager.getAppWidgetIds(
                ComponentName(context, CalendarWidgetProvider::class.java)
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
            ACTION_PREVIOUS_MONTH -> {
                val appWidgetId = intent.getIntExtra(
                    AppWidgetManager.EXTRA_APPWIDGET_ID,
                    AppWidgetManager.INVALID_APPWIDGET_ID
                )
                if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                    navigateMonth(context, appWidgetId, -1)
                }
            }
            ACTION_NEXT_MONTH -> {
                val appWidgetId = intent.getIntExtra(
                    AppWidgetManager.EXTRA_APPWIDGET_ID,
                    AppWidgetManager.INVALID_APPWIDGET_ID
                )
                if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                    navigateMonth(context, appWidgetId, 1)
                }
            }
            ACTION_SELECT_DATE -> {
                val appWidgetId = intent.getIntExtra(
                    AppWidgetManager.EXTRA_APPWIDGET_ID,
                    AppWidgetManager.INVALID_APPWIDGET_ID
                )
                val selectedDate = intent.getLongExtra(EXTRA_SELECTED_DATE, 0L)
                if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID && selectedDate > 0) {
                    selectDate(context, appWidgetId, selectedDate)
                }
            }
            ACTION_ADD_TASK_CALENDAR -> {
                Log.d(TAG, "Add task from calendar widget")
                val selectedDate = intent.getLongExtra(EXTRA_SELECTED_DATE, 0L)
                launchAppForNewTask(context, selectedDate)
            }
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.calendar_widget)
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        // Get current displayed month/year (default to current date)
        val calendar = Calendar.getInstance()
        val currentMonth = prefs.getInt("widget_${appWidgetId}_month", calendar.get(Calendar.MONTH))
        val currentYear = prefs.getInt("widget_${appWidgetId}_year", calendar.get(Calendar.YEAR))
        
        // Get selected date (default to today)
        val selectedDate = prefs.getLong(
            "widget_${appWidgetId}_selected_date",
            calendar.timeInMillis
        )

        // Set month/year text
        calendar.set(Calendar.YEAR, currentYear)
        calendar.set(Calendar.MONTH, currentMonth)
        val monthYearFormat = SimpleDateFormat("MMMM yyyy", Locale.getDefault())
        views.setTextViewText(R.id.month_year_text, monthYearFormat.format(calendar.time))

        // Set selected date text
        val selectedCalendar = Calendar.getInstance().apply { timeInMillis = selectedDate }
        val dateFormat = SimpleDateFormat("EEEE, MMM d", Locale.getDefault())
        val isToday = isSameDay(selectedCalendar, Calendar.getInstance())
        views.setTextViewText(
            R.id.selected_date_text,
            if (isToday) "Today" else dateFormat.format(selectedCalendar.time)
        )

        // Set up previous month button
        val prevIntent = Intent(context, CalendarWidgetProvider::class.java).apply {
            action = ACTION_PREVIOUS_MONTH
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        views.setOnClickPendingIntent(
            R.id.btn_previous_month,
            PendingIntent.getBroadcast(
                context,
                appWidgetId * 1000 + 1,
                prevIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        )

        // Set up next month button
        val nextIntent = Intent(context, CalendarWidgetProvider::class.java).apply {
            action = ACTION_NEXT_MONTH
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        views.setOnClickPendingIntent(
            R.id.btn_next_month,
            PendingIntent.getBroadcast(
                context,
                appWidgetId * 1000 + 2,
                nextIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        )

        // Set up add task button
        val addIntent = Intent(context, CalendarWidgetProvider::class.java).apply {
            action = ACTION_ADD_TASK_CALENDAR
            putExtra(EXTRA_SELECTED_DATE, selectedDate)
        }
        views.setOnClickPendingIntent(
            R.id.btn_add_task_calendar,
            PendingIntent.getBroadcast(
                context,
                appWidgetId * 1000 + 4,
                addIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        )

        // Set up calendar grid
        val gridIntent = Intent(context, CalendarGridService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            data = Uri.parse("calendar_grid://$appWidgetId")
        }
        views.setRemoteAdapter(R.id.calendar_grid, gridIntent)

        // Set up pending intent template for date selection
        val selectIntent = Intent(context, CalendarWidgetProvider::class.java).apply {
            action = ACTION_SELECT_DATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        views.setPendingIntentTemplate(
            R.id.calendar_grid,
            PendingIntent.getBroadcast(
                context,
                appWidgetId * 1000 + 3,
                selectIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
        )

        // Set up task list
        val taskIntent = Intent(context, CalendarTaskService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            data = Uri.parse("calendar_tasks://$appWidgetId/${System.currentTimeMillis()}")
        }
        views.setRemoteAdapter(R.id.task_list, taskIntent)
        views.setEmptyView(R.id.task_list, R.id.empty_view)

        appWidgetManager.updateAppWidget(appWidgetId, views)
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.calendar_grid)
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.task_list)
    }

    private fun navigateMonth(context: Context, appWidgetId: Int, offset: Int) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val calendar = Calendar.getInstance()
        
        val currentMonth = prefs.getInt("widget_${appWidgetId}_month", calendar.get(Calendar.MONTH))
        val currentYear = prefs.getInt("widget_${appWidgetId}_year", calendar.get(Calendar.YEAR))
        
        calendar.set(Calendar.YEAR, currentYear)
        calendar.set(Calendar.MONTH, currentMonth)
        calendar.add(Calendar.MONTH, offset)

        prefs.edit()
            .putInt("widget_${appWidgetId}_month", calendar.get(Calendar.MONTH))
            .putInt("widget_${appWidgetId}_year", calendar.get(Calendar.YEAR))
            .apply()

        val appWidgetManager = AppWidgetManager.getInstance(context)
        updateAppWidget(context, appWidgetManager, appWidgetId)
    }

    private fun selectDate(context: Context, appWidgetId: Int, dateMillis: Long) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putLong("widget_${appWidgetId}_selected_date", dateMillis)
            .apply()

        val appWidgetManager = AppWidgetManager.getInstance(context)
        updateAppWidget(context, appWidgetManager, appWidgetId)
    }

    private fun isSameDay(cal1: Calendar, cal2: Calendar): Boolean {
        return cal1.get(Calendar.YEAR) == cal2.get(Calendar.YEAR) &&
               cal1.get(Calendar.DAY_OF_YEAR) == cal2.get(Calendar.DAY_OF_YEAR)
    }

    override fun onEnabled(context: Context) {
        Log.d(TAG, "Calendar widget enabled")
    }


    private fun launchAppForNewTask(context: Context, selectedDate: Long) {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("action", "create_task")
            if (selectedDate > 0) {
                putExtra("date", selectedDate)
            }
        }
        context.startActivity(intent)
    }
    override fun onDisabled(context: Context) {
        Log.d(TAG, "Calendar widget disabled")
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val editor = prefs.edit()
        for (id in appWidgetIds) {
            editor.remove("widget_${id}_month")
            editor.remove("widget_${id}_year")
            editor.remove("widget_${id}_selected_date")
        }
        editor.apply()
    }
}
