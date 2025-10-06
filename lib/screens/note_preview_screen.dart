import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../models/note.dart';
import '../utils/smart_markdown_helper.dart';
import '../services/theme_service.dart';
import 'note_editor_screen.dart';

/// Full-screen note preview that renders complete markdown
///
/// This screen displays the note's content with full markdown rendering
/// for the best reading experience. Users can navigate here via short tap
/// on the NotePreviewCard.
class NotePreviewScreen extends StatelessWidget {
  final Note note;

  const NotePreviewScreen({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          // Pin indicator
          if (note.isPinned)
            Icon(Icons.push_pin, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (note.title.isNotEmpty) ...[
              Text(
                note.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_getSubtitle(note.content).isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _getSubtitle(note.content),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
            ],

            // Full markdown content with same styling as editor preview
            if (_getCleanContentWithoutTitleAndSubtitle(
              note.content,
            ).isNotEmpty)
              MarkdownBody(
                data: _getCleanContentWithoutTitleAndSubtitle(note.content),
                selectable: true,
                styleSheet: SmartMarkdownHelper.createCompactStyleSheet(context)
                    .copyWith(
                      p: Theme.of(
                        context,
                      ).textTheme.bodyLarge, // Larger body text
                      listBullet: Theme.of(
                        context,
                      ).textTheme.bodyLarge, // Larger list text
                      code: AppTheme.getCodeTextStyle(context).copyWith(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                    ),
              )
            else
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    Icon(
                      Icons.description,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant
                          .withAlpha((255 * 0.5).round()),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'This note is empty',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to edit mode using existing editor
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => NoteEditorScreen(noteId: note.id),
            ),
          );
        },
        child: Icon(Icons.edit),
      ),
    );
  }

  /// Extracts subtitle from second line if it's an H2 header
  String _getSubtitle(String content) {
    final lines = content.split('\n');
    if (lines.length < 2) return '';

    final secondLine = lines[1].trim();
    if (secondLine.startsWith('## ')) {
      return secondLine.replaceFirst('## ', '');
    }

    return '';
  }

  /// Extracts content without title and subtitle lines but preserves other formatting
  String _getCleanContentWithoutTitleAndSubtitle(String content) {
    final lines = content.split('\n');
    if (lines.isEmpty) return '';

    // Skip the first non-empty line (title) and subtitle if present
    bool titleFound = false;
    bool subtitleFound = false;
    List<String> contentLines = [];

    for (String line in lines) {
      if (!titleFound && line.trim().isNotEmpty) {
        titleFound = true; // This is the title line, skip it
        continue;
      }

      if (titleFound && !subtitleFound && line.trim().startsWith('## ')) {
        subtitleFound = true; // This is the subtitle line, skip it
        continue;
      }

      if (titleFound) {
        contentLines.add(line);
      }
    }

    return contentLines.join('\n').trim();
  }
}
