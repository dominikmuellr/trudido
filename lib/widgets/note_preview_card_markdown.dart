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
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../widgets/common/common.dart';
import '../theme/spacing_tokens.dart';

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

  /// Converts Quill Delta JSON to formatted TextSpan
  TextSpan _quillToTextSpan(
    BuildContext context,
    WidgetRef ref, {
    bool hideImages = false,
  }) {
    try {
      final json = jsonDecode(note.content) as List;
      final migratedJson = _migrateFontSizes(json);
      final List<InlineSpan> spans = [];

      final baseStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
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

      for (var op in migratedJson) {
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

                spans.add(TextSpan(text: remainingText, style: style));
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
                    borderRadius: BorderRadius.circular(4),
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
                            borderRadius: BorderRadius.circular(4),
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
                      borderRadius: BorderRadius.circular(4),
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
                      borderRadius: BorderRadius.circular(4),
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
                          borderRadius: BorderRadius.circular(4),
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
          }

          spans.add(TextSpan(text: text, style: style));
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

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Edit option
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                onTap();
              },
            ),
            // Pin/Unpin option
            if (onPin != null)
              ListTile(
                leading: Icon(
                  note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                ),
                title: Text(note.isPinned ? 'Unpin' : 'Pin'),
                onTap: () {
                  Navigator.pop(context);
                  onPin!();
                },
              ),
            // Move to folder option (only if not in vault)
            if (!isInVault && onMoveToFolder != null)
              ListTile(
                leading: const Icon(Icons.drive_file_move_outline),
                title: const Text('Move to Folder'),
                onTap: () {
                  Navigator.pop(context);
                  onMoveToFolder!();
                },
              ),
            // Delete option
            if (onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onDelete!();
                },
              ),
          ],
        ),
      ),
    );
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

    // Show title or placeholder for empty titles
    final titleSpan = note.title.isEmpty
        ? TextSpan(
            text: '(No title)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(
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
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                )
              : _parseMarkdownToTextSpan(
                  note.title,
                  context,
                  ref,
                  isTitle: true,
                ));

    // For Quill notes, render with formatting; for markdown, parse structure
    final contentText = _isQuillFormat()
        ? _extractPlainTextFromQuill()
        : _extractContentOnly(contentLines);

    final bodySpan = searchHighlight != null && searchHighlight!.isNotEmpty
        ? _applyHighlighting(
            contentText,
            context,
            Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          )
        : (_isQuillFormat()
              ? _quillToTextSpan(context, ref, hideImages: true)
              : _parseMarkdownToTextSpan(
                  contentText,
                  context,
                  ref,
                  isTitle: false,
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
      child: ExpressiveGestureDetector(
        onTap: onTap,
        onLongPress: () {
          // Show context menu on long press
          _showContextMenu(context);
        },
        child: _buildCard(
          context: context,
          spacing: spacing,
          titleSpan: titleSpan,
          subtitle: subtitle,
          isTodoTxt: isTodoTxt,
          bodySpan: bodySpan,
          formattedDate: formattedDate,
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
  }) {
    final cardColor = Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.08);

    final mainCard = Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: cardColor,
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
                      color: Theme.of(context).colorScheme.primary,
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
              if (subtitle.isNotEmpty) ...[
                SizedBox(height: spacing.s4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Body snippet - show todo.txt tasks or markdown content
              if (isTodoTxt)
                ..._buildTodoTxtPreview(context)
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

              // Expanded image banner
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
                      borderRadius: BorderRadius.circular(10),
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

              // Footer with metadata
              SizedBox(height: spacing.s12),
              Row(
                children: [
                  ScaledIcon(
                    Icons.schedule,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(width: spacing.s4),
                  Flexible(
                    child: Text(
                      formattedDate,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
        vertical: spacing.isCompact ? spacing.s2 : spacing.s4,
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
  }) {
    if (text.isEmpty) return const TextSpan(text: '');

    final baseStyle = isTitle
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.2,
            color: Theme.of(context).colorScheme.secondary,
          )
        : Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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

    List<TextSpan> spans = [];
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
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, match.start),
            style: baseStyle,
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
            decorationColor: Theme.of(context).colorScheme.onSurfaceVariant,
          );
          break;
        case 'underline':
          style = baseStyle?.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: Theme.of(context).colorScheme.onSurfaceVariant,
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
          style = AppTheme.getCodeTextStyle(context).copyWith(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            color: Theme.of(context).colorScheme.onSurface,
          );
          break;
      }

      spans.add(TextSpan(text: matchText, style: style));
      currentIndex = match.end;
    }

    // Add remaining text
    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex), style: baseStyle));
    }

    // If no formatting was found, return simple text span
    if (spans.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
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
        contentOnlyLines.add(trimmedLine);
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
          }
        }
      }

      return buffer.toString().trim();
    } catch (e) {
      return note.content;
    }
  }

  /// Builds a preview of todo.txt tasks (max 2 tasks shown)
  List<Widget> _buildTodoTxtPreview(BuildContext context) {
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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ];
    }

    return [
      const SizedBox(height: 8),
      ...lines.map((line) => _buildTodoTxtTaskPreview(context, line)),
    ];
  }

  /// Builds a compact preview of a single todo.txt task
  Widget _buildTodoTxtTaskPreview(BuildContext context, String line) {
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
            color: isCompleted
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
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
                ..._buildInlineTextWithChips(context, remaining, isCompleted),
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
    bool isCompleted,
  ) {
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
              color: isCompleted
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : null,
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
          borderRadius: BorderRadius.circular(4),
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
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          Icons.videocam,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
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
