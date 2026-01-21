// Trudido - A privacy-focused todo and notes app
// Copyright (C) 2025 Dominik Müller
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import '../models/note.dart';
import '../models/todo.dart';
import '../services/storage_service.dart';

/// Service for exporting notes and todos as PDF files
class PdfExportService {
  /// Export all todos and notes as a comprehensive PDF
  static Future<bool> exportAllDataToPdf() async {
    try {
      if (kDebugMode) {
        debugPrint('[PdfExport] Starting comprehensive data export...');
      }

      // Get all data
      await StorageService.waitNotesReady();
      await StorageService.waitTodosReady();

      final notes = StorageService.getAllNotes();
      final todos = await StorageService.getAllTodosAsync();

      if (kDebugMode) {
        debugPrint(
          '[PdfExport] Found ${todos.length} todos and ${notes.length} notes',
        );
      }

      if (notes.isEmpty && todos.isEmpty) {
        if (kDebugMode) {
          debugPrint('[PdfExport] No data to export');
        }
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
        if (kDebugMode) {
          debugPrint('[PdfExport] Adding ${todos.length} todos to PDF');
        }
        _addTodosSection(pdf, todos, font, fontBold, fontItalic, dateFormat);
      } else {
        if (kDebugMode) {
          debugPrint('[PdfExport] No todos to export');
        }
      }

      // Export notes section
      if (notes.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('[PdfExport] Adding ${notes.length} notes to PDF');
        }
        await _addNotesSection(
          pdf,
          notes,
          font,
          fontBold,
          fontItalic,
          dateFormat,
        );
      } else {
        if (kDebugMode) {
          debugPrint('[PdfExport] No notes to export');
        }
      }

      // Save or share the PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Trudido_Export_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf',
      );

      if (kDebugMode) {
        debugPrint('[PdfExport] Comprehensive export successful');
      }
      return true;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[PdfExport] Export failed: $e');
        debugPrint('[PdfExport] Stack trace: $stackTrace');
      }
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
  static Future<void> _addNotesSection(
    pw.Document pdf,
    List<Note> notes,
    pw.Font font,
    pw.Font fontBold,
    pw.Font fontItalic,
    DateFormat dateFormat,
  ) async {
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
      await _addSingleNote(pdf, note, font, fontBold, fontItalic, dateFormat);
    }
  }

  /// Add a single note to PDF with images and formatting
  static Future<void> _addSingleNote(
    pw.Document pdf,
    Note note,
    pw.Font font,
    pw.Font fontBold,
    pw.Font fontItalic,
    DateFormat dateFormat,
  ) async {
    final contentWidgets = <pw.Widget>[];

    // Title
    contentWidgets.add(
      pw.Header(
        level: 0,
        child: pw.Text(
          note.title,
          style: pw.TextStyle(font: fontBold, fontSize: 24),
        ),
      ),
    );

    // Metadata
    contentWidgets.add(
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

    contentWidgets.add(pw.Divider(thickness: 1));
    contentWidgets.add(pw.SizedBox(height: 10));

    // Parse Quill JSON and render with images
    try {
      final jsonContent = jsonDecode(note.content);
      List<dynamic> ops;

      if (jsonContent is List) {
        ops = jsonContent;
      } else if (jsonContent is Map && jsonContent.containsKey('ops')) {
        ops = jsonContent['ops'] as List<dynamic>;
      } else {
        throw FormatException('Not Quill format');
      }

      // Process each op
      for (var op in ops) {
        if (op is! Map<String, dynamic> || !op.containsKey('insert')) continue;

        final insert = op['insert'];
        final attrs = (op['attributes'] is Map)
            ? (op['attributes'] as Map).cast<String, dynamic>()
            : <String, dynamic>{};

        // Handle media embeds
        if (insert is Map) {
          final custom = insert['custom'];
          if (kDebugMode) {
            debugPrint(
              '[PdfExport] Found Map insert, custom field type: ${custom?.runtimeType}',
            );
            debugPrint('[PdfExport] Custom value: $custom');
          }

          if (custom is String) {
            if (kDebugMode) {
              debugPrint(
                '[PdfExport] Custom is String, attempting to parse...',
              );
            }
            try {
              final parsed = jsonDecode(custom) as Map<String, dynamic>;
              if (kDebugMode) {
                debugPrint('[PdfExport] Parsed media: $parsed');
              }

              // The media field contains ANOTHER JSON string
              final mediaString = parsed['media'] as String?;
              if (mediaString != null) {
                if (kDebugMode) {
                  debugPrint(
                    '[PdfExport] Found media string, parsing again...',
                  );
                }
                final media = jsonDecode(mediaString) as Map<String, dynamic>;
                if (kDebugMode) {
                  debugPrint('[PdfExport] Final parsed media: $media');
                }

                final type = media['type'] as String?;
                final pathStr = media['path'] as String?;
                if (kDebugMode) {
                  debugPrint('[PdfExport] Type: $type, Path: $pathStr');
                }

                if (type == 'image' && pathStr != null) {
                  final file = File(pathStr);
                  final exists = await file.exists();
                  if (kDebugMode) {
                    debugPrint('[PdfExport] Image file exists: $exists');
                  }
                  if (exists) {
                    final bytes = await file.readAsBytes();
                    if (kDebugMode) {
                      debugPrint('[PdfExport] Loaded ${bytes.length} bytes');
                    }
                    final image = pw.MemoryImage(bytes);
                    contentWidgets.add(pw.SizedBox(height: 8));
                    contentWidgets.add(
                      pw.Center(
                        child: pw.Image(
                          image,
                          width: PdfPageFormat.a4.availableWidth * 0.7,
                          fit: pw.BoxFit.scaleDown,
                        ),
                      ),
                    );
                    contentWidgets.add(pw.SizedBox(height: 8));
                    if (kDebugMode) {
                      debugPrint('[PdfExport] Image widget added!');
                    }
                  }
                }
              }
            } catch (e) {
              if (kDebugMode) {
                debugPrint('[PdfExport] Error parsing custom: $e');
              }
            }
          } else if (custom is Map) {
            if (kDebugMode) {
              debugPrint('[PdfExport] Custom is Map: ${custom.keys.toList()}');
            }
          }
          continue;
        }

        // Handle text
        if (insert is String && insert.isNotEmpty) {
          var style = pw.TextStyle(font: font, fontSize: 12);
          if (attrs['bold'] == true) style = style.copyWith(font: fontBold);
          if (attrs['italic'] == true) style = style.copyWith(font: fontItalic);

          if (attrs.containsKey('header')) {
            final level = attrs['header'] is int ? attrs['header'] as int : 1;
            final size = level == 1 ? 18.0 : (level == 2 ? 16.0 : 14.0);
            contentWidgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 10, bottom: 5),
                child: pw.Text(
                  insert,
                  style: pw.TextStyle(font: fontBold, fontSize: size),
                ),
              ),
            );
          } else if (attrs['list'] == 'checked') {
            contentWidgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 20, bottom: 2),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('[x] ', style: style),
                    pw.Expanded(child: pw.Text(insert, style: style)),
                  ],
                ),
              ),
            );
          } else if (attrs['list'] == 'unchecked') {
            contentWidgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 20, bottom: 2),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('[ ] ', style: style),
                    pw.Expanded(child: pw.Text(insert, style: style)),
                  ],
                ),
              ),
            );
          } else if (attrs['list'] == 'bullet') {
            contentWidgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 20, bottom: 2),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('\u2022 ', style: style),
                    pw.Expanded(child: pw.Text(insert, style: style)),
                  ],
                ),
              ),
            );
          } else {
            contentWidgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(insert, style: style),
              ),
            );
          }
        }
      }
    } catch (e) {
      // Fallback to plain text
      contentWidgets.add(
        pw.Text(note.content, style: pw.TextStyle(font: font, fontSize: 12)),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => contentWidgets,
      ),
    );
  }
}
