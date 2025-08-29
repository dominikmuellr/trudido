package com.trudido.app

import android.os.Build
import android.os.Bundle
import android.util.Log
import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        var methodChannel: MethodChannel? = null
        private var processStartNano: Long = System.nanoTime() // baseline for cold start
        private var firstFrameLogged = false
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Mark Java/Kotlin onCreate reached; additional timing done once first frame renders.
        Log.d("StartupTrace", "onCreate elapsedMs=" + (System.nanoTime() - processStartNano)/1_000_000)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
    val notificationChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.trudido.app/notifications")
        methodChannel = notificationChannel

        // Unified permissions/system settings channel
        val permsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.perms")

        permsChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getSdkInt" -> result.success(Build.VERSION.SDK_INT)
                "canScheduleExactAlarms" -> result.success(PermissionsHelper.canScheduleExactAlarms(applicationContext))
                "openExactAlarmSettings" -> {
                    val ok = PermissionsHelper.openExactAlarmSettings(this)
                    result.success(ok)
                }
                "isIgnoringBatteryOptimizations" -> result.success(PermissionsHelper.isIgnoringBatteryOptimizations(applicationContext))
                "requestIgnoreBatteryOptimizations" -> result.success(PermissionsHelper.requestIgnoreBatteryOptimizations(this))
                "openBatteryOptimizationSettings" -> result.success(PermissionsHelper.openBatteryOptimizationSettings(this))
                "areNotificationsEnabled" -> result.success(PermissionsHelper.areNotificationsEnabled(applicationContext))
                "requestPostNotifications" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        try {
                            requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 2002)
                            result.success(true)
                        } catch (e: Exception) { result.error("ERR", e.message, null) }
                    } else result.success(true)
                }
                "openChannelSettings" -> {
                    val channelId = (call.arguments as? String) ?: "task_channel"
                    val ok = PermissionsHelper.openChannelSettings(this, channelId)
                    result.success(ok)
                }
                "openAppNotificationSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) { result.error("ERR", e.message, null) }
                }
                "consumeLateAlarmPrompt" -> {
                    val ok = LateAlarmTracker.consumePromptIfNeeded(applicationContext)
                    result.success(ok)
                }
                "scheduleDebugExactAlarm" -> {
                    try {
                        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        val triggerAt = System.currentTimeMillis() + 2 * 60 * 1000
                        val intent = Intent(this, MainActivity::class.java).apply { action = "com.trudido.app.DEBUG_ALARM" }
                        val pi = android.app.PendingIntent.getActivity(
                            this, 424242, intent,
                            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                        )
                        val info = AlarmManager.AlarmClockInfo(triggerAt, pi)
                        am.setAlarmClock(info, pi)
                        result.success(true)
                    } catch (e: Exception) { result.error("ERR", e.message, null) }
                }
                else -> result.notImplemented()
            }
        }

        notificationChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleNotification" -> {
                    val args = call.arguments as Map<*, *>
                    val taskId = args["taskId"] as String
                    val title = args["title"] as String
                    val body = args["body"] as String
                    val triggerTime = (args["triggerTime"] as Number).toLong()
                    val uniqueKey = args["uniqueKey"] as String? ?: taskId
                    NotificationScheduler.scheduleExact(applicationContext, taskId, title, body, triggerTime, uniqueKey.hashCode())
                    result.success(true)
                }
                "cancelScheduledNotification" -> {
                    val args = call.arguments as Map<*, *>
                    val key = args["taskId"] as String
                    NotificationScheduler.cancel(applicationContext, key)
                    result.success(true)
                }
                "getPendingActions" -> result.success(PendingActionStore.getPendingActions(applicationContext))
                "clearPendingActions" -> { PendingActionStore.clear(applicationContext); result.success(true) }
                "canScheduleExactAlarms" -> {
                    val can = if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) true else {
                        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        am.canScheduleExactAlarms()
                    }
                    result.success(can)
                }
                "openExactAlarmSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                                data = Uri.parse("package:" + packageName)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) { result.error("ERR", e.message, null) }
                    } else result.success(true)
                }
                "isIgnoringBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) result.success(true) else {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                }
                "openBatteryOptimizationSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:" + packageName)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            try { startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) } catch (_: Exception) {}
                            result.error("ERR", e.message, null)
                        }
                    } else result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Post-notification permission request is handled via UI flow; don't auto request here.
        NotificationScheduler.createChannel(applicationContext)

    // Step 2: Missed reminder catch-up (show any past-due within grace, drop stale, reschedule future not yet active if lost)
    try { MissedReminderCatchUp.run(applicationContext) } catch (t: Throwable) { Log.w("CatchUp", "failed: ${t.message}") }

        // First frame timing (using existing FlutterActivity window attach as fallback if renderer API unavailable)
        if (!firstFrameLogged) {
            window?.decorView?.post {
                if (!firstFrameLogged) {
                    firstFrameLogged = true
                    val totalMs = (System.nanoTime() - processStartNano)/1_000_000
                    Log.i("StartupTrace", "firstFrame (decorView post) totalMs=$totalMs")
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (isFinishing) methodChannel = null
    }
}
