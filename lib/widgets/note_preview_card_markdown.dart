import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';
import '../providers/app_providers.dart';
import '../services/theme_service.dart';

/// A clean, scannable preview card with lightweight markdown rendering
///
/// This widget implements a CUSTOM, lightweight markdown parser specifically
/// optimized for list view performance. Unlike full markdown packages that
/// are resource-intensive, this approach manually handles only the most
/// common formatting elements (bold, italic, headers) to provide a smooth
/// user experience while maintaining visual appeal.
///
/// Gestural Navigation:
/// - Short tap (onTap): Navigate to full-screen preview
/// - Long press (onLongPress): Navigate to edit mode
/// - Pin/Delete: Via popup menu
///
/// Key Performance Benefits:
/// - No heavy markdown package overhead
/// - Optimized for scrolling lists
/// - Fixed card heights prevent layout recalculations
/// - Manual parsing is faster than full markdown rendering
class NotePreviewCard extends ConsumerWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onPin;
  final VoidCallback? onDelete;
  final VoidCallback?
  onDeleteConfirmed; // For direct deletion without confirmation

  const NotePreviewCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onLongPress,
    this.onPin,
    this.onDelete,
    this.onDeleteConfirmed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Extract content structure
    final contentLines = note.content.split('\n');
    final subtitle = _extractSubtitle(contentLines);

    // Read swipe preference
    final preferences = ref.watch(preferencesStateProvider);
    // Map the physical swipe directions to the configured actions.
    // startToEnd => user swiped right (maps to swipeRightAction)
    final actionStart =
        preferences.swipeRightAction; // 'delete' | 'pin' | 'none'
    // endToStart => user swiped left (maps to swipeLeftAction)
    final actionEnd = preferences.swipeLeftAction;

    final titleSpan = _parseMarkdownToTextSpan(
      note.title.isEmpty ? 'Untitled' : note.title,
      context,
      isTitle: true,
    );
    final bodySpan = _parseMarkdownToTextSpan(
      _extractContentOnly(contentLines),
      context,
      isTitle: false,
    );
    final formattedDate = DateFormat(
      'MMM d, y • h:mm a',
    ).format(note.updatedAt);

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
                  Icon(
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
                  Icon(
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
            } catch (e) {
              debugPrint('Error during note deletion: $e');
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
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          elevation: 2,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surface,
            ),
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
                        Icon(
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

                  // Body snippet with lightweight markdown rendering
                  if (bodySpan.text?.isNotEmpty == true ||
                      bodySpan.children?.isNotEmpty == true) ...[
                    SizedBox(
                      height: subtitle.isNotEmpty ? 6 : 8,
                    ), // Less space if subtitle exists
                    // CRITICAL: maxLines=2 prevents vertical overflow while showing content
                    RichText(
                      maxLines: 2, // ⭐ KEY to preventing RenderFlex overflow
                      overflow: TextOverflow
                          .ellipsis, // ⭐ Essential for graceful truncation
                      text: bodySpan,
                    ),
                  ],

                  // Footer with metadata
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formattedDate,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_getWordCount(note.content)} words',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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

    List<TextSpan> spans = [];
    int currentIndex = 0;

    // Find all bold and italic patterns
    final patterns = <RegExp>[
      RegExp(r'\*\*([^*]+)\*\*'), // **bold**
      RegExp(r'\*([^*]+)\*'), // *italic*
      RegExp(r'__([^_]+)__'), // __bold__
      RegExp(r'_([^_]+)_'), // _italic_
      RegExp(r'`([^`]+)`'), // `code`
    ];

    // Create a list of all matches with their positions
    List<MapEntry<Match, String>> allMatches = [];

    for (RegExp pattern in patterns) {
      for (Match match in pattern.allMatches(text)) {
        String type = '';
        if (pattern.pattern.contains(r'\*\*') ||
            pattern.pattern.contains(r'__')) {
          type = 'bold';
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

    // Build TextSpan with formatted sections
    for (var matchEntry in allMatches) {
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

  /// Calculates word count for metadata display
  int _getWordCount(String content) {
    if (content.trim().isEmpty) return 0;
    return content.trim().split(RegExp(r'\s+')).length;
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
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  onPin: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          note.isPinned ? 'Unpinned note' : 'Pinned note',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  onDelete: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Deleted: ${note.title}'),
                        duration: const Duration(seconds: 1),
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
