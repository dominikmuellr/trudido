// Trudido - A privacy-focused todo and notes app
// Copyright (C) 2026 Dominik Müller
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

/// Line accumulation helper for Quill-to-PDF conversion inside [PdfExportService].
/// In Quill Delta, block attributes live on the "\n" op that terminates each
/// block; preceding text ops carry only inline attributes.  We accumulate spans
/// across ops and emit one [_NotePdfLine] per logical line.
class _NotePdfLine {
  final List<pw.TextSpan>? spans;
  final Map<String, dynamic> blockAttrs;
  _NotePdfLine({this.spans, required this.blockAttrs});
}

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

  /// Add a single note to PDF with images and formatting.
  ///
  /// Uses line-accumulation to correctly handle Quill Delta format where block
  /// attributes (header, list, code-block, blockquote) are placed on the "\n"
  /// op that terminates each block, not on the text content ops.
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

    // Parse Quill JSON and render
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

      // Build inline TextStyle from Quill inline attributes.
      pw.TextStyle styledText(Map<String, dynamic> attrs) {
        var s = pw.TextStyle(font: font, fontSize: 12);
        if (attrs['bold'] == true) s = s.copyWith(font: fontBold);
        if (attrs['italic'] == true) s = s.copyWith(font: fontItalic);
        if (attrs['code'] == true) s = s.copyWith(font: pw.Font.helvetica());
        if (attrs.containsKey('link')) s = s.copyWith(color: PdfColors.blue);
        if (attrs['strike'] == true) {
          s = s.copyWith(decoration: pw.TextDecoration.lineThrough);
        }
        if (attrs['underline'] == true) {
          s = s.copyWith(decoration: pw.TextDecoration.underline);
        }
        return s;
      }

      // Phase 1 – accumulate ops into logical lines.
      final List<_NotePdfLine> lines = [];
      List<pw.TextSpan> currentSpans = [];

      for (var op in ops) {
        if (op is! Map<String, dynamic> || !op.containsKey('insert')) continue;

        final insert = op['insert'];
        final attrs = (op['attributes'] is Map)
            ? (op['attributes'] as Map).cast<String, dynamic>()
            : <String, dynamic>{};

        // ── Map inserts (media, link embeds, etc.) ─────────────────────────
        if (insert is Map) {
          // Flush accumulated spans before inserting a block-level widget.
          if (currentSpans.isNotEmpty) {
            lines.add(
              _NotePdfLine(spans: List.from(currentSpans), blockAttrs: {}),
            );
            currentSpans.clear();
          }

          // Custom media embed: {"insert": {"custom": "{\"media\":\"...\"}"}}
          String? mediaJson;
          if (insert.containsKey('custom')) {
            final raw = insert['custom'];
            if (raw is String) {
              mediaJson = raw;
              try {
                final parsed = jsonDecode(raw) as Map<String, dynamic>;
                if (parsed.containsKey('media')) {
                  mediaJson = parsed['media'] as String;
                }
              } catch (_) {}
            }
          } else if (insert.containsKey('media')) {
            mediaJson = insert['media'] as String?;
          }

          if (mediaJson != null) {
            try {
              final mediaData = jsonDecode(mediaJson) as Map<String, dynamic>;
              final type = mediaData['type'] as String? ?? 'image';
              final pathStr = mediaData['path'] as String?;
              if (type == 'image' && pathStr != null) {
                final file = File(pathStr);
                if (await file.exists()) {
                  final bytes = await file.readAsBytes();
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
                    debugPrint(
                      '[PdfExport] Image added for note ${note.title}',
                    );
                  }
                }
              }
            } catch (e) {
              if (kDebugMode) debugPrint('[PdfExport] Media parse error: $e');
            }
            continue;
          }

          // Link embed – extract display text into a span.
          if (insert.containsKey('link')) {
            final linkData = insert['link'];
            String linkText = '';
            if (linkData is Map) {
              linkText =
                  (linkData['text'] as String?) ??
                  (linkData['url'] as String?) ??
                  '';
            } else if (linkData is String) {
              try {
                final parsed = jsonDecode(linkData) as Map<String, dynamic>;
                linkText =
                    (parsed['text'] as String?) ??
                    (parsed['url'] as String?) ??
                    '';
              } catch (_) {
                linkText = linkData;
              }
            }
            if (linkText.isNotEmpty) {
              currentSpans.add(
                pw.TextSpan(
                  text: linkText,
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 12,
                    color: PdfColors.blue,
                  ),
                ),
              );
            }
          }
          continue;
        }

        // ── Text insert ─────────────────────────────────────────────────────
        if (insert is String) {
          final parts = insert.split('\n');
          for (var i = 0; i < parts.length; i++) {
            final part = parts[i];
            if (part.isNotEmpty) {
              currentSpans.add(
                pw.TextSpan(text: part, style: styledText(attrs)),
              );
            }
            if (i < parts.length - 1) {
              // The block attributes for this line come from attrs of the \n op.
              lines.add(
                _NotePdfLine(
                  spans: List.from(currentSpans),
                  blockAttrs: Map<String, dynamic>.from(attrs),
                ),
              );
              currentSpans.clear();
            }
          }
        }
      }

      if (currentSpans.isNotEmpty) {
        lines.add(_NotePdfLine(spans: List.from(currentSpans), blockAttrs: {}));
      }

      // Phase 2 – render lines as PDF widgets.
      int idx = 0;
      while (idx < lines.length) {
        final line = lines[idx];
        final block = line.blockAttrs;

        // ── Lists ────────────────────────────────────────────────────────────
        if (block.containsKey('list')) {
          final listType = block['list'] as String? ?? 'bullet';
          final items = <_NotePdfLine>[];

          if (listType == 'ordered') {
            while (idx < lines.length &&
                lines[idx].blockAttrs['list'] == 'ordered') {
              items.add(lines[idx]);
              idx++;
            }
            for (var i = 0; i < items.length; i++) {
              contentWidgets.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 20, bottom: 2),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 24,
                        child: pw.Text(
                          '${i + 1}.',
                          style: pw.TextStyle(font: font, fontSize: 12),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.RichText(
                          text: pw.TextSpan(
                            children: items[i].spans ?? [pw.TextSpan(text: '')],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          } else {
            // bullet / checked / unchecked – group all consecutive non-ordered
            while (idx < lines.length &&
                lines[idx].blockAttrs.containsKey('list') &&
                lines[idx].blockAttrs['list'] != 'ordered') {
              items.add(lines[idx]);
              idx++;
            }
            for (var item in items) {
              final iType = item.blockAttrs['list'] as String? ?? listType;
              final String marker;
              final double markerWidth;
              if (iType == 'checked') {
                marker = '[x]';
                markerWidth = 28;
              } else if (iType == 'unchecked') {
                marker = '[ ]';
                markerWidth = 28;
              } else {
                marker = '\u2022';
                markerWidth = 14;
              }
              contentWidgets.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 20, bottom: 2),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: markerWidth,
                        child: pw.Text(
                          marker,
                          style: pw.TextStyle(font: font, fontSize: 11),
                        ),
                      ),
                      pw.SizedBox(width: 4),
                      pw.Expanded(
                        child: pw.RichText(
                          text: pw.TextSpan(
                            children: item.spans ?? [pw.TextSpan(text: '')],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          }
          continue;
        }

        // ── Header ───────────────────────────────────────────────────────────
        if (block.containsKey('header')) {
          final level = block['header'] is int
              ? block['header'] as int
              : int.tryParse(block['header']?.toString() ?? '') ?? 1;
          final size = level == 1 ? 20.0 : (level == 2 ? 18.0 : 14.0);
          contentWidgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
              child: pw.RichText(
                text: pw.TextSpan(
                  children: line.spans ?? [pw.TextSpan(text: '')],
                  style: pw.TextStyle(font: fontBold, fontSize: size),
                ),
              ),
            ),
          );
          idx++;
          continue;
        }

        // ── Code block ───────────────────────────────────────────────────────
        if (block.containsKey('code-block')) {
          contentWidgets.add(
            pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 4),
              padding: const pw.EdgeInsets.all(8),
              color: PdfColors.grey200,
              child: pw.RichText(
                text: pw.TextSpan(
                  children: line.spans ?? [pw.TextSpan(text: '')],
                  style: pw.TextStyle(fontSize: 11, font: pw.Font.helvetica()),
                ),
              ),
            ),
          );
          idx++;
          continue;
        }

        // ── Blockquote ───────────────────────────────────────────────────────
        if (block.containsKey('blockquote')) {
          contentWidgets.add(
            pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 2),
              padding: const pw.EdgeInsets.only(left: 10),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(color: PdfColors.grey400, width: 3),
                ),
              ),
              child: pw.RichText(
                text: pw.TextSpan(
                  children: line.spans ?? [pw.TextSpan(text: '')],
                  style: pw.TextStyle(
                    font: fontItalic,
                    fontSize: 12,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
            ),
          );
          idx++;
          continue;
        }

        // ── Plain paragraph (skip empty trailing-newline lines) ───────────────
        if (line.spans != null && line.spans!.isNotEmpty) {
          contentWidgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.RichText(
                text: pw.TextSpan(
                  children: line.spans!,
                  style: pw.TextStyle(font: font, fontSize: 12),
                ),
              ),
            ),
          );
        }
        idx++;
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
