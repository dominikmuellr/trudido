package com.trudido.app

import android.content.Context
import android.util.Log

/**
 * Stores & reads the persistent-notifications preference in a dedicated
 * native SharedPreferences file (not Flutter's DataStore).
 * Written from Dart via MethodChannel, read by native receivers.
 */
object PersistentNotificationPref {
    private const val PREFS_NAME = "trudido_notification_prefs"
    private const val KEY = "persistent_notifications"

    fun isEnabled(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val result = prefs.getBoolean(KEY, false)
        Log.d("PersistentNotifPref", "isEnabled=$result")
        return result
    }

    fun setEnabled(context: Context, enabled: Boolean) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(KEY, enabled).apply()
        Log.d("PersistentNotifPref", "setEnabled=$enabled")
    }
}
