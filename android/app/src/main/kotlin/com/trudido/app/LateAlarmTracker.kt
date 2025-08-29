package com.trudido.app

import android.content.Context
import android.util.Log

/** Tracks late alarm firings to decide when to nudge user about battery optimization. */
object LateAlarmTracker {
    private const val PREFS = "late_alarm_tracker"
    private const val KEY_WINDOW_START = "window_start"
    private const val KEY_LATE_COUNT = "late_count"
    private const val KEY_PROMPT_NEEDED = "prompt_needed"
    private const val KEY_LAST_PROMPT = "last_prompt"

    private const val WINDOW_MS = 6 * 60 * 60 * 1000L // 6h rolling window
    private const val LATE_THRESHOLD_MS = 2 * 60 * 1000L // consider >2 min late
    private const val LATE_COUNT_THRESHOLD = 3 // within window
    private const val PROMPT_COOLDOWN_MS = 48 * 60 * 60 * 1000L // 48h

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun recordFire(ctx: Context, scheduledAt: Long, firedAt: Long = System.currentTimeMillis()) {
        if (scheduledAt <= 0L) return
        val lateness = firedAt - scheduledAt
        if (lateness < LATE_THRESHOLD_MS) return
        val p = prefs(ctx)
        val now = firedAt
        var windowStart = p.getLong(KEY_WINDOW_START, 0L)
        var count = p.getInt(KEY_LATE_COUNT, 0)
        if (windowStart == 0L || now - windowStart > WINDOW_MS) {
            windowStart = now
            count = 0
        }
        count += 1
        var promptNeeded = p.getBoolean(KEY_PROMPT_NEEDED, false)
        val lastPrompt = p.getLong(KEY_LAST_PROMPT, 0L)
        if (!promptNeeded && count >= LATE_COUNT_THRESHOLD && (lastPrompt == 0L || now - lastPrompt > PROMPT_COOLDOWN_MS)) {
            promptNeeded = true
            Log.i("LateAlarmTracker", "Triggering promptNeeded count=$count latenessMs=$lateness")
        }
        p.edit()
            .putLong(KEY_WINDOW_START, windowStart)
            .putInt(KEY_LATE_COUNT, count)
            .putBoolean(KEY_PROMPT_NEEDED, promptNeeded)
            .apply()
    }

    /** Returns true if a prompt should be shown now and consumes the flag. */
    fun consumePromptIfNeeded(ctx: Context): Boolean {
        val p = prefs(ctx)
        val needed = p.getBoolean(KEY_PROMPT_NEEDED, false)
        if (!needed) return false
        p.edit()
            .putBoolean(KEY_PROMPT_NEEDED, false)
            .putLong(KEY_LAST_PROMPT, System.currentTimeMillis())
            .apply()
        return true
    }
}