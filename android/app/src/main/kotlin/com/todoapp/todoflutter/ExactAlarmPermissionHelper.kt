package com.todoapp.todoflutter

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings

/**
 * Requests the exact alarm permission (Android 12+/API 31+) one time on first launch.
 * This launches the system settings panel similar to notification permission prompting.
 * The result is not directly delivered; the app should attempt to schedule alarms regardless
 * and rely on [AlarmManager.canScheduleExactAlarms] checks.
 */
object ExactAlarmPermissionHelper {
    private const val PREFS = "exact_alarm_permission"
    private const val KEY_PROMPTED = "prompted_v1"

    fun maybePrompt(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (am.canScheduleExactAlarms()) return // already allowed

        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (prefs.getBoolean(KEY_PROMPTED, false)) return // already prompted once

        prefs.edit().putBoolean(KEY_PROMPTED, true).apply()
        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
            data = Uri.parse("package:" + context.packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            context.startActivity(intent)
        } catch (_: Exception) {
            // Some OEMs may block the intent; ignore gracefully.
        }
    }
// (removed legacy content)
}
