package com.trudido.app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.Toast

/**
 * TaskFileHandler
 *
 * Provides intent builders and file I/O helpers for import/export using SAF.
 * All activity result handling is done in MainActivity.
 */
class TaskFileHandler(private val context: Context) {
    companion object {
        const val REQUEST_CODE_EXPORT = 9001
        const val REQUEST_CODE_IMPORT = 9002
        const val REQUEST_CODE_MARKDOWN_EXPORT = 9004
    }

    // Temporarily store export data passed from Flutter
    var pendingExportData: String? = null
    
    // Temporarily store markdown notes for SAF export
    var pendingMarkdownNotes: List<Map<String, String>>? = null

    // Sample JSON to export. Replace with your real data when integrating.
    val sampleJsonForExport: String = """
        {
          "version": 1,
          "exportedAt": "${System.currentTimeMillis()}",
          "tasks": [
            {
              "id": "1",
              "title": "Buy groceries",
              "completed": false,
              "priority": "medium",
              "dueDate": "2025-09-05",
              "category": "Personal"
            },
            {
              "id": "2",
              "title": "Prepare project report",
              "completed": true,
              "priority": "high",
              "dueDate": "2025-09-04",
              "category": "Work"
            }
          ]
        }
    """.trimIndent()

    fun buildExportIntent(): Intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
        addCategory(Intent.CATEGORY_OPENABLE)
        type = "application/json"
        putExtra(Intent.EXTRA_TITLE, "tasks_export.json")
        addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
    }

    fun buildImportIntent(): Intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
        addCategory(Intent.CATEGORY_OPENABLE)
        type = "application/json"
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
    }

    fun writeJsonToUri(uri: Uri, json: String? = null): Boolean {
        return try {
            context.contentResolver.openOutputStream(uri)?.use { output ->
                (json ?: sampleJsonForExport).toByteArray(Charsets.UTF_8).let { output.write(it) }
                output.flush()
            } ?: return false
            showToast("Export successful")
            true
        } catch (t: Throwable) {
            showToast("Export failed: ${t.message ?: "Unknown error"}")
            false
        }
    }

    fun readJsonFromUri(uri: Uri): String? {
        return try {
            context.contentResolver.openInputStream(uri)?.use { input ->
                input.bufferedReader(Charsets.UTF_8).readText()
            } ?: run {
                showToast("Import failed: Unable to open input stream")
                null
            }
        } catch (t: Throwable) {
            showToast("Import failed: ${t.message ?: "Unknown error"}")
            null
        }
    }

    fun showToast(message: String) {
        Toast.makeText(context.applicationContext, message, Toast.LENGTH_SHORT).show()
    }

    /**
     * Build intent to pick a directory for markdown export via SAF
     */
    fun buildMarkdownExportIntent(): Intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
    }

    /**
     * Write multiple markdown files to a directory URI selected via SAF
     * @param treeUri The directory URI from ACTION_OPEN_DOCUMENT_TREE
     * @param notes List of maps containing "filename" and "content" keys
     * @return Number of successfully exported notes
     */
    fun writeMarkdownFilesToUri(treeUri: Uri, notes: List<Map<String, String>>): Int {
        var exportedCount = 0
        try {
            val docUri = android.provider.DocumentsContract.buildDocumentUriUsingTree(
                treeUri,
                android.provider.DocumentsContract.getTreeDocumentId(treeUri)
            )
            
            for (note in notes) {
                val filename = note["filename"] ?: continue
                val content = note["content"] ?: continue
                
                try {
                    // Create a new document in the directory
                    val newDocUri = android.provider.DocumentsContract.createDocument(
                        context.contentResolver,
                        docUri,
                        "text/markdown",
                        filename
                    )
                    
                    if (newDocUri != null) {
                        context.contentResolver.openOutputStream(newDocUri)?.use { output ->
                            output.write(content.toByteArray(Charsets.UTF_8))
                            output.flush()
                        }
                        exportedCount++
                    }
                } catch (e: Exception) {
                    android.util.Log.e("TaskFileHandler", "Failed to export note $filename: ${e.message}")
                }
            }
            
            if (exportedCount > 0) {
                showToast("Exported $exportedCount notes as markdown")
            } else {
                showToast("Failed to export notes")
            }
        } catch (t: Throwable) {
            android.util.Log.e("TaskFileHandler", "Markdown export failed: ${t.message}")
            showToast("Export failed: ${t.message ?: "Unknown error"}")
        }
        return exportedCount
    }
}
