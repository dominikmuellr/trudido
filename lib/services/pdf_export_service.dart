import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:intl/intl.dart';
import 'dart:convert';
import '../models/note.dart';
import '../models/todo.dart';
import '../services/storage_service.dart';

/// Service for exporting notes and todos as PDF files
class PdfExportService {
  /// Export all todos and notes as a comprehensive PDF
  static Future<bool> exportAllDataToPdf() async {
    try {
      debugPrint('[PdfExport] Starting comprehensive data export...');

      // Get all data
      await StorageService.waitNotesReady();
      await StorageService.waitTodosReady();

      final notes = StorageService.getAllNotes();
      final todos = await StorageService.getAllTodosAsync();

      debugPrint(
        '[PdfExport] Found ${todos.length} todos and ${notes.length} notes',
      );

      if (notes.isEmpty && todos.isEmpty) {
        debugPrint('[PdfExport] No data to export');
        return false;
      }

      // Create PDF document
      final pdf = pw.Document();

      // Load fonts
      final font = await PdfGoogleFonts.robotoRegular();
      final fontBold = await PdfGoogleFonts.robotoBold();
      final fontItalic = await PdfGoogleFonts.robotoItalic();

      final dateFormat = DateFormat('MMM d, y · h:mm a');
      final now = DateTime.now();

      // Title page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'Trudido Data Export',
                    style: pw.TextStyle(font: fontBold, fontSize: 32),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'Generated on ${dateFormat.format(now)}',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 14,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 40),
                  pw.Text(
                    '${todos.length} Tasks • ${notes.length} Notes',
                    style: pw.TextStyle(font: fontBold, fontSize: 18),
                  ),
                ],
              ),
            );
          },
        ),
      );

      // Export todos section
      if (todos.isNotEmpty) {
        debugPrint('[PdfExport] Adding ${todos.length} todos to PDF');
        _addTodosSection(pdf, todos, font, fontBold, fontItalic, dateFormat);
      } else {
        debugPrint('[PdfExport] No todos to export');
      }

      // Export notes section
      if (notes.isNotEmpty) {
        debugPrint('[PdfExport] Adding ${notes.length} notes to PDF');
        _addNotesSection(pdf, notes, font, fontBold, fontItalic, dateFormat);
      } else {
        debugPrint('[PdfExport] No notes to export');
      }

      // Save or share the PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Trudido_Export_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf',
      );

      debugPrint('[PdfExport] Comprehensive export successful');
      return true;
    } catch (e, stackTrace) {
      debugPrint('[PdfExport] Export failed: $e');
      debugPrint('[PdfExport] Stack trace: $stackTrace');
      return false;
    }
  }

  /// Add todos section to PDF
  static void _addTodosSection(
    pw.Document pdf,
    List<Todo> todos,
    pw.Font font,
    pw.Font fontBold,
    pw.Font fontItalic,
    DateFormat dateFormat,
  ) {
    // Group todos by status
    final pending = todos.where((t) => !t.isCompleted).toList();
    final completed = todos.where((t) => t.isCompleted).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          final widgets = <pw.Widget>[];

          // Section header
          widgets.add(
            pw.Header(
              level: 0,
              child: pw.Text(
                'Tasks',
                style: pw.TextStyle(font: fontBold, fontSize: 28),
              ),
            ),
          );
          widgets.add(pw.SizedBox(height: 10));
          widgets.add(pw.Divider(thickness: 2));
          widgets.add(pw.SizedBox(height: 20));

          // Pending tasks
          if (pending.isNotEmpty) {
            widgets.add(
              pw.Text(
                'Pending Tasks (${pending.length})',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 18,
                  color: PdfColors.blue700,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 10));

            for (var todo in pending) {
              widgets.addAll(
                _buildTodoItem(todo, font, fontBold, fontItalic, dateFormat),
              );
            }
            widgets.add(pw.SizedBox(height: 30));
          }

          // Completed tasks
          if (completed.isNotEmpty) {
            widgets.add(
              pw.Text(
                'Completed Tasks (${completed.length})',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 18,
                  color: PdfColors.green700,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 10));

            for (var todo in completed) {
              widgets.addAll(
                _buildTodoItem(todo, font, fontBold, fontItalic, dateFormat),
              );
            }
          }

          return widgets;
        },
      ),
    );
  }

  /// Build a todo item widget
  static List<pw.Widget> _buildTodoItem(
    Todo todo,
    pw.Font font,
    pw.Font fontBold,
    pw.Font fontItalic,
    DateFormat dateFormat,
  ) {
    final widgets = <pw.Widget>[];

    widgets.add(
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        margin: const pw.EdgeInsets.only(bottom: 12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Title with checkbox
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 16,
                  height: 16,
                  margin: const pw.EdgeInsets.only(right: 8, top: 2),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: todo.isCompleted
                          ? PdfColors.green
                          : PdfColors.grey600,
                      width: 2,
                    ),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(3),
                    ),
                    color: todo.isCompleted ? PdfColors.green : null,
                  ),
                  child: todo.isCompleted
                      ? pw.Center(
                          child: pw.Text(
                            '✓',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 10,
                              font: fontBold,
                            ),
                          ),
                        )
                      : null,
                ),
                pw.Expanded(
                  child: pw.Text(
                    todo.text,
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 14,
                      decoration: todo.isCompleted
                          ? pw.TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
              ],
            ),

            // Metadata
            if (todo.dueDate != null ||
                todo.priority != 'none' ||
                todo.tags.isNotEmpty ||
                todo.notes?.isNotEmpty == true) ...[
              pw.SizedBox(height: 8),
              pw.Divider(color: PdfColors.grey200),
              pw.SizedBox(height: 8),

              if (todo.dueDate != null)
                pw.Text(
                  'Due: ${dateFormat.format(todo.dueDate!)}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),

              if (todo.priority != 'none')
                pw.Text(
                  'Priority: ${todo.priority.toUpperCase()}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),

              if (todo.tags.isNotEmpty)
                pw.Text(
                  'Tags: ${todo.tags.join(", ")}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),

              if (todo.notes?.isNotEmpty == true) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  todo.notes!,
                  style: pw.TextStyle(
                    font: fontItalic,
                    fontSize: 10,
                    color: PdfColors.grey800,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );

    return widgets;
  }

  /// Add notes section to PDF
  static void _addNotesSection(
    pw.Document pdf,
    List<Note> notes,
    pw.Font font,
    pw.Font fontBold,
    pw.Font fontItalic,
    DateFormat dateFormat,
  ) {
    // Add section divider page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'Notes',
                  style: pw.TextStyle(font: fontBold, fontSize: 28),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  '${notes.length} total notes',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 14,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Add each note
    for (var note in notes) {
      _addSingleNote(pdf, note, font, fontBold, fontItalic, dateFormat);
    }
  }

  /// Add a single note to PDF
  static void _addSingleNote(
    pw.Document pdf,
    Note note,
    pw.Font font,
    pw.Font fontBold,
    pw.Font fontItalic,
    DateFormat dateFormat,
  ) {
    // Try to parse as Quill JSON content, fallback to plain text
    String noteContent = note.content;

    try {
      final jsonContent = jsonDecode(note.content);
      if (jsonContent is List) {
        final quillDoc = quill.Document.fromJson(jsonContent);
        noteContent = quillDoc.toPlainText();
      }
    } catch (e) {
      // Not JSON or not Quill format, use as plain text
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          final widgets = <pw.Widget>[];

          // Title
          widgets.add(
            pw.Header(
              level: 0,
              child: pw.Text(
                note.title,
                style: pw.TextStyle(font: fontBold, fontSize: 24),
              ),
            ),
          );

          // Metadata
          widgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 20),
              child: pw.Text(
                'Created: ${dateFormat.format(note.createdAt)}\n'
                'Updated: ${dateFormat.format(note.updatedAt)}',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            ),
          );

          widgets.add(pw.Divider(thickness: 1));
          widgets.add(pw.SizedBox(height: 10));

          // Content
          widgets.add(
            pw.Text(noteContent, style: pw.TextStyle(font: font, fontSize: 12)),
          );

          return widgets;
        },
      ),
    );
  }
}
