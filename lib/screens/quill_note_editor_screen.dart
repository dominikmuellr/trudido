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
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/quill_delta.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import '../models/note.dart';
import '../controllers/notes_controller.dart';
import '../repositories/notes_repository.dart';
import '../repositories/note_folder_repository.dart';
import '../services/note_export_service.dart';
import '../utils/markdown_to_quill_converter.dart';
import '../services/media_service.dart';
import '../widgets/media_embed_builder.dart';
import '../widgets/link_embed_builder.dart';
import '../widgets/floating_note_toolbar.dart';
import '../widgets/quill_toolbar_widgets.dart';
import '../widgets/note_editor_dialogs.dart';
import '../widgets/note_editor_controls.dart';
import '../providers/app_providers.dart';
import '../services/preferences_service.dart';
import '../providers/note_history_provider.dart';
import '../widgets/note_history_bottom_sheet.dart';
import '../widgets/mention_autocomplete_popup.dart';
import '../widgets/backlinks_section.dart';
import '../utils/mention_parser.dart';
import '../utils/mention_navigator.dart';
import '../models/note_history.dart';
import '../services/storage_service.dart';
import '../widgets/common/common.dart';

/// Media type enum
enum MediaType { photo, video }

/// String extension for capitalization
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}

/// Screen for creating and editing rich text notes using Quill WYSIWYG editor
class QuillNoteEditorScreen extends ConsumerStatefulWidget {
  final String? noteId;
  final String? initialFolderId;
  final String? initialTitle;

  const QuillNoteEditorScreen({
    super.key,
    this.noteId,
    this.initialFolderId,
    this.initialTitle,
  });

  @override
  ConsumerState<QuillNoteEditorScreen> createState() =>
      _QuillNoteEditorScreenState();
}

class _QuillNoteEditorScreenState extends ConsumerState<QuillNoteEditorScreen> {
  late quill.QuillController _quillController;
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _hasUnsavedChanges = false;
  Note? _originalNote;
  Timer? _autoSaveTimer;
  String _saveStatus = '';
  static const Duration _autoSaveDuration = Duration(seconds: 1);

  // History recording with debouncing
  Timer? _historyRecordTimer;
  String? _lastRecordedContent; // Content at last history entry
  DateTime? _lastHistoryRecordTime;
  static const Duration _historyRecordDelay = Duration(
    seconds: 10,
  ); // Wait 10s of inactivity
  static const int _minContentChangeForHistory =
      50; // Min characters changed for immediate history
  static const Duration _maxHistoryInterval = Duration(
    minutes: 2,
  ); // Force history entry after 2 min

  // Flag to skip history recording during undo/redo operations
  bool _isRestoringFromHistory = false;

  // Slash menu
  bool _showSlashMenu = false;
  int _slashCommandStartIndex = -1;
  double _slashMenuTop = 100.0; // Default position
  int _previousLineCount = 0; // Track line count for deletion detection

  // Media service
  final MediaService _mediaService = MediaService();

  // Track media files to detect deletions
  Set<String> _trackedMediaFiles = {};

  // Toolbar expansion state
  bool _showMoreToolbar = false;
  bool _hideToolbar = false;
  bool _useFloatingToolbar = false;

  // Mention autocomplete
  MentionAutocompletePopup? _mentionPopup;
  bool _quillTapPending = false;

  /// Mention ranges from the last time the document was clean.
  /// Used to detect partial mention damage (atomic deletion).
  List<({int start, int end, String link, String text})> _prevMentionRanges =
      [];
  bool _mentionGuardActive = false;

  @override
  void initState() {
    super.initState();
    // Initialize with empty document
    _quillController = quill.QuillController.basic();
    // Set initial title if provided (from quick input bar)
    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }
    _loadNote();
    _loadToolbarPreferences();
    _quillController.addListener(_onContentChanged);
    _quillController.addListener(_checkForSlashCommand);
    _quillController.addListener(_handleScrollOnDelete);
    _quillController.addListener(_trackMediaChanges);
    _quillController.addListener(_handleMarkdownShortcuts);
    _quillController.addListener(_onQuillMentionCheck);
    // Title controller listener for unsaved changes
    _titleController.addListener(_onTitleChanged);
    // Update toolbar buttons when selection changes
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });

    // Auto-focus for new notes
    if (widget.noteId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }

    debugPrint('QuillNoteEditor initialized: noteId=${widget.noteId}');
  }

  /// Load toolbar visibility preferences
  void _loadToolbarPreferences() {
    final prefs = ref.read(preferencesStateProvider);
    setState(() {
      // Check if floating toolbar is enabled
      _useFloatingToolbar = prefs.useFloatingNoteToolbar;

      // For new notes, always show the main toolbar by default
      // User can still collapse it, but it starts expanded
      if (widget.noteId == null) {
        _hideToolbar = false;
        _showMoreToolbar = prefs.showMoreNoteToolbar;
      } else {
        _hideToolbar = prefs.hideNoteToolbar;
        _showMoreToolbar = prefs.showMoreNoteToolbar;
      }
    });
  }

  /// Save toolbar visibility preferences
  Future<void> _saveToolbarPreferences() async {
    final prefsService = PreferencesService();
    final updated = await prefsService.update(
      hideNoteToolbar: _hideToolbar,
      showMoreNoteToolbar: _showMoreToolbar,
    );
    ref.read(preferencesStateProvider.notifier).update(updated);
  }

  void _handleScrollOnDelete() {
    // Scroll adjustment when deleting lines
    if (!_scrollController.hasClients) return;

    final text = _quillController.document.toPlainText();
    final selection = _quillController.selection;
    if (!selection.isValid) {
      return;
    }

    final textBeforeCursor = text.substring(
      0,
      selection.baseOffset.clamp(0, text.length),
    );
    final lineCount = '\n'.allMatches(textBeforeCursor).length;

    if (kDebugMode) {
      debugPrint(
        '_handleScrollOnDelete: lineCount=$lineCount, previous=$_previousLineCount',
      );
    }

    // Detect line deletion and scroll up proportionally
    if (lineCount < _previousLineCount) {
      final linesDeleted = _previousLineCount - lineCount;
      if (kDebugMode) {
        debugPrint('Lines deleted: $linesDeleted, scrolling up...');
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final maxScroll = _scrollController.position.maxScrollExtent;
          final currentScroll = _scrollController.offset;

          // Scroll up immediately by the amount of deleted lines
          final lineHeight = 24.0;
          final scrollAmount = linesDeleted * lineHeight;
          final targetScroll = (currentScroll - scrollAmount).clamp(
            0.0,
            maxScroll,
          );
          if (kDebugMode) {
            debugPrint(
              'Scrolling from $currentScroll to $targetScroll (delta: $scrollAmount)',
            );
          }
          _scrollController.jumpTo(targetScroll);
        }
      });
    }
    _previousLineCount = lineCount;
  }

  bool _shouldShowPlaceholder() {
    // Show placeholder when cursor is on an empty line
    final selection = _quillController.selection;
    if (!selection.isCollapsed) return false;

    final text = _quillController.document.toPlainText();
    if (text.isEmpty) return true;

    final cursorPosition = selection.baseOffset;
    if (cursorPosition < 0 || cursorPosition > text.length) return false;

    // Find the start and end of the current line
    int lineStart = cursorPosition;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    int lineEnd = cursorPosition;
    while (lineEnd < text.length && text[lineEnd] != '\n') {
      lineEnd++;
    }

    // Check if the line is empty or only whitespace
    final lineContent = text.substring(lineStart, lineEnd).trim();
    return lineContent.isEmpty;
  }

  void _handleMarkdownShortcuts() {
    final selection = _quillController.selection;
    if (!selection.isCollapsed) return;

    final text = _quillController.document.toPlainText();
    final cursorPosition = selection.baseOffset;

    if (cursorPosition <= 0 || cursorPosition > text.length) return;

    // Get the current line
    int lineStart = cursorPosition;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    final lineText = text.substring(lineStart, cursorPosition);

    // Check if user just typed a space after markdown syntax
    if (cursorPosition > 0 && text[cursorPosition - 1] == ' ') {
      quill.Attribute? attribute;

      // Header shortcuts: # , ## , ###
      if (lineText == '# ') {
        attribute = quill.Attribute.h1;
      } else if (lineText == '## ') {
        attribute = quill.Attribute.h2;
      } else if (lineText == '### ') {
        attribute = quill.Attribute.h3;
      }
      // List shortcuts: - , 1. , [ ]
      else if (lineText == '- ') {
        attribute = quill.Attribute.ul;
      } else if (RegExp(r'^\d+\.\s$').hasMatch(lineText)) {
        attribute = quill.Attribute.ol;
      } else if (lineText == '[] ' || lineText == '[ ] ') {
        attribute = quill.Attribute.unchecked;
      }
      // Block quote: >
      else if (lineText == '> ') {
        attribute = quill.Attribute.blockQuote;
      }

      if (attribute != null) {
        // Schedule the format application after the current event loop
        Future.microtask(() {
          _applyMarkdownFormat(lineStart, cursorPosition, attribute!);
        });
      }
    }
  }

  void _applyMarkdownFormat(int start, int end, quill.Attribute attribute) {
    try {
      final markdownLength = end - start;

      // Remove the markdown syntax (e.g., "# ", "- ", etc.)
      _quillController.replaceText(
        start,
        markdownLength,
        '',
        TextSelection.collapsed(offset: start),
      );

      // Apply block-level formatting (header, list, etc.) to current position
      // This will format the entire paragraph/block at the cursor position
      _quillController.formatSelection(attribute);
    } catch (e) {
      debugPrint('Error applying markdown format: $e');
    }
  }

  void _checkForSlashCommand() {
    try {
      final selection = _quillController.selection;

      // Close menu if text is selected
      if (!selection.isCollapsed) {
        if (_showSlashMenu) {
          setState(() => _showSlashMenu = false);
        }
        return;
      }

      final cursorPosition = selection.baseOffset;
      if (cursorPosition <= 0) {
        if (_showSlashMenu) setState(() => _showSlashMenu = false);
        return;
      }

      final text = _quillController.document.toPlainText();
      if (text.isEmpty || cursorPosition > text.length) {
        if (_showSlashMenu) setState(() => _showSlashMenu = false);
        return;
      }

      final charBeforeCursor = text[cursorPosition - 1];

      // Show menu: just typed '/' at start or after space/newline
      if (charBeforeCursor == '/' && !_showSlashMenu) {
        if (cursorPosition == 1 ||
            (cursorPosition > 1 &&
                (text[cursorPosition - 2] == ' ' ||
                    text[cursorPosition - 2] == '\n'))) {
          // Get screen and keyboard dimensions
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
          final screenHeight = MediaQuery.of(context).size.height;
          final menuHeight = 120.0;

          // Calculate available space above keyboard
          final availableHeight = screenHeight - keyboardHeight;

          // Simple positioning: place menu in the middle of available space
          // This ensures it's always visible regardless of scroll position
          final clampedTop = (availableHeight - menuHeight) / 2;

          setState(() {
            _showSlashMenu = true;
            _slashCommandStartIndex = cursorPosition - 1;
            _slashMenuTop = clampedTop;
          });
          return;
        }
      }

      // Close menu: typed anything after '/', moved cursor, or deleted '/'
      if (_showSlashMenu) {
        final shouldClose =
            cursorPosition !=
                _slashCommandStartIndex + 1 || // Moved away or typed more
            _slashCommandStartIndex >= text.length || // Slash was deleted
            text[_slashCommandStartIndex] != '/'; // Slash position changed

        if (shouldClose) {
          setState(() => _showSlashMenu = false);
        }
      }
    } catch (e) {
      // Fail gracefully
      if (_showSlashMenu) setState(() => _showSlashMenu = false);
    }
  }

  void _insertSlashCommand(String type) {
    // Remove the '/' character
    final deleteLength =
        _quillController.selection.baseOffset - _slashCommandStartIndex;
    _quillController.replaceText(
      _slashCommandStartIndex,
      deleteLength,
      '',
      TextSelection.collapsed(offset: _slashCommandStartIndex),
    );

    setState(() {
      _showSlashMenu = false;
    });

    // Handle different command types
    switch (type) {
      case 'image':
        _insertImage();
        break;
      case 'video':
        _insertVideo();
        break;
      case 'voice':
        _insertVoiceNote();
        break;
      case 'link':
        _insertLink();
        break;
      case 'code':
        _insertCodeBlock();
        break;
    }
  }

  Future<void> _insertImage() async {
    // Show dialog to pick from gallery or take photo
    await _showMediaPickerDialog(MediaType.photo);
  }

  Future<void> _insertVideo() async {
    // Show dialog to pick from gallery or record video
    await _showMediaPickerDialog(MediaType.video);
  }

  Future<void> _insertVoiceNote() async {
    // Show voice recording dialog
    await _showVoiceRecordingDialog();
  }

  Future<File?> _showMediaPickerDialog(MediaType type) async {
    final dialogContext = context;
    return showDialog<File?>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          type == MediaType.photo
              ? Icons.image_outlined
              : Icons.videocam_outlined,
          size: 32,
        ),
        title: Text(type == MediaType.photo ? 'Add Photo' : 'Add Video'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                type == MediaType.photo
                    ? Icons.photo_library_outlined
                    : Icons.video_library_outlined,
              ),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context); // Close the dialog
                final file = type == MediaType.photo
                    ? await _mediaService.pickImageFromGallery()
                    : await _mediaService.pickVideoFromGallery();
                if (dialogContext.mounted && file != null) {
                  // Return the file by completing the dialog's future
                  await _insertMediaFile(
                    file,
                    type == MediaType.photo ? 'image' : 'video',
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(
                type == MediaType.photo
                    ? Icons.camera_alt_outlined
                    : Icons.videocam_outlined,
              ),
              title: Text(
                type == MediaType.photo ? 'Take Photo' : 'Record Video',
              ),
              onTap: () async {
                Navigator.pop(context); // Close the dialog
                final file = type == MediaType.photo
                    ? await _mediaService.takePhoto()
                    : await _mediaService.recordVideo();
                if (dialogContext.mounted && file != null) {
                  // Return the file by completing the dialog's future
                  await _insertMediaFile(
                    file,
                    type == MediaType.photo ? 'image' : 'video',
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _insertMediaFile(File file, String type) async {
    try {
      // Copy file to app directory
      final savedFile = await _mediaService.saveMediaToAppDirectory(file, type);

      if (kDebugMode) {
        debugPrint('Inserting media: type=$type, path=${savedFile.path}');
      }

      // Get current selection position
      int index = _quillController.selection.baseOffset;

      // If at the very beginning (position 0), ensure we have a newline first
      if (index == 0 && _quillController.document.length == 1) {
        // Empty document - add a newline first so media doesn't become the title
        _quillController.document.insert(0, '\n');
        index = 1;
      }

      // Create a custom embed block with media data
      final mediaData = jsonEncode({'type': type, 'path': savedFile.path});

      if (kDebugMode) {
        debugPrint('Media data JSON: $mediaData');
      }

      final mediaEmbed = quill.BlockEmbed.custom(
        quill.CustomBlockEmbed('media', mediaData),
      );

      if (kDebugMode) {
        debugPrint('Created embed: ${mediaEmbed.toString()}');
      }

      // Insert the embed with newlines around it
      _quillController.document.insert(index, '\n');
      _quillController.document.insert(index + 1, mediaEmbed);
      _quillController.document.insert(index + 2, '\n');

      _quillController.updateSelection(
        TextSelection.collapsed(offset: index + 3),
        quill.ChangeSource.local,
      );

      // Trigger auto-scroll after media insertion with a delay to ensure rendering
      if (kDebugMode) {
        debugPrint('Scheduling auto-scroll after media insertion');
      }
      // Scroll handled by QuillEditor itself

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${type.capitalize()} added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding $type: $e')));
      }
    }
  }

  Future<void> _showVoiceRecordingDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => VoiceRecordingDialog(
        mediaService: _mediaService,
        onRecordingComplete: (File file) async {
          await _insertMediaFile(file, 'voice');
        },
      ),
    );
  }

  void _insertLink() {
    showDialog(
      context: context,
      builder: (context) => LinkInsertDialog(
        onInsert: (url, text) {
          final index = _quillController.selection.baseOffset;
          final displayText = text.isNotEmpty ? text : url;

          // Insert link text with link attribute (inline)
          _quillController.replaceText(
            index,
            0,
            displayText,
            TextSelection.collapsed(offset: index + displayText.length),
          );

          // Apply link attribute
          _quillController.formatText(
            index,
            displayText.length,
            quill.LinkAttribute(url),
          );

          debugPrint('Inserted inline link: text="$displayText", url="$url"');
        },
      ),
    );
  }

  void _insertCodeBlock() {
    final index = _quillController.selection.baseOffset;
    _quillController.formatText(index, 0, quill.Attribute.codeBlock);
  }

  Future<void> _loadNote() async {
    if (widget.noteId == null) {
      return;
    }

    final repository = ref.read(notesRepositoryProvider);
    Note? note = await repository.getNoteById(widget.noteId!);

    _originalNote = note;

    if (_originalNote != null) {
      // Set the title from the note
      _titleController.text = _originalNote!.title;

      // Try to load as Quill JSON first, fallback to markdown for old notes
      quill.Document document;
      try {
        // Check if content is Quill JSON format
        if (_originalNote!.content.trim().startsWith('[')) {
          final json = jsonDecode(_originalNote!.content);

          // MIGRATION: Clean up old font size format ("18px" -> "18")
          var migratedJson = _migrateFontSizes(json);

          // MIGRATION: Convert raw @[Title](type:id) to display @Title + link
          migratedJson = _migrateRawMentions(migratedJson);

          document = quill.Document.fromJson(migratedJson);
        } else {
          // Legacy markdown format - convert to Quill (content only, not title)
          document = MarkdownToQuillConverter.markdownToDocument(
            _originalNote!.content,
          );
        }
      } catch (e) {
        // If JSON parsing fails, treat as markdown (content only)
        document = MarkdownToQuillConverter.markdownToDocument(
          _originalNote!.content,
        );
      }

      // Initialize tracked media files from loaded document
      _initializeTrackedMedia(document);

      // Initialize last recorded content for history debouncing
      _lastRecordedContent = _originalNote!.content;
      _lastHistoryRecordTime = DateTime.now();

      setState(() {
        _quillController = quill.QuillController(
          document: document,
          selection: const TextSelection.collapsed(offset: 0),
        );
        _quillController.addListener(_onContentChanged);
        _quillController.addListener(_checkForSlashCommand);
        _quillController.addListener(_handleScrollOnDelete);
        _quillController.addListener(_trackMediaChanges);
        _quillController.addListener(_handleMarkdownShortcuts);
        _quillController.addListener(_onQuillMentionCheck);
        _prevMentionRanges = _findQuillMentionRanges();
      });

      // Request focus after loading to show keyboard
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });

      // Initialize history stack from persisted storage
      _initializeHistoryStack();
    }
  }

  /// Initialize the in-memory history stack from persisted storage
  Future<void> _initializeHistoryStack() async {
    final noteId = _originalNote?.id ?? widget.noteId;
    if (noteId == null) return;

    final history = await StorageService.getNoteHistoryForNote(noteId);
    if (history.isNotEmpty) {
      ref
          .read(noteHistoryStackProvider.notifier)
          .initializeFromHistory(noteId, history);
    }
  }

  void _onTitleChanged() {
    _autoSaveTimer?.cancel();

    final hasChanges = _originalNote == null
        ? _titleController.text.trim().isNotEmpty ||
              _quillController.document.toPlainText().trim().isNotEmpty
        : _titleController.text != _originalNote!.title;

    if (mounted) {
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

  /// Scans the Quill delta for all mention link ranges.
  List<({int start, int end, String link, String text})>
  _findQuillMentionRanges() {
    final ranges = <({int start, int end, String link, String text})>[];
    final delta = _quillController.document.toDelta();
    int offset = 0;
    for (final op in delta.toList()) {
      if (op.isInsert) {
        if (op.data is String) {
          final text = op.data as String;
          final attrs = op.attributes;
          if (attrs != null && attrs.containsKey('link')) {
            final link = attrs['link'].toString();
            if (link.startsWith('mention:')) {
              ranges.add((
                start: offset,
                end: offset + text.length,
                link: link,
                text: text,
              ));
            }
          }
          offset += text.length;
        } else {
          offset += 1; // embed
        }
      }
    }
    return ranges;
  }

  void _onQuillMentionCheck() {
    if (_mentionGuardActive) return;
    _mentionGuardActive = true;
    try {
      _onQuillMentionCheckInner();
    } catch (e) {
      _mentionPopup?.hide();
    } finally {
      _mentionGuardActive = false;
    }
  }

  void _onQuillMentionCheckInner() {
    final selection = _quillController.selection;
    if (!selection.isCollapsed) {
      _quillTapPending = false;
      _mentionPopup?.hide();
      _prevMentionRanges = _findQuillMentionRanges();
      return;
    }

    final cursor = selection.baseOffset;
    final currentRanges = _findQuillMentionRanges();

    // ── Atomic deletion: if a mention was partially damaged, delete it ──
    for (final prev in _prevMentionRanges) {
      bool found = false;
      for (final curr in currentRanges) {
        if (curr.link == prev.link && curr.text == prev.text) {
          found = true;
          break;
        }
      }
      if (!found) {
        // Check if a shorter version still exists (partially deleted)
        for (final curr in currentRanges) {
          if (curr.link == prev.link && curr.text != prev.text) {
            // Mention was damaged → delete the remaining fragment
            _quillController.removeListener(_onQuillMentionCheck);
            _quillController.replaceText(
              curr.start,
              curr.end - curr.start,
              '',
              TextSelection.collapsed(offset: curr.start),
            );
            _quillController.addListener(_onQuillMentionCheck);
            _prevMentionRanges = _findQuillMentionRanges();
            _quillTapPending = false;
            return;
          }
        }
      }
    }

    _prevMentionRanges = currentRanges;

    // ── Cursor snap: if cursor is strictly inside a mention, snap out ──
    for (final range in currentRanges) {
      if (cursor > range.start && cursor < range.end) {
        _mentionPopup?.hide();
        // Navigate on real tap
        if (_quillTapPending) {
          _quillTapPending = false;
          _openLink(range.link);
          return;
        }
        // Snap cursor to nearest edge (schedule after Quill's own
        // tap handling completes to avoid being overridden)
        final snapTo = (cursor - range.start) <= (range.end - cursor)
            ? range.start
            : range.end;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _quillController.updateSelection(
            TextSelection.collapsed(offset: snapTo),
            quill.ChangeSource.local,
          );
        });
        return;
      }
    }

    // ── Cursor at mention boundary: suppress popup, navigate on tap ──
    if (cursor > 0) {
      for (final range in currentRanges) {
        if (cursor == range.end) {
          // Cursor is right at the end of a mention
          if (_quillTapPending) {
            _quillTapPending = false;
            _mentionPopup?.hide();
            _openLink(range.link);
            return;
          }
        }
      }
    }
    _quillTapPending = false;

    // ── Suppress popup if cursor is adjacent to a mention ──
    for (final range in currentRanges) {
      if (cursor >= range.start && cursor <= range.end) {
        _mentionPopup?.hide();
        return;
      }
    }

    // ── Normal autocomplete trigger detection ──
    final text = _quillController.document.toPlainText();
    final query = MentionParser.detectMentionTrigger(text, cursor);

    if (query != null) {
      _mentionPopup ??= MentionAutocompletePopup(
        context: context,
        ref: ref,
        onItemSelected: _onQuillMentionSelected,
        excludeId: widget.noteId,
      );
      _mentionPopup!.show(query);
    } else {
      _mentionPopup?.hide();
    }
  }

  void _onQuillMentionSelected(MentionSearchItem item) {
    try {
      final displayText = '@${item.title}';
      final linkUrl = 'mention:${item.type}:${item.id}';

      final text = _quillController.document.toPlainText();
      final cursor = _quillController.selection.baseOffset;
      final range = MentionParser.getMentionTriggerRange(text, cursor);

      if (range != null) {
        final deleteLength = range.end - range.start;
        _quillController.removeListener(_onQuillMentionCheck);
        _quillController.replaceText(
          range.start,
          deleteLength,
          '$displayText ',
          TextSelection.collapsed(offset: range.start + displayText.length + 1),
        );
        // Apply link attribute to the mention text (not the trailing space)
        _quillController.formatText(
          range.start,
          displayText.length,
          quill.Attribute.fromKeyValue('link', linkUrl),
        );
        _quillController.addListener(_onQuillMentionCheck);
        _prevMentionRanges = _findQuillMentionRanges();
      }
    } catch (e) {
      debugPrint('Error inserting mention: $e');
    }
  }

  void _onContentChanged() {
    final currentJson = jsonEncode(
      _quillController.document.toDelta().toJson(),
    );

    final hasChanges = _originalNote == null
        ? _quillController.document.toPlainText().trim().isNotEmpty
        : currentJson != _originalNote!.content;

    _autoSaveTimer?.cancel();

    // Always update state to refresh placeholder visibility and unsaved changes
    if (mounted) {
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

  void _initializeTrackedMedia(quill.Document document) {
    try {
      _trackedMediaFiles.clear();
      final delta = document.toDelta();

      for (var op in delta.toList()) {
        if (op.data is Map) {
          final data = op.data as Map;
          // Check for custom embed structure: {"custom": "{\"media\":\"...\"}" }
          if (data.containsKey('custom')) {
            try {
              final customData =
                  jsonDecode(data['custom'] as String) as Map<String, dynamic>;
              if (customData.containsKey('media')) {
                final mediaData =
                    jsonDecode(customData['media'] as String)
                        as Map<String, dynamic>;
                final filePath = mediaData['path'] as String;
                _trackedMediaFiles.add(filePath);
              }
            } catch (e) {
              if (kDebugMode) {
                debugPrint('Error parsing custom embed during init: $e');
              }
            }
          }
          // Fallback for old format
          else if (data.containsKey('media')) {
            try {
              final mediaData =
                  jsonDecode(data['media'] as String) as Map<String, dynamic>;
              final filePath = mediaData['path'] as String;
              _trackedMediaFiles.add(filePath);
            } catch (e) {
              if (kDebugMode) {
                debugPrint('Error parsing media during init: $e');
              }
            }
          }
        }
      }
      if (kDebugMode) {
        debugPrint(
          'Initialized media tracking with ${_trackedMediaFiles.length} files',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error initializing media tracking: $e');
      }
    }
  }

  void _trackMediaChanges() {
    try {
      // Get all media embeds currently in the document
      final currentMediaFiles = <String>{};
      final delta = _quillController.document.toDelta();

      for (var op in delta.toList()) {
        if (op.data is Map) {
          final data = op.data as Map;
          // Check for custom embed structure: {"custom": "{\"media\":\"...\"}" }
          if (data.containsKey('custom')) {
            try {
              final customData =
                  jsonDecode(data['custom'] as String) as Map<String, dynamic>;
              if (customData.containsKey('media')) {
                final mediaData =
                    jsonDecode(customData['media'] as String)
                        as Map<String, dynamic>;
                final filePath = mediaData['path'] as String;
                currentMediaFiles.add(filePath);
              }
            } catch (e) {
              if (kDebugMode) {
                debugPrint('Error parsing custom embed in tracker: $e');
              }
            }
          }
          // Fallback for old format
          else if (data.containsKey('media')) {
            try {
              final mediaData =
                  jsonDecode(data['media'] as String) as Map<String, dynamic>;
              final filePath = mediaData['path'] as String;
              currentMediaFiles.add(filePath);
            } catch (e) {
              if (kDebugMode) {
                debugPrint('Error parsing media in tracker: $e');
              }
            }
          }
        }
      }

      // Find deleted files (were tracked but now removed from document)
      final deletedFiles = _trackedMediaFiles.difference(currentMediaFiles);

      // Delete the files from filesystem
      for (final filePath in deletedFiles) {
        try {
          final file = File(filePath);
          if (file.existsSync()) {
            file.deleteSync();
            if (kDebugMode) {
              debugPrint('Deleted removed media file: $filePath');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error deleting media file: $e');
          }
        }
      }

      // Update tracked files
      _trackedMediaFiles = currentMediaFiles;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error tracking media changes: $e');
      }
    }
  }

  /// Migrate old font size format from "18px" to "18"
  /// This ensures compatibility with flutter_quill's getFontSize function
  List<dynamic> _migrateFontSizes(List<dynamic> deltaJson) {
    return deltaJson.map((op) {
      if (op is Map<String, dynamic>) {
        final attributes = op['attributes'];
        if (attributes is Map<String, dynamic> &&
            attributes.containsKey('size')) {
          final sizeValue = attributes['size'];
          if (sizeValue is String && sizeValue.endsWith('px')) {
            // Remove "px" suffix
            final cleanedSize = sizeValue.replaceAll(RegExp(r'px$'), '');
            // Create new attributes map with cleaned size
            final newAttributes = Map<String, dynamic>.from(attributes);
            newAttributes['size'] = cleanedSize;
            // Return new operation with cleaned attributes
            return {...op, 'attributes': newAttributes};
          }
        }
      }
      return op;
    }).toList();
  }

  /// Migrates raw `@[Title](type:id)` mentions in Quill delta JSON to
  /// display text `@Title` with a `link: mention:type:id` attribute.
  List<dynamic> _migrateRawMentions(List<dynamic> deltaJson) {
    final pattern = MentionParser.mentionPattern;
    final result = <dynamic>[];

    for (final op in deltaJson) {
      if (op is Map<String, dynamic> && op['insert'] is String) {
        final text = op['insert'] as String;
        final attrs = op['attributes'] as Map<String, dynamic>?;

        if (!pattern.hasMatch(text)) {
          result.add(op);
          continue;
        }

        // Split this insert op around mention patterns
        int lastEnd = 0;
        for (final match in pattern.allMatches(text)) {
          // Text before the mention
          if (match.start > lastEnd) {
            final before = text.substring(lastEnd, match.start);
            result.add({
              'insert': before,
              if (attrs != null) 'attributes': Map<String, dynamic>.from(attrs),
            });
          }

          // The mention itself: display as @Title with link attribute
          final title = match.group(1)!;
          final type = match.group(2)!;
          final id = match.group(3)!;
          final mentionAttrs = <String, dynamic>{
            if (attrs != null) ...attrs,
            'link': 'mention:$type:$id',
          };
          result.add({'insert': '@$title', 'attributes': mentionAttrs});

          lastEnd = match.end;
        }

        // Remaining text after last mention
        if (lastEnd < text.length) {
          result.add({
            'insert': text.substring(lastEnd),
            if (attrs != null) 'attributes': Map<String, dynamic>.from(attrs),
          });
        }
      } else {
        result.add(op);
      }
    }

    return result;
  }

  String _getPlainText() {
    return _quillController.document.toPlainText().trim();
  }

  Future<void> _performAutoSave() async {
    final plainText = _getPlainText();

    if (plainText.isEmpty) {
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

  Future<void> _saveNoteInternal({bool showFeedback = true}) async {
    // Get title from the title controller
    final title = _titleController.text.trim().isEmpty
        ? 'Untitled'
        : _titleController.text.trim();

    // Store Quill document as JSON to preserve all formatting
    final content = jsonEncode(_quillController.document.toDelta().toJson());

    if (kDebugMode) {
      debugPrint('=== SAVING NOTE ===');
      debugPrint('Title: $title');
      debugPrint(
        'Content preview: ${content.substring(0, content.length > 200 ? 200 : content.length)}...',
      );
      debugPrint('Content length: ${content.length}');
    }

    if (_quillController.document.toPlainText().trim().isEmpty &&
        _titleController.text.trim().isEmpty) {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enter a title or some content'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
      throw Exception('Note cannot be empty');
    }

    final controller = ref.read(notesControllerProvider.notifier);
    Note? savedNote;
    final existingId = _originalNote?.id ?? widget.noteId;

    // Capture content before saving for history
    final contentBefore = _originalNote?.content;

    if (existingId != null) {
      savedNote = await controller.updateNote(
        id: existingId,
        title: title,
        content: content,
        lineHeightMultiplier: _originalNote?.lineHeightMultiplier,
        paragraphSpacing: _originalNote?.paragraphSpacing,
      );

      // Schedule history recording with debouncing (skip during undo/redo)
      if (savedNote != null &&
          contentBefore != null &&
          contentBefore != content &&
          !_isRestoringFromHistory) {
        _scheduleHistoryRecord(existingId, contentBefore, content);
      }
    } else {
      savedNote = await controller.createNote(
        title: title,
        content: content,
        folderId: widget.initialFolderId,
      );
    }

    // Check if save failed (encryption or storage error)
    if (savedNote == null) {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save note. Please try again.'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
      throw Exception('Failed to save note');
    }

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
        if (!wasUpdate) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  Future<bool> _showDiscardDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard Changes?'),
            content: const Text(
              'You have unsaved changes. Do you want to discard them?',
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
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
  }

  IconData _getStatusIcon() {
    if (_saveStatus.contains('saving')) {
      return Icons.sync;
    } else if (_saveStatus.contains('saved')) {
      return Icons.check_circle;
    } else if (_saveStatus.contains('failed')) {
      return Icons.error;
    }
    return Icons.info;
  }

  Color _getStatusColor() {
    if (_saveStatus.contains('saved')) {
      return Theme.of(context).colorScheme.primary;
    } else if (_saveStatus.contains('failed')) {
      return Theme.of(context).colorScheme.error;
    }
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  // Handle undo operation - navigates back in history tree
  void _handleUndo() {
    final noteId = _originalNote?.id ?? widget.noteId;
    if (noteId == null) return;

    final tree = ref.read(historyTreeProvider(noteId));
    if (tree == null) return;

    // Get current content before navigating back (for live version save)
    final currentContent = jsonEncode(
      _quillController.document.toDelta().toJson(),
    );

    final navigator = ref.read(noteHistoryNavigatorProvider.notifier);
    final entryId = navigator.navigateBack(
      noteId,
      tree,
      currentLiveContent: currentContent,
    );

    if (entryId != null) {
      final entry = tree.getNode(entryId)?.entry;
      if (entry != null && entry.contentBefore != null) {
        _isRestoringFromHistory = true;
        _restoreContentFromJson(entry.contentBefore!);
        // Reset flag after the save completes
        Future.delayed(const Duration(milliseconds: 100), () {
          _isRestoringFromHistory = false;
        });
      }
    }
  }

  // Handle redo operation - navigates forward in history tree
  void _handleRedo() {
    final noteId = _originalNote?.id ?? widget.noteId;
    if (noteId == null) return;

    final notifier = ref.read(noteHistoryStackProvider.notifier);
    final navigator = ref.read(noteHistoryNavigatorProvider.notifier);

    // Check if we're about to return to live version
    final isReturningToLive =
        navigator.isAtLiveVersion(noteId) == false &&
        ref.read(noteHistoryNavigatorProvider)[noteId]?.forwardStack.isEmpty ==
            true;

    final tree = ref.read(historyTreeProvider(noteId));
    final entryId = navigator.navigateForward(noteId);

    if (entryId != null && tree != null) {
      // Navigating to a specific history entry
      final entry = tree.getNode(entryId)?.entry;
      if (entry != null && entry.contentAfter != null) {
        _isRestoringFromHistory = true;
        _restoreContentFromJson(entry.contentAfter!);
        Future.delayed(const Duration(milliseconds: 100), () {
          _isRestoringFromHistory = false;
        });
      }
    } else if (isReturningToLive) {
      // Returning to live version - restore the saved live content
      final liveContent = notifier.getLiveContent(noteId);
      if (liveContent != null) {
        _isRestoringFromHistory = true;
        _restoreContentFromJson(liveContent);
        Future.delayed(const Duration(milliseconds: 100), () {
          _isRestoringFromHistory = false;
        });
      }
    }
  }

  // Restore content from JSON string (Quill Delta format)
  void _restoreContentFromJson(String jsonContent) {
    try {
      // Try to parse as JSON (Quill Delta format)
      final json = jsonDecode(jsonContent);
      if (json is List) {
        final delta = Delta.fromJson(json);
        _quillController.document = quill.Document.fromDelta(delta);
      } else {
        // Fallback: treat as plain text/markdown
        _quillController.document = MarkdownToQuillConverter.markdownToDocument(
          jsonContent,
        );
      }
      // Update _originalNote to reflect the restored content
      // This prevents the restored content from being recorded as a new change
      if (_originalNote != null) {
        _originalNote = _originalNote!.copyWith(content: jsonContent);
      }
      setState(() {
        _hasUnsavedChanges = true; // Mark as needing save
      });
      // Save the restored content (but skip history recording via _isRestoringFromHistory flag)
      _saveNoteInternal(showFeedback: false);
    } catch (e) {
      // Fallback: treat as markdown/plain text
      try {
        _quillController.document = MarkdownToQuillConverter.markdownToDocument(
          jsonContent,
        );
        if (_originalNote != null) {
          _originalNote = _originalNote!.copyWith(content: jsonContent);
        }
        setState(() {
          _hasUnsavedChanges = true;
        });
        _saveNoteInternal(showFeedback: false);
      } catch (e2) {
        if (kDebugMode) {
          debugPrint('Error restoring content: $e2');
        }
      }
    }
  }

  // Show note history bottom sheet
  void _showNoteHistory() {
    final noteId = _originalNote?.id ?? widget.noteId;
    if (noteId == null) return;

    showNoteHistoryBottomSheet(
      context: context,
      noteId: noteId,
      noteTitle: _originalNote?.title ?? 'Untitled',
      onRestore: (content) {
        if (content == null) return;
        _isRestoringFromHistory = true;
        _restoreContentFromJson(content);
        // Reset flag after the save completes
        Future.delayed(const Duration(milliseconds: 100), () {
          _isRestoringFromHistory = false;
        });
      },
    );
  }

  Future<void> _showExportOptions() async {
    // Prepare note content from quill controller
    final plain = _quillController.document.toPlainText().trim();
    // Try to auto-format first lines as headers similar to markdown editor
    final lines = plain.split('\n');
    final firstLine = lines.isNotEmpty ? lines.first.trim() : '';
    final title = firstLine.replaceFirst(RegExp(r'^#+\s*'), '');

    final noteToExport = Note(
      title: title,
      content: plain,
      createdAt: _originalNote?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      folderId: _originalNote?.folderId ?? widget.initialFolderId,
    );

    final folder = noteToExport.folderId == null
        ? null
        : NoteFolderRepository().getNoteFolderById(noteToExport.folderId!);

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
    if (!mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // Show only an indeterminate spinner (no textual message)
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
            children: [CircularProgressIndicator()],
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
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text('Exported "$filename"')));
    } catch (e) {
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _openLink(String url) async {
    // Handle mention links
    if (url.startsWith('mention:')) {
      final parts = url.substring('mention:'.length).split(':');
      if (parts.length >= 2) {
        final type = parts[0];
        final id = parts.sublist(1).join(':');
        final mention = MentionLink(
          title: '',
          type: type,
          id: id,
          start: 0,
          end: 0,
        );
        MentionNavigator.navigateToMention(context, ref, mention);
      }
      return;
    }

    try {
      // Add scheme if not present
      String urlString = url;
      if (!urlString.startsWith('http://') &&
          !urlString.startsWith('https://')) {
        urlString = 'https://$urlString';
      }

      // Use url_launcher to open the link in the system browser
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        // Open in external browser app (not in-app webview)
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        // Fallback: show snackbar if URL can't be launched
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $urlString')),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error opening link: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error opening link')));
      }
    }
  }

  /// Schedule a history record with debouncing.
  /// Only creates a history entry after 10 seconds of inactivity,
  /// or immediately if there's a large change (50+ chars).
  void _scheduleHistoryRecord(
    String noteId,
    String contentBefore,
    String contentAfter,
  ) {
    // Check if history feature is enabled
    final preferences = ref.read(preferencesStateProvider);
    if (!preferences.enableNoteHistory) {
      return; // Don't record history when feature is disabled
    }

    // Cancel any pending history record
    _historyRecordTimer?.cancel();

    // Calculate content change size
    final contentChange = (contentAfter.length - contentBefore.length).abs();

    // Initialize last recorded content if needed
    _lastRecordedContent ??= contentBefore;

    // Check if we should record immediately (large change or max interval exceeded)
    final now = DateTime.now();
    final timeSinceLastRecord = _lastHistoryRecordTime != null
        ? now.difference(_lastHistoryRecordTime!)
        : _maxHistoryInterval;

    final shouldRecordImmediately =
        contentChange >= _minContentChangeForHistory ||
        timeSinceLastRecord >= _maxHistoryInterval;

    if (shouldRecordImmediately) {
      _recordHistoryEntry(noteId, contentAfter);
    } else {
      // Schedule for later (after period of inactivity)
      _historyRecordTimer = Timer(_historyRecordDelay, () {
        if (mounted) {
          _recordHistoryEntry(noteId, contentAfter);
        }
      });
    }
  }

  /// Actually record a history entry
  void _recordHistoryEntry(String noteId, String currentContent) {
    // Don't record if content hasn't changed from last recorded version
    if (_lastRecordedContent == currentContent) return;

    final historyEntry = NoteHistoryEntry(
      noteId: noteId,
      contentBefore: _lastRecordedContent,
      contentAfter: currentContent,
    );

    ref.read(noteHistoryStackProvider.notifier).pushUndo(noteId, historyEntry);

    // Update tracking
    _lastRecordedContent = currentContent;
    _lastHistoryRecordTime = DateTime.now();
  }

  @override
  void dispose() {
    _quillController.removeListener(_onQuillMentionCheck);
    _mentionPopup?.hide();
    _autoSaveTimer?.cancel();
    _historyRecordTimer?.cancel();

    // Record any pending history entry before disposing
    final noteId = _originalNote?.id ?? widget.noteId;
    final currentContent = jsonEncode(
      _quillController.document.toDelta().toJson(),
    );
    if (noteId != null &&
        _lastRecordedContent != null &&
        _lastRecordedContent != currentContent &&
        !_isRestoringFromHistory) {
      _recordHistoryEntry(noteId, currentContent);
    }

    _quillController.dispose();
    _titleController.dispose();
    _titleFocusNode.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _mediaService.dispose();
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
        resizeToAvoidBottomInset: true, // Let keyboard push content up
        appBar: AppBar(
          titleSpacing: 12,
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.3),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                inputDecorationTheme: const InputDecorationTheme(
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  filled: false,
                ),
              ),
              child: TextField(
                controller: _titleController,
                focusNode: _titleFocusNode,
                decoration: const InputDecoration.collapsed(hintText: 'Title'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                cursorColor: Theme.of(context).colorScheme.primary,
                maxLines: 1,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) {
                  _focusNode.requestFocus();
                },
              ),
            ),
          ),
          actions: [
            // Save status indicator - compact, in actions area
            if (_saveStatus.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Icon(
                  _getStatusIcon(),
                  size: 18,
                  color: _getStatusColor(),
                ),
              ),
            // Toolbar toggle button - only show when not using floating toolbar
            if (!_useFloatingToolbar)
              ExpressiveIconButton(
                icon: Icon(
                  _hideToolbar
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_up,
                  color: _hideToolbar
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.primary,
                ),
                tooltip: _hideToolbar ? 'Show formatting' : 'Hide formatting',
                onPressed: () {
                  setState(() {
                    _hideToolbar = !_hideToolbar;
                  });
                  _saveToolbarPreferences();
                },
              ),
            ExpressiveIconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Export',
              onPressed: () => _showExportOptions(),
            ),
          ],
        ),
        // Floating toolbar FAB - shown when floating toolbar is enabled
        floatingActionButton: _useFloatingToolbar
            ? Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom > 0
                      ? 8 // When keyboard is open, FAB is just above it
                      : 0,
                ),
                child: FloatingNoteToolbar(
                  controller: _quillController,
                  onInsertImage: _insertImage,
                  onInsertVideo: _insertVideo,
                  onInsertVoice: _insertVoiceNote,
                  onInsertLink: _insertLink,
                  currentLineHeight: _originalNote?.lineHeightMultiplier ?? 1.5,
                  currentParagraphSpacing:
                      _originalNote?.paragraphSpacing ?? 8.0,
                  onLineHeightChanged: (newHeight) {
                    if (_originalNote != null) {
                      setState(() {
                        _originalNote = _originalNote!.copyWith(
                          lineHeightMultiplier: newHeight,
                        );
                        _hasUnsavedChanges = true;
                      });
                      _saveNoteInternal(showFeedback: false);
                    }
                  },
                  onParagraphSpacingChanged: (newSpacing) {
                    if (_originalNote != null) {
                      setState(() {
                        _originalNote = _originalNote!.copyWith(
                          paragraphSpacing: newSpacing,
                        );
                        _hasUnsavedChanges = true;
                      });
                      _saveNoteInternal(showFeedback: false);
                    }
                  },
                ),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: SafeArea(
          top: false, // AppBar handles top
          bottom: true, // Ensure content clears bottom nav bar
          child: Column(
            children: [
              // Main toolbar - collapsible (only when not using floating toolbar)
              if (!_hideToolbar && !_useFloatingToolbar)
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Primary toolbar - essential commands with scroll indicator
                      ScrollableToolbar(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 8),
                            // More options toggle button - at the beginning for visibility
                            ExpressiveIconButton(
                              icon: Icon(
                                _showMoreToolbar
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 20,
                              ),
                              tooltip: _showMoreToolbar
                                  ? 'Hide more options'
                                  : 'More options',
                              onPressed: () {
                                setState(() {
                                  _showMoreToolbar = !_showMoreToolbar;
                                });
                                _saveToolbarPreferences();
                              },
                            ),
                            const ToolbarDivider(),
                            // Font family dropdown - first, like Google Docs
                            FontFamilyDropdown(
                              controller: _quillController,
                              onChanged: () => setState(() {}),
                            ),
                            const ToolbarDivider(),
                            // Font size dropdown - numeric sizes like Word
                            FontSizeDropdown(
                              controller: _quillController,
                              onChanged: () => setState(() {}),
                            ),
                            const ToolbarDivider(),
                            // Bold, Italic, Underline - most common actions
                            quill.QuillToolbarToggleStyleButton(
                              attribute: quill.Attribute.bold,
                              controller: _quillController,
                              options:
                                  const quill.QuillToolbarToggleStyleButtonOptions(),
                            ),
                            quill.QuillToolbarToggleStyleButton(
                              attribute: quill.Attribute.italic,
                              controller: _quillController,
                              options:
                                  const quill.QuillToolbarToggleStyleButtonOptions(),
                            ),
                            quill.QuillToolbarToggleStyleButton(
                              attribute: quill.Attribute.underline,
                              controller: _quillController,
                              options:
                                  const quill.QuillToolbarToggleStyleButtonOptions(),
                            ),
                            const ToolbarDivider(),
                            // Header style dropdown - paragraph formatting
                            HeaderStyleDropdown(
                              controller: _quillController,
                              onChanged: () => setState(() {}),
                            ),
                            const ToolbarDivider(),
                            // Lists
                            quill.QuillToolbarToggleStyleButton(
                              attribute: quill.Attribute.ul,
                              controller: _quillController,
                              options:
                                  const quill.QuillToolbarToggleStyleButtonOptions(),
                            ),
                            quill.QuillToolbarToggleStyleButton(
                              attribute: quill.Attribute.ol,
                              controller: _quillController,
                              options:
                                  const quill.QuillToolbarToggleStyleButtonOptions(),
                            ),
                            quill.QuillToolbarToggleCheckListButton(
                              controller: _quillController,
                              options:
                                  const quill.QuillToolbarToggleCheckListButtonOptions(),
                            ),
                            const SizedBox(width: 12),
                          ],
                        ),
                      ),
                      // Secondary toolbar - additional commands (collapsible)
                      if (_showMoreToolbar)
                        ScrollableToolbar(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 12),
                              quill.QuillToolbarToggleStyleButton(
                                attribute: quill.Attribute.strikeThrough,
                                controller: _quillController,
                                options:
                                    const quill.QuillToolbarToggleStyleButtonOptions(),
                              ),
                              quill.QuillToolbarToggleStyleButton(
                                attribute: quill.Attribute.inlineCode,
                                controller: _quillController,
                                options:
                                    const quill.QuillToolbarToggleStyleButtonOptions(),
                              ),
                              const ToolbarDivider(),
                              quill.QuillToolbarToggleStyleButton(
                                attribute: quill.Attribute.blockQuote,
                                controller: _quillController,
                                options:
                                    const quill.QuillToolbarToggleStyleButtonOptions(),
                              ),
                              quill.QuillToolbarToggleStyleButton(
                                attribute: quill.Attribute.codeBlock,
                                controller: _quillController,
                                options:
                                    const quill.QuillToolbarToggleStyleButtonOptions(),
                              ),
                              const ToolbarDivider(),
                              quill.QuillToolbarIndentButton(
                                controller: _quillController,
                                isIncrease: false,
                                options:
                                    const quill.QuillToolbarIndentButtonOptions(),
                              ),
                              quill.QuillToolbarIndentButton(
                                controller: _quillController,
                                isIncrease: true,
                                options:
                                    const quill.QuillToolbarIndentButtonOptions(),
                              ),
                              const ToolbarDivider(),
                              LineHeightDropdown(
                                currentHeight:
                                    _originalNote?.lineHeightMultiplier ?? 1.5,
                                onChanged: (newHeight) {
                                  if (_originalNote != null) {
                                    setState(() {
                                      _originalNote = _originalNote!.copyWith(
                                        lineHeightMultiplier: newHeight,
                                      );
                                      _hasUnsavedChanges = true;
                                    });
                                    _saveNoteInternal(showFeedback: false);
                                  }
                                },
                              ),
                              ParagraphSpacingDropdown(
                                currentSpacing:
                                    _originalNote?.paragraphSpacing ?? 8.0,
                                onChanged: (newSpacing) {
                                  if (_originalNote != null) {
                                    setState(() {
                                      _originalNote = _originalNote!.copyWith(
                                        paragraphSpacing: newSpacing,
                                      );
                                      _hasUnsavedChanges = true;
                                    });
                                    _saveNoteInternal(showFeedback: false);
                                  }
                                },
                              ),
                              const ToolbarDivider(),
                              quill.QuillToolbarColorButton(
                                controller: _quillController,
                                isBackground: false,
                                options:
                                    const quill.QuillToolbarColorButtonOptions(),
                              ),
                              quill.QuillToolbarColorButton(
                                controller: _quillController,
                                isBackground: true,
                                options:
                                    const quill.QuillToolbarColorButtonOptions(),
                              ),
                              const ToolbarDivider(),
                              quill.QuillToolbarClearFormatButton(
                                controller: _quillController,
                                options:
                                    const quill.QuillToolbarClearFormatButtonOptions(),
                              ),
                              const SizedBox(width: 12),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              // Backlinks (items that reference this note)
              if (_originalNote != null)
                BacklinksSection(itemId: _originalNote!.id, itemType: 'note'),
              // Quill editor
              Expanded(
                child: Stack(
                  children: [
                    Listener(
                      onPointerUp: (_) {
                        _quillTapPending = true;
                      },
                      child: quill.QuillEditor(
                        focusNode: _focusNode,
                        scrollController: _scrollController,
                        controller: _quillController,
                        config: quill.QuillEditorConfig(
                          onLaunchUrl: (url) {
                            if (url.startsWith('mention:')) {
                              _openLink(url);
                            } else {
                              _openLink(url);
                            }
                          },
                          linkActionPickerDelegate:
                              (context, link, node) async {
                                if (link.startsWith('mention:')) {
                                  _openLink(link);
                                  return quill.LinkMenuAction.none;
                                }
                                return quill.defaultLinkActionPickerDelegate(
                                  context,
                                  link,
                                  node,
                                );
                              },
                          customStyles: quill.DefaultStyles(
                            link: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.none,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.4),
                            ),
                            paragraph: quill.DefaultTextBlockStyle(
                              TextStyle(
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onSurface,
                                height:
                                    _originalNote?.lineHeightMultiplier ?? 1.5,
                              ),
                              quill.HorizontalSpacing(0, 0),
                              quill.VerticalSpacing(
                                _originalNote?.paragraphSpacing ?? 8.0,
                                _originalNote?.paragraphSpacing ?? 8.0,
                              ),
                              quill.VerticalSpacing(0, 0),
                              null,
                            ),
                            lists: quill.DefaultListBlockStyle(
                              TextStyle(
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onSurface,
                                height:
                                    _originalNote?.lineHeightMultiplier ?? 1.5,
                              ),
                              quill.HorizontalSpacing(0, 0),
                              quill.VerticalSpacing(
                                _originalNote?.paragraphSpacing ?? 8.0,
                                _originalNote?.paragraphSpacing ?? 8.0,
                              ),
                              quill.VerticalSpacing(0, 0),
                              null,
                              null,
                            ),
                          ),
                          embedBuilders: [
                            MediaEmbedBuilder(),
                            LinkEmbedBuilder(),
                          ],
                          padding: EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: 16,
                            bottom:
                                math.max(
                                  MediaQuery.of(context).viewInsets.bottom,
                                  MediaQuery.of(context).viewPadding.bottom,
                                ) +
                                16,
                          ),
                          placeholder: _shouldShowPlaceholder()
                              ? 'Type "/" for media, "@" to link tasks or notes'
                              : null,
                        ),
                      ),
                    ),
                    // Slash command menu - positioned at cursor height
                    if (_showSlashMenu)
                      Positioned(
                        left: 16,
                        right: 16,
                        top: _slashMenuTop,
                        child: SlashCommandMenu(
                          onInsertImage: () => _insertSlashCommand('image'),
                          onInsertVideo: () => _insertSlashCommand('video'),
                          onInsertVoice: () => _insertSlashCommand('voice'),
                          onInsertLink: () => _insertSlashCommand('link'),
                          onInsertCode: () => _insertSlashCommand('code'),
                        ),
                      ),
                    // Floating history controls - visible when feature enabled
                    Consumer(
                      builder: (context, ref, _) {
                        final preferences = ref.watch(preferencesStateProvider);
                        if (!preferences.enableNoteHistory) {
                          return const SizedBox.shrink();
                        }
                        return Positioned(
                          left: 16,
                          bottom: MediaQuery.of(context).viewInsets.bottom > 0
                              ? 8
                              : 16,
                          child: FloatingHistoryControls(
                            noteId: _originalNote?.id ?? widget.noteId,
                            onUndo: _handleUndo,
                            onRedo: _handleRedo,
                            onShowHistory: _showNoteHistory,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
