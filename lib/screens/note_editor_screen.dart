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
import 'package:flutter/gestures.dart';
import 'package:trudido/utils/responsive_size.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/note.dart';
import '../controllers/notes_controller.dart';
import '../repositories/notes_repository.dart';
import '../repositories/note_folder_repository.dart';
import '../services/note_export_service.dart';
import '../providers/app_providers.dart';
import '../providers/note_history_provider.dart';
import '../utils/markdown_inline_patterns.dart';
import '../widgets/mention_autocomplete_popup.dart';
import '../widgets/mention_text.dart';
import '../widgets/backlinks_section.dart';
import '../utils/mention_parser.dart';
import '../utils/mention_navigator.dart';
import '../widgets/note_history_bottom_sheet.dart';
import '../widgets/common/common.dart';

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
  late final MentionTextEditingController _contentController;
  late final TabController _tabController;
  bool _isEditing = false;
  bool _hasUnsavedChanges = false;
  Note? _originalNote;
  Timer? _debounceTimer;
  Timer? _autoSaveTimer;
  String _saveStatus = '';
  static const Duration _autoSaveDuration = Duration(seconds: 1);
  static const Duration _previewDuration = Duration(milliseconds: 100);

  // Preview panel state
  bool _showPreview = false;
  bool _userToggledPreview = false; // Track if user manually toggled preview
  double _previewHeight = 200.0; // Initial height
  static const double _minPreviewHeight = 100.0;
  static const double _maxPreviewHeight = 500.0;

  // Mention autocomplete
  MentionAutocompletePopup? _mentionPopup;

  @override
  void initState() {
    super.initState();
    _contentController = MentionTextEditingController();
    _contentController.onMentionTap = (mention) {
      _mentionPopup?.hide();
      MentionNavigator.navigateToMention(context, ref, mention);
    };
    _tabController = TabController(length: 2, vsync: this);

    _loadNote();
    _contentController.addListener(_onContentChanged);
    _contentController.addListener(_onMentionCheck);

    if (kDebugMode) {
      debugPrint('NoteEditor initialized: noteId=${widget.noteId}');
    }
  }

  Future<void> _loadNote() async {
    if (widget.noteId == null) {
      return;
    }

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
        _contentController.setFromStorageText(_originalNote!.content);
      } else {
        _contentController.setFromStorageText(
          '$titleLine\n${_originalNote!.content}',
        );
      }
    } else {
      _contentController.setFromStorageText(
        '$titleLine\n${_originalNote!.content}',
      );
    }

    // Check if loaded note has markdown and show preview
    _updatePreviewVisibility(_contentController.text);

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

  Future<void> _performAutoSave() async {
    final content = _contentController.text.trim();
    if (kDebugMode) {
      debugPrint('DEBUG AutoSave - content length: ${content.length}');
    }
    if (content.isEmpty) {
      setState(() {
        _saveStatus = 'Content required for save';
      });
      Future.delayed(const Duration(milliseconds: 1200), () {
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
        Future.delayed(const Duration(milliseconds: 1200), () {
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
        Future.delayed(const Duration(milliseconds: 1800), () {
          if (mounted) {
            setState(() {
              _saveStatus = '';
            });
          }
        });
      }
    }
  }

  void _onMentionCheck() {
    final text = _contentController.text;
    final cursor = _contentController.selection.baseOffset;

    // Suppress popup when cursor sits at a mention boundary
    if (_contentController.mentionAtCursor(cursor) != null) {
      _mentionPopup?.hide();
      return;
    }

    final query = MentionParser.detectMentionTrigger(text, cursor);

    if (query != null) {
      _mentionPopup ??= MentionAutocompletePopup(
        context: context,
        ref: ref,
        onItemSelected: _onMentionSelected,
        excludeId: widget.noteId,
      );
      _mentionPopup!.show(query);
    } else {
      _mentionPopup?.hide();
    }
  }

  void _onMentionSelected(MentionSearchItem item) {
    final mentionLink = MentionLink(
      title: item.title,
      type: item.type,
      id: item.id,
      start: 0,
      end: 0,
    );

    final range = MentionParser.getMentionTriggerRange(
      _contentController.text,
      _contentController.selection.baseOffset,
    );
    if (range == null) return;

    _contentController.removeListener(_onMentionCheck);
    _contentController.removeListener(_onContentChanged);
    _contentController.insertMention(mentionLink, range.start, range.end);
    _contentController.addListener(_onContentChanged);
    _contentController.addListener(_onMentionCheck);
  }

  @override
  void dispose() {
    _removeSlashMenu();
    _contentController.removeListener(_onMentionCheck);
    _mentionPopup?.hide();
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
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Note' : 'New Note'),
          actions: [
            if (_saveStatus.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: ScaledIcon(
                  _getStatusIcon(),
                  size: 20,
                  color: _getStatusColor(),
                ),
              ),
            // Undo button (only when editing existing note and feature enabled)
            if (_isEditing && widget.noteId != null)
              Consumer(
                builder: (context, ref, _) {
                  final preferences = ref.watch(preferencesStateProvider);
                  if (!preferences.enableNoteHistory) {
                    return const SizedBox.shrink();
                  }
                  final canUndo = ref.watch(canUndoProvider(widget.noteId!));
                  return ExpressiveIconButton(
                    icon: const Icon(Icons.undo),
                    tooltip: 'Undo',
                    onPressed: canUndo ? () => _handleUndo(ref) : null,
                  );
                },
              ),
            // Redo button (only when editing existing note and feature enabled)
            if (_isEditing && widget.noteId != null)
              Consumer(
                builder: (context, ref, _) {
                  final preferences = ref.watch(preferencesStateProvider);
                  if (!preferences.enableNoteHistory) {
                    return const SizedBox.shrink();
                  }
                  final canRedo = ref.watch(canRedoProvider(widget.noteId!));
                  return ExpressiveIconButton(
                    icon: const Icon(Icons.redo),
                    tooltip: 'Redo',
                    onPressed: canRedo ? () => _handleRedo(ref) : null,
                  );
                },
              ),
            // History button (only when editing existing note and feature enabled)
            if (_isEditing && widget.noteId != null)
              Consumer(
                builder: (context, ref, _) {
                  final preferences = ref.watch(preferencesStateProvider);
                  if (!preferences.enableNoteHistory) {
                    return const SizedBox.shrink();
                  }
                  return ExpressiveIconButton(
                    icon: const Icon(Icons.history),
                    tooltip: 'View history',
                    onPressed: () => _showNoteHistory(),
                  );
                },
              ),
            ExpressiveIconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Export',
              onPressed: () => _showExportOptions(),
            ),
          ],
        ),
        body: Column(
          children: [
            // Editor section
            Expanded(child: _buildMarkdownEditor()),
            // Backlinks (items that reference this note)
            if (_isEditing && widget.noteId != null)
              BacklinksSection(itemId: widget.noteId!, itemType: 'note'),
            // Preview toggle button
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
              ),
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                child: ExpressiveInkWell(
                  onTap: () {
                    setState(() {
                      _showPreview = !_showPreview;
                      _userToggledPreview =
                          true; // User manually toggled, respect their choice
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _showPreview
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _showPreview ? 'Hide Preview' : 'Show Preview',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Preview panel with draggable divider
            if (_showPreview)
              Container(
                height: _previewHeight,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    // Draggable divider
                    ExpressiveGestureDetector(
                      onVerticalDragUpdate: (details) {
                        setState(() {
                          // Calculate max height based on available screen space
                          final screenHeight = MediaQuery.of(
                            context,
                          ).size.height;
                          final appBarHeight = AppBar().preferredSize.height;
                          final statusBarHeight = MediaQuery.of(
                            context,
                          ).padding.top;
                          final toggleButtonHeight =
                              40.0; // Approximate height of toggle button
                          final safeMaxHeight =
                              screenHeight -
                              appBarHeight -
                              statusBarHeight -
                              toggleButtonHeight -
                              150; // Leave space for editor

                          _previewHeight = (_previewHeight - details.delta.dy)
                              .clamp(
                                _minPreviewHeight,
                                safeMaxHeight.clamp(
                                  _minPreviewHeight,
                                  _maxPreviewHeight,
                                ),
                              );
                        });
                      },
                      child: Container(
                        height: 24,
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHigh,
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Preview content
                    Expanded(child: _buildPreviewContent()),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkdownEditor() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Listener(
        onPointerUp: (_) => _contentController.notifyPointerUp(),
        child: TextField(
          controller: _contentController,
          decoration: InputDecoration(
            hintText:
                'Note title...\n\nStart writing your note here.\n\nType "/" for formatting, "@" to link tasks or notes.',
            hintStyle: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              fontStyle: FontStyle.italic,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            fillColor: Colors.transparent,
            filled: false,
          ),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (value) {
            _detectSlashCommand(_contentController, true);
            _updatePreviewVisibility(value);
            setState(() {});
          },
        ),
      ),
    );
  }

  /// Check if text contains markdown syntax
  bool _hasMarkdownSyntax(String text) {
    if (text.trim().isEmpty) return false;

    return text.contains('**') || // bold
        text.contains('*') || // italic (but check it's not just multiplication)
        text.contains('~~') || // strikethrough
        text.contains('==') || // highlight
        text.contains('`') || // code
        text.contains('<u>') || // underline
        text.contains('# ') || // headers
        text.contains('## ') ||
        text.contains('### ') ||
        text.contains('- [ ]') || // checkboxes
        text.contains('- [x]') ||
        text.contains('> ') || // quotes
        (text.contains('[') && text.contains('](')) || // links
        text.contains('![') || // images
        text.contains('```') || // code blocks
        text.contains('---'); // dividers
  }

  /// Update preview visibility based on markdown detection
  void _updatePreviewVisibility(String text) {
    // If user manually toggled preview, respect their choice
    if (_userToggledPreview) return;

    // Auto-show preview if markdown is detected
    final hasMarkdown = _hasMarkdownSyntax(text);
    if (_showPreview != hasMarkdown) {
      setState(() {
        _showPreview = hasMarkdown;
      });
    }
  }

  Widget _buildPreviewContent() {
    final content = _contentController.text;
    if (content.trim().isEmpty) {
      return Center(
        child: Text(
          'Preview will appear here',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Align(
        alignment: Alignment.topLeft,
        child: _buildMarkdownPreview(content),
      ),
    );
  }

  Widget _buildMarkdownPreview(String markdown) {
    return Text.rich(
      _parseMarkdownToTextSpan(markdown, context),
      style: Theme.of(context).textTheme.bodyLarge,
      textAlign: TextAlign.left,
    );
  }

  TextSpan _parseMarkdownToTextSpan(String text, BuildContext context) {
    if (text.isEmpty) return const TextSpan(text: '');

    final lines = text.split('\n');
    List<InlineSpan> allSpans = [];

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      TextStyle? lineStyle;

      if (line.startsWith('# ')) {
        line = line.substring(2);
        lineStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        );
      } else if (line.startsWith('## ')) {
        line = line.substring(3);
        lineStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        );
      } else if (line.startsWith('### ')) {
        line = line.substring(4);
        lineStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        );
      } else if (line.trim().startsWith('- [ ] ')) {
        line = '☐ ${line.trim().substring(6)}';
      } else if (line.trim().startsWith('- [x] ')) {
        line = '☑ ${line.trim().substring(6)}';
      } else if (line.trim().startsWith('- ')) {
        line = '• ${line.trim().substring(2)}';
      }
      // Handle quotes
      else if (line.trim().startsWith('> ')) {
        line = line.trim().substring(2);
        lineStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        );
      }

      final baseStyle =
          lineStyle ??
          Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            height: ref.watch(preferencesStateProvider).lineHeightMultiplier,
          );

      // Parse inline formatting within the line
      final lineSpans = _parseInlineFormatting(line, context, baseStyle);
      allSpans.addAll(lineSpans);

      // Add newline if not last line
      if (i < lines.length - 1) {
        allSpans.add(const TextSpan(text: '\n'));
      }
    }

    return TextSpan(children: allSpans);
  }

  List<InlineSpan> _parseInlineFormatting(
    String text,
    BuildContext context,
    TextStyle? baseStyle,
  ) {
    List<InlineSpan> spans = [];
    int currentIndex = 0;

    final filteredMatches = MarkdownInlinePatterns.findNonOverlappingMatches(
      text,
      MarkdownInlinePatterns.textStyles,
    );

    for (var matchEntry in filteredMatches) {
      final match = matchEntry.key;
      final type = matchEntry.value;

      if (match.start > currentIndex) {
        // Process plain text segment for mentions
        spans.addAll(
          _parseMentionsInText(
            text.substring(currentIndex, match.start),
            baseStyle,
          ),
        );
      }

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
            decorationColor: Theme.of(context).colorScheme.onSurface,
          );
          break;
        case 'underline':
          style = baseStyle?.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: Theme.of(context).colorScheme.onSurface,
          );
          break;
        case 'highlight':
          style = baseStyle?.copyWith(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.7),
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          );
          break;
        case 'code':
          final fontSize = baseStyle?.fontSize ?? 14.0;
          style = baseStyle?.copyWith(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            color: Theme.of(context).colorScheme.primary,
            fontFamily: 'monospace',
            fontSize: fontSize * 0.9,
          );
          break;
      }

      spans.add(TextSpan(text: matchText, style: style));
      currentIndex = match.end;
    }

    // Add remaining text (process for mentions too)
    if (currentIndex < text.length) {
      spans.addAll(
        _parseMentionsInText(text.substring(currentIndex), baseStyle),
      );
    }

    // Return list with at least one span
    if (spans.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }
    return spans;
  }

  /// Parses a plain text segment for `@Name` mention patterns that exist
  /// in the controller's mention map and returns styled, tappable spans.
  List<InlineSpan> _parseMentionsInText(String text, TextStyle? baseStyle) {
    final mentionMap = _contentController.mentionMap;
    if (mentionMap.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final colorScheme = Theme.of(context).colorScheme;
    final hits = MentionTextEditingController.findMentionHits(text, mentionMap);

    if (hits.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final hit in hits) {
      if (hit.start > lastEnd) {
        spans.add(
          TextSpan(text: text.substring(lastEnd, hit.start), style: baseStyle),
        );
      }

      final mentionStyle = baseStyle?.copyWith(
        color: hit.mention.isTask ? colorScheme.primary : colorScheme.tertiary,
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
        decorationStyle: TextDecorationStyle.dotted,
        decorationColor:
            (hit.mention.isTask ? colorScheme.primary : colorScheme.tertiary)
                .withValues(alpha: 0.5),
      );

      spans.add(
        TextSpan(
          text: hit.key,
          style: mentionStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              MentionNavigator.navigateToMention(context, ref, hit.mention);
            },
        ),
      );

      lastEnd = hit.end;
    }

    if (lastEnd == 0) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
    }

    return spans;
  }

  OverlayEntry? _slashMenuOverlay;

  void _detectSlashCommand(TextEditingController controller, bool isMarkdown) {
    final text = controller.text;
    final selection = controller.selection;
    if (!selection.isValid || selection.start == 0) {
      _removeSlashMenu();
      return;
    }

    final textBeforeCursor = text.substring(0, selection.start);
    if (textBeforeCursor.endsWith('/')) {
      if (selection.start == 1 || text[selection.start - 2].trim().isEmpty) {
        _showSlashCommandMenu(controller, isMarkdown);
      } else {
        _removeSlashMenu();
      }
    } else if (textBeforeCursor.endsWith('/ ') ||
        !textBeforeCursor.contains('/') ||
        (textBeforeCursor.lastIndexOf('/') < textBeforeCursor.length - 10)) {
      _removeSlashMenu();
    }
  }

  void _showSlashCommandMenu(
    TextEditingController controller,
    bool isMarkdown,
  ) {
    _removeSlashMenu();

    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    _slashMenuOverlay = OverlayEntry(
      builder: (context) => Positioned(
        left: 20,
        right: 20,
        top: (screenHeight - keyboardHeight) * 0.2,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: isMarkdown
                  ? [
                      _buildSlashMenuItem(
                        icon: Icons.format_bold,
                        title: 'Bold',
                        hint: '**text**',
                        onTap: () {
                          _removeSlashMenu();
                          _insertFormat(controller, '**', '**');
                        },
                      ),
                      _buildSlashMenuItem(
                        icon: Icons.format_italic,
                        title: 'Italic',
                        hint: '*text*',
                        onTap: () {
                          _removeSlashMenu();
                          _insertFormat(controller, '*', '*');
                        },
                      ),
                      _buildSlashMenuItem(
                        icon: Icons.format_underlined,
                        title: 'Underline',
                        hint: '<u>text</u>',
                        onTap: () {
                          _removeSlashMenu();
                          _insertFormat(controller, '<u>', '</u>');
                        },
                      ),
                      _buildSlashMenuItem(
                        icon: Icons.strikethrough_s,
                        title: 'Strikethrough',
                        hint: '~~text~~',
                        onTap: () {
                          _removeSlashMenu();
                          _insertFormat(controller, '~~', '~~');
                        },
                      ),
                      _buildSlashMenuItem(
                        icon: Icons.title,
                        title: 'Heading 1',
                        hint: '# text',
                        onTap: () {
                          _removeSlashMenu();
                          _insertFormat(controller, '# ', '');
                        },
                      ),
                      _buildSlashMenuItem(
                        icon: Icons.title,
                        title: 'Heading 2',
                        hint: '## text',
                        onTap: () {
                          _removeSlashMenu();
                          _insertFormat(controller, '## ', '');
                        },
                      ),
                      _buildSlashMenuItem(
                        icon: Icons.title,
                        title: 'Heading 3',
                        hint: '### text',
                        onTap: () {
                          _removeSlashMenu();
                          _insertFormat(controller, '### ', '');
                        },
                      ),
                      _buildSlashMenuItem(
                        icon: Icons.format_list_bulleted,
                        title: 'Bullet List',
                        hint: '- item',
                        onTap: () {
                          _removeSlashMenu();
                          _insertFormat(controller, '- ', '');
                        },
                      ),
                      _buildSlashMenuItem(
                        icon: Icons.format_list_numbered,
                        title: 'Numbered List',
                        hint: '1. item',
                        onTap: () {
                          _removeSlashMenu();
                          _insertFormat(controller, '1. ', '');
                        },
                      ),
                      _buildSlashMenuItem(
                        icon: Icons.check_box,
                        title: 'Checkbox',
                        hint: '- [ ] task',
                        onTap: () {
                          _removeSlashMenu();
                          _insertFormat(controller, '- [ ] ', '');
                        },
                      ),
                      _buildSlashMenuItem(
                        icon: Icons.check_box_outlined,
                        title: 'Checked Box',
                        hint: '- [x] done',
                        onTap: () {
                          _removeSlashMenu();
                          _insertFormat(controller, '- [x] ', '');
                        },
                      ),
                      _buildSlashMenuItem(
                        icon: Icons.format_quote,
                        title: 'Quote',
                        hint: '> quote',
                        onTap: () {
                          _removeSlashMenu();
                          _insertFormat(controller, '> ', '');
                        },
                      ),
                      _buildSlashMenuItem(
                        icon: Icons.code,
                        title: 'Inline Code',
                        hint: '`code`',
                        onTap: () {
                          _removeSlashMenu();
                          _insertFormat(controller, '`', '`');
                        },
                      ),
                      _buildSlashMenuItem(
                        icon: Icons.code_outlined,
                        title: 'Code Block',
                        hint: '```code```',
                        onTap: () {
                          _removeSlashMenu();
                          _insertFormat(controller, '```\n', '\n```');
                        },
                      ),
                      _buildSlashMenuItem(
                        icon: Icons.link,
                        title: 'Link',
                        hint: '[text](url)',
                        onTap: () {
                          _removeSlashMenu();
                          _insertFormat(controller, '[', '](url)');
                        },
                      ),
                      _buildSlashMenuItem(
                        icon: Icons.image,
                        title: 'Image',
                        hint: '![alt](url)',
                        onTap: () {
                          _removeSlashMenu();
                          _insertFormat(controller, '![', '](url)');
                        },
                      ),
                      _buildSlashMenuItem(
                        icon: Icons.table_chart,
                        title: 'Table',
                        hint: '| col | col |',
                        onTap: () {
                          _removeSlashMenu();
                          _insertFormat(
                            controller,
                            '| Column 1 | Column 2 |\n|----------|----------|\n| ',
                            ' | |\n',
                          );
                        },
                      ),
                      _buildSlashMenuItem(
                        icon: Icons.horizontal_rule,
                        title: 'Divider',
                        hint: '---',
                        onTap: () {
                          _removeSlashMenu();
                          _insertFormat(controller, '\n---\n', '');
                        },
                      ),
                      _buildSlashMenuItem(
                        icon: Icons.highlight,
                        title: 'Highlight',
                        hint: '==text==',
                        onTap: () {
                          _removeSlashMenu();
                          _insertFormat(controller, '==', '==');
                        },
                      ),
                    ]
                  : [
                      _buildSlashMenuItem(
                        icon: Icons.label_outline,
                        title: 'Priority',
                        hint: '(A)',
                        onTap: () {
                          _removeSlashMenu();
                          _insertFormat(controller, '(A) ', '');
                        },
                      ),
                      _buildSlashMenuItem(
                        icon: Icons.add,
                        title: 'Project',
                        hint: '+project',
                        onTap: () {
                          _removeSlashMenu();
                          _insertFormat(controller, '+', '');
                        },
                      ),
                      _buildSlashMenuItem(
                        icon: Icons.alternate_email,
                        title: 'Context',
                        hint: '@context',
                        onTap: () {
                          _removeSlashMenu();
                          _insertFormat(controller, '@', '');
                        },
                      ),
                      _buildSlashMenuItem(
                        icon: Icons.check_circle,
                        title: 'Mark Done',
                        hint: 'x',
                        onTap: () {
                          _removeSlashMenu();
                          _insertFormat(controller, 'x ', '');
                        },
                      ),
                    ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_slashMenuOverlay!);
  }

  Widget _buildSlashMenuItem({
    required IconData icon,
    required String title,
    required String hint,
    required VoidCallback onTap,
  }) {
    return ExpressiveInkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Text(title),
            const Spacer(),
            if (hint.isNotEmpty)
              Text(
                hint,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  void _removeSlashMenu() {
    _slashMenuOverlay?.remove();
    _slashMenuOverlay = null;
  }

  void _insertFormat(
    TextEditingController controller,
    String prefix,
    String suffix,
  ) {
    final text = controller.text;
    final selection = controller.selection;

    if (!selection.isValid || selection.start == 0) return;

    final lastSlashIndex = text.lastIndexOf('/');
    if (lastSlashIndex == -1) return; // No slash found

    // Split text: everything before the slash, and everything after the cursor
    final beforeSlash = text.substring(0, lastSlashIndex);
    final afterCursor = text.substring(selection.start);

    final newText = beforeSlash + prefix + suffix + afterCursor;

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: beforeSlash.length + prefix.length,
      ),
    );
  }

  Future<void> _saveNoteInternal({bool showFeedback = true}) async {
    String rawContent = _contentController.toStorageText();
    if (kDebugMode) {
      debugPrint('DEBUG Save - Raw content from controller: "$rawContent"');
    }

    // Auto-format content with markdown headers
    final formattedContent = _autoFormatWithHeaders(rawContent);
    if (kDebugMode) {
      debugPrint('DEBUG Save - After autoformat: "$formattedContent"');
    }

    // Extract title from first line of formatted content
    final lines = formattedContent.split('\n');
    final firstLine = lines.isNotEmpty ? lines.first.trim() : '';
    final title = firstLine.replaceFirst(RegExp(r'^#+\s*'), '');
    rawContent = formattedContent;
    if (kDebugMode) {
      debugPrint('DEBUG Save - Final content to save: "$rawContent"');
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

    final controller = ref.read(notesControllerProvider.notifier);
    Note? savedNote;
    // Prefer an existing note id from the loaded original note, fallback to
    // the widget.noteId (when editing via route). If we have an id, update
    // the existing note; otherwise create a new one.
    final existingId = _originalNote?.id ?? widget.noteId;
    if (existingId != null) {
      savedNote = await controller.updateNote(
        id: existingId,
        title: title,
        content: rawContent,
      );
      // Mark as editing from now on so subsequent saves will update.
      _isEditing = true;
    } else {
      if (kDebugMode) {
        debugPrint(
          'DEBUG Save - Creating note with folderId: ${widget.initialFolderId}',
        );
      }
      savedNote = await controller.createNote(
        title: title,
        content: rawContent,
        folderId: widget.initialFolderId, // Save to selected folder
      );
      if (kDebugMode) {
        debugPrint(
          'DEBUG Save - Note created with id: ${savedNote?.id}, folderId: ${savedNote?.folderId}',
        );
      }
      // After creating, mark as editing so future autosaves update this note
      _isEditing = true;
    }

    _contentController.setFromStorageText(rawContent);
    // Move cursor to end to avoid disruption
    _contentController.selection = TextSelection.fromPosition(
      TextPosition(offset: _contentController.text.length),
    );

    if (mounted) {
      setState(() {
        _hasUnsavedChanges = false;
        _originalNote = savedNote;
      });
      if (showFeedback) {
        final wasUpdate = existingId != null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wasUpdate
                  ? 'Note updated successfully'
                  : 'Note created successfully',
            ),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          ),
        );
        // If this was a manual create (not an update), close the editor as
        // previous behavior expected. For autosaves showFeedback is false so
        // we won't pop.
        if (!wasUpdate) {
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

  Future<void> _showExportOptions() async {
    // Build a Note from current editor content (use formatted content)
    final rawContent = _contentController.toStorageText().trim();
    final formatted = _autoFormatWithHeaders(rawContent);
    final lines = formatted.split('\n');
    final firstLine = lines.isNotEmpty ? lines.first.trim() : '';
    final title = firstLine.replaceFirst(RegExp(r'^#+\s*'), '');

    final noteToExport = Note(
      title: title,
      content: formatted,
      createdAt: _originalNote?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      folderId: _originalNote?.folderId ?? widget.initialFolderId,
    );

    // Check vault folder
    final folderId = noteToExport.folderId;
    final folder = folderId == null
        ? null
        : NoteFolderRepository().getNoteFolderById(folderId);

    if (folder != null && folder.isVault) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export is disabled for vault notes'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Show bottom-sheet export menu (only PDF for now)
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.25,
          minChildSize: 0.15,
          maxChildSize: 0.6,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: ListView(
                controller: scrollController,
                children: [
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      'Export',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.picture_as_pdf_outlined),
                    title: const Text('Export as PDF'),
                    subtitle: const Text('Create a PDF of this note'),
                    onTap: () => Navigator.pop(context, 'pdf'),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );

    if (choice == null) return;

    if (choice == 'pdf') {
      await _exportAsPdf(noteToExport);
    }
  }

  Future<void> _exportAsPdf(Note note) async {
    // Show progress
    if (!mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Generating PDF...'),
            ],
          ),
        ),
      ),
    );

    try {
      final bytes = await NoteExportService.generatePdfBytes(note);
      final safeTitle = (note.title.isEmpty ? 'note' : note.title).replaceAll(
        RegExp(r'[^A-Za-z0-9_\-]'),
        '_',
      );
      final filename =
          '$safeTitle-${DateTime.now().toIso8601String().split('T').first}.pdf';
      await NoteExportService.sharePdf(bytes, filename);
      if (!mounted) return;
      navigator.pop(); // dismiss progress
      messenger.showSnackBar(SnackBar(content: Text('Exported "$filename"')));
    } catch (e) {
      if (!mounted) return;
      navigator.pop(); // dismiss progress
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
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
          ExpressiveTextButton(
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

  void _handleUndo(WidgetRef ref) {
    if (widget.noteId == null) return;
    final entry = ref
        .read(noteHistoryStackProvider.notifier)
        .undo(widget.noteId!);
    if (entry != null) {
      setState(() {
        _contentController.setFromStorageText(entry.contentBefore ?? '');
        _hasUnsavedChanges = true;
      });
    }
  }

  void _handleRedo(WidgetRef ref) {
    if (widget.noteId == null) return;
    final entry = ref
        .read(noteHistoryStackProvider.notifier)
        .redo(widget.noteId!);
    if (entry != null) {
      setState(() {
        _contentController.setFromStorageText(entry.contentAfter ?? '');
        _hasUnsavedChanges = true;
      });
    }
  }

  void _showNoteHistory() {
    if (widget.noteId == null) return;

    // Extract title from content (first non-empty line)
    final lines = _contentController.text.split('\n');
    final title = lines
        .firstWhere((line) => line.trim().isNotEmpty, orElse: () => 'Untitled')
        .trim()
        .replaceFirst(RegExp(r'^#+\s*'), '');

    showNoteHistoryBottomSheet(
      context: context,
      noteId: widget.noteId!,
      noteTitle: title,
      onRestore: (restoredContent) {
        setState(() {
          _contentController.setFromStorageText(restoredContent ?? '');
          _hasUnsavedChanges = true;
        });
      },
    );
  }
}
