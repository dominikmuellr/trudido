package com.trudido.app

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract
import android.util.Log
import androidx.work.*
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
                        workList.any {
                            it.state == WorkInfo.State.ENQUEUED ||
                            it.state == WorkInfo.State.RUNNING
                        }
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

            val backupData = getAppDataForBackup()
            val fileName = generateBackupFileName()

            // Always write to app folder (required for in-app listing/import)
            val appFile = createBackupFileInAppFolder(fileName)
            writeBackupData(appFile, backupData)
            cleanupOldBackups()

            // Also write to user-selected custom folder via SAF if configured
            val prefs = context.getSharedPreferences("backup_prefs", Context.MODE_PRIVATE)
            val customFolderUri = prefs.getString("custom_backup_folder", null)
            if (customFolderUri != null) {
                writeBackupToCustomFolder(customFolderUri, fileName, backupData)
            }

            Log.d(TAG, "Automatic backup completed successfully: ${appFile.name}")
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
     * Gets app data for backup by reading the cached backup data
     * Flutter caches the backup data to a file when the app is active
     */
    private fun getAppDataForBackup(): String {
        // Read from cached backup data file
        val cacheFile = File(context.filesDir, "auto_backup_cache.json")
        
        if (cacheFile.exists()) {
            try {
                val cachedData = cacheFile.readText(Charsets.UTF_8)
                if (cachedData.isNotEmpty()) {
                    Log.d(TAG, "Using cached backup data (${cachedData.length} bytes)")
                    return cachedData
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error reading cached backup data", e)
            }
        }
        
        // No cached data available - this means the app hasn't been opened recently
        // Return empty backup with error indicator
        Log.w(TAG, "No cached backup data available - app may not have been opened recently")
        val timestamp = System.currentTimeMillis()
        return """
        {
          "version": "1.3.2",
          "backup_type": "automatic",
          "exported_at": "${Date(timestamp)}",
          "timestamp": $timestamp,
          "error": "no_cached_data",
          "message": "No backup data available. Please open the app to refresh backup cache.",
          "todos": [],
          "categories": [],
          "notes": [],
          "noteFolders": []
        }
        """.trimIndent()
    }

    /**
     * Generates a timestamped backup filename.
     */
    private fun generateBackupFileName(): String {
        val dateFormat = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.getDefault())
        return "auto_backup_${dateFormat.format(Date())}.json"
    }

    /**
     * Creates a backup File in the app's private external storage.
     * This is always used so that in-app listing and import keep working.
     */
    private fun createBackupFileInAppFolder(fileName: String): File {
        val backupDir = File(context.getExternalFilesDir(null), BACKUP_FOLDER)
        if (!backupDir.exists()) {
            backupDir.mkdirs()
        }
        return File(backupDir, fileName)
    }

    /**
     * Writes the backup data to the user-selected SAF folder.
     * Uses persisted URI permissions so this works from a background Worker.
     * Failures are logged but do not affect the primary app-folder backup.
     */
    private fun writeBackupToCustomFolder(folderUri: String, fileName: String, data: String) {
        try {
            val treeUri = Uri.parse(folderUri)
            val docId = DocumentsContract.getTreeDocumentId(treeUri)
            val docUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, docId)

            val newDocUri = DocumentsContract.createDocument(
                context.contentResolver,
                docUri,
                "application/json",
                fileName
            )

            if (newDocUri != null) {
                context.contentResolver.openOutputStream(newDocUri)?.use { out ->
                    out.write(data.toByteArray(Charsets.UTF_8))
                    out.flush()
                }
                Log.d(TAG, "Backup also written to custom folder: $newDocUri")
            } else {
                Log.w(TAG, "DocumentsContract.createDocument returned null for custom folder")
            }
        } catch (e: Exception) {
            // Non-fatal: primary backup to app folder already succeeded
            Log.e(TAG, "Failed to write backup to custom folder (URI: $folderUri): ${e.message}")
        }
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
