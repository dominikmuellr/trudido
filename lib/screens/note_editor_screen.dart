import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:async';
import '../models/note.dart';
import '../controllers/notes_controller.dart';
import '../repositories/notes_repository.dart';
import '../services/storage_service.dart';
import '../utils/smart_markdown_helper.dart';

/// Screen for creating and editing markdown notes
class NoteEditorScreen extends ConsumerStatefulWidget {
  final String? noteId; // null for new note, ID for editing existing note

  const NoteEditorScreen({
    super.key,
    this.noteId,
  });

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> with TickerProviderStateMixin {
  late final TextEditingController _contentController;
  late final TabController _tabController;
  bool _isEditing = false;
  bool _hasUnsavedChanges = false;
  Note? _originalNote;
  Timer? _debounceTimer;
  Timer? _autoSaveTimer;
  String _saveStatus = '';
  static const Duration _autoSaveDuration = Duration(seconds: 1);
  static const Duration _previewDuration = Duration(milliseconds: 100);

  /// Builds a basic markdown formatting toolbar
  Widget _buildMarkdownToolbar() {
    return Material(
      elevation: 1,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Container(
        height: 56, // Standard Material toolbar height
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _toolbarButton(PhosphorIcons.textB(), '**', tooltip: 'Bold'),
                _toolbarButton(PhosphorIcons.textItalic(), '*', tooltip: 'Italic'),
                _toolbarButton(PhosphorIcons.textH(), '# ', tooltip: 'Heading'),
                _toolbarButton(PhosphorIcons.listBullets(), '- ', tooltip: 'List'),
                _toolbarButton(PhosphorIcons.table(), '\n| Header 1 | Header 2 |\n| --- | --- |\n| Row 1 Col 1 | Row 1 Col 2 |\n', tooltip: 'Table'),
                _toolbarButton(PhosphorIcons.code(), '\n```dart\ncode\n```\n', tooltip: 'Code Block'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Helper for toolbar buttons
  Widget _toolbarButton(IconData icon, String markdown, {String? tooltip}) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: () => _insertMarkdown(markdown),
      splashRadius: 24,
    );
  }

  /// Builds text style that makes the first line larger (title-like)
  TextStyle _buildContentTextStyle() {
    return Theme.of(context).textTheme.bodyLarge ?? const TextStyle();
  }

  /// Inserts markdown at the current cursor position
  void _insertMarkdown(String markdown) {
    final controller = _contentController;
    final text = controller.text;
    final selection = controller.selection;
  final newText = text.replaceRange(
      selection.start,
      selection.end,
      markdown,
    );
    controller.text = newText;
    // Move cursor after inserted markdown
    final newOffset = selection.start + markdown.length;
    controller.selection = TextSelection.collapsed(offset: newOffset);
  }

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController();
    _tabController = TabController(length: 2, vsync: this);
    _loadNote();
    _contentController.addListener(_onContentChanged);
  }

  Future<void> _loadNote() async {
    if (widget.noteId == null) return;

    final repository = ref.read(notesRepositoryProvider);

    // Try immediate sync read first. If notes storage isn't ready yet this
    // can return null which previously caused the editor to treat an
    // existing note as new and create duplicates on autosave. Wait for the
    // notes box to be ready and try again to reliably load the note.
    Note? note = repository.getNoteById(widget.noteId!);
    if (note == null) {
      await StorageService.waitNotesReady();
      note = repository.getNoteById(widget.noteId!);
    }

    if (note != null) {
      _originalNote = note;
      // When editing, put title and content together with title as first line
      final titleLine = _originalNote!.title;
      final contentLines = _originalNote!.content.split('\n');

      // If the stored content already contains the title (possibly with
      // markdown header prefixes like '#'), don't prepend the title again.
      // Compare a header-stripped first line to the saved title.
      if (contentLines.isNotEmpty) {
        final firstLineStripped = contentLines.first.trim().replaceFirst(RegExp(r'^#+\s*'), '');
        if (firstLineStripped == titleLine.trim()) {
          _contentController.text = _originalNote!.content;
        } else {
          _contentController.text = '$titleLine\n${_originalNote!.content}';
        }
      } else {
        _contentController.text = '$titleLine\n${_originalNote!.content}';
      }
      _isEditing = true;
    }
  }

  void _onContentChanged() {
    final content = _contentController.text;
    final lines = content.split('\n');
    final currentTitle = lines.isNotEmpty ? lines.first.trim() : '';
    
    final hasChanges = _originalNote == null
        ? content.isNotEmpty
        : currentTitle != _originalNote!.title ||
            content != ('${_originalNote!.title}\n${_originalNote!.content}');
    _debounceTimer?.cancel();
    _autoSaveTimer?.cancel();
    if (hasChanges != _hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = hasChanges;
      });
    }
    _debounceTimer = Timer(_previewDuration, () {
      if (mounted) {
        setState(() {});
      }
    });
    if (hasChanges) {
      _autoSaveTimer = Timer(_autoSaveDuration, () {
        if (mounted && _hasUnsavedChanges) {
          _performAutoSave();
        }
      });
    }
  }

  Future<void> _performAutoSave() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      setState(() {
            _saveStatus = 'Content required for save';
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _saveStatus = '';
          });
        }
      });
      return;
    }
    setState(() {
      _saveStatus = 'Auto-saving...';
    });
    try {
      await _saveNoteInternal(showFeedback: false);
      if (mounted) {
        setState(() {
          _saveStatus = 'Auto-saved';
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _saveStatus = '';
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saveStatus = 'Auto-save failed';
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _saveStatus = '';
            });
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _autoSaveTimer?.cancel();
    _contentController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _hasUnsavedChanges) {
          final shouldDiscard = await _showDiscardDialog();
          if (shouldDiscard == true && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Note' : 'New Note'),
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(icon: Icon(PhosphorIcons.pencil()), text: 'Editor'),
              Tab(icon: Icon(PhosphorIcons.eye()), text: 'Preview'),
            ],
          ),
          actions: [
            if (_saveStatus.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Icon(
                  _getStatusIcon(),
                  size: 20,
                  color: _getStatusColor(),
                ),
              ),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildEditorTab(),
            _buildPreviewTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorTab() {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    return Column(
      children: [
        // Sticky toolbar at the top
        _buildMarkdownToolbar(),
        // Scrollable content below
        Expanded(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, keyboardHeight + 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    hintText: 'Note title...\n\nStart writing your note here. The first line will be your title.',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  style: _buildContentTextStyle(),
                  minLines: 15,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  textAlignVertical: TextAlignVertical.top,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (value) {
                    setState(() {
                      // Trigger rebuild to update text styling
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Tip: First line becomes the title automatically. Use markdown syntax for formatting.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewTab() {
    final content = _contentController.text;
    
    // Extract title, subtitle, and remaining content separately
    final lines = content.split('\n');
    final firstLine = lines.isNotEmpty ? lines.first.trim() : '';
    final secondLine = lines.length > 1 ? lines[1].trim() : '';
    
    // Check if first line is a markdown header
    final isFirstLineHeader = firstLine.startsWith('#');
    final title = isFirstLineHeader ? firstLine.replaceFirst(RegExp(r'^#+\s*'), '') : firstLine;
    
    // Check if second line is a subtitle (H2)
    final isSecondLineSubtitle = secondLine.startsWith('## ');
    final subtitle = isSecondLineSubtitle ? secondLine.replaceFirst('## ', '') : '';
    
    // Extract content excluding title and subtitle lines
    int contentStartIndex = 1; // Skip title by default
    if (isSecondLineSubtitle) {
      contentStartIndex = 2; // Skip both title and subtitle
    }
    
    final contentOnly = lines.length > contentStartIndex 
        ? lines.skip(contentStartIndex).join('\n').trim() 
        : '';
    
    if (content.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIcons.fileText(),
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Nothing to preview yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Switch to the Editor tab to start writing',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
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
          if (contentOnly.isNotEmpty)
            MarkdownBody(
              data: contentOnly,
              selectable: true,
              styleSheet: SmartMarkdownHelper.createCompactStyleSheet(context).copyWith(
                p: Theme.of(context).textTheme.bodyLarge, // Larger body text
                listBullet: Theme.of(context).textTheme.bodyLarge, // Larger list text
                code: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
            )
          else if (isFirstLineHeader)
            Text(
              'Start writing content below the title...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _saveNoteInternal({bool showFeedback = true}) async {
    final rawContent = _contentController.text;
    
    // Auto-format content with markdown headers
    final formattedContent = _autoFormatWithHeaders(rawContent);
    
    // Extract title from first line of formatted content
    final lines = formattedContent.split('\n');
    final firstLine = lines.isNotEmpty ? lines.first.trim() : '';
    
    // Remove markdown header symbols for clean title storage
    final title = firstLine.isNotEmpty 
        ? firstLine.replaceFirst(RegExp(r'^#+\s*'), '') 
        : 'Untitled';
    
    if (rawContent.trim().isEmpty) {
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter some content for the note'),
            backgroundColor: Colors.red,
          ),
        );
      }
      throw Exception('Content cannot be empty');
    }
    
    final controller = ref.read(notesControllerProvider.notifier);
    Note? savedNote;
    // Prefer an existing note id from the loaded original note, fallback to
    // the widget.noteId (when editing via route). If we have an id, update
    // the existing note; otherwise create a new one.
    final existingId = _originalNote?.id ?? widget.noteId;
    final wasCreate = existingId == null;
    if (existingId != null) {
      savedNote = await controller.updateNote(
        id: existingId,
        title: title,
        content: formattedContent,
      );
      // Mark as editing from now on so subsequent saves will update.
      _isEditing = true;
    } else {
      savedNote = await controller.createNote(
        title: title,
        content: formattedContent,
      );
      if (savedNote != null) {
        // After creating, mark as editing so future autosaves update this note
        _isEditing = true;
      }
    }
    
    // Update the controller text with formatted content to reflect the changes
    if (_contentController.text != formattedContent) {
      _contentController.text = formattedContent;
      // Move cursor to end to avoid disruption
      _contentController.selection = TextSelection.fromPosition(
        TextPosition(offset: formattedContent.length),
      );
    }
    
    if (savedNote != null && mounted) {
      setState(() {
        _hasUnsavedChanges = false;
        _originalNote = savedNote;
      });
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing && !wasCreate ? 'Note updated successfully' : 'Note created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // If this was a manual create (not an update), close the editor as
        // previous behavior expected. For autosaves showFeedback is false so
        // we won't pop.
        if (wasCreate) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  /// Auto-formats content with markdown headers for first two lines
  String _autoFormatWithHeaders(String content) {
    final lines = content.split('\n');
    if (lines.isEmpty) return content;
    
    final processedLines = <String>[];
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      if (i == 0 && line.trim().isNotEmpty && !line.trim().startsWith('#')) {
        // First line becomes H1 if it's not already a header
        processedLines.add('# ${line.trim()}');
      } else if (i == 1 && line.trim().isNotEmpty && !line.trim().startsWith('#')) {
        // Second line becomes H2 if it's not already a header
        processedLines.add('## ${line.trim()}');
      } else {
        // Keep other lines as-is
        processedLines.add(line);
      }
    }
    
    return processedLines.join('\n');
  }

  Future<bool?> _showDiscardDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to leave without saving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    final colorScheme = Theme.of(context).colorScheme;
    switch (_saveStatus) {
      case 'Auto-saving...':
      case 'Saving...':
        return colorScheme.primary;
      case 'Auto-saved':
      case 'Saved':
        return colorScheme.primary;
      case 'Auto-save failed':
      case 'Save failed':
      case 'Title required for save':
        return colorScheme.error;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }

  IconData _getStatusIcon() {
    switch (_saveStatus) {
      case 'Auto-saving...':
      case 'Saving...':
        return PhosphorIcons.cloudArrowUp();
      case 'Auto-saved':
      case 'Saved':
        return PhosphorIcons.checkCircle();
      case 'Auto-save failed':
      case 'Save failed':
      case 'Title required for save':
        return PhosphorIcons.warning();
      default:
        return PhosphorIcons.info();
    }
  }
}