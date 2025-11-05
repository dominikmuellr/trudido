package com.trudido.app

import android.os.Build
import android.os.Bundle
import android.util.Log
import android.app.AlarmManager
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.os.PowerManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private lateinit var fileHandler: TaskFileHandler
    companion object {
        var methodChannel: MethodChannel? = null
        var filesChannel: MethodChannel? = null
        private const val REQUEST_CODE_CHOOSE_BACKUP_FOLDER = 9003
        private var processStartNano: Long = System.nanoTime() // baseline for cold start
        private var firstFrameLogged = false
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        fileHandler = TaskFileHandler(this)
        // Mark Java/Kotlin onCreate reached; additional timing done once first frame renders.
        Log.d("StartupTrace", "onCreate elapsedMs=" + (System.nanoTime() - processStartNano)/1_000_000)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
    val notificationChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.trudido.app/notifications")
        methodChannel = notificationChannel

        // Text scale channel for widget font size updates
        val textScaleChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "trudido/text_scale")
        textScaleChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidgetTextSize" -> {
                    val scale = (call.argument<Double>("scale") ?: 1.0).toFloat()
                    val ignoreSystem = call.argument<Boolean>("ignoreSystem") ?: false
                    // Store preferences for future widget updates
                    getSharedPreferences("flutter", MODE_PRIVATE)
                        .edit()
                        .putFloat("flutter.textScale", scale)
                        .putBoolean("flutter.ignoreSystemTextScale", ignoreSystem)
                        .apply()
                    // Widget update would go here when widget is implemented
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Unified permissions/system settings channel
        val permsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.perms")

        // Files channel for import/export via SAF
        val files = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.files").also { filesChannel = it }
        files.setMethodCallHandler { call, result ->
            when (call.method) {
                "startExport" -> {
                    val jsonData = call.arguments as String?
                    val intent = fileHandler.buildExportIntent()
                    fileHandler.pendingExportData = jsonData
                    startActivityForResult(intent, TaskFileHandler.REQUEST_CODE_EXPORT)
                    result.success(true)
                }
                "startImport" -> {
                    val intent = fileHandler.buildImportIntent()
                    startActivityForResult(intent, TaskFileHandler.REQUEST_CODE_IMPORT)
                    result.success(true)
                }
                "scheduleAutoBackup" -> {
                    val intervalHours = (call.arguments as? Map<String, Any>)?.get("intervalHours") as? Int ?: 24
                    val requiresCharging = (call.arguments as? Map<String, Any>)?.get("requiresCharging") as? Boolean ?: false
                    
                    AutoBackupWorker.schedulePeriodicBackup(
                        this,
                        intervalHours.toLong(),
                        requiresCharging,
                        requiresBatteryNotLow = true
                    )
                    result.success(true)
                }
                "cancelAutoBackup" -> {
                    AutoBackupWorker.cancelAutoBackup(this)
                    result.success(true)
                }
                "isAutoBackupScheduled" -> {
                    AutoBackupWorker.isAutoBackupScheduled(this) { isScheduled ->
                        result.success(isScheduled)
                    }
                }
                "openBackupFolder" -> {
                    val success = openBackupFolderInFileManager()
                    result.success(success)
                }
                "listAutoBackups" -> {
                    val backups = listAutoBackupFiles()
                    result.success(backups)
                }
                "importAutoBackup" -> {
                    val filename = call.arguments as? String
                    if (filename != null) {
                        val json = readAutoBackupFile(filename)
                        if (json != null) {
                            filesChannel?.invokeMethod("onImport", json)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "chooseBackupFolder" -> {
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                        addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                    }
                    startActivityForResult(intent, REQUEST_CODE_CHOOSE_BACKUP_FOLDER)
                    result.success(true)
                }
                "getCustomBackupFolder" -> {
                    val customFolder = getSharedPreferences("backup_prefs", MODE_PRIVATE)
                        .getString("custom_backup_folder", null)
                    result.success(customFolder)
                }
                "clearCustomBackupFolder" -> {
                    getSharedPreferences("backup_prefs", MODE_PRIVATE)
                        .edit()
                        .remove("custom_backup_folder")
                        .apply()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

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

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (resultCode != Activity.RESULT_OK || data == null) return

        val uri = data.data ?: return
        when (requestCode) {
            TaskFileHandler.REQUEST_CODE_EXPORT -> {
                val exportData = fileHandler.pendingExportData
                fileHandler.writeJsonToUri(uri, exportData)
                fileHandler.pendingExportData = null
            }
            TaskFileHandler.REQUEST_CODE_IMPORT -> {
                val json = fileHandler.readJsonFromUri(uri)
                if (json != null) {
                    filesChannel?.invokeMethod("onImport", json)
                }
            }
            REQUEST_CODE_CHOOSE_BACKUP_FOLDER -> {
                // Save the selected folder URI for custom backup location
                val takeFlags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                contentResolver.takePersistableUriPermission(uri, takeFlags)
                
                // Store the URI in preferences
                getSharedPreferences("backup_prefs", MODE_PRIVATE)
                    .edit()
                    .putString("custom_backup_folder", uri.toString())
                    .apply()
                
                // Notify Flutter that folder was selected
                filesChannel?.invokeMethod("onBackupFolderSelected", uri.toString())
            }
        }
    }

    /**
     * Opens the auto backup folder in the system file manager
     */
    private fun openBackupFolderInFileManager(): Boolean {
        return try {
            val backupDir = java.io.File(getExternalFilesDir(null), "AutoBackups")
            
            // Ensure the directory exists
            if (!backupDir.exists()) {
                backupDir.mkdirs()
            }
            
            // Method 1: Try to open the specific folder using file URI
            try {
                val uri = android.net.Uri.fromFile(backupDir)
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "resource/folder")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                startActivity(intent)
                return true
            } catch (e: Exception) {
                Log.d("MainActivity", "Method 1 failed: ${e.message}")
            }
            
            // Method 2: Try using ACTION_GET_CONTENT to open file picker at location
            try {
                val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                    type = "*/*"
                    addCategory(Intent.CATEGORY_OPENABLE)
                    putExtra("android.content.extra.SHOW_ADVANCED", true)
                    putExtra("android.content.extra.FANCY", true)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                return true
            } catch (e: Exception) {
                Log.d("MainActivity", "Method 2 failed: ${e.message}")
            }
            
            // Method 3: Try to open parent directory with FILES app
            try {
                val filesDir = getExternalFilesDir(null)
                val uri = android.net.Uri.fromFile(filesDir)
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "resource/folder")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                return true
            } catch (e: Exception) {
                Log.d("MainActivity", "Method 3 failed: ${e.message}")
            }
            
            // Method 4: Generic file manager intent
            try {
                val intent = Intent("android.intent.action.MAIN").apply {
                    addCategory("android.intent.category.APP_FILES")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                return true
            } catch (e: Exception) {
                Log.d("MainActivity", "Method 4 failed: ${e.message}")
            }
            
            return false
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to open backup folder", e)
            return false
        }
    }

    /**
     * Lists all available auto backup files with their metadata
     */
    private fun listAutoBackupFiles(): List<Map<String, Any>> {
        return try {
            val backupDir = java.io.File(getExternalFilesDir(null), "AutoBackups")
            if (!backupDir.exists()) {
                return emptyList()
            }

            val backupFiles = backupDir.listFiles { file ->
                file.name.startsWith("auto_backup_") && file.name.endsWith(".json")
            }?.sortedByDescending { it.lastModified() } ?: emptyList()

            backupFiles.map { file ->
                mapOf(
                    "filename" to file.name,
                    "size" to file.length(),
                    "lastModified" to file.lastModified(),
                    "path" to file.absolutePath
                )
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to list auto backup files", e)
            emptyList()
        }
    }

    /**
     * Reads the content of a specific auto backup file
     */
    private fun readAutoBackupFile(filename: String): String? {
        return try {
            val backupDir = java.io.File(getExternalFilesDir(null), "AutoBackups")
            val backupFile = java.io.File(backupDir, filename)
            
            if (!backupFile.exists() || !backupFile.canRead()) {
                Log.e("MainActivity", "Backup file not found or not readable: $filename")
                return null
            }

            backupFile.readText(Charsets.UTF_8)
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to read backup file: $filename", e)
            null
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (isFinishing) {
            methodChannel = null
            filesChannel = null
        }
    }
}
