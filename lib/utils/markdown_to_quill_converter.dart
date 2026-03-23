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

import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'markdown_inline_patterns.dart';

/// Converts markdown text to Quill Delta format
/// This allows seamless migration from markdown notes to Quill WYSIWYG editor
class MarkdownToQuillConverter {
  /// Convert markdown string to Quill Document
  static Document markdownToDocument(String markdown) {
    if (markdown.trim().isEmpty) {
      return Document()..insert(0, '\n');
    }

    final delta = Delta();
    final lines = markdown.split('\n');

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];

      if (line.startsWith('### ')) {
        final text = line.substring(4);
        delta.insert(text);
        delta.insert('\n', {'header': 3});
      } else if (line.startsWith('## ')) {
        final text = line.substring(3);
        delta.insert(text);
        delta.insert('\n', {'header': 2});
      } else if (line.startsWith('# ')) {
        final text = line.substring(2);
        delta.insert(text);
        delta.insert('\n', {'header': 1});
      } else if (line.trim().startsWith('- [x] ')) {
        final text = line.trim().substring(6);
        _insertInlineFormatting(delta, text);
        delta.insert('\n', {'list': 'checked'});
      } else if (line.trim().startsWith('- [ ] ')) {
        final text = line.trim().substring(6);
        _insertInlineFormatting(delta, text);
        delta.insert('\n', {'list': 'unchecked'});
      } else if (line.trim().startsWith('- ')) {
        final text = line.trim().substring(2);
        _insertInlineFormatting(delta, text);
        delta.insert('\n', {'list': 'bullet'});
      } else if (RegExp(r'^\d+\.\s').hasMatch(line.trim())) {
        final text = line.trim().replaceFirst(RegExp(r'^\d+\.\s'), '');
        _insertInlineFormatting(delta, text);
        delta.insert('\n', {'list': 'ordered'});
      } else if (line.trim().startsWith('> ')) {
        final text = line.trim().substring(2);
        _insertInlineFormatting(delta, text);
        delta.insert('\n', {'blockquote': true});
      } else if (line.trim().startsWith('```')) {
        // Parse optional language identifier after opening ```
        final openFence = line.trim();
        final language = openFence.length > 3
            ? openFence.substring(3).trim()
            : '';
        // Store language as the code-block attribute value when present,
        // otherwise fall back to boolean true for plain code blocks.
        final dynamic codeBlockValue =
            language.isNotEmpty ? language : true;

        if (i + 1 < lines.length) {
          i++; // Move to first code line
          // Each line gets its own code-block terminator so Quill treats
          // each as a proper code-block paragraph (not embedded \n in one op).
          while (i < lines.length && !lines[i].trim().startsWith('```')) {
            if (lines[i].isNotEmpty) {
              delta.insert(lines[i]);
            }
            delta.insert('\n', {'code-block': codeBlockValue});
            i++;
          }
          // 'i' now points to the closing ```; outer for-loop increments past it.
        }
      }
      // Regular line with inline formatting
      else {
        if (line.isEmpty && i < lines.length - 1) {
          delta.insert('\n');
        } else if (line.isNotEmpty) {
          _insertInlineFormatting(delta, line);
          if (i < lines.length - 1) {
            delta.insert('\n');
          }
        }
      }
    }

    // Ensure document ends with newline
    if (!markdown.endsWith('\n')) {
      delta.insert('\n');
    }

    return Document.fromDelta(delta);
  }

  /// Insert text with inline formatting (bold, italic, etc.)
  static void _insertInlineFormatting(Delta delta, String text) {
    if (text.isEmpty) {
      return;
    }

    int currentIndex = 0;
    final filteredMatches = MarkdownInlinePatterns.findNonOverlappingMatches(
      text,
      MarkdownInlinePatterns.quillAttributes,
    );

    // Insert text with formatting
    for (var matchEntry in filteredMatches) {
      final match = matchEntry.key;
      final attributes = matchEntry.value;

      // Insert text before match
      if (match.start > currentIndex) {
        delta.insert(text.substring(currentIndex, match.start));
      }

      // Insert formatted text
      final matchText = match.group(1) ?? '';
      delta.insert(matchText, attributes);
      currentIndex = match.end;
    }

    // Insert remaining text
    if (currentIndex < text.length) {
      delta.insert(text.substring(currentIndex));
    }
  }

  /// Convert Quill Document back to markdown (for export/backup/preview).
  ///
  /// Quill Delta structure: each "block" (paragraph, header, list item, etc.)
  /// is terminated by a `\n` op that carries the block-level attributes.
  /// Inline formatting attributes live on the text ops BEFORE the newline.
  /// Embed ops (images, videos, voice notes) have non-String data and are
  /// skipped so they never produce garbage characters in the output.
  static String documentToMarkdown(Document document) {
    final output = StringBuffer();
    final lineBuffer = StringBuffer();
    bool inCodeBlock = false;

    void flushLine(Map<String, dynamic>? blockAttrs) {
      final line = lineBuffer.toString();
      lineBuffer.clear();

      // Code-block lines: accumulate under a single ``` fence.
      // The value is either true (no language) or a language string.
      if (blockAttrs != null && blockAttrs['code-block'] != null) {
        if (!inCodeBlock) {
          final lang = blockAttrs['code-block'];
          final langSuffix =
              (lang is String && lang.isNotEmpty) ? lang : '';
          output.write('```$langSuffix\n');
          inCodeBlock = true;
        }
        output.write('$line\n');
        return;
      }

      // Close open code fence when leaving code-block
      if (inCodeBlock) {
        output.write('```\n');
        inCodeBlock = false;
      }

      if (blockAttrs != null) {
        if (blockAttrs.containsKey('header')) {
          final level = (blockAttrs['header'] as num?)?.toInt() ?? 1;
          output.write('${'#' * level} $line\n');
          return;
        }
        if (blockAttrs.containsKey('list')) {
          switch (blockAttrs['list']) {
            case 'bullet':
              output.write('- $line\n');
            case 'ordered':
              output.write('1. $line\n');
            case 'checked':
              output.write('- [x] $line\n');
            default: // 'unchecked'
              output.write('- [ ] $line\n');
          }
          return;
        }
        if (blockAttrs['blockquote'] == true) {
          output.write('> $line\n');
          return;
        }
      }

      output.write('$line\n');
    }

    for (final op in document.toDelta().toList()) {
      if (!op.isInsert) continue;
      // Handle non-string embeds: convert table embeds to Markdown, skip others.
      if (op.data is! String) {
        if (op.data is Map) {
          final map = op.data as Map;
          if (map.containsKey('custom')) {
            try {
              final customData =
                  jsonDecode(map['custom'] as String) as Map<String, dynamic>;
              final tableDataString = customData['table'] as String?;
              if (tableDataString != null) {
                final tableData =
                    jsonDecode(tableDataString) as Map<String, dynamic>;
                final rows = tableData['rows'] as int;
                final cols = tableData['cols'] as int;
                final rawCells = tableData['cells'] as List;
                final cells = List.generate(
                  rows,
                  (r) => List.generate(
                    cols,
                    (c) => (rawCells[r][c] as String).replaceAll('|', '\\|'),
                  ),
                );
                // Header row
                output.write('| ${cells[0].join(' | ')} |\n');
                // Separator row
                output.write('|${List.filled(cols, ' --- ').join('|')}|\n');
                // Data rows
                for (int r = 1; r < rows; r++) {
                  output.write('| ${cells[r].join(' | ')} |\n');
                }
              }
            } catch (_) {}
          }
        }
        continue;
      }

      final text = op.data as String;
      final attrs = op.attributes;

      if (text == '\n') {
        // This is the block terminator — flush the accumulated line
        flushLine(attrs);
      } else {
        // Inline text op — apply inline formatting then buffer it
        String formatted = text;
        if (attrs != null && attrs.isNotEmpty) {
          if (attrs['bold'] == true) formatted = '**$formatted**';
          if (attrs['italic'] == true) formatted = '*$formatted*';
          if (attrs['strike'] == true) formatted = '~~$formatted~~';
          if (attrs['code'] == true) formatted = '`$formatted`';
          if (attrs['underline'] == true) formatted = '<u>$formatted</u>';
          if (attrs.containsKey('background')) formatted = '==$formatted==';
          if (attrs.containsKey('link')) {
            final url = attrs['link'] as String? ?? '';
            if (url.startsWith('mention:')) {
              // Re-encode as @[Title](type:id) so _convertMentionsForMarkdown
              // can turn it into a tappable link in the preview.
              final parts = url.substring('mention:'.length).split(':');
              if (parts.length >= 2) {
                final type = parts[0];
                final id = parts.sublist(1).join(':');
                final title = formatted.startsWith('@')
                    ? formatted.substring(1)
                    : formatted;
                formatted = '@[$title]($type:$id)';
              }
            } else {
              formatted = '[$formatted]($url)';
            }
          }
        }
        lineBuffer.write(formatted);
      }
    }

    // Close any still-open code fence
    if (inCodeBlock) output.write('```\n');
    // Flush any remaining text that had no trailing newline op
    if (lineBuffer.isNotEmpty) output.write(lineBuffer.toString());

    return output.toString();
  }
}
