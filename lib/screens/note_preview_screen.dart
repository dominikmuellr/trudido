import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'dart:convert';
import '../models/note.dart';
import '../utils/smart_markdown_helper.dart';
import '../utils/todo_txt_converter.dart';
import '../services/theme_service.dart';
import '../services/vault_auth_service.dart';
import '../repositories/note_folder_repository.dart';
import '../repositories/notes_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'quill_note_editor_screen.dart';

/// Full-screen note preview that renders complete markdown
///
/// This screen displays the note's content with full markdown rendering
/// for the best reading experience. Users can navigate here via short tap
/// on the NotePreviewCard.
class NotePreviewScreen extends ConsumerStatefulWidget {
  final Note note;

  const NotePreviewScreen({super.key, required this.note});

  @override
  ConsumerState<NotePreviewScreen> createState() => _NotePreviewScreenState();
}

class _NotePreviewScreenState extends ConsumerState<NotePreviewScreen> {
  late Note _currentNote;
  quill.QuillController? _quillController;
  bool _isQuillFormat = false;

  @override
  void initState() {
    super.initState();
    _currentNote = widget.note;
    _initializeContent();
  }

  void _initializeContent() {
    // Check if content is Quill JSON format
    if (_currentNote.content.trim().startsWith('[')) {
      try {
        final json = jsonDecode(_currentNote.content);
        final migratedJson = _migrateFontSizes(json);
        final document = quill.Document.fromJson(migratedJson);
        _quillController = quill.QuillController(
          document: document,
          selection: const TextSelection.collapsed(offset: 0),
        );
        _quillController!.readOnly = true;
        _isQuillFormat = true;
      } catch (e) {
        // If parsing fails, treat as markdown
        _isQuillFormat = false;
      }
    }
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

  @override
  void dispose() {
    _quillController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTodoTxt =
        _currentNote.todoTxtContent != null &&
        _currentNote.todoTxtContent!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        actions: [
          // Sort button for todo.txt notes
          if (isTodoTxt)
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              tooltip: 'Sort tasks',
              onSelected: (String sortType) {
                _sortTodoTxt(sortType);
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem(
                  value: 'priority',
                  child: Row(
                    children: [
                      Icon(Icons.priority_high, size: 18),
                      SizedBox(width: 8),
                      Text('By Priority'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'project',
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 18),
                      SizedBox(width: 8),
                      Text('By Project'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'context',
                  child: Row(
                    children: [
                      Icon(Icons.alternate_email, size: 18),
                      SizedBox(width: 8),
                      Text('By Context'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'completion',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 18),
                      SizedBox(width: 8),
                      Text('Done / Not Done'),
                    ],
                  ),
                ),
              ],
            ),
          // Pin indicator
          if (_currentNote.isPinned)
            Icon(Icons.push_pin, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_currentNote.title.isNotEmpty) ...[
              Text(
                _currentNote.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!isTodoTxt &&
                  _getSubtitle(_currentNote.content).isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _getSubtitle(_currentNote.content),
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

            // Show todo.txt preview, Quill content, or markdown content
            if (isTodoTxt)
              _buildTodoTxtPreview()
            else if (_isQuillFormat && _quillController != null)
              // Render Quill content with read-only editor
              quill.QuillEditor(
                controller: _quillController!,
                scrollController: ScrollController(),
                focusNode: FocusNode(),
                config: const quill.QuillEditorConfig(
                  readOnlyMouseCursor: SystemMouseCursors.text,
                  padding: EdgeInsets.zero,
                ),
              )
            else if (_getCleanContentWithoutTitleAndSubtitle(
              _currentNote.content,
            ).isNotEmpty)
              MarkdownBody(
                data: _getCleanContentWithoutTitleAndSubtitle(
                  _currentNote.content,
                ),
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
        onPressed: () async {
          // Check if note belongs to vault folder and require auth
          if (_currentNote.folderId != null) {
            final folderRepo = NoteFolderRepository();
            final folder = folderRepo.getNoteFolderById(_currentNote.folderId!);

            if (folder != null && folder.isVault) {
              // Require authentication for vault note editing
              final authenticated = await VaultAuthService.authenticate(
                context: context,
                folderId: folder.id,
                folderName: folder.name,
                useBiometric: folder.useBiometric,
                hasPassword: folder.hasPassword,
              );

              if (!authenticated) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Authentication required to edit vault notes',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }
            }
          }

          // Navigate to edit mode using WYSIWYG Quill editor
          if (context.mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    QuillNoteEditorScreen(noteId: _currentNote.id),
              ),
            );
          }
        },
        child: Icon(Icons.edit),
      ),
    );
  }

  void _sortTodoTxt(String sortType) async {
    String sorted;
    switch (sortType) {
      case 'priority':
        sorted = TodoTxtConverter.sortByPriority(_currentNote.todoTxtContent!);
        break;
      case 'project':
        sorted = TodoTxtConverter.sortByProject(_currentNote.todoTxtContent!);
        break;
      case 'context':
        sorted = TodoTxtConverter.sortByContext(_currentNote.todoTxtContent!);
        break;
      case 'completion':
        sorted = TodoTxtConverter.sortByCompletion(
          _currentNote.todoTxtContent!,
        );
        break;
      default:
        return;
    }

    // Update the note in the database
    final repository = ref.read(notesRepositoryProvider);
    final updatedNote = await repository.updateNote(
      id: _currentNote.id,
      title: _currentNote.title,
      content: _currentNote.content,
      todoTxtContent: sorted,
    );

    if (updatedNote != null) {
      setState(() {
        _currentNote = updatedNote;
      });
    }
  }

  void _toggleTaskCompletion(String line) async {
    final lines = (_currentNote.todoTxtContent ?? '').split('\n');
    final updatedLines = <String>[];

    for (var l in lines) {
      if (l.trim() == line.trim()) {
        // Toggle completion for this line
        if (l.trim().startsWith('x ')) {
          // Remove completion
          updatedLines.add(l.trim().substring(2).trim());
        } else {
          // Add completion
          updatedLines.add('x ${l.trim()}');
        }
      } else {
        updatedLines.add(l);
      }
    }

    final updatedContent = updatedLines.join('\n');

    // Update the note in the database
    final repository = ref.read(notesRepositoryProvider);
    final updatedNote = await repository.updateNote(
      id: _currentNote.id,
      title: _currentNote.title,
      content: _currentNote.content,
      todoTxtContent: updatedContent,
    );

    if (updatedNote != null) {
      setState(() {
        _currentNote = updatedNote;
      });
    }
  }

  Widget _buildTodoTxtPreview() {
    final todoTxtContent = _currentNote.todoTxtContent ?? '';
    final lines = todoTxtContent.split('\n');

    // Extract title (first line), subtitle (second line if not a task), and tasks
    // Title is already displayed from _currentNote.title, so we just skip it
    String subtitle = '';
    int tasksStartIndex = 0;

    if (lines.isNotEmpty) {
      // Skip first line (title)
      tasksStartIndex = 1;

      // Check if second line is a subtitle (not a task)
      if (lines.length > 1) {
        final secondLine = lines[1].trim();
        if (secondLine.isNotEmpty &&
            !secondLine.startsWith('x ') &&
            !RegExp(r'^\([A-Z]\)').hasMatch(secondLine) &&
            !secondLine.startsWith('#')) {
          subtitle = secondLine;
          tasksStartIndex = 2;
        }
      }
    }

    final tasks = <Widget>[];

    for (var i = tasksStartIndex; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) continue;

      // Skip comment lines but show them differently
      if (line.trim().startsWith('#')) {
        tasks.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              line,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        );
        continue;
      }

      tasks.add(_buildTodoTxtTaskCard(line));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Display title (already shown in AppBar area, but show subtitle here if present)
        if (subtitle.isNotEmpty) ...[
          Text(
            subtitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
        ],
        ...tasks,
      ],
    );
  }

  Widget _buildTodoTxtTaskCard(String line) {
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

    // Extract projects and contexts, and separate them from display text
    final projects = <String>[];
    final contexts = <String>[];
    final words = remaining.split(' ');
    final displayWords = <String>[];

    for (var word in words) {
      if (word.startsWith('+') && word.length > 1) {
        projects.add(word);
      } else if (word.startsWith('@') && word.length > 1) {
        contexts.add(word);
      } else {
        displayWords.add(word);
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isCompleted
          ? Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withOpacity(0.5)
          : Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: IconButton(
          icon: Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isCompleted
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          onPressed: () => _toggleTaskCompletion(line),
        ),
        title: Row(
          children: [
            if (priority != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getPriorityColor(priority),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  priority,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                displayWords.join(' '),
                style: TextStyle(
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                  color: isCompleted
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        subtitle: (projects.isNotEmpty || contexts.isNotEmpty)
            ? Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  ...projects.map(
                    (p) => Chip(
                      label: Text(p, style: const TextStyle(fontSize: 11)),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      side: BorderSide.none,
                    ),
                  ),
                  ...contexts.map(
                    (c) => Chip(
                      label: Text(c, style: const TextStyle(fontSize: 11)),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.secondaryContainer,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      side: BorderSide.none,
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
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
    print('DEBUG Preview - Full content: "$content"');

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

    final result = contentLines.join('\n').trim();
    print('DEBUG Preview - Cleaned content for markdown: "$result"');
    return result;
  }
}
