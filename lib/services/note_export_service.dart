import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../models/note.dart';
import 'package:path/path.dart' as path;
import 'dart:convert';

// Helper structure used while converting Quill ops to PDF blocks
class _PdfLine {
  final List<pw.TextSpan>? spans;
  final Map<String, dynamic> blockAttrs;
  _PdfLine({this.spans, required this.blockAttrs});
}

pw.TextStyle _mapInlineAttributesToStyle(Map<String, dynamic> attrs) {
  var style = pw.TextStyle(fontSize: 12);
  if (attrs.containsKey('bold') && attrs['bold'] == true) {
    style = style.copyWith(fontWeight: pw.FontWeight.bold);
  }
  if (attrs.containsKey('italic') && attrs['italic'] == true) {
    // pdf package uses FontStyle for italic
    style = style.copyWith(fontStyle: pw.FontStyle.italic);
  }
  if (attrs.containsKey('code') && attrs['code'] == true) {
    style = style.copyWith(font: pw.Font.helvetica());
  }
  if (attrs.containsKey('link')) {
    style = style.copyWith(color: PdfColors.blue);
  }
  return style;
}

/// Parse markdown image references and append PDF widgets to `contentWidgets`.
/// Supports image syntax: ![alt](path)
Future<void> _addMarkdownWidgets(
  String content,
  List<pw.Widget> contentWidgets,
) async {
  final regex = RegExp(r'!\[[^\]]*\]\(([^)]+)\)');
  int last = 0;

  for (final match in regex.allMatches(content)) {
    if (match.start > last) {
      final textSegment = content.substring(last, match.start);
      if (textSegment.trim().isNotEmpty) {
        contentWidgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Text(textSegment, style: pw.TextStyle(fontSize: 12)),
          ),
        );
      }
    }

    final imgPathRaw = match.group(1)?.trim();
    final imgPath = imgPathRaw ?? '';

    try {
      final file = File(imgPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final image = pw.MemoryImage(bytes);
        contentWidgets.add(pw.SizedBox(height: 8));
        contentWidgets.add(
          pw.Center(
            child: pw.Image(
              image,
              width: PdfPageFormat.a4.availableWidth * 0.9,
              fit: pw.BoxFit.scaleDown,
            ),
          ),
        );
        contentWidgets.add(pw.SizedBox(height: 8));
      } else {
        contentWidgets.add(
          pw.Text(
            '[Missing image: $imgPath]',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
          ),
        );
      }
    } catch (e) {
      contentWidgets.add(
        pw.Text(
          '[Error loading image: $imgPath]',
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
        ),
      );
    }

    last = match.end;
  }

  if (last < content.length) {
    final remaining = content.substring(last);
    if (remaining.trim().isNotEmpty) {
      contentWidgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(remaining, style: pw.TextStyle(fontSize: 12)),
        ),
      );
    }
  }
}

/// Service responsible for generating and sharing note exports (PDF)
class NoteExportService {
  /// Generates a simple PDF containing the note title, timestamps and content.
  static Future<Uint8List> generatePdfBytes(Note note) async {
    final doc = pw.Document();

    final title = note.title.isNotEmpty ? note.title : 'Untitled';
    final created = note.createdAt.toLocal();
    final updated = note.updatedAt.toLocal();

    // Build content widgets, handling Quill JSON with media embeds
    List<pw.Widget> contentWidgets = [];

    // Header
    contentWidgets.add(
      pw.Header(
        level: 0,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Created: ${created.toIso8601String()}',
              style: pw.TextStyle(fontSize: 9),
            ),
            pw.Text(
              'Updated: ${updated.toIso8601String()}',
              style: pw.TextStyle(fontSize: 9),
            ),
            pw.Divider(),
          ],
        ),
      ),
    );

    // If content is Quill JSON (starts with '[') try to parse and include media
    if (note.content.trim().startsWith('[')) {
      try {
        final ops = jsonDecode(note.content) as List<dynamic>;

        // Convert ops into logical lines with inline spans so we can map
        // block-level formatting (headers, lists) and inline (bold/italic).
        final List<_PdfLine> lines = [];
        List<pw.TextSpan> currentSpans = [];

        for (var op in ops) {
          if (op is Map<String, dynamic> && op.containsKey('insert')) {
            final insert = op['insert'];
            final attributes = (op['attributes'] is Map)
                ? (op['attributes'] as Map).cast<String, dynamic>()
                : <String, dynamic>{};

            // Media embed handling: flush current line, then add media widget
            if (insert is Map) {
              String? mediaJson;
              if (insert.containsKey('custom')) {
                mediaJson = insert['custom'] as String;
                try {
                  final parsed = jsonDecode(mediaJson) as Map<String, dynamic>;
                  if (parsed.containsKey('media')) {
                    mediaJson = parsed['media'] as String;
                  }
                } catch (e) {}
              } else if (insert.containsKey('media')) {
                mediaJson = insert['media'] as String;
              }

              if (mediaJson != null) {
                if (currentSpans.isNotEmpty) {
                  lines.add(
                    _PdfLine(spans: List.from(currentSpans), blockAttrs: {}),
                  );
                  currentSpans.clear();
                }

                try {
                  final mediaData =
                      jsonDecode(mediaJson) as Map<String, dynamic>;
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
                            width: PdfPageFormat.a4.availableWidth * 0.9,
                            fit: pw.BoxFit.scaleDown,
                          ),
                        ),
                      );
                      contentWidgets.add(pw.SizedBox(height: 8));
                    } else {
                      contentWidgets.add(
                        pw.Text(
                          '[Missing image: $pathStr]',
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey,
                          ),
                        ),
                      );
                    }
                  } else if (type == 'video' && pathStr != null) {
                    final uint8list = await VideoThumbnail.thumbnailData(
                      video: pathStr,
                      imageFormat: ImageFormat.JPEG,
                      maxWidth: 800,
                      quality: 75,
                    );
                    if (uint8list != null) {
                      final image = pw.MemoryImage(uint8list);
                      contentWidgets.add(pw.SizedBox(height: 8));
                      contentWidgets.add(
                        pw.Center(
                          child: pw.Image(
                            image,
                            width: PdfPageFormat.a4.availableWidth * 0.9,
                            fit: pw.BoxFit.scaleDown,
                          ),
                        ),
                      );
                      contentWidgets.add(
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 4),
                          child: pw.Text(
                            'Video: ${path.basename(pathStr)}',
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey,
                            ),
                          ),
                        ),
                      );
                      contentWidgets.add(pw.SizedBox(height: 8));
                    } else {
                      contentWidgets.add(
                        pw.Text(
                          '[Video thumbnail unavailable]',
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey,
                          ),
                        ),
                      );
                    }
                  } else if (type == 'voice' && pathStr != null) {
                    contentWidgets.add(
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 6),
                        child: pw.Text(
                          'Audio: ${path.basename(pathStr)}',
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey,
                          ),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  contentWidgets.add(
                    pw.Text(
                      '[Attachment]',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                    ),
                  );
                }

                continue;
              }
            }

            // Text insert: split into lines by newline and create spans
            if (insert is String) {
              final parts = insert.split('\n');
              for (var i = 0; i < parts.length; i++) {
                final part = parts[i];
                if (part.isNotEmpty) {
                  final spanStyle = _mapInlineAttributesToStyle(attributes);
                  currentSpans.add(pw.TextSpan(text: part, style: spanStyle));
                }

                // If newline occurred, the block attributes live on this op
                if (i < parts.length - 1) {
                  final blockAttrs = Map<String, dynamic>.from(attributes);
                  lines.add(
                    _PdfLine(
                      spans: List.from(currentSpans),
                      blockAttrs: blockAttrs,
                    ),
                  );
                  currentSpans.clear();
                }
              }
            }
          }
        }

        if (currentSpans.isNotEmpty) {
          lines.add(_PdfLine(spans: List.from(currentSpans), blockAttrs: {}));
          currentSpans.clear();
        }

        // Convert lines into PDF widgets
        int idx = 0;
        while (idx < lines.length) {
          final line = lines[idx];
          final block = line.blockAttrs;

          // Lists grouping
          if (block.containsKey('list')) {
            final listType = block['list'] as String? ?? 'bullet';
            final items = <_PdfLine>[];
            while (idx < lines.length &&
                (lines[idx].blockAttrs['list'] == listType)) {
              items.add(lines[idx]);
              idx++;
            }

            if (listType == 'ordered') {
              for (var i = 0; i < items.length; i++) {
                final item = items[i];
                final number = i + 1;
                contentWidgets.add(
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      children: [
                        pw.Container(
                          width: 24,
                          child: pw.Text(
                            '$number.',
                            style: pw.TextStyle(fontSize: 12),
                          ),
                        ),
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
            } else {
              for (var item in items) {
                contentWidgets.add(
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      children: [
                        pw.Container(
                          width: 14,
                          child: pw.Text(
                            '•',
                            style: pw.TextStyle(fontSize: 12),
                          ),
                        ),
                        pw.SizedBox(width: 6),
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

          // Header
          if (block.containsKey('header')) {
            final level = (block['header'] is int)
                ? block['header'] as int
                : int.tryParse(block['header']?.toString() ?? '') ?? 1;
            double size = 16;
            if (level == 1) size = 20;
            if (level == 2) size = 18;
            if (level >= 3) size = 14;
            contentWidgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 6, bottom: 2),
                child: pw.RichText(
                  text: pw.TextSpan(
                    children: line.spans ?? [pw.TextSpan(text: '')],
                    style: pw.TextStyle(
                      fontSize: size,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
            idx++;
            continue;
          }

          // Paragraph
          contentWidgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.RichText(
                text: pw.TextSpan(
                  children: line.spans ?? [pw.TextSpan(text: '')],
                  style: pw.TextStyle(fontSize: 12),
                ),
              ),
            ),
          );
          idx++;
        }
      } catch (e) {
        // If parsing fails, fallback to plain text
        contentWidgets.add(
          pw.Text(note.content, style: pw.TextStyle(fontSize: 12)),
        );
      }
    } else {
      // Plain markdown/text: try to embed images referenced with Markdown image
      // syntax `![alt](path)` and include textual content.
      try {
        await _addMarkdownWidgets(note.content, contentWidgets);
      } catch (e) {
        // fallback to plain text on any error
        contentWidgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(note.content, style: pw.TextStyle(fontSize: 12)),
          ),
        );
      }
    }

    // Create the page
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => contentWidgets,
      ),
    );

    return doc.save();
  }

  /// Shares a PDF using the platform sharing mechanism.
  static Future<void> sharePdf(
    Uint8List bytes,
    String filename,
    BuildContext context,
  ) async {
    try {
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (e) {
      // Rethrow so callers can show appropriate UI
      rethrow;
    }
  }
}
