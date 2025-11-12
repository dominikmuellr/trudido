import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

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

      // Handle headers
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
      }
      // Handle checkboxes
      else if (line.trim().startsWith('- [x] ')) {
        final text = line.trim().substring(6);
        _insertInlineFormatting(delta, text);
        delta.insert('\n', {'list': 'checked'});
      } else if (line.trim().startsWith('- [ ] ')) {
        final text = line.trim().substring(6);
        _insertInlineFormatting(delta, text);
        delta.insert('\n', {'list': 'unchecked'});
      }
      // Handle bullet lists
      else if (line.trim().startsWith('- ')) {
        final text = line.trim().substring(2);
        _insertInlineFormatting(delta, text);
        delta.insert('\n', {'list': 'bullet'});
      }
      // Handle numbered lists
      else if (RegExp(r'^\d+\.\s').hasMatch(line.trim())) {
        final text = line.trim().replaceFirst(RegExp(r'^\d+\.\s'), '');
        _insertInlineFormatting(delta, text);
        delta.insert('\n', {'list': 'ordered'});
      }
      // Handle quotes
      else if (line.trim().startsWith('> ')) {
        final text = line.trim().substring(2);
        _insertInlineFormatting(delta, text);
        delta.insert('\n', {'blockquote': true});
      }
      // Handle code blocks
      else if (line.trim().startsWith('```')) {
        // Skip opening ```
        if (i + 1 < lines.length) {
          final codeLines = <String>[];
          i++; // Move to next line
          while (i < lines.length && !lines[i].trim().startsWith('```')) {
            codeLines.add(lines[i]);
            i++;
          }
          final codeText = codeLines.join('\n');
          delta.insert(codeText);
          delta.insert('\n', {'code-block': true});
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
    final patterns = <RegExp, Map<String, dynamic>>{
      // Bold patterns
      RegExp(r'\*\*([^*]+)\*\*'): {'bold': true},
      RegExp(r'__([^_]+)__'): {'bold': true},

      // Italic patterns (with lookbehind/lookahead to avoid matching ** or __)
      RegExp(r'(?<!\*)\*(?!\*)([^*]+)\*(?!\*)'): {'italic': true},
      RegExp(r'(?<!_)_(?!_)([^_]+)_(?!_)'): {'italic': true},

      // Other formatting
      RegExp(r'~~([^~]+)~~'): {'strike': true},
      RegExp(r'`([^`]+)`'): {'code': true},
      RegExp(r'<u>([^<]+)</u>'): {'underline': true},
      RegExp(r'==([^=]+)=='): {'background': '#ffff00'}, // Highlight
    };

    // Find all matches
    List<MapEntry<Match, Map<String, dynamic>>> allMatches = [];
    patterns.forEach((pattern, attributes) {
      for (var match in pattern.allMatches(text)) {
        allMatches.add(MapEntry(match, attributes));
      }
    });

    // Sort by position
    allMatches.sort((a, b) => a.key.start.compareTo(b.key.start));

    // Filter overlapping matches
    List<MapEntry<Match, Map<String, dynamic>>> filteredMatches = [];
    for (var matchEntry in allMatches) {
      final match = matchEntry.key;
      bool overlaps = filteredMatches.any(
        (existing) =>
            match.start < existing.key.end && match.end > existing.key.start,
      );
      if (!overlaps) {
        filteredMatches.add(matchEntry);
      }
    }

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

  /// Convert Quill Document back to markdown (for export/backup)
  static String documentToMarkdown(Document document) {
    final buffer = StringBuffer();
    final ops = document.toDelta().toList();

    for (var op in ops) {
      if (op.isInsert) {
        final text = op.data.toString();
        final attrs = op.attributes;

        if (attrs == null || attrs.isEmpty) {
          buffer.write(text);
          continue;
        }

        // Handle block-level formatting
        if (attrs.containsKey('header')) {
          final level = attrs['header'] as int;
          buffer.write('${'#' * level} ${text.replaceAll('\n', '')}');
          continue;
        }

        if (attrs.containsKey('list')) {
          final listType = attrs['list'];
          final cleanText = text.replaceAll('\n', '');
          if (listType == 'bullet') {
            buffer.write('- $cleanText');
          } else if (listType == 'ordered') {
            buffer.write('1. $cleanText');
          } else if (listType == 'checked') {
            buffer.write('- [x] $cleanText');
          } else if (listType == 'unchecked') {
            buffer.write('- [ ] $cleanText');
          }
          continue;
        }

        if (attrs.containsKey('blockquote')) {
          buffer.write('> ${text.replaceAll('\n', '')}');
          continue;
        }

        if (attrs.containsKey('code-block')) {
          buffer.write('```\n${text.replaceAll('\n', '')}\n```');
          continue;
        }

        // Handle inline formatting
        String formattedText = text;

        if (attrs.containsKey('bold') && attrs['bold'] == true) {
          formattedText = '**$formattedText**';
        }

        if (attrs.containsKey('italic') && attrs['italic'] == true) {
          formattedText = '*$formattedText*';
        }

        if (attrs.containsKey('strike') && attrs['strike'] == true) {
          formattedText = '~~$formattedText~~';
        }

        if (attrs.containsKey('code') && attrs['code'] == true) {
          formattedText = '`$formattedText`';
        }

        if (attrs.containsKey('underline') && attrs['underline'] == true) {
          formattedText = '<u>$formattedText</u>';
        }

        if (attrs.containsKey('background')) {
          formattedText = '==$formattedText==';
        }

        buffer.write(formattedText);
      }
    }

    return buffer.toString();
  }
}
