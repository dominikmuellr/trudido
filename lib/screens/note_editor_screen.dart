import 'package:flutter/material.dart';
import 'package:trudido/utils/responsive_size.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'dart:async';
import '../models/note.dart';
import '../controllers/notes_controller.dart';
import '../repositories/notes_repository.dart';
import '../utils/smart_markdown_helper.dart';
import '../services/theme_service.dart';
import '../utils/todo_txt_converter.dart';

/// Screen for creating and editing markdown notes
class NoteEditorScreen extends ConsumerStatefulWidget {
  final String? noteId; // null for new note, ID for editing existing note
  final String? initialFolderId; // folder to save new note in

  const NoteEditorScreen({super.key, this.noteId, this.initialFolderId});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen>
    with TickerProviderStateMixin {
  late final TextEditingController _contentController;
  late final TextEditingController _todoTxtController;
  late final TextEditingController _todoTxtTitleController;
  late final TabController _tabController;
  bool _isEditing = false;
  bool _hasUnsavedChanges = false;
  Note? _originalNote;
  Timer? _debounceTimer;
  Timer? _autoSaveTimer;
  String _saveStatus = '';
  static const Duration _autoSaveDuration = Duration(seconds: 1);
  static const Duration _previewDuration = Duration(milliseconds: 100);

  // View mode: 'markdown' or 'todotxt'
  String _viewMode = 'markdown';

  // Static variable to remember last used mode across all notes
  static String _lastUsedMode = 'markdown';

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
                _toolbarButton(Icons.format_bold, '**', tooltip: 'Bold'),
                _toolbarButton(Icons.format_italic, '*', tooltip: 'Italic'),
                _toolbarButton(Icons.title, '# ', tooltip: 'Heading'),
                _toolbarButton(
                  Icons.format_list_bulleted,
                  '- ',
                  tooltip: 'List',
                ),
                _toolbarButton(
                  Icons.table_chart,
                  '\n| Header 1 | Header 2 |\n| --- | --- |\n| Row 1 Col 1 | Row 1 Col 2 |\n',
                  tooltip: 'Table',
                ),
                _toolbarButton(
                  Icons.code,
                  '\n```dart\ncode\n```\n',
                  tooltip: 'Code Block',
                ),
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
      icon: ScaledIcon(icon),
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
    final newText = text.replaceRange(selection.start, selection.end, markdown);
    controller.text = newText;
    // Move cursor after inserted markdown
    final newOffset = selection.start + markdown.length;
    controller.selection = TextSelection.collapsed(offset: newOffset);
  }

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController();
    _todoTxtController = TextEditingController();
    _todoTxtTitleController = TextEditingController();
    _tabController = TabController(length: 2, vsync: this);

    // For new notes, use the last used mode
    if (widget.noteId == null) {
      _viewMode = _lastUsedMode;
    }

    _loadNote();
    _contentController.addListener(_onContentChanged);
    _todoTxtController.addListener(_onTodoTxtChanged);
    _todoTxtTitleController.addListener(_onTodoTxtChanged);

    print(
      'NoteEditor initialized: noteId=${widget.noteId}, viewMode=$_viewMode',
    );
  }

  Future<void> _loadNote() async {
    if (widget.noteId == null) return;

    final repository = ref.read(notesRepositoryProvider);

    // Try immediate sync read first. If notes storage isn't ready yet this
    // can return null which previously caused the editor to treat an
    // existing note as new and create duplicates on autosave. Wait for the
    // notes box to be ready and try again to reliably load the note.
    Note? note = await repository.getNoteById(widget.noteId!);

    _originalNote = note;
    // When editing, put title and content together with title as first line
    final titleLine = _originalNote!.title;
    final contentLines = _originalNote!.content.split('\n');

    // If the stored content already contains the title (possibly with
    // markdown header prefixes like '#'), don't prepend the title again.
    // Compare a header-stripped first line to the saved title.
    if (contentLines.isNotEmpty) {
      final firstLineStripped = contentLines.first.trim().replaceFirst(
        RegExp(r'^#+\s*'),
        '',
      );
      if (firstLineStripped == titleLine.trim()) {
        _contentController.text = _originalNote!.content;
      } else {
        _contentController.text = '$titleLine\n${_originalNote!.content}';
      }
    } else {
      _contentController.text = '$titleLine\n${_originalNote!.content}';
    }

    // Load todo.txt content if available, otherwise generate from markdown
    if (_originalNote!.todoTxtContent != null &&
        _originalNote!.todoTxtContent!.isNotEmpty) {
      _todoTxtController.text = _originalNote!.todoTxtContent!;
      _todoTxtTitleController.text = _originalNote!.title;
      // If note has todo.txt content, open in todo.txt mode
      setState(() {
        _viewMode = 'todotxt';
      });
    } else {
      _todoTxtController.text = TodoTxtConverter.markdownToTodoTxt(
        _originalNote!.content,
      );
      _todoTxtTitleController.text = _originalNote!.title;
      // Default to markdown mode
      setState(() {
        _viewMode = 'markdown';
      });
    }

    _isEditing = true;
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

  void _onTodoTxtChanged() {
    // When todo.txt content changes, track changes for auto-save
    if (_viewMode == 'todotxt') {
      final hasChanges =
          _originalNote == null ||
          _todoTxtController.text != (_originalNote!.todoTxtContent ?? '');
      _debounceTimer?.cancel();
      _autoSaveTimer?.cancel();
      if (hasChanges != _hasUnsavedChanges) {
        setState(() {
          _hasUnsavedChanges = hasChanges;
        });
      }
      if (hasChanges) {
        _autoSaveTimer = Timer(_autoSaveDuration, () {
          if (mounted && _hasUnsavedChanges) {
            _performAutoSave();
          }
        });
      }
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
    _todoTxtController.dispose();
    _todoTxtTitleController.dispose();
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
              Tab(icon: ScaledIcon(Icons.edit), text: 'Editor'),
              Tab(icon: ScaledIcon(Icons.preview), text: 'Preview'),
            ],
          ),
          actions: [
            // View mode toggle (Markdown / todo.txt)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'markdown',
                    label: Text('.md'),
                    icon: Icon(Icons.text_fields, size: 18),
                  ),
                  ButtonSegment<String>(
                    value: 'todotxt',
                    label: Text('.txt'),
                    icon: Icon(Icons.checklist, size: 18),
                  ),
                ],
                selected: {_viewMode},
                style: ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    final previousMode = _viewMode;
                    _viewMode = newSelection.first;

                    // Save the last used mode for future new notes
                    _lastUsedMode = _viewMode;

                    print('Switching from $previousMode to $_viewMode');

                    // Only sync content if there is actual content to convert
                    // Don't fill empty notes with example text - let hint text show
                    if (_viewMode == 'todotxt' && previousMode == 'markdown') {
                      // Switching TO todo.txt view: convert markdown to todo.txt
                      final markdownContent = _contentController.text.trim();

                      if (markdownContent.isNotEmpty) {
                        print(
                          'Converting markdown to todo.txt: ${markdownContent.length} chars',
                        );

                        final converted = TodoTxtConverter.markdownToTodoTxt(
                          markdownContent,
                        );
                        print('Converted result: ${converted.length} chars');

                        if (converted.isNotEmpty) {
                          _todoTxtController.text = converted;
                        }
                      }
                      // If markdown is empty, leave todo.txt empty too (show hint)
                    } else if (_viewMode == 'markdown' &&
                        previousMode == 'todotxt') {
                      // Switching TO markdown view: convert todo.txt to markdown
                      final todoTxtRaw = _todoTxtController.text.trim();

                      if (todoTxtRaw.isNotEmpty) {
                        print(
                          'Converting todo.txt to markdown: ${todoTxtRaw.length} chars',
                        );

                        // Remove comment lines (starting with #)
                        final todoTxtContent = todoTxtRaw
                            .split('\n')
                            .where((line) => !line.trim().startsWith('#'))
                            .join('\n')
                            .trim();

                        print(
                          'After removing comments: ${todoTxtContent.length} chars',
                        );

                        if (todoTxtContent.isNotEmpty) {
                          final markdownFromTodoTxt =
                              TodoTxtConverter.todoTxtToMarkdown(
                                todoTxtContent,
                              );
                          print('Converted to markdown: $markdownFromTodoTxt');

                          // Get title from existing content or create one
                          final lines = _contentController.text.split('\n');
                          final titleLine =
                              lines.isNotEmpty && lines.first.trim().isNotEmpty
                              ? lines.first
                              : 'My Tasks';

                          _contentController.text =
                              '$titleLine\n\n$markdownFromTodoTxt';
                        }
                      }
                      // If todo.txt is empty, leave markdown empty too (show hint)
                    }
                  });
                },
              ),
            ),
            if (_saveStatus.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: ScaledIcon(
                  _getStatusIcon(),
                  size: 20,
                  color: _getStatusColor(),
                ),
              ),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: [_buildEditorTab(), _buildPreviewTab()],
        ),
      ),
    );
  }

  Widget _buildEditorTab() {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    // Show different editor based on view mode
    if (_viewMode == 'todotxt') {
      return _buildTodoTxtEditor(keyboardHeight);
    }

    return Column(
      children: [
        // Sticky toolbar at the top
        _buildMarkdownToolbar(),
        // Scrollable content below
        Expanded(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16.0,
              16.0,
              16.0,
              keyboardHeight + 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _contentController,
                  decoration: InputDecoration(
                    hintText:
                        'Note title...\n\nStart writing your note here. The first line will be your title.',
                    hintStyle: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withOpacity(0.6),
                      fontStyle: FontStyle.italic,
                    ),
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  style: _buildContentTextStyle(),
                  minLines: 15,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  textAlignVertical: TextAlignVertical.top,
                  textCapitalization: TextCapitalization.none,
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

  Widget _buildTodoTxtEditor(double keyboardHeight) {
    return Column(
      children: [
        // Todo.txt toolbar
        Material(
          elevation: 1,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sort dropdown button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.sort, size: 18),
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
                  ),
                  _todoTxtButton(
                    icon: Icons.priority_high,
                    label: '(A)',
                    tooltip: 'High priority',
                    onPressed: () => _insertTodoTxtPrefix('(A) '),
                  ),
                  _todoTxtButton(
                    icon: Icons.add,
                    label: '+Project',
                    tooltip: 'Add project tag',
                    onPressed: () => _insertTodoTxtPrefix(' +Project'),
                  ),
                  _todoTxtButton(
                    icon: Icons.alternate_email,
                    label: '@Context',
                    tooltip: 'Add context tag',
                    onPressed: () => _insertTodoTxtPrefix(' @Context'),
                  ),
                  _todoTxtButton(
                    icon: Icons.check_circle,
                    label: 'Done',
                    tooltip: 'Mark as completed',
                    onPressed: () => _insertTodoTxtPrefix('x '),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16.0,
              16.0,
              16.0,
              keyboardHeight + 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title field for todo.txt notes
                TextFormField(
                  controller: _todoTxtTitleController,
                  decoration: InputDecoration(
                    hintText: 'Note title...',
                    hintStyle: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withOpacity(0.6),
                      fontStyle: FontStyle.italic,
                    ),
                    border: const OutlineInputBorder(),
                    labelText: 'Title',
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 1,
                  textCapitalization: TextCapitalization.none,
                ),
                const SizedBox(height: 16),
                // Tasks field
                TextFormField(
                  controller: _todoTxtController,
                  decoration: InputDecoration(
                    hintText:
                        'Enter tasks in todo.txt format:\n\n'
                        '(A) Call dentist tomorrow @Phone\n'
                        '(B) Finish project report +Work @Computer\n'
                        'Buy groceries +Shopping @Home\n'
                        'x Completed task looks like this\n\n'
                        'Tip: Use toolbar buttons above to add priority, projects, contexts',
                    hintStyle: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withOpacity(0.6),
                      fontStyle: FontStyle.italic,
                    ),
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  style: _buildContentTextStyle(),
                  minLines: 15,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  textAlignVertical: TextAlignVertical.top,
                  textCapitalization: TextCapitalization.none,
                ),
                const SizedBox(height: 8),
                Text(
                  'Todo.txt benefits:\n'
                  '• Plain text - works everywhere\n'
                  '• Priority: (A-Z) for importance levels\n'
                  '• Projects: +ProjectName to group tasks\n'
                  '• Contexts: @Location or @Tool needed\n'
                  '• Completion: prefix with "x" when done',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                // Show detected projects and contexts
                if (_todoTxtController.text.isNotEmpty) ...[
                  _buildTodoTxtInfo(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _todoTxtButton({
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: OutlinedButton.icon(
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 36),
        ),
      ),
    );
  }

  void _sortTodoTxt(String sortType) {
    String sorted;
    switch (sortType) {
      case 'priority':
        sorted = TodoTxtConverter.sortByPriority(_todoTxtController.text);
        break;
      case 'project':
        sorted = TodoTxtConverter.sortByProject(_todoTxtController.text);
        break;
      case 'context':
        sorted = TodoTxtConverter.sortByContext(_todoTxtController.text);
        break;
      case 'completion':
        sorted = TodoTxtConverter.sortByCompletion(_todoTxtController.text);
        break;
      default:
        sorted = _todoTxtController.text;
    }
    setState(() {
      _todoTxtController.text = sorted;
    });
  }

  void _insertTodoTxtPrefix(String prefix) {
    final controller = _todoTxtController;
    final text = controller.text;
    final selection = controller.selection;

    // Insert at the beginning of the current line
    final lines = text.split('\n');
    final cursorLine =
        text.substring(0, selection.start).split('\n').length - 1;

    if (cursorLine >= 0 && cursorLine < lines.length) {
      lines[cursorLine] = prefix + lines[cursorLine];
      controller.text = lines.join('\n');

      // Move cursor after inserted prefix
      final newOffset = selection.start + prefix.length;
      controller.selection = TextSelection.collapsed(offset: newOffset);
    }
  }

  Widget _buildTodoTxtInfo() {
    final projects = TodoTxtConverter.getProjects(_todoTxtController.text);
    final contexts = TodoTxtConverter.getContexts(_todoTxtController.text);

    if (projects.isEmpty && contexts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (projects.isNotEmpty) ...[
              Text(
                'Projects: ${projects.join(', ')}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
            ],
            if (contexts.isNotEmpty) ...[
              Text(
                'Contexts: ${contexts.join(', ')}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewTab() {
    // Show content in its native format
    if (_viewMode == 'todotxt') {
      // Preview todo.txt in its native format
      return _buildTodoTxtPreview();
    }

    // Markdown preview
    final content = _contentController.text;

    // Extract title, subtitle, and remaining content separately
    final lines = content.split('\n');
    final firstLine = lines.isNotEmpty ? lines.first.trim() : '';
    final secondLine = lines.length > 1 ? lines[1].trim() : '';

    // Check if first line is a markdown header
    final isFirstLineHeader = firstLine.startsWith('#');
    final title = isFirstLineHeader
        ? firstLine.replaceFirst(RegExp(r'^#+\s*'), '')
        : firstLine;

    // Check if second line is a subtitle (H2)
    final isSecondLineSubtitle = secondLine.startsWith('## ');
    final subtitle = isSecondLineSubtitle
        ? secondLine.replaceFirst('## ', '')
        : '';

    // Extract content excluding title and subtitle lines
    int contentStartIndex = 1; // Skip title by default
    if (isSecondLineSubtitle) {
      contentStartIndex = 2; // Skip both title and subtitle
    }

    final contentOnly = lines.length > contentStartIndex
        ? lines.skip(contentStartIndex).join('\n').trim()
        : '';

    if (content.isEmpty || contentOnly.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaledIcon(
              Icons.description,
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
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
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
              checkboxBuilder: (bool value) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Icon(
                    value ? Icons.check_box : Icons.check_box_outline_blank,
                    size: 20,
                    color: value
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                );
              },
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

  Widget _buildTodoTxtPreview() {
    final todoTxtContent = _todoTxtController.text;

    if (todoTxtContent.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaledIcon(
              Icons.checklist,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No tasks yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Switch to the Editor tab to add tasks',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final lines = todoTxtContent.split('\n');
    final tasks = <Widget>[];

    for (var line in lines) {
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _todoTxtTitleController.text.trim().isNotEmpty
                      ? _todoTxtTitleController.text
                      : 'My Tasks',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              // Sort button in preview
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
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          ...tasks,
        ],
      ),
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

    // Parse dates
    final datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}\s+');
    while (datePattern.hasMatch(remaining)) {
      remaining = remaining.replaceFirst(datePattern, '').trim();
    }

    // Extract projects and contexts
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

    // Build the card
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isCompleted
          ? Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withOpacity(0.5)
          : null,
      child: ListTile(
        leading: Icon(
          isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isCompleted
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
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

  Future<void> _saveNoteInternal({bool showFeedback = true}) async {
    String rawContent;
    String title;

    if (_viewMode == 'markdown') {
      rawContent = _contentController.text;
      // Auto-format content with markdown headers
      final formattedContent = _autoFormatWithHeaders(rawContent);
      // Extract title from first line of formatted content
      final lines = formattedContent.split('\n');
      final firstLine = lines.isNotEmpty ? lines.first.trim() : '';
      // Remove markdown header symbols for clean title storage
      title = firstLine.isNotEmpty
          ? firstLine.replaceFirst(RegExp(r'^#+\s*'), '')
          : 'Untitled';
      rawContent = formattedContent;
    } else {
      // In todo.txt mode: title comes from the title field
      // Content is just the tasks converted to markdown
      final todoLines = _todoTxtController.text
          .split('\n')
          .where((line) => !line.trim().startsWith('#'))
          .join('\n');

      // Get title from the title field or use default
      title = _todoTxtTitleController.text.trim().isNotEmpty
          ? _todoTxtTitleController.text.trim()
          : 'My Tasks';

      // Convert todo.txt tasks to markdown, but don't include title
      final markdownTasks = TodoTxtConverter.todoTxtToMarkdown(todoLines);
      rawContent = '$title\n\n$markdownTasks';
    }

    if (rawContent.trim().isEmpty) {
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enter some content for the note'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
      throw Exception('Content cannot be empty');
    }

    // Sync todo.txt content
    final todoTxtContent = _viewMode == 'todotxt'
        ? _todoTxtController.text
        : TodoTxtConverter.markdownToTodoTxt(rawContent);

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
        content: rawContent,
        todoTxtContent: todoTxtContent,
      );
      // Mark as editing from now on so subsequent saves will update.
      _isEditing = true;
    } else {
      savedNote = await controller.createNote(
        title: title,
        content: rawContent,
        folderId: widget.initialFolderId, // Save to selected folder
        todoTxtContent: todoTxtContent,
      );
      // After creating, mark as editing so future autosaves update this note
      _isEditing = true;
    }

    // Update the controller text with formatted content to reflect the changes
    if (_viewMode == 'markdown' && _contentController.text != rawContent) {
      _contentController.text = rawContent;
      // Move cursor to end to avoid disruption
      _contentController.selection = TextSelection.fromPosition(
        TextPosition(offset: rawContent.length),
      );
    }

    if (mounted) {
      setState(() {
        _hasUnsavedChanges = false;
        _originalNote = savedNote;
      });
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing && !wasCreate
                  ? 'Note updated successfully'
                  : 'Note created successfully',
            ),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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
      } else if (i == 1 &&
          line.trim().isNotEmpty &&
          !line.trim().startsWith('#')) {
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
        return Icons.cloud_upload;
      case 'Auto-saved':
      case 'Saved':
        return Icons.check_circle;
      case 'Auto-save failed':
      case 'Save failed':
      case 'Title required for save':
        return Icons.warning;
      default:
        return Icons.info;
    }
  }
}
