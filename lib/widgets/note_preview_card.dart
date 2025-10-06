import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';

/// A clean, scannable preview card for displaying notes in a list
///
/// This widget handles notes of any length by:
/// - Using maxLines to limit text display
/// - Using TextOverflow.ellipsis to gracefully truncate long content
/// - Stripping markdown formatting for clean readable previews
class NotePreviewCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onPin;
  final VoidCallback? onDelete;

  const NotePreviewCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onPin,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Extract title and body from content
    final contentLines = note.content.split('\n');
    final title = _extractTitle(contentLines);
    final bodySnippet = _extractBodySnippet(contentLines);
    final formattedDate = DateFormat(
      'MMM d, y • h:mm a',
    ).format(note.updatedAt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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

                  // Title - CRITICAL: maxLines and overflow prevent layout overflow
                  Expanded(
                    child: Text(
                      title,
                      // maxLines: Limits title to exactly 1 line to prevent vertical overflow
                      maxLines: 1,
                      // overflow: Adds "..." when text exceeds the available space
                      // This is ESSENTIAL for preventing RenderFlex overflow errors
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.2, // Tight line height for consistent spacing
                      ),
                    ),
                  ),

                  // Action menu
                  if (onPin != null || onDelete != null) ...[
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      padding: EdgeInsets.zero,
                      onSelected: (value) {
                        switch (value) {
                          case 'pin':
                            onPin?.call();
                            break;
                          case 'delete':
                            onDelete?.call();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        if (onPin != null)
                          PopupMenuItem(
                            value: 'pin',
                            child: Row(
                              children: [
                                Icon(
                                  note.isPinned
                                      ? Icons.push_pin
                                      : Icons.push_pin_outlined,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(note.isPinned ? 'Unpin' : 'Pin'),
                              ],
                            ),
                          ),
                        if (onDelete != null)
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 16, color: Colors.red),
                                const SizedBox(width: 8),
                                const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),

              // Body snippet - CRITICAL: maxLines prevents overflow
              if (bodySnippet.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  bodySnippet,
                  // maxLines: Limits body to exactly 2 lines to prevent vertical overflow
                  // This is the KEY to preventing RenderFlex overflow in list views
                  maxLines: 2,
                  // overflow: Essential for graceful text truncation when content is too long
                  // Without this, long text would cause horizontal overflow errors
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.3, // Comfortable reading height
                  ),
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
    );
  }

  /// Extracts a clean title from the first line of content
  /// Removes markdown formatting for readable display
  String _extractTitle(List<String> contentLines) {
    if (contentLines.isEmpty) return 'Untitled';

    String firstNonEmptyLine = '';
    for (String line in contentLines) {
      if (line.trim().isNotEmpty) {
        firstNonEmptyLine = line.trim();
        break;
      }
    }

    if (firstNonEmptyLine.isEmpty) return 'Untitled';

    // Remove markdown formatting from title
    return _stripMarkdownFormatting(firstNonEmptyLine);
  }

  /// Extracts body snippet from remaining lines after the title
  /// Removes markdown formatting for clean preview
  String _extractBodySnippet(List<String> contentLines) {
    if (contentLines.isEmpty) return '';

    // Find the first non-empty line (which is the title) and skip it
    bool titleFound = false;
    List<String> bodyLines = [];

    for (String line in contentLines) {
      if (!titleFound && line.trim().isNotEmpty) {
        titleFound = true; // This is the title line, skip it
        continue;
      }

      if (titleFound && line.trim().isNotEmpty) {
        bodyLines.add(line.trim());
      }
    }

    if (bodyLines.isEmpty) return '';

    // Join the body lines and clean up markdown
    final bodyText = bodyLines.join(' ').trim();
    return _stripMarkdownFormatting(bodyText);
  }

  /// Strips markdown formatting to provide clean, readable text
  /// This prevents visual clutter in the preview cards
  String _stripMarkdownFormatting(String text) {
    return text
        // Remove headers
        .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
        // Remove bold/italic
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*([^*]+)\*'), r'$1')
        .replaceAll(RegExp(r'__([^_]+)__'), r'$1')
        .replaceAll(RegExp(r'_([^_]+)_'), r'$1')
        // Remove links
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
        // Remove inline code
        .replaceAll(RegExp(r'`([^`]+)`'), r'$1')
        // Remove list markers
        .replaceAll(RegExp(r'^\s*[-*+]\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*\d+\.\s*', multiLine: true), '')
        // Remove blockquotes
        .replaceAll(RegExp(r'^>\s*', multiLine: true), '')
        // Clean up whitespace
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Calculates word count for metadata display
  int _getWordCount(String content) {
    if (content.trim().isEmpty) return 0;
    return content.trim().split(RegExp(r'\s+')).length;
  }
}

// Demo implementation showing how to use the NotePreviewCard
class NotePreviewDemo extends StatelessWidget {
  const NotePreviewDemo({super.key});

  // Dummy data for demonstration
  static final List<Note> _dummyNotes = [
    Note(
      id: '1',
      title: 'Meeting Notes', // This will be ignored, title comes from content
      content: '''# Project Planning Meeting
      
**Attendees**: John, Sarah, Mike, Lisa

## Action Items
- [ ] Review wireframes by Friday
- [ ] Set up development environment
- [ ] Create initial project structure

## Notes
The meeting went well. We discussed the project timeline and identified key milestones. Everyone seems excited about the new features we're planning to implement.

**Next meeting**: Monday 2PM
*Location*: Conference Room B

### Technical Discussion
We need to consider the following technologies:
1. Flutter for mobile development
2. Firebase for backend services  
3. GitHub for version control

The team agreed on using **Agile methodology** for this project.''',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
      isPinned: true,
    ),
    Note(
      id: '2',
      title: 'Recipe',
      content: '''Chocolate Chip Cookies

*Ingredients*:
- 2 cups flour
- 1 cup butter
- 3/4 cup brown sugar  
- 1/2 cup white sugar
- 2 eggs
- 2 tsp vanilla
- 1 tsp baking soda
- 1 tsp salt
- 2 cups chocolate chips

**Instructions**: Mix dry ingredients. Cream butter and sugars. Add eggs and vanilla. Combine wet and dry ingredients. Fold in chocolate chips. Bake at 375°F for 9-11 minutes.''',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
      isPinned: false,
    ),
    Note(
      id: '3',
      title: 'Short Note',
      content: 'Just a quick reminder to buy groceries tomorrow.',
      createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      isPinned: false,
    ),
    Note(
      id: '4',
      title: 'Code Snippet',
      content: '''```dart
void main() {
  print('Hello, World!');
}
```

This is a simple Dart program that prints "Hello, World!" to the console.

## Usage
Run this code in any Dart environment or Flutter app.''',
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 30)),
      isPinned: false,
    ),
    Note(
      id: '5',
      title: 'Very Long Note',
      content:
          '''# Extremely Long Note with Lots of Content to Test Overflow Handling

This note contains a tremendous amount of text that would normally cause overflow issues in a poorly designed card component. The purpose of this note is to demonstrate how the NotePreviewCard widget gracefully handles extremely long content by using maxLines and TextOverflow.ellipsis properties.

## Section 1: The Problem
When displaying notes in a list view, developers often encounter RenderFlex overflow errors. This happens when text content exceeds the available space in the widget. The symptoms include:

- Yellow and black striped overflow indicators
- Broken layouts that don't fit on screen
- Poor user experience with unreadable content
- App crashes in extreme cases

## Section 2: The Solution  
The key to solving this problem lies in using Flutter's built-in text overflow handling:

### maxLines Property
This property limits the number of lines a Text widget can display. By setting maxLines: 1 for titles and maxLines: 2 for body text, we ensure consistent card heights and prevent vertical overflow.

### TextOverflow.ellipsis Property  
This property adds "..." at the end of truncated text, providing a visual indicator that there's more content available. This is crucial for user experience as it signals that tapping the card will reveal the full content.

## Section 3: Implementation Details
The NotePreviewCard widget implements these solutions by:

1. Extracting clean titles from the first line of content
2. Creating readable body snippets from remaining content
3. Stripping markdown formatting for clean display
4. Using consistent spacing and typography
5. Providing interactive elements like pin buttons and menus

## Section 4: Best Practices
When building similar components, remember:
- Always set maxLines for text that could be long
- Use TextOverflow.ellipsis for graceful truncation
- Test with extremely long content like this note
- Consider user experience when displaying truncated content
- Provide clear navigation to view full content

This approach ensures that your Flutter app remains stable and usable regardless of content length!''',
      createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 2)),
      isPinned: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Note Preview Cards Demo'),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _dummyNotes.length,
        itemBuilder: (context, index) {
          final note = _dummyNotes[index];
          return NotePreviewCard(
            note: note,
            onTap: () {
              // Handle note tap - navigate to detail view
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Tapped: ${note.title}'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            onPin: () {
              // Handle pin toggle
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
              // Handle delete
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
    );
  }
}

// Example app to run the demo
class NotePreviewApp extends StatelessWidget {
  const NotePreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Note Preview Card Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const NotePreviewDemo(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Uncomment to run as standalone app
// void main() {
//   runApp(const NotePreviewApp());
// }
