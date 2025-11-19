import 'package:flutter/material.dart';
import '../utils/responsive_size.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../models/note.dart';
import '../providers/app_providers.dart';
import '../services/theme_service.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

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
  });

  /// Checks if content is Quill JSON format
  bool _isQuillFormat() {
    return note.content.trim().startsWith('[');
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
  TextSpan _quillToTextSpan(BuildContext context) {
    try {
      final json = jsonDecode(note.content) as List;
      final migratedJson = _migrateFontSizes(json);
      final List<InlineSpan> spans = [];

      final baseStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        height: 1.3,
      );

      // Skip the title line if note has a title
      bool skipFirstLine = note.title.isNotEmpty;
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
              } catch (e) {}
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
    debugPrint('Note title: ${note.title}');

    // Check if this is a todo.txt note
    final isTodoTxt =
        note.todoTxtContent != null && note.todoTxtContent!.isNotEmpty;

    // Extract content structure - handle both Quill JSON and markdown
    final displayContent = _getDisplayContent();
    final contentLines = displayContent.split('\n');
    final subtitle = _extractSubtitle(contentLines);

    // Read swipe preference
    final preferences = ref.watch(preferencesStateProvider);
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
              ).colorScheme.onSurfaceVariant.withOpacity(0.5),
              fontStyle: FontStyle.italic,
            ),
          )
        : _parseMarkdownToTextSpan(note.title, context, isTitle: true);

    // For Quill notes, render with formatting; for markdown, parse structure
    final bodySpan = _isQuillFormat()
        ? _quillToTextSpan(context)
        : _parseMarkdownToTextSpan(
            _extractContentOnly(contentLines),
            context,
            isTitle: false,
          );
    debugPrint('Preview: bodySpan created successfully');

    final formattedDate = _formatCompactDate(note.updatedAt);

    return Dismissible(
      key: ValueKey(
        'dismissible_${note.id}',
      ), // Use ValueKey for better tracking
      // Background for startToEnd (user swiped right)
      background: actionStart == 'none'
          ? Container()
          : Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
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
                  const SizedBox(height: 4),
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
              padding: const EdgeInsets.only(right: 20),
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
                  const SizedBox(height: 4),
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
                  title: const Text('Delete Note'),
                  content: const Text(
                    'Are you sure you want to delete this note? This action cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Delete'),
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
            } catch (e) {}
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
      child: GestureDetector(
        onTap: onTap,
        onLongPress: () {
          // Show context menu on long press
          _showContextMenu(context);
        },
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          elevation: 0, // Modern MD3: flat design with no shadow
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest // Highest surface for best visibility
              : Theme.of(context)
                    .colorScheme
                    .surfaceContainer, // Balanced elevation in light mode
          child: Container(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                        const SizedBox(width: 8),
                      ],

                      // Title with lightweight markdown rendering
                      // CRITICAL: maxLines=1 prevents vertical overflow
                      Expanded(
                        child: RichText(
                          textScaler: MediaQuery.textScalerOf(context),
                          maxLines: 1, // ⭐ ESSENTIAL for preventing overflow
                          overflow:
                              TextOverflow.ellipsis, // ⭐ Graceful truncation
                          text: titleSpan,
                        ),
                      ),
                    ],
                  ),

                  // Subtitle (if exists)
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4), // Reduced from 6 to 4
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
                  else if (bodySpan.text?.isNotEmpty == true ||
                      bodySpan.children?.isNotEmpty == true) ...[
                    SizedBox(
                      height: subtitle.isNotEmpty ? 6 : 8,
                    ), // Less space if subtitle exists
                    // Show more lines to allow cards to expand with content
                    RichText(
                      textScaler: MediaQuery.textScalerOf(context),
                      maxLines: 8, // Allow more lines for variable height cards
                      overflow: TextOverflow.ellipsis,
                      text: bodySpan,
                    ),
                  ],

                  // Footer with metadata
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ScaledIcon(
                        Icons.schedule,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
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
        ),
      ),
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
    BuildContext context, {
    required bool isTitle,
  }) {
    if (text.isEmpty) return const TextSpan(text: '');

    final baseStyle = isTitle
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.2,
          )
        : Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.3,
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

    // Find all markdown formatting patterns
    // Use negative lookbehind/lookahead to avoid matching conflicts
    final patterns = <RegExp>[
      RegExp(r'\*\*([^*]+)\*\*'), // **bold**
      RegExp(r'(?<!\*)\*(?!\*)([^*]+)\*(?!\*)'), // *italic* but not part of **
      RegExp(r'__([^_]+)__'), // __bold__
      RegExp(r'(?<!_)_(?!_)([^_]+)_(?!_)'), // _italic_ but not part of __
      RegExp(r'~~([^~]+)~~'), // ~~strikethrough~~
      RegExp(r'==([^=]+)=='), // ==highlight==
      RegExp(r'`([^`]+)`'), // `code`
      RegExp(r'<u>([^<]+)</u>'), // <u>underline</u>
    ];

    // Create a list of all matches with their positions
    List<MapEntry<Match, String>> allMatches = [];

    for (RegExp pattern in patterns) {
      final matches = pattern.allMatches(text).toList();
      for (Match match in matches) {
        String type = '';
        if (pattern.pattern.contains(r'\*\*') ||
            pattern.pattern.contains(r'__')) {
          type = 'bold';
        } else if (pattern.pattern.contains(r'~~')) {
          type = 'strikethrough';
        } else if (pattern.pattern.contains(r'==')) {
          type = 'highlight';
        } else if (pattern.pattern.contains(r'<u>')) {
          type = 'underline';
        } else if (pattern.pattern.contains(r'\*') ||
            pattern.pattern.contains(r'_')) {
          type = 'italic';
        } else if (pattern.pattern.contains(r'`')) {
          type = 'code';
        }
        allMatches.add(MapEntry(match, type));
      }
    }

    // Sort matches by start position
    allMatches.sort((a, b) => a.key.start.compareTo(b.key.start));

    // Filter out overlapping matches - keep longer/earlier matches
    List<MapEntry<Match, String>> filteredMatches = [];
    for (var matchEntry in allMatches) {
      final match = matchEntry.key;
      bool overlaps = false;

      for (var existing in filteredMatches) {
        // Check if this match overlaps with an already-added match
        if (match.start < existing.key.end && match.end > existing.key.start) {
          overlaps = true;
          print(
            'DEBUG Card Parse - Skipping overlapping match "${match.group(0)}" at ${match.start}-${match.end} (overlaps with "${existing.key.group(0)}" at ${existing.key.start}-${existing.key.end})',
          );
          break;
        }
      }

      if (!overlaps) {
        filteredMatches.add(matchEntry);
      }
    }

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
            ).colorScheme.primaryContainer.withOpacity(0.5),
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

  String _formatCompactDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateDay = DateTime(date.year, date.month, date.day);
    final timeFormat = DateFormat('HH:mm');

    if (dateDay == today) {
      return 'Today ${timeFormat.format(date)}';
    } else if (dateDay == yesterday) {
      return 'Yesterday ${timeFormat.format(date)}';
    } else if (now.difference(date).inDays < 7) {
      // Within the last week, show day name and time
      return '${DateFormat('EEEE').format(date)} ${timeFormat.format(date)}';
    } else if (date.year == now.year) {
      // Same year, show day and month
      return DateFormat('d MMM').format(date);
    } else {
      // Different year, show full date
      return DateFormat('d MMM y').format(date);
    }
  }
}

// Demo implementation showing lightweight markdown rendering in action
class MarkdownPreviewDemo extends StatelessWidget {
  const MarkdownPreviewDemo({super.key});

  // Dummy data demonstrating various markdown formatting
  static final List<Note> _dummyNotes = [
    Note(
      id: '1',
      title: 'Rich Formatting Demo',
      content: '''# Project Planning Meeting

**Attendees**: John, Sarah, Mike, Lisa
*Location*: Conference Room B

## Action Items
The meeting went **very well**. We discussed the *project timeline* and identified key milestones.

Key points:
- Review `wireframes` by Friday
- Set up **development environment**  
- Create *initial* project structure

**Next meeting**: Monday 2PM in the `main conference room`.

The team agreed on using __Agile methodology__ for this project.''',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
      isPinned: true,
    ),
    Note(
      id: '2',
      title: 'Recipe with Formatting',
      content: '''## Chocolate Chip Cookies

**Ingredients**:
- 2 cups *all-purpose* flour
- 1 cup **butter** (softened)
- 3/4 cup `brown sugar`  
- 1/2 cup __white sugar__
- 2 _large_ eggs

**Instructions**: Mix dry ingredients. Cream `butter` and *sugars*. Add **eggs** and vanilla.''',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
      isPinned: false,
    ),
    Note(
      id: '3',
      title: 'Simple Note',
      content: '''Just a **quick reminder** to buy groceries tomorrow.

Items needed:
- *Fresh bread*
- `Organic milk`
- __Extra cheese__''',
      createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      isPinned: false,
    ),
    Note(
      id: '4',
      title: 'Code and Technical Notes',
      content: '''### Flutter Development Notes

This is a **technical** note with `code snippets` and formatting.

Key concepts:
- Use `maxLines` for **overflow prevention**
- Implement *lightweight* markdown parsing
- Optimize for __list performance__

Remember: **Performance** is _critical_ for smooth scrolling!''',
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 30)),
      isPinned: false,
    ),
    Note(
      id: '5',
      title: 'Mixed Formatting Test',
      content: '''# Long Note with **Mixed** Formatting

This note contains **bold text**, *italic text*, `code snippets`, and __underlined text__ to test our lightweight markdown parser.

## Performance Benefits

Our custom parser handles:
- **Bold formatting** with double asterisks
- *Italic text* with single asterisks  
- `Inline code` with backticks
- __Bold with underscores__
- _Italic with underscores_

## Why This Approach Works

The **key insight** is that full markdown packages are *overkill* for list previews. Our lightweight solution:

1. Maintains **smooth scrolling** performance
2. Provides *visual appeal* with formatting
3. Uses `TextSpan` for efficient rendering
4. Handles __overflow gracefully__

This approach gives us the **best of both worlds**: performance _and_ visual appeal!''',
      createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 2)),
      isPinned: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lightweight Markdown Previews'),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      ),
      body: Column(
        children: [
          // Information banner explaining the approach
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '✨ Lightweight Markdown Rendering',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'These cards use a custom, performance-optimized markdown parser that handles bold, italic, and code formatting without the overhead of full markdown packages.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),

          // List of notes with lightweight markdown rendering
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
              itemCount: _dummyNotes.length,
              itemBuilder: (context, index) {
                final note = _dummyNotes[index];
                return NotePreviewCard(
                  note: note,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Opened: ${note.title}'),
                        duration: const Duration(milliseconds: 800),
                      ),
                    );
                  },
                  onPin: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          note.isPinned ? 'Unpinned note' : 'Pinned note',
                        ),
                        duration: const Duration(milliseconds: 800),
                      ),
                    );
                  },
                  onDelete: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Deleted: ${note.title}'),
                        duration: const Duration(milliseconds: 800),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Example app to run the demo
class MarkdownPreviewApp extends StatelessWidget {
  const MarkdownPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lightweight Markdown Preview Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MarkdownPreviewDemo(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Uncomment to run as standalone app
// void main() {
//   runApp(const MarkdownPreviewApp());
// }

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
      final thumbnail = await VideoThumbnail.thumbnailFile(
        video: widget.videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 120, // Higher resolution for better quality
        quality: 75,
      );

      if (mounted) {
        setState(() {
          _thumbnailPath = thumbnail;
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
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.2)),
              child: Icon(
                Icons.play_circle_outline,
                size: 20,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
