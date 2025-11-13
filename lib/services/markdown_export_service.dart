import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../models/note.dart';
import '../services/storage_service.dart';

/// Service for exporting and importing notes as individual markdown files
class MarkdownExportService {
  static const String _notesSubfolder = 'exported_notes';

  /// Export all notes as individual .md files to a user-selected directory
  static Future<bool> exportNotesToFiles() async {
    try {
      debugPrint('[MarkdownExport] Starting notes export...');

      // Get all notes
      await StorageService.waitNotesReady();
      final notes = StorageService.getAllNotes();

      if (notes.isEmpty) {
        debugPrint('[MarkdownExport] No notes to export');
        return false;
      }

      // Let user choose directory
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      // Create notes subdirectory
      final notesDir = Directory('$selectedDirectory/$_notesSubfolder');
      if (!await notesDir.exists()) {
        await notesDir.create(recursive: true);
      }

      // Export each note as a .md file
      int exportedCount = 0;
      for (final note in notes) {
        final success = await _exportSingleNote(note, notesDir.path);
        if (success) exportedCount++;
      }

      debugPrint(
        '[MarkdownExport] Exported $exportedCount/${notes.length} notes to ${notesDir.path}',
      );
      return exportedCount > 0;
    } catch (e, stackTrace) {
      debugPrint('[MarkdownExport] Export failed: $e');
      debugPrint('[MarkdownExport] Stack trace: $stackTrace');
      return false;
    }
  }

  /// Export a single note to a markdown file
  static Future<bool> _exportSingleNote(Note note, String directoryPath) async {
    try {
      // Generate safe filename from note title
      final fileName = _generateSafeFileName(note);
      final filePath = '$directoryPath/$fileName.md';

      // Create markdown content with frontmatter
      final markdownContent = _generateMarkdownContent(note);

      // Write to file
      final file = File(filePath);
      await file.writeAsString(markdownContent);

      debugPrint(
        '[MarkdownExport] Exported note: ${note.title} -> $fileName.md',
      );
      return true;
    } catch (e) {
      debugPrint('[MarkdownExport] Failed to export note "${note.title}": $e');
      return false;
    }
  }

  /// Generate a safe filename from note title and date
  static String _generateSafeFileName(Note note) {
    // Use creation date for consistent naming
    final datePrefix = note.createdAt.toIso8601String().substring(
      0,
      10,
    ); // YYYY-MM-DD

    // Clean title for filename
    String cleanTitle = note.title.isNotEmpty ? note.title : 'untitled';
    cleanTitle = cleanTitle
        .replaceAll(RegExp(r'[^\w\s-]'), '') // Remove special chars
        .replaceAll(RegExp(r'\s+'), '-') // Replace spaces with hyphens
        .toLowerCase()
        .trim();

    // Limit length
    if (cleanTitle.length > 50) {
      cleanTitle = cleanTitle.substring(0, 50);
    }

    return '$datePrefix-$cleanTitle';
  }

  /// Generate markdown content with YAML frontmatter
  static String _generateMarkdownContent(Note note) {
    final buffer = StringBuffer();

    // YAML frontmatter for metadata
    buffer.writeln('---');
    buffer.writeln('id: "${note.id}"');
    buffer.writeln('title: "${note.title.replaceAll('"', '\\"')}"');
    buffer.writeln('created: ${note.createdAt.toIso8601String()}');
    buffer.writeln('modified: ${note.updatedAt.toIso8601String()}');
    buffer.writeln('exported_from: "Trudido Todo App"');
    buffer.writeln('export_date: ${DateTime.now().toIso8601String()}');
    buffer.writeln('---');
    buffer.writeln();

    // Note title as H1 (if different from title in frontmatter)
    if (note.title.isNotEmpty) {
      buffer.writeln('# ${note.title}');
      buffer.writeln();
    }

    // Note content
    buffer.writeln(note.content);

    return buffer.toString();
  }

  /// Import markdown files from a user-selected directory or individual files
  static Future<ImportResult> importNotesFromFiles() async {
    try {
      debugPrint('[MarkdownImport] Starting notes import...');

      // Different approach for mobile vs desktop
      if (Platform.isAndroid || Platform.isIOS) {
        return _importFromMobileFilePicker();
      } else {
        return _importFromDesktopDirectory();
      }
    } catch (e, stackTrace) {
      debugPrint('[MarkdownImport] Import failed: $e');
      debugPrint('[MarkdownImport] Stack trace: $stackTrace');
      return ImportResult(success: false, message: 'Import failed: $e');
    }
  }

  /// Mobile-friendly import: pick individual .md or .json files
  static Future<ImportResult> _importFromMobileFilePicker() async {
    try {
      // Pick multiple .md or .json files
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['md', 'json'],
        allowMultiple: true,
        dialogTitle: 'Select Markdown or JSON Files to Import',
      );

      if (result == null || result.files.isEmpty) {
        debugPrint('[MarkdownImport] User cancelled file selection');
        return ImportResult(success: false, message: 'Import cancelled');
      }

      // Process each selected file
      int importedCount = 0;
      int skippedCount = 0;
      final errors = <String>[];

      for (final platformFile in result.files) {
        if (platformFile.path == null) {
          errors.add('${platformFile.name}: No file path available');
          continue;
        }

        final file = File(platformFile.path!);
        final importResult = await _importSingleFile(file);

        if (importResult.success) {
          importedCount++;
        } else if (importResult.message == 'skipped') {
          skippedCount++;
        } else {
          errors.add('${platformFile.name}: ${importResult.message}');
        }
      }

      debugPrint(
        '[MarkdownImport] Mobile import completed: $importedCount imported, $skippedCount skipped, ${errors.length} errors',
      );

      if (importedCount > 0) {
        final message =
            'Successfully imported $importedCount note(s)${skippedCount > 0 ? ' ($skippedCount skipped as duplicates)' : ''}${errors.isNotEmpty ? '. ${errors.length} files had errors.' : ''}';
        return ImportResult(success: true, message: message);
      } else {
        return ImportResult(
          success: false,
          message:
              'No notes imported.${errors.isNotEmpty ? " Errors: ${errors.take(3).join(", ")}" : ""}',
        );
      }
    } catch (e) {
      debugPrint('[MarkdownImport] Mobile import failed: $e');
      return ImportResult(success: false, message: 'Mobile import failed: $e');
    }
  }

  /// Desktop import: pick directory and scan for .md files
  static Future<ImportResult> _importFromDesktopDirectory() async {
    try {
      // Let user choose directory
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      // Find all .md files in the directory (including subdirectories)
      final markdownFiles = await _findMarkdownFiles(selectedDirectory!);

      if (markdownFiles.isEmpty) {
        debugPrint('[MarkdownImport] No .md files found in selected directory');
        return ImportResult(
          success: false,
          message: 'No markdown files found in the selected directory',
        );
      }

      // Import each file
      int importedCount = 0;
      int skippedCount = 0;
      final errors = <String>[];

      for (final file in markdownFiles) {
        final result = await _importSingleFile(file);
        if (result.success) {
          importedCount++;
        } else if (result.message == 'skipped') {
          skippedCount++;
        } else {
          errors.add('${file.path}: ${result.message}');
        }
      }

      debugPrint(
        '[MarkdownImport] Desktop import completed: $importedCount imported, $skippedCount skipped, ${errors.length} errors',
      );

      if (importedCount > 0) {
        final message =
            'Successfully imported $importedCount note(s)${skippedCount > 0 ? ' ($skippedCount skipped as duplicates)' : ''}${errors.isNotEmpty ? '. ${errors.length} files had errors.' : ''}';
        return ImportResult(success: true, message: message);
      } else {
        return ImportResult(
          success: false,
          message:
              'No notes imported.${errors.isNotEmpty ? " Errors: ${errors.join(", ")}" : ""}',
        );
      }
    } catch (e) {
      debugPrint('[MarkdownImport] Desktop import failed: $e');
      return ImportResult(success: false, message: 'Desktop import failed: $e');
    }
  }

  /// Find all .md files in a directory recursively
  static Future<List<File>> _findMarkdownFiles(String directoryPath) async {
    final files = <File>[];
    final directory = Directory(directoryPath);

    if (!await directory.exists()) return files;

    await for (final entity in directory.list(recursive: true)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.md')) {
        files.add(entity);
      }
    }

    return files;
  }

  /// Import a single markdown or JSON file
  static Future<ImportResult> _importSingleFile(File file) async {
    try {
      final content = await file.readAsString();
      final fileName = file.path.toLowerCase();

      Note? note;

      // Handle JSON files (Quill format)
      if (fileName.endsWith('.json')) {
        note = _parseJsonFile(content, file.path);
      }
      // Handle Markdown files
      else if (fileName.endsWith('.md')) {
        note = _parseMarkdownFile(content, file.path);
      } else {
        return ImportResult(success: false, message: 'Unsupported file format');
      }

      if (note == null) {
        return ImportResult(success: false, message: 'Could not parse file');
      }

      // Check if note already exists (by ID if available, or by title+content)
      await StorageService.waitNotesReady();
      final existingNotes = StorageService.getAllNotes();

      // Check for duplicate note by ID (from frontmatter)
      final existingById = existingNotes
          .where((n) => n.id == note!.id)
          .firstOrNull;
      if (existingById != null) {
        debugPrint(
          '[MarkdownImport] Skipping duplicate note (ID exists): ${note.title}',
        );
        return ImportResult(success: false, message: 'skipped');
      }

      // Check for duplicate note by title and content similarity
      final similarNote = existingNotes
          .where(
            (n) =>
                n.title == note!.title &&
                n.content.trim() == note.content.trim(),
          )
          .firstOrNull;

      if (similarNote != null) {
        debugPrint('[MarkdownImport] Skipping similar note: ${note.title}');
        return ImportResult(success: false, message: 'skipped');
      }

      // Save the note
      await StorageService.saveNote(note);
      debugPrint('[MarkdownImport] Imported note: ${note.title}');
      return ImportResult(success: true, message: 'imported');
    } catch (e) {
      debugPrint('[MarkdownImport] Failed to import ${file.path}: $e');
      return ImportResult(success: false, message: e.toString());
    }
  }

  /// Parse a markdown file and extract note data
  static Note? _parseMarkdownFile(String content, String filePath) {
    try {
      String title = '';
      String noteContent = content;
      String? noteId;
      DateTime? createdAt;
      DateTime? updatedAt;

      // Check for YAML frontmatter
      if (content.startsWith('---')) {
        final frontmatterEnd = content.indexOf('---', 3);
        if (frontmatterEnd != -1) {
          final frontmatter = content.substring(3, frontmatterEnd).trim();
          noteContent = content.substring(frontmatterEnd + 3).trim();

          // Parse frontmatter
          for (final line in frontmatter.split('\n')) {
            final colonIndex = line.indexOf(':');
            if (colonIndex == -1) continue;

            final key = line.substring(0, colonIndex).trim();
            final value = line
                .substring(colonIndex + 1)
                .trim()
                .replaceAll('"', '');

            switch (key) {
              case 'id':
                noteId = value;
                break;
              case 'title':
                title = value;
                break;
              case 'created':
                createdAt = DateTime.tryParse(value);
                break;
              case 'modified':
                updatedAt = DateTime.tryParse(value);
                break;
            }
          }
        }
      }

      // Extract title from first H1 if not in frontmatter
      if (title.isEmpty) {
        final h1Match = RegExp(
          r'^# (.+)$',
          multiLine: true,
        ).firstMatch(noteContent);
        if (h1Match != null) {
          title = h1Match.group(1)!.trim();
          // Remove the H1 from content
          noteContent = noteContent.replaceFirst(h1Match.group(0)!, '').trim();
        }
      }

      // Use filename as title if still empty
      if (title.isEmpty) {
        final fileName = filePath.split(Platform.pathSeparator).last;
        title = fileName
            .replaceAll('.md', '')
            .replaceAll(RegExp(r'^\d{4}-\d{2}-\d{2}-'), '');
        title = title.replaceAll('-', ' ').trim();
        if (title.isEmpty) title = 'Imported Note';
      }

      final now = DateTime.now();

      return Note(
        id: noteId, // Will generate new UUID if null
        title: title,
        content: noteContent,
        createdAt: createdAt ?? now,
        updatedAt: updatedAt ?? now,
      );
    } catch (e) {
      debugPrint('[MarkdownImport] Failed to parse markdown file: $e');
      return null;
    }
  }

  /// Parse a JSON file (Quill Delta format) and extract note data
  static Note? _parseJsonFile(String content, String filePath) {
    try {
      final jsonData = jsonDecode(content);

      // Expected format: {"title": "...", "content": "[{...}]", "createdAt": "...", ...}
      if (jsonData is! Map<String, dynamic>) {
        debugPrint('[MarkdownImport] Invalid JSON format - expected object');
        return null;
      }

      final title = jsonData['title'] as String? ?? 'Imported Note';
      final noteContent = jsonData['content'] as String? ?? '[]';
      final noteId = jsonData['id'] as String?;

      DateTime? createdAt;
      DateTime? updatedAt;

      if (jsonData['createdAt'] != null) {
        createdAt = DateTime.tryParse(jsonData['createdAt'] as String);
      }
      if (jsonData['updatedAt'] != null) {
        updatedAt = DateTime.tryParse(jsonData['updatedAt'] as String);
      }

      final now = DateTime.now();

      return Note(
        id: noteId,
        title: title,
        content: noteContent,
        createdAt: createdAt ?? now,
        updatedAt: updatedAt ?? now,
      );
    } catch (e) {
      debugPrint('[MarkdownImport] Failed to parse JSON file: $e');
      return null;
    }
  }
}

/// Result of an import operation
class ImportResult {
  final bool success;
  final String message;

  ImportResult({required this.success, required this.message});
}
