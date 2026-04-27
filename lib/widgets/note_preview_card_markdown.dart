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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/responsive_size.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import '../models/note.dart';
import '../providers/app_providers.dart';
import '../services/theme_service.dart';
import '../utils/date_formatters.dart';
import '../utils/markdown_inline_patterns.dart';
import '../utils/mention_parser.dart';
import '../utils/note_colors.dart';
import '../utils/smart_markdown_helper.dart';
import '../utils/syntax_highlighter.dart';
import '../utils/language_detector.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../widgets/common/common.dart';
import '../theme/spacing_tokens.dart';
import '../repositories/note_folder_repository.dart';

/// A clean, scannable preview card with lightweight markdown rendering
///
/// This widget implements a CUSTOM, lightweight markdown parser specifically
/// optimized for list view performance. Unlike full markdown packages that
/// are resource-intensive, this approach manually handles only the most
/// common formatting elements (bold, italic, headers) to provide a smooth
/// user experience while maintaining visual appeal.
///
/// Gestural Navigation:
/// - Short tap (onTap): Navigate directly to edit mode
/// - Long press: Show context menu (Edit, Pin/Unpin, Move, Delete)
/// - Swipe: Pin or Delete (configurable in settings)
///
/// Key Performance Benefits:
/// - No heavy markdown package overhead
/// - Optimized for scrolling lists
/// - Fixed card heights prevent layout recalculations
/// - Manual parsing is faster than full markdown rendering
class NotePreviewCard extends ConsumerWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onPin;
  final VoidCallback? onDelete;
  final VoidCallback?
  onDeleteConfirmed; // For direct deletion without confirmation
  final VoidCallback? onMoveToFolder; // Move to different folder
  final bool isInVault; // Whether note is in a vault folder
  final bool
  showFormatIndicator; // Show .md/.txt indicator (only in All Notes view)
  final String? searchHighlight; // Search term to highlight
  final bool isGridView; // True when rendered inside the grid layout
  final void Function(int? colorValue)? onColorChange; // Set custom card color
  final bool selectable; // Whether multi-select mode is active
  final bool selected; // Whether this card is currently selected
  final VoidCallback?
  onSelectToggle; // Called on long-press to enter/toggle selection

  const NotePreviewCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onPin,
    this.onDelete,
    this.onDeleteConfirmed,
    this.onMoveToFolder,
    this.isInVault = false, // Default to not in vault
    this.showFormatIndicator = false, // Default to hidden
    this.searchHighlight,
    this.isGridView = false,
    this.onColorChange,
    this.selectable = false,
    this.selected = false,
    this.onSelectToggle,
  });

  /// Checks if content is Quill JSON format
  bool _isQuillFormat() {
    return note.content.trim().startsWith('[');
  }

  /// Returns true when a TextSpan (and all its children) contain only
  /// whitespace / newline text – used to suppress empty body sections.
  static bool _isSpanEffectivelyEmpty(InlineSpan span) {
    if (span is WidgetSpan) return false; // visible widget → not empty
    if (span is TextSpan) {
      final text = span.text;
      if (text != null && text.trim().isNotEmpty) return false;
      final children = span.children;
      if (children != null) {
        for (final child in children) {
          if (!_isSpanEffectivelyEmpty(child)) return false;
        }
      }
    }
    return true;
  }

  /// Extracts the file path of the first image embedded in the note.
  ///
  /// Handles both Quill JSON embeds and plain markdown `![]()` syntax.
  /// Returns `null` when no image is found or the file does not exist.
  String? _extractFirstImagePath() {
    try {
      if (_isQuillFormat()) {
        final dynamic decoded = jsonDecode(note.content);
        if (decoded is! List) return null;
        for (final op in decoded) {
          if (op is! Map) continue;
          final insertValue = op['insert'];
          if (insertValue is! Map) continue;

          String? mediaJson;
          if (insertValue.containsKey('custom')) {
            try {
              final parsed =
                  jsonDecode(insertValue['custom'] as String)
                      as Map<String, dynamic>;
              if (parsed.containsKey('media')) {
                mediaJson = parsed['media'] as String;
              }
            } catch (_) {}
          } else if (insertValue.containsKey('media')) {
            mediaJson = insertValue['media'] as String;
          }

          if (mediaJson != null) {
            try {
              final mediaData = jsonDecode(mediaJson) as Map<String, dynamic>;
              if (mediaData['type'] == 'image' && mediaData['path'] is String) {
                return mediaData['path'] as String;
              }
            } catch (_) {}
          }
        }
      } else {
        // Markdown format — find first `![alt](path)` pattern
        final match = RegExp(r'!\[.*?\]\((.+?)\)').firstMatch(note.content);
        if (match != null) return match.group(1);
      }
    } catch (_) {}
    return null;
  }

  /// Migrate old font size format from "18px" to "18"
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

  /// Extracts plain text content from either Quill JSON or markdown
  String _getDisplayContent() {
    // Check if content is Quill JSON format
    if (_isQuillFormat()) {
      try {
        final json = jsonDecode(note.content);
        final migratedJson = _migrateFontSizes(json);
        final document = quill.Document.fromJson(migratedJson);
        final plainText = document.toPlainText();
        return plainText;
      } catch (e) {
        // If parsing fails, treat as markdown
        return note.content;
      }
    }
    // Legacy markdown content
    return note.content;
  }

  /// Expands a text string into a list of [InlineSpan]s with mention links
  /// styled to match the note preview/view mode.
  List<InlineSpan> _expandMentions(
    String text,
    TextStyle? style,
    BuildContext context,
  ) {
    final mentions = MentionParser.extractMentions(text);
    if (mentions.isEmpty) {
      return [TextSpan(text: text, style: style)];
    }

    final mentionColor = SmartMarkdownHelper.getLinkColor(context);
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final mention in mentions) {
      if (mention.start > lastEnd) {
        spans.add(
          TextSpan(text: text.substring(lastEnd, mention.start), style: style),
        );
      }
      spans.add(
        TextSpan(
          text: '@${mention.title}',
          style: style?.copyWith(
            color: mentionColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      lastEnd = mention.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: style));
    }

    return spans;
  }

  /// Converts Quill Delta JSON to formatted TextSpan
  TextSpan _quillToTextSpan(
    BuildContext context,
    WidgetRef ref, {
    bool hideImages = false,
    Color? onCardColor,
  }) {
    try {
      final json = jsonDecode(note.content) as List;
      final migratedJson = _migrateFontSizes(json);
      final List<InlineSpan> spans = [];

      final baseStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: onCardColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
        height: note.lineHeightMultiplier,
      );

      // Check if the first line of content matches the title
      // Only skip if it's a duplicate (legacy notes had title in content)
      bool skipFirstLine = false;
      if (note.title.isNotEmpty && migratedJson.isNotEmpty) {
        final firstOp = migratedJson.first;
        if (firstOp is Map && firstOp.containsKey('insert')) {
          final firstText = firstOp['insert'];
          if (firstText is String) {
            final firstLine = firstText.split('\n').first.trim();
            // Only skip if first line matches title (legacy duplicated title)
            skipFirstLine = firstLine == note.title.trim();
          }
        }
      }
      bool firstLineSkipped = false;

      // Pre-pass: forward scan to identify code block groups and build
      // syntax-highlighted spans for each group.
      // In Quill Delta, code-block is a LINE-LEVEL attribute on '\n' ops.
      // Consecutive '\n' ops with code-block form a single logical block.
      final Map<int, List<InlineSpan>> codeBlockGroupSpans = {};
      final Set<int> codeBlockOpIndices = {};
      {
        final brightness = Theme.of(context).brightness;
        int groupStart = -1; // first op index of the current code block group
        int lineBufferStart =
            -1; // first op index of the current line's content
        final codeText = StringBuffer();
        String? groupLanguage;

        void flushGroup() {
          if (groupStart < 0) return;
          final raw = codeText.toString();
          final trimmed = raw.endsWith('\n')
              ? raw.substring(0, raw.length - 1)
              : raw;
          final lang =
              groupLanguage ?? LanguageDetector.detectLanguage(trimmed);
          final highlighted = CodeSyntaxHighlighter.highlightToSpans(
            trimmed,
            lang,
            brightness,
          );
          // Always use the full highlighted TextSpan (not just its children)
          // so that the monospace font and theme-correct default color
          // (from baseStyle + _defaultColor) are preserved via style inheritance.
          codeBlockGroupSpans[groupStart] = [highlighted];
          groupStart = -1;
          lineBufferStart = -1;
          codeText.clear();
          groupLanguage = null;
        }

        for (int si = 0; si < migratedJson.length; si++) {
          final sop = migratedJson[si];
          if (sop is! Map || !sop.containsKey('insert')) continue;
          final sInsert = sop['insert'];

          if (sInsert is! String) {
            // Embed — flush any open code block
            flushGroup();
            lineBufferStart = -1;
            continue;
          }

          if (sInsert != '\n' && !sInsert.contains('\n')) {
            // Plain content op (no newline) — accumulate into current line buffer
            if (lineBufferStart < 0) lineBufferStart = si;
            continue;
          }

          if (sInsert == '\n') {
            final sAttrs = sop['attributes'] as Map?;
            final codeBlockAttr = sAttrs?['code-block'];

            if (codeBlockAttr != null) {
              // Code-block line terminator — open/extend the current group
              if (groupStart < 0) {
                groupStart = lineBufferStart >= 0 ? lineBufferStart : si;
              }
              // Mark content ops belonging to this line
              if (lineBufferStart >= 0) {
                for (int ci = lineBufferStart; ci < si; ci++) {
                  final cop = migratedJson[ci];
                  codeBlockOpIndices.add(ci);
                  if (cop is Map && cop['insert'] is String) {
                    codeText.write(cop['insert'] as String);
                  }
                }
              }
              codeBlockOpIndices.add(si); // the '\n' op itself
              codeText.write('\n');
              // Capture explicit language (first non-trivial value wins)
              if (groupLanguage == null &&
                  codeBlockAttr is String &&
                  codeBlockAttr != 'true' &&
                  codeBlockAttr.isNotEmpty) {
                groupLanguage = codeBlockAttr;
              }
              lineBufferStart = -1;
            } else {
              // Normal line — flush any open code block
              flushGroup();
              lineBufferStart = -1;
            }
          } else {
            // Text op that contains embedded '\n' (multi-line insert) — flush
            flushGroup();
            lineBufferStart = -1;
          }
        }
        flushGroup(); // flush any trailing code block
      }

      for (int opIdx = 0; opIdx < migratedJson.length; opIdx++) {
        final op = migratedJson[opIdx];
        if (op is Map && op.containsKey('insert')) {
          final insertValue = op['insert'];

          // Skip text until we pass the first line (title) if needed
          if (skipFirstLine && !firstLineSkipped && insertValue is String) {
            final text = insertValue;
            if (text.contains('\n')) {
              // This text contains a newline - skip everything up to and including the first newline
              final firstNewlineIndex = text.indexOf('\n');
              final remainingText = text.substring(firstNewlineIndex + 1);
              firstLineSkipped = true;

              // If there's text after the first newline, process it
              if (remainingText.isNotEmpty) {
                final attributes = op['attributes'] as Map?;
                TextStyle style = baseStyle ?? const TextStyle();

                if (attributes != null) {
                  if (attributes['bold'] == true) {
                    style = style.copyWith(fontWeight: FontWeight.bold);
                  }
                  if (attributes['italic'] == true) {
                    style = style.copyWith(fontStyle: FontStyle.italic);
                  }
                  if (attributes['underline'] == true) {
                    style = style.copyWith(
                      decoration: TextDecoration.underline,
                    );
                  }
                  if (attributes['strike'] == true) {
                    style = style.copyWith(
                      decoration: TextDecoration.lineThrough,
                    );
                  }
                }

                spans.addAll(_expandMentions(remainingText, style, context));
              }
              continue;
            } else if (text.trim().isNotEmpty) {
              // This is title text without newline - skip it entirely
              continue;
            }
            // Empty text, just continue
            continue;
          }

          // Check if this is a custom embed (media)
          // Quill wraps custom embeds: {"insert": {"custom": "{\"media\":\"json_string\"}"}}
          if (insertValue is Map) {
            // Check for Quill custom embed wrapper
            String? mediaJson;
            if (insertValue.containsKey('custom')) {
              // New format: wrapped in "custom"
              final customData = insertValue['custom'] as String;
              // Parse the custom data to check if it contains media
              try {
                final parsed = jsonDecode(customData) as Map<String, dynamic>;
                if (parsed.containsKey('media')) {
                  mediaJson = parsed['media'] as String;
                }
              } catch (e) {
                // Ignore JSON parse errors for malformed custom data
              }
            } else if (insertValue.containsKey('media')) {
              // Old format: direct media key (fallback)
              mediaJson = insertValue['media'] as String;
            }

            if (mediaJson != null) {
              try {
                final mediaData = jsonDecode(mediaJson) as Map<String, dynamic>;
                final mediaType = mediaData['type'] as String;
                final mediaPath = mediaData['path'] as String?;

                Widget thumbnail;
                if (mediaType == 'image' && mediaPath != null) {
                  // When the big banner is shown, skip inline image thumbnails
                  if (hideImages) continue;
                  // Show actual image thumbnail
                  thumbnail = ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(mediaPath),
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.image,
                            size: 20,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        );
                      },
                    ),
                  );
                } else if (mediaType == 'video' && mediaPath != null) {
                  // Show actual video thumbnail with play icon overlay
                  thumbnail = VideoThumbnailWidget(videoPath: mediaPath);
                } else if (mediaType == 'voice') {
                  // Show audio waveform icon
                  thumbnail = Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.mic,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  );
                } else {
                  // Generic attachment icon
                  thumbnail = Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.attachment,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  );
                }

                spans.add(
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        right: 4,
                        top: 2,
                        bottom: 2,
                      ),
                      child: thumbnail,
                    ),
                  ),
                );
              } catch (e) {
                // If parsing fails, show generic attachment icon
                spans.add(
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        right: 4,
                        top: 2,
                        bottom: 2,
                      ),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.attachment,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              }
              continue;
            }
            // Other types of embeds (images, formulas, etc.) - skip them
            continue;
          }

          final text = op['insert'].toString();
          final attributes = op['attributes'] as Map?;

          TextStyle style = baseStyle ?? const TextStyle();

          if (attributes != null) {
            if (attributes['bold'] == true) {
              style = style.copyWith(fontWeight: FontWeight.bold);
            }
            if (attributes['italic'] == true) {
              style = style.copyWith(fontStyle: FontStyle.italic);
            }
            if (attributes['underline'] == true) {
              style = style.copyWith(decoration: TextDecoration.underline);
            }
            if (attributes['strike'] == true) {
              style = style.copyWith(decoration: TextDecoration.lineThrough);
            }
            if (attributes['header'] != null) {
              final headerLevel = attributes['header'] as int;
              style = style.copyWith(
                fontSize: headerLevel == 1 ? 20 : (headerLevel == 2 ? 18 : 16),
                fontWeight: FontWeight.bold,
              );
            }

            // Quill-format mentions: @Title with link="mention:type:id"
            final link = attributes['link'];
            if (link is String && link.startsWith('mention:')) {
              final mentionColor = SmartMarkdownHelper.getLinkColor(context);
              spans.add(
                TextSpan(
                  text: text,
                  style: style.copyWith(
                    color: mentionColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
              continue;
            }
          }

          // Skip ops that are part of a code block — handled by the pre-pass
          if (codeBlockOpIndices.contains(opIdx)) {
            if (codeBlockGroupSpans.containsKey(opIdx)) {
              spans.addAll(codeBlockGroupSpans[opIdx]!);
            }
            continue;
          }

          spans.addAll(_expandMentions(text, style, context));
        }
      }

      return TextSpan(
        children: spans.isEmpty
            ? [TextSpan(text: '', style: baseStyle)]
            : spans,
      );
    } catch (e) {
      // Fallback to plain text
      final fallbackText = _getDisplayContent();
      return TextSpan(
        text: fallbackText,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          height: 1.3,
        ),
      );
    }
  }

  void _showContextMenu(BuildContext context, Offset tapPosition) {
    if (!context.mounted) return;
    final overlayState = Overlay.maybeOf(context);
    final renderObject = overlayState?.context.findRenderObject();
    if (renderObject is! RenderBox) return;
    final overlay = renderObject;
    final position = RelativeRect.fromRect(
      tapPosition & const Size(1, 1),
      Offset.zero & overlay.size,
    );

    showMenu<void>(
      context: context,
      position: position,
      items: [
        // Edit option
        PopupMenuItem<void>(
          onTap: onTap,
          child: const ListTile(
            leading: Icon(Icons.edit),
            title: Text('Edit'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        // Pin/Unpin option
        if (onPin != null)
          PopupMenuItem<void>(
            onTap: onPin,
            child: ListTile(
              leading: Icon(
                note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              ),
              title: Text(note.isPinned ? 'Unpin' : 'Pin'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        // Card color picker
        if (onColorChange != null)
          PopupMenuItem<void>(
            onTap: () {
              final ctx = context;
              Future.microtask(() {
                if (ctx.mounted) _showColorPicker(ctx);
              });
            },
            child: ListTile(
              leading: Icon(
                Icons.palette_outlined,
                color: resolveNoteColor(
                  note.colorValue,
                  Theme.of(context).brightness,
                ),
              ),
              title: const Text('Card color'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        // Move to folder option (only if not in vault)
        if (!isInVault && onMoveToFolder != null)
          PopupMenuItem<void>(
            onTap: onMoveToFolder,
            child: const ListTile(
              leading: Icon(Icons.drive_file_move_outline),
              title: Text('Move to Folder'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        // Delete option
        if (onDelete != null)
          PopupMenuItem<void>(
            onTap: onDelete,
            child: const ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Delete', style: TextStyle(color: Colors.red)),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }

  static List<NoteColorOption> get _colorPalette => kNoteColorPalette;

  void _showColorPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Card color', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ..._colorPalette.map((option) {
                    final brightness = Theme.of(ctx).brightness;
                    final isSelected = option.index == note.colorValue;
                    final swatchColor =
                        option.colorForBrightness(brightness) ??
                        Theme.of(ctx).colorScheme.surfaceContainerHighest;
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        onColorChange!(option.index);
                      },
                      child: Tooltip(
                        message: option.label,
                        child: AnimatedScale(
                          scale: isSelected ? 1.15 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: swatchColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(ctx).colorScheme.primary
                                    : Theme.of(ctx).colorScheme.outline
                                          .withValues(alpha: 0.4),
                                width: isSelected ? 3 : 1.5,
                              ),
                            ),
                            child: option.index == null
                                ? Icon(
                                    Icons.format_color_reset,
                                    size: 20,
                                    color: Theme.of(
                                      ctx,
                                    ).colorScheme.onSurfaceVariant,
                                  )
                                : isSelected
                                ? Icon(
                                    Icons.check,
                                    size: 20,
                                    color: swatchColor.computeLuminance() > 0.4
                                        ? Colors.black87
                                        : Colors.white,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    );
                  }),
                  // Custom colour wheel swatch
                  _buildCustomColorSwatch(ctx, context),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomColorSwatch(BuildContext sheetCtx, BuildContext rootCtx) {
    final hasCustom = isCustomNoteColor(note.colorValue);
    final customColor = hasCustom ? Color(note.colorValue!) : null;
    return GestureDetector(
      onTap: () {
        Navigator.pop(sheetCtx);
        _showCustomColorPicker(rootCtx);
      },
      child: Tooltip(
        message: 'Custom',
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: customColor,
            shape: BoxShape.circle,
            gradient: customColor == null
                ? const SweepGradient(
                    colors: [
                      Color(0xFFFF0000),
                      Color(0xFFFFFF00),
                      Color(0xFF00FF00),
                      Color(0xFF00FFFF),
                      Color(0xFF0000FF),
                      Color(0xFFFF00FF),
                      Color(0xFFFF0000),
                    ],
                  )
                : null,
            border: Border.all(
              color: hasCustom
                  ? Theme.of(sheetCtx).colorScheme.primary
                  : Theme.of(
                      sheetCtx,
                    ).colorScheme.outline.withValues(alpha: 0.4),
              width: hasCustom ? 3 : 1.5,
            ),
          ),
          child: hasCustom
              ? Icon(
                  Icons.check,
                  size: 20,
                  color: customColor!.computeLuminance() > 0.4
                      ? Colors.black87
                      : Colors.white,
                )
              : const Icon(
                  Icons.colorize,
                  size: 18,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black38, blurRadius: 2)],
                ),
        ),
      ),
    );
  }

  Future<void> _showCustomColorPicker(BuildContext context) async {
    final hasCustom = isCustomNoteColor(note.colorValue);
    Color pickedColor = hasCustom
        ? Color(note.colorValue!)
        : const Color(0xFFE8DEF8);
    bool confirmed = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final lum = pickedColor.computeLuminance();
          final bool tooDark = lum < 0.06;
          final bool tooBright = lum > 0.90;
          final bool valid = !tooDark && !tooBright;
          return AlertDialog(
            title: const Text('Custom color'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ColorPicker(
                    color: pickedColor,
                    onColorChanged: (c) => setState(() => pickedColor = c),
                    pickersEnabled: const {
                      ColorPickerType.wheel: true,
                      ColorPickerType.accent: false,
                      ColorPickerType.primary: false,
                      ColorPickerType.bw: false,
                      ColorPickerType.custom: false,
                      ColorPickerType.customSecondary: false,
                    },
                    enableOpacity: false,
                    showColorCode: true,
                    colorCodeHasColor: true,
                    wheelDiameter: 280,
                  ),
                  if (!valid)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        tooDark
                            ? 'Color is too dark — pick a lighter shade'
                            : 'Color is too bright — pick a darker shade',
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.error,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: valid
                    ? () {
                        confirmed = true;
                        Navigator.pop(ctx);
                      }
                    : null,
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed) {
      onColorChange!(pickedColor.toARGB32());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if this is a todo.txt note
    final isTodoTxt =
        note.todoTxtContent != null && note.todoTxtContent!.isNotEmpty;

    // Extract content structure - handle both Quill JSON and markdown
    final displayContent = _getDisplayContent();
    final contentLines = displayContent.split('\n');
    final subtitle = _extractSubtitle(contentLines);

    // Read swipe preference
    final preferences = ref.watch(preferencesStateProvider);
    final spacing = ref.watch(adaptiveSpacingProvider);
    // Map the physical swipe directions to the configured actions.
    // startToEnd => user swiped right (maps to swipeRightAction)
    final actionStart =
        preferences.swipeRightAction; // 'delete' | 'pin' | 'none'
    // endToStart => user swiped left (maps to swipeLeftAction)
    final actionEnd = preferences.swipeLeftAction;

    // Compute adaptive on-card text colors so text stays readable on any
    // card background (palette or custom). Null when using theme default.
    final brightness = Theme.of(context).brightness;
    final explicitCardBg = resolveNoteColor(note.colorValue, brightness);
    Color? folderCardBg;
    if (note.folderId != null) {
      final folders = ref
          .watch(noteFoldersProvider)
          .maybeWhen(data: (value) => value, orElse: () => null);
      if (folders != null) {
        for (final folder in folders) {
          if (folder.id == note.folderId) {
            final alpha = brightness == Brightness.dark ? 0.32 : 0.16;
            folderCardBg = Color(folder.color).withValues(alpha: alpha);
            break;
          }
        }
      }
    }
    final cardBg = explicitCardBg ?? folderCardBg;
    final Color? onCardColor = cardBg != null
        ? (cardBg.computeLuminance() > 0.35
              ? const Color(0xDD000000) // black87
              : Colors.white)
        : null;
    final Color? onCardSecondary = cardBg != null
        ? (cardBg.computeLuminance() > 0.35
              ? const Color(0x8A000000) // black54
              : const Color(0xB3FFFFFF)) // white70
        : null;

    // Show title or placeholder for empty titles
    final titleSpan = note.title.isEmpty
        ? TextSpan(
            text: '(No title)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color:
                  onCardSecondary ??
                  Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              fontStyle: FontStyle.italic,
            ),
          )
        : (searchHighlight != null && searchHighlight!.isNotEmpty
              ? _applyHighlighting(
                  note.title,
                  context,
                  Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                )
              : _parseMarkdownToTextSpan(
                  note.title,
                  context,
                  ref,
                  isTitle: true,
                  onCardColor: onCardColor,
                ));

    // For Quill notes, render with formatting; for markdown, parse structure
    var contentText = _isQuillFormat()
        ? _extractPlainTextFromQuill()
        : _extractContentOnly(contentLines);

    // When searching, show a snippet around the first match instead of the beginning
    if (searchHighlight != null &&
        searchHighlight!.isNotEmpty &&
        contentText.isNotEmpty) {
      contentText = _extractSnippet(contentText, searchHighlight!);
    }

    final bodySpan = searchHighlight != null && searchHighlight!.isNotEmpty
        ? _applyHighlighting(
            contentText,
            context,
            Theme.of(context).textTheme.bodyMedium?.copyWith(
              color:
                  onCardColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          )
        : (_isQuillFormat()
              ? _quillToTextSpan(
                  context,
                  ref,
                  hideImages: true,
                  onCardColor: onCardSecondary,
                )
              : _parseMarkdownToTextSpan(
                  contentText,
                  context,
                  ref,
                  isTitle: false,
                  onCardColor: onCardSecondary,
                ));

    final formattedDate = _formatCompactDate(
      note.updatedAt,
      preferences.resolveUse24Hour(
        MediaQuery.of(context).alwaysUse24HourFormat,
      ),
    );

    return Dismissible(
      key: ValueKey(
        'dismissible_${note.id}',
      ), // Use ValueKey for better tracking
      direction: selectable
          ? DismissDirection.none
          : DismissDirection.horizontal,
      // Background for startToEnd (user swiped right)
      background: actionStart == 'none'
          ? Container()
          : Container(
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.only(left: spacing.s20),
              decoration: BoxDecoration(
                color: actionStart == 'delete'
                    ? Colors.red
                    : Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaledIcon(
                    actionStart == 'delete'
                        ? Icons.delete
                        : (note.isPinned
                              ? Icons.push_pin
                              : Icons.push_pin_outlined),
                    color: Colors.white,
                    size: 28,
                  ),
                  SizedBox(height: spacing.s4),
                  Text(
                    actionStart == 'delete'
                        ? 'DELETE'
                        : (note.isPinned ? 'UNPIN' : 'PIN'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
      // Background for endToStart (user swiped left)
      secondaryBackground: actionEnd == 'none'
          ? Container()
          : Container(
              alignment: Alignment.centerRight,
              padding: EdgeInsets.only(right: spacing.s20),
              decoration: BoxDecoration(
                color: actionEnd == 'delete'
                    ? Colors.red
                    : Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaledIcon(
                    actionEnd == 'delete'
                        ? Icons.delete
                        : (note.isPinned
                              ? Icons.push_pin
                              : Icons.push_pin_outlined),
                    color: Colors.white,
                    size: 28,
                  ),
                  SizedBox(height: spacing.s4),
                  Text(
                    actionEnd == 'delete'
                        ? 'DELETE'
                        : (note.isPinned ? 'UNPIN' : 'PIN'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
      confirmDismiss: (direction) async {
        // direction == startToEnd => user swiped right => maps to actionStart
        final isDeleteAction =
            (actionStart == 'delete' &&
                direction == DismissDirection.startToEnd) ||
            (actionEnd == 'delete' && direction == DismissDirection.endToStart);

        if (isDeleteAction) {
          // Delete action - show confirmation and handle deletion directly
          final confirmed =
              await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Move to Bin'),
                  content: const Text(
                    'Move this note to bin? You can restore it later from the Bin.',
                  ),
                  actions: [
                    ExpressiveTextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    ExpressiveTextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ExpressiveTextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Move to Bin'),
                    ),
                  ],
                ),
              ) ??
              false;

          if (confirmed) {
            // Perform the actual deletion here, before dismissing
            try {
              if (onDeleteConfirmed != null) {
                onDeleteConfirmed!.call();
              } else {
                onDelete?.call();
              }
            } catch (e) {
              // Ignore errors during note deletion
            }
          }

          return confirmed; // Allow dismissal only if confirmed and deleted
        } else {
          // Non-delete action: could be 'pin' or 'none'. Only run pin if configured.
          final action = direction == DismissDirection.startToEnd
              ? actionStart
              : actionEnd;
          if (action == 'pin') {
            onPin?.call();
          }
          return false; // Don't dismiss the card for pin/none actions
        }
      },
      onDismissed: (direction) {
        // This should now be empty since we handle everything in confirmDismiss
        // The deletion should already be completed by the time this is called
      },
      child: _NoteGestureHandler(
        onTap: selectable ? onSelectToggle : onTap,
        onLongPress: selectable
            ? null
            : onSelectToggle != null
            ? () {
                HapticFeedback.selectionClick();
                onSelectToggle!();
              }
            : null,
        onLongPressWithPosition: selectable || onSelectToggle != null
            ? null
            : (position) => _showContextMenu(context, position),
        child: Stack(
          children: [
            _buildCard(
              context: context,
              spacing: spacing,
              titleSpan: titleSpan,
              subtitle: subtitle,
              isTodoTxt: isTodoTxt,
              bodySpan: bodySpan,
              formattedDate: formattedDate,
              cardColor: cardBg,
              onCardColor: onCardColor,
              onCardSecondary: onCardSecondary,
              compactNotesView: preferences.compactNotesView,
            ),
            // Selection overlay
            if (selectable)
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: selected
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: selected
                        ? Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          )
                        : null,
                  ),
                ),
              ),
            if (selectable)
              Positioned(
                top: 8,
                right: 8,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 120),
                  child: selected
                      ? Icon(
                          Icons.check_circle,
                          key: const ValueKey('checked'),
                          color: Theme.of(context).colorScheme.primary,
                          size: 22,
                        )
                      : Icon(
                          Icons.radio_button_unchecked,
                          key: const ValueKey('unchecked'),
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          size: 22,
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required AdaptiveSpacing spacing,
    required TextSpan titleSpan,
    required String subtitle,
    required bool isTodoTxt,
    required TextSpan bodySpan,
    required String formattedDate,
    required bool compactNotesView,
    Color? cardColor,
    Color? onCardColor,
    Color? onCardSecondary,
  }) {
    final brightness = Theme.of(context).brightness;
    final effectiveCardColor =
        cardColor ?? Theme.of(context).colorScheme.surfaceContainerHigh;
    final allTags = note.tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    final visibleTags = allTags.take(3).toList();
    final hiddenTagsCount = allTags.length - visibleTags.length;
    final tagColor =
        (onCardSecondary ?? Theme.of(context).colorScheme.onSurfaceVariant)
            .withValues(alpha: 0.9);
    final tagBackground = tagColor.withValues(alpha: 0.14);

    final mainCard = Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: SpacingBorderRadius.lg,
        side: note.isPinned
            ? BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.4),
                width: 1.5,
              )
            : brightness == Brightness.light
            ? BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.5,
              )
            : BorderSide.none,
      ),
      color: effectiveCardColor,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: spacing.insets16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with pin indicator, title, and menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pin indicator
                  if (note.isPinned) ...[
                    ScaledIcon(
                      Icons.push_pin,
                      size: 16,
                      color:
                          onCardColor ?? Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(width: spacing.s8),
                  ],

                  // Title with lightweight markdown rendering
                  Expanded(
                    child: RichText(
                      textScaler: MediaQuery.textScalerOf(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: titleSpan,
                    ),
                  ),
                ],
              ),

              // Subtitle (if exists)
              if (!compactNotesView && subtitle.isNotEmpty) ...[
                SizedBox(height: spacing.s4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: onCardColor ?? Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Body snippet - show todo.txt tasks or markdown content
              if (!compactNotesView)
                if (isTodoTxt)
                  ..._buildTodoTxtPreview(context, onCardColor: onCardSecondary)
                else if (!_isSpanEffectivelyEmpty(bodySpan)) ...[
                  SizedBox(
                    height: subtitle.isNotEmpty ? spacing.s6 : spacing.s8,
                  ),
                  RichText(
                    textScaler: MediaQuery.textScalerOf(context),
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                    text: bodySpan,
                  ),
                ],

              // Table preview for Quill notes with embedded tables
              if (!compactNotesView)
                Builder(
                  builder: (context) {
                    final tableData = _extractFirstTableData();
                    if (tableData == null) return const SizedBox.shrink();
                    return Padding(
                      padding: EdgeInsets.only(top: spacing.s8),
                      child: _buildTablePreview(context, tableData),
                    );
                  },
                ),

              // Expanded image banner
              if (!compactNotesView)
                Builder(
                  builder: (context) {
                    final imagePath = _extractFirstImagePath();
                    if (imagePath == null) return const SizedBox.shrink();
                    final imageFile = File(imagePath);
                    if (!imageFile.existsSync()) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: EdgeInsets.only(top: spacing.s12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          imageFile,
                          width: double.infinity,
                          height: 160,
                          fit: isGridView ? BoxFit.cover : BoxFit.contain,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    );
                  },
                ),

              if (visibleTags.isNotEmpty) ...[
                SizedBox(height: compactNotesView ? spacing.s8 : spacing.s12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...visibleTags.map(
                      (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: tagBackground,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '#$tag',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: tagColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                    if (hiddenTagsCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: tagBackground,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '+$hiddenTagsCount',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: tagColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                  ],
                ),
              ],

              // Footer with metadata
              SizedBox(height: spacing.s12),
              Row(
                children: [
                  ScaledIcon(
                    Icons.schedule,
                    size: 14,
                    color:
                        (onCardSecondary ??
                                Theme.of(context).colorScheme.onSurfaceVariant)
                            .withValues(alpha: 0.55),
                  ),
                  SizedBox(width: spacing.s4),
                  Flexible(
                    child: Text(
                      formattedDate,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color:
                            (onCardSecondary ??
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant)
                                .withValues(alpha: 0.55),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.s8,
        vertical: spacing.isCompact ? spacing.s4 : spacing.s6,
      ),
      child: mainCard,
    );
  }

  /// LIGHTWEIGHT MARKDOWN PARSER
  ///
  /// This is the CORE of our performance-optimized solution. Instead of using
  /// a heavy markdown package, we manually parse only the most important
  /// formatting elements. This approach is:
  ///
  /// ✅ FAST: No package overhead, direct string processing
  /// ✅ LIGHTWEIGHT: Only handles essential formatting (bold, italic, headers)
  /// ✅ SMOOTH: Optimized for scrolling list performance
  /// ✅ VISUAL: Provides rich text formatting without performance cost
  ///
  /// This is the BEST PRACTICE for list view markdown previews!
  TextSpan _parseMarkdownToTextSpan(
    String text,
    BuildContext context,
    WidgetRef? ref, {
    required bool isTitle,
    Color? onCardColor,
  }) {
    if (text.isEmpty) return const TextSpan(text: '');

    final baseStyle = isTitle
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: onCardColor ?? Theme.of(context).colorScheme.secondary,
          )
        : Theme.of(context).textTheme.bodyMedium?.copyWith(
            color:
                onCardColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
            height: ref != null
                ? ref.watch(preferencesStateProvider).lineHeightMultiplier
                : 1.3,
          );

    // Handle headers first - strip # symbols and make them plain text
    // Headers in preview should not be huge, just slightly emphasized
    text = text.replaceAllMapped(RegExp(r'^#+\s*(.*)$', multiLine: true), (
      match,
    ) {
      return match.group(1) ?? '';
    });

    // Handle checkboxes - replace with Unicode checkbox characters
    text = text.replaceAllMapped(RegExp(r'^- \[x\]\s+', multiLine: true), (
      match,
    ) {
      return '☑ '; // Checked box
    });
    text = text.replaceAllMapped(RegExp(r'^- \[ \]\s+', multiLine: true), (
      match,
    ) {
      return '☐ '; // Unchecked box
    });

    // Handle list items - replace "- " at start of line with bullet
    text = text.replaceAllMapped(RegExp(r'^-\s+', multiLine: true), (match) {
      return '• '; // Replace with bullet character
    });

    // Handle numbered lists - keep as is
    // They already look good: 1. item, 2. item

    List<InlineSpan> spans = [];
    int currentIndex = 0;

    final filteredMatches = MarkdownInlinePatterns.findNonOverlappingMatches(
      text,
      MarkdownInlinePatterns.textStyles,
    );

    // Build TextSpan with formatted sections
    for (var matchEntry in filteredMatches) {
      final match = matchEntry.key;
      final type = matchEntry.value;

      // Add text before the match
      if (match.start > currentIndex) {
        spans.addAll(
          _expandMentions(
            text.substring(currentIndex, match.start),
            baseStyle,
            context,
          ),
        );
      }

      // Add the formatted match
      final matchText = match.group(1) ?? '';
      TextStyle? style;

      switch (type) {
        case 'bold':
          style = baseStyle?.copyWith(fontWeight: FontWeight.bold);
          break;
        case 'italic':
          style = baseStyle?.copyWith(fontStyle: FontStyle.italic);
          break;
        case 'strikethrough':
          style = baseStyle?.copyWith(
            decoration: TextDecoration.lineThrough,
            decorationColor:
                onCardColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
          );
          break;
        case 'underline':
          style = baseStyle?.copyWith(
            decoration: TextDecoration.underline,
            decorationColor:
                onCardColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
          );
          break;
        case 'highlight':
          style = baseStyle?.copyWith(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.5),
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          );
          break;
        case 'code':
          final codeColor =
              onCardColor ?? Theme.of(context).colorScheme.onSurface;
          style = AppTheme.getCodeTextStyle(context).copyWith(
            backgroundColor: codeColor.withValues(alpha: 0.12),
            color: codeColor,
          );
          break;
      }

      spans.addAll(_expandMentions(matchText, style, context));
      currentIndex = match.end;
    }

    // Add remaining text
    if (currentIndex < text.length) {
      spans.addAll(
        _expandMentions(text.substring(currentIndex), baseStyle, context),
      );
    }

    // If no formatting was found, return simple text span
    if (spans.isEmpty) {
      return TextSpan(children: _expandMentions(text, baseStyle, context));
    }

    return TextSpan(children: spans);
  }

  /// Extracts subtitle from second line if it's an H2 header
  String _extractSubtitle(List<String> contentLines) {
    if (contentLines.length < 2) return '';

    // Skip empty lines and find the second non-empty line
    bool titleFound = false;
    for (String line in contentLines) {
      if (line.trim().isEmpty) continue;

      if (!titleFound) {
        titleFound = true; // Skip title line
        continue;
      }

      // This is the second non-empty line - check if it's a subtitle
      if (line.trim().startsWith('## ')) {
        return line.trim().replaceFirst('## ', '');
      }

      break; // Stop after checking the second non-empty line
    }

    return '';
  }

  /// Extracts only content lines (excluding title and subtitle)
  String _extractContentOnly(List<String> contentLines) {
    if (contentLines.isEmpty) return '';

    // Skip title and subtitle, collect remaining content
    bool titleFound = false;
    bool subtitleFound = false;
    List<String> contentOnlyLines = [];

    for (String line in contentLines) {
      if (!titleFound && line.trim().isNotEmpty) {
        titleFound = true; // Skip title line
        continue;
      }

      if (titleFound && !subtitleFound && line.trim().startsWith('## ')) {
        subtitleFound = true; // Skip subtitle line
        continue;
      }

      if (titleFound && line.trim().isNotEmpty) {
        // Regular content line - clean up any remaining headers
        String trimmedLine = line.trim();
        if (trimmedLine.startsWith('### ') || trimmedLine.startsWith('#### ')) {
          trimmedLine = trimmedLine.replaceFirst(RegExp(r'^#+\s*'), '');
        }
        // Handle table rows: skip separator rows, extract cell text from data rows
        if (trimmedLine.startsWith('|')) {
          if (RegExp(r'^\|[\s\-:|]+\|?$').hasMatch(trimmedLine)) {
            continue; // Skip separator rows like |---|---|
          }
          final cells = trimmedLine
              .split('|')
              .map((cell) => cell.trim())
              .where((cell) => cell.isNotEmpty)
              .join(' · ');
          if (cells.isNotEmpty) contentOnlyLines.add(cells);
        } else {
          contentOnlyLines.add(trimmedLine);
        }
      }
    }

    return contentOnlyLines.join(' ').trim();
  }

  String _extractPlainTextFromQuill() {
    try {
      final List<dynamic> deltaJson = json.decode(note.content);
      final buffer = StringBuffer();

      for (final op in deltaJson) {
        if (op is Map && op.containsKey('insert')) {
          final insert = op['insert'];
          if (insert is String) {
            buffer.write(insert);
          } else if (insert is Map && insert.containsKey('custom')) {
            try {
              final parsed =
                  jsonDecode(insert['custom'] as String)
                      as Map<String, dynamic>;
              if (parsed.containsKey('table')) {
                final tableData =
                    jsonDecode(parsed['table'] as String)
                        as Map<String, dynamic>;
                final rawCells = tableData['cells'] as List;
                for (final row in rawCells) {
                  for (final cell in (row as List)) {
                    final text = (cell as String).trim();
                    if (text.isNotEmpty) buffer.write(' $text');
                  }
                }
              }
            } catch (_) {}
          }
        }
      }

      return buffer.toString().trim();
    } catch (e) {
      return note.content;
    }
  }

  /// Extracts the first table embed data from Quill JSON content.
  Map<String, dynamic>? _extractFirstTableData() {
    if (!_isQuillFormat()) return null;
    try {
      final List<dynamic> deltaJson = jsonDecode(note.content);
      for (final op in deltaJson) {
        if (op is! Map || !op.containsKey('insert')) continue;
        final insert = op['insert'];
        if (insert is! Map || !insert.containsKey('custom')) continue;
        try {
          final parsed =
              jsonDecode(insert['custom'] as String) as Map<String, dynamic>;
          if (parsed.containsKey('table')) {
            return jsonDecode(parsed['table'] as String)
                as Map<String, dynamic>;
          }
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  }

  /// Builds a compact mini-table widget for the note preview card.
  Widget _buildTablePreview(
    BuildContext context,
    Map<String, dynamic> tableData,
  ) {
    final theme = Theme.of(context);
    final rows = tableData['rows'] as int;
    final cols = tableData['cols'] as int;
    final rawCells = tableData['cells'] as List;
    final previewRows = rows > 3 ? 3 : rows;
    final previewCols = cols > 3 ? 3 : cols;
    final extraRows = rows - previewRows;
    final extraCols = cols - previewCols;
    final borderColor = theme.colorScheme.outlineVariant;
    final headerBg = theme.colorScheme.primaryContainer.withValues(alpha: 0.35);
    final moreStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontStyle: FontStyle.italic,
      fontSize: 11,
    );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...List.generate(previewRows, (r) {
            final isHeader = r == 0;
            return IntrinsicHeight(
              child: Row(
                children: [
                  ...List.generate(previewCols, (c) {
                    return Expanded(
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 28),
                        decoration: BoxDecoration(
                          color: isHeader
                              ? headerBg
                              : theme.colorScheme.surface.withValues(
                                  alpha: 0.5,
                                ),
                          border: Border(
                            right: c < previewCols - 1
                                ? BorderSide(color: borderColor, width: 0.5)
                                : BorderSide.none,
                            bottom: r < previewRows - 1
                                ? BorderSide(color: borderColor, width: 0.5)
                                : BorderSide.none,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Text(
                          (rawCells[r][c] as String).trim(),
                          style: isHeader
                              ? theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                )
                              : theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }),
                  if (extraCols > 0)
                    Container(
                      width: 28,
                      constraints: const BoxConstraints(minHeight: 28),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: borderColor, width: 0.5),
                          bottom: r < previewRows - 1
                              ? BorderSide(color: borderColor, width: 0.5)
                              : BorderSide.none,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: r == 0
                          ? Text('+$extraCols', style: moreStyle)
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
            );
          }),
          if (extraRows > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '+$extraRows more row${extraRows == 1 ? '' : 's'}',
                style: moreStyle,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  /// Builds a preview of todo.txt tasks (max 2 tasks shown)
  List<Widget> _buildTodoTxtPreview(
    BuildContext context, {
    Color? onCardColor,
  }) {
    final todoContent = note.todoTxtContent ?? '';
    final lines = todoContent
        .split('\n')
        .where((line) => line.trim().isNotEmpty && !line.trim().startsWith('#'))
        .take(8) // Show up to 8 tasks for variable height cards
        .toList();

    if (lines.isEmpty) {
      return [
        const SizedBox(height: 8),
        Text(
          'No tasks yet',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color:
                onCardColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ];
    }

    return [
      const SizedBox(height: 8),
      ...lines.map(
        (line) =>
            _buildTodoTxtTaskPreview(context, line, onCardColor: onCardColor),
      ),
    ];
  }

  /// Builds a compact preview of a single todo.txt task
  Widget _buildTodoTxtTaskPreview(
    BuildContext context,
    String line, {
    Color? onCardColor,
  }) {
    var remaining = line.trim();
    var isCompleted = false;
    String? priority;

    // Check for completion
    if (remaining.startsWith('x ')) {
      isCompleted = true;
      remaining = remaining.substring(2).trim();
    }

    // Check for priority
    final priorityMatch = RegExp(r'^\(([A-Z])\)\s+(.*)').firstMatch(remaining);
    if (priorityMatch != null) {
      priority = priorityMatch.group(1);
      remaining = priorityMatch.group(2) ?? '';
    }

    // Extract ALL projects and contexts
    final projects = <String>[];
    final contexts = <String>[];
    final projectMatches = RegExp(r'\+(\w+)').allMatches(remaining);
    final contextMatches = RegExp(r'@(\w+)').allMatches(remaining);

    for (var match in projectMatches) {
      projects.add(match.group(1)!);
    }
    for (var match in contextMatches) {
      contexts.add(match.group(1)!);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCompleted ? Icons.check_box : Icons.check_box_outline_blank,
            size: 16,
            color:
                onCardColor ??
                (isCompleted
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Priority badge
                if (priority != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(priority),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      priority,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
                // Task text with inline chips for tags
                ..._buildInlineTextWithChips(
                  context,
                  remaining,
                  isCompleted,
                  onCardColor: onCardColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds inline text with chips for +project and @context tags
  List<Widget> _buildInlineTextWithChips(
    BuildContext context,
    String text,
    bool isCompleted, {
    Color? onCardColor,
  }) {
    final widgets = <Widget>[];
    final words = text.split(' ');

    for (var i = 0; i < words.length; i++) {
      final word = words[i];

      // Check for tags (only alphanumeric after + or @)
      final projectMatch = RegExp(r'^(\+\w+)').firstMatch(word);
      final contextMatch = RegExp(r'^(@\w+)').firstMatch(word);

      if (projectMatch != null && word.length > 1) {
        // Project tag - render as chip (includes punctuation in the chip)
        widgets.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              word,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        );
      } else if (contextMatch != null && word.length > 1) {
        // Context tag - render as chip (includes punctuation in the chip)
        widgets.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              word,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        );
      } else {
        // Regular text
        widgets.add(
          Text(
            word,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              decoration: isCompleted ? TextDecoration.lineThrough : null,
              color:
                  onCardColor ??
                  (isCompleted
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : null),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'A':
        return Colors.red;
      case 'B':
        return Colors.orange;
      case 'C':
        return Colors.yellow.shade700;
      default:
        return Colors.grey;
    }
  }

  String _formatCompactDate(DateTime date, bool use24Hour) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateDay = DateTime(date.year, date.month, date.day);

    if (dateDay == today) {
      return 'Today ${DateFormatters.formatTime(date, use24Hour: use24Hour)}';
    } else if (dateDay == yesterday) {
      return 'Yesterday ${DateFormatters.formatTime(date, use24Hour: use24Hour)}';
    } else if (now.difference(date).inDays < 7) {
      // Within the last week, show day name and time
      return '${DateFormat('EEEE').format(date)} ${DateFormatters.formatTime(date, use24Hour: use24Hour)}';
    } else if (date.year == now.year) {
      // Same year, show day and month
      return DateFormat('d MMM').format(date);
    } else {
      // Different year, show full date
      return DateFormat('d MMM y').format(date);
    }
  }

  /// Extracts a short snippet around the first match of [query] in [content].
  String _extractSnippet(String content, String query, {int radius = 80}) {
    final lowerContent = content.toLowerCase();
    // Try each token from the query
    final tokens = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty);
    int matchIndex = -1;
    for (final token in tokens) {
      matchIndex = lowerContent.indexOf(token);
      if (matchIndex != -1) break;
    }
    if (matchIndex == -1) return content; // No match found, show as-is

    final start = (matchIndex - radius).clamp(0, content.length);
    final end = (matchIndex + query.length + radius).clamp(0, content.length);
    final prefix = start > 0 ? '...' : '';
    final suffix = end < content.length ? '...' : '';
    return '$prefix${content.substring(start, end)}$suffix';
  }

  TextSpan _applyHighlighting(
    String text,
    BuildContext context,
    TextStyle? baseStyle,
  ) {
    if (searchHighlight == null || searchHighlight!.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final lowerText = text.toLowerCase();
    final lowerHighlight = searchHighlight!.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerHighlight, start);
      if (index == -1) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        }
        break;
      }

      if (index > start) {
        spans.add(
          TextSpan(text: text.substring(start, index), style: baseStyle),
        );
      }

      spans.add(
        TextSpan(
          text: text.substring(index, index + searchHighlight!.length),
          style:
              baseStyle?.copyWith(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ) ??
              TextStyle(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
        ),
      );

      start = index + searchHighlight!.length;
    }

    return TextSpan(children: spans);
  }
}

/// Widget to display video thumbnail with play button overlay
class VideoThumbnailWidget extends StatefulWidget {
  final String videoPath;

  const VideoThumbnailWidget({super.key, required this.videoPath});

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  String? _thumbnailPath;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    try {
      // Generate temp file path first
      final tempDir = await getTemporaryDirectory();
      final thumbPath =
          '${tempDir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final success = await FcNativeVideoThumbnail().getVideoThumbnail(
        srcFile: widget.videoPath,
        destFile: thumbPath,
        width: 240,
        height: 180,
        quality: 75,
        format: 'jpeg',
      );

      if (mounted && success) {
        setState(() {
          _thumbnailPath = thumbPath;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_hasError || _thumbnailPath == null) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.videocam,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          Image.file(
            File(_thumbnailPath!),
            width: 40,
            height: 40,
            fit: BoxFit.cover,
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
              ),
              child: Icon(
                Icons.play_circle_outline,
                size: 20,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gesture handler that captures position for long-press context menu
// ---------------------------------------------------------------------------
class _NoteGestureHandler extends StatefulWidget {
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final void Function(Offset position)? onLongPressWithPosition;
  final Widget child;

  const _NoteGestureHandler({
    this.onTap,
    this.onLongPress,
    this.onLongPressWithPosition,
    required this.child,
  });

  @override
  State<_NoteGestureHandler> createState() => _NoteGestureHandlerState();
}

class _NoteGestureHandlerState extends State<_NoteGestureHandler> {
  Offset _lastPointerPosition = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) => _lastPointerPosition = event.position,
      child: ExpressiveGestureDetector(
        onTap: widget.onTap,
        onLongPress:
            widget.onLongPress ??
            (widget.onLongPressWithPosition != null
                ? () => widget.onLongPressWithPosition!(_lastPointerPosition)
                : null),
        child: widget.child,
      ),
    );
  }
}
