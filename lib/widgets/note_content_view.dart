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
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note.dart';
import '../utils/smart_markdown_helper.dart';
import '../utils/markdown_to_quill_converter.dart';
import '../utils/mention_parser.dart';
import '../utils/mention_navigator.dart';
import '../services/theme_service.dart';
import 'code_block_markdown_builder.dart';

/// Read-only note content renderer used by the freeform quick view popup.
///
/// Renders Quill JSON or markdown content with proper formatting,
/// code block highlighting, and clickable mentions.
class NoteContentView extends ConsumerStatefulWidget {
  final Note note;

  const NoteContentView({super.key, required this.note});

  @override
  ConsumerState<NoteContentView> createState() => _NoteContentViewState();
}

class _NoteContentViewState extends ConsumerState<NoteContentView> {
  quill.QuillController? _quillController;
  bool _isQuillFormat = false;

  @override
  void initState() {
    super.initState();
    _initializeContent();
  }

  void _initializeContent() {
    if (widget.note.content.trim().startsWith('[')) {
      try {
        final json = jsonDecode(widget.note.content);
        final migratedJson = _migrateFontSizes(json);
        final document = quill.Document.fromJson(migratedJson);
        _quillController = quill.QuillController(
          document: document,
          selection: const TextSelection.collapsed(offset: 0),
        );
        _quillController!.readOnly = true;
        _isQuillFormat = true;
      } catch (_) {
        _isQuillFormat = false;
      }
    }
  }

  List<dynamic> _migrateFontSizes(List<dynamic> deltaJson) {
    return deltaJson.map((op) {
      if (op is Map<String, dynamic>) {
        final attributes = op['attributes'];
        if (attributes is Map<String, dynamic> &&
            attributes.containsKey('size')) {
          final sizeValue = attributes['size'];
          if (sizeValue is String && sizeValue.endsWith('px')) {
            final cleanedSize = sizeValue.replaceAll(RegExp(r'px$'), '');
            final newAttributes = Map<String, dynamic>.from(attributes);
            newAttributes['size'] = cleanedSize;
            return {...op, 'attributes': newAttributes};
          }
        }
      }
      return op;
    }).toList();
  }

  @override
  void dispose() {
    _quillController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isQuillFormat && _quillController != null) {
      return SelectionArea(
        child: MarkdownBody(
          data: _convertMentionsForMarkdown(
            MarkdownToQuillConverter.documentToMarkdown(
              _quillController!.document,
            ),
          ),
          selectable: false,
          builders: {'pre': CodeBlockMarkdownBuilder()},
          onTapLink: (text, href, title) => _handleMentionTap(text, href),
          styleSheet: SmartMarkdownHelper.createStyleSheet(context).copyWith(
            p: Theme.of(context).textTheme.bodyLarge,
            listBullet: Theme.of(context).textTheme.bodyLarge,
            code: AppTheme.getCodeTextStyle(context).copyWith(
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.1),
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      );
    }

    final cleanContent = _getCleanContentWithoutTitleAndSubtitle(
      widget.note.content,
    );
    if (cleanContent.isNotEmpty) {
      return SelectionArea(
        child: MarkdownBody(
          data: _convertMentionsForMarkdown(cleanContent),
          selectable: false,
          builders: {'pre': CodeBlockMarkdownBuilder()},
          onTapLink: (text, href, title) => _handleMentionTap(text, href),
          styleSheet: SmartMarkdownHelper.createCompactStyleSheet(context)
              .copyWith(
                p: Theme.of(context).textTheme.bodyLarge,
                listBullet: Theme.of(context).textTheme.bodyLarge,
                code: AppTheme.getCodeTextStyle(context).copyWith(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.1),
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
        ),
      );
    }

    return Center(
      child: Column(
        children: [
          const SizedBox(height: 24),
          Icon(
            Icons.description,
            size: 48,
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant
                .withAlpha((255 * 0.5).round()),
          ),
          const SizedBox(height: 12),
          Text(
            'This note is empty',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _handleMentionTap(String text, String? href) {
    if (href != null && href.startsWith('mention:')) {
      final parts = href.substring('mention:'.length).split(':');
      if (parts.length >= 2) {
        final type = parts[0];
        final id = parts.sublist(1).join(':');
        MentionNavigator.navigateToMention(
          context,
          ref,
          MentionLink(
            title: text.replaceFirst('\u2060@', ''),
            type: type,
            id: id,
            start: 0,
            end: 0,
          ),
        );
      }
    }
  }

  String _getCleanContentWithoutTitleAndSubtitle(String content) {
    final lines = content.split('\n');
    if (lines.isEmpty) return '';

    bool titleFound = false;
    bool subtitleFound = false;
    List<String> contentLines = [];

    for (String line in lines) {
      if (!titleFound && line.trim().isNotEmpty) {
        titleFound = true;
        continue;
      }
      if (titleFound && !subtitleFound && line.trim().startsWith('## ')) {
        subtitleFound = true;
        continue;
      }
      if (titleFound) {
        contentLines.add(line);
      }
    }

    return contentLines.join('\n').trim();
  }

  String _convertMentionsForMarkdown(String text) {
    return text.replaceAllMapped(
      MentionParser.mentionPattern,
      (match) =>
          '[\u2060@${match.group(1)}](mention:${match.group(2)}:${match.group(3)})',
    );
  }
}
