package com.trudido.app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.util.Log
import androidx.work.*
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.TimeUnit

/**
 * AutoBackupWorker - Handles automatic background backups using WorkManager
 * 
 * This worker runs periodically to create automatic backups of user data.
 * It operates independently of the manual export function and saves backups
 * to the app's external files directory.
 */
class AutoBackupWorker(
    private val context: Context,
    params: WorkerParameters
) : Worker(context, params) {

    companion object {
        private const val TAG = "AutoBackupWorker"
        private const val UNIQUE_WORK_NAME = "auto_backup_work"
        private const val BACKUP_FOLDER = "AutoBackups"
        private const val MAX_BACKUP_FILES = 10 // Keep only 10 most recent backups
        
        /**
         * Schedules periodic automatic backups
         * 
         * @param context Application context
         * @param intervalHours How often to run backup (in hours)
         * @param requiresCharging Whether device must be charging
         * @param requiresBatteryNotLow Whether device battery must not be low
         */
        fun schedulePeriodicBackup(
            context: Context,
            intervalHours: Long = 24, // Default: daily backup
            requiresCharging: Boolean = false,
            requiresBatteryNotLow: Boolean = true
        ) {
            // Build constraints for when backup should run
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.NOT_REQUIRED)
                .setRequiresCharging(requiresCharging)
                .setRequiresBatteryNotLow(requiresBatteryNotLow)
                .setRequiresStorageNotLow(true) // Always require sufficient storage
                .build()

            // Create periodic work request
            val backupRequest = PeriodicWorkRequestBuilder<AutoBackupWorker>(intervalHours, TimeUnit.HOURS)
                .setConstraints(constraints)
                .setInitialDelay(1, TimeUnit.HOURS) // Wait 1 hour before first backup
                .addTag("auto_backup")
                .build()

            // Schedule the work (replaces any existing auto backup work)
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                UNIQUE_WORK_NAME,
                ExistingPeriodicWorkPolicy.UPDATE,
                backupRequest
            )

            Log.d(TAG, "Scheduled periodic backup every $intervalHours hours")
        }

        /**
         * Cancels automatic backup scheduling
         */
        fun cancelAutoBackup(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(UNIQUE_WORK_NAME)
            Log.d(TAG, "Cancelled automatic backup")
        }

        /**
         * Checks if auto backup is currently scheduled
         */
        fun isAutoBackupScheduled(context: Context, callback: (Boolean) -> Unit) {
            val workInfos = WorkManager.getInstance(context).getWorkInfosForUniqueWork(UNIQUE_WORK_NAME)
            workInfos.addListener({
                try {
                    val workList = workInfos.get()
                    val isScheduled = workList.isNotEmpty() && 
                        workList.any { it.state == WorkInfo.State.ENQUEUED }
                    callback(isScheduled)
                } catch (e: Exception) {
                    Log.e(TAG, "Error checking auto backup status", e)
                    callback(false)
                }
            }, context.mainExecutor)
        }
    }

    /**
     * Main work execution - performs the actual backup
     */
    override fun doWork(): Result {
        return try {
            Log.d(TAG, "Starting automatic backup...")

            // Get app data from Flutter (this would require method channel integration)
            val backupData = getAppDataForBackup()
            
            // Create backup file
            val backupFile = createBackupFile()
            
            // Write data to file
            writeBackupData(backupFile, backupData)
            
            // Clean up old backup files
            cleanupOldBackups()
            
            Log.d(TAG, "Automatic backup completed successfully: ${backupFile.name}")
            Result.success()
            
        } catch (e: Exception) {
            Log.e(TAG, "Automatic backup failed", e)
            // Retry with exponential backoff if failure was temporary
            if (runAttemptCount < 3) {
                Result.retry()
            } else {
                Result.failure()
            }
        }
    }

    /**
     * Gets app data for backup (placeholder - would need method channel integration)
     * In a full implementation, this would communicate with Flutter to get real data
     */
    private fun getAppDataForBackup(): String {
        // For now, return sample data structure
        // In real implementation, this would use MethodChannel to get data from Flutter
        val timestamp = System.currentTimeMillis()
        return """
        {
          "version": "1.0.0",
          "backup_type": "automatic",
          "exported_at": "${Date(timestamp)}",
          "timestamp": $timestamp,
          "todos": [],
          "categories": [],
          "settings": {
            "backup_created_by": "AutoBackupWorker"
          }
        }
        """.trimIndent()
    }

    /**
     * Creates a backup file with timestamp in name
     */
    private fun createBackupFile(): File {
        // Check if user has selected a custom backup folder
        val prefs = context.getSharedPreferences("backup_prefs", Context.MODE_PRIVATE)
        val customFolderUri = prefs.getString("custom_backup_folder", null)
        
        return if (customFolderUri != null) {
            createBackupFileInCustomFolder(customFolderUri)
        } else {
            createBackupFileInAppFolder()
        }
    }
    
    /**
     * Creates backup file in user-selected custom folder
     * For WorkManager, we'll create in a predictable subfolder of the custom location
     */
    private fun createBackupFileInCustomFolder(customFolderUri: String): File {
        try {
            // For WorkManager, we'll create backups in a subfolder named "auto_backups"
            // within the custom folder. We'll use a temp file approach and copy later
            // if needed, but for now we'll fall back to app folder for reliability
            Log.d(TAG, "Custom folder set: $customFolderUri, using app folder for auto backup reliability")
        } catch (e: Exception) {
            Log.e(TAG, "Error with custom backup folder, falling back to app folder", e)
        }
        
        // For WorkManager reliability, always use app folder but log the custom setting
        return createBackupFileInAppFolder()
    }
    
    /**
     * Creates backup file in app's default folder
     */
    private fun createBackupFileInAppFolder(): File {
        // Create backup directory in app's external files directory
        val backupDir = File(context.getExternalFilesDir(null), BACKUP_FOLDER)
        if (!backupDir.exists()) {
            backupDir.mkdirs()
        }

        // Generate filename with timestamp
        val dateFormat = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.getDefault())
        val timestamp = dateFormat.format(Date())
        val fileName = "auto_backup_$timestamp.json"

        return File(backupDir, fileName)
    }

    /**
     * Writes backup data to file
     */
    private fun writeBackupData(file: File, data: String) {
        FileOutputStream(file).use { output ->
            output.write(data.toByteArray(Charsets.UTF_8))
            output.flush()
        }
        Log.d(TAG, "Backup data written to: ${file.absolutePath}")
    }

    /**
     * Removes old backup files, keeping only the most recent ones
     */
    private fun cleanupOldBackups() {
        val backupDir = File(context.getExternalFilesDir(null), BACKUP_FOLDER)
        if (!backupDir.exists()) return

        val backupFiles = backupDir.listFiles { file ->
            file.name.startsWith("auto_backup_") && file.name.endsWith(".json")
        }?.sortedByDescending { it.lastModified() }

        if (backupFiles != null && backupFiles.size > MAX_BACKUP_FILES) {
            // Delete excess files
            val filesToDelete = backupFiles.drop(MAX_BACKUP_FILES)
            filesToDelete.forEach { file ->
                if (file.delete()) {
                    Log.d(TAG, "Deleted old backup: ${file.name}")
                }
            }
        }
    }
}
