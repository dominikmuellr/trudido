// Trudido - A privacy-focused todo and notes app
// Copyright (C) 2025 Dominik Müller
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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
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
import '../providers/app_providers.dart';
import '../services/preferences_service.dart';

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

  const QuillNoteEditorScreen({super.key, this.noteId, this.initialFolderId});

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

  @override
  void initState() {
    super.initState();
    // Initialize with empty document
    _quillController = quill.QuillController.basic();
    _loadNote();
    _loadToolbarPreferences();
    _quillController.addListener(_onContentChanged);
    _quillController.addListener(_checkForSlashCommand);
    _quillController.addListener(_handleScrollOnDelete);
    _quillController.addListener(_trackMediaChanges);
    _quillController.addListener(_handleMarkdownShortcuts);
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

    print('QuillNoteEditor initialized: noteId=${widget.noteId}');
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
    ref.read(preferencesStateProvider.notifier).state = updated;
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

    debugPrint(
      '_handleScrollOnDelete: lineCount=$lineCount, previous=$_previousLineCount',
    );

    // Detect line deletion and scroll up proportionally
    if (lineCount < _previousLineCount) {
      final linesDeleted = _previousLineCount - lineCount;
      debugPrint('Lines deleted: $linesDeleted, scrolling up...');

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
          debugPrint(
            'Scrolling from $currentScroll to $targetScroll (delta: $scrollAmount)',
          );
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
      print('Error applying markdown format: $e');
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
          TextButton(
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

      debugPrint('Inserting media: type=$type, path=${savedFile.path}');

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

      debugPrint('Media data JSON: $mediaData');

      final mediaEmbed = quill.BlockEmbed.custom(
        quill.CustomBlockEmbed('media', mediaData),
      );

      debugPrint('Created embed: ${mediaEmbed.toString()}');

      // Insert the embed with newlines around it
      _quillController.document.insert(index, '\n');
      _quillController.document.insert(index + 1, mediaEmbed);
      _quillController.document.insert(index + 2, '\n');

      _quillController.updateSelection(
        TextSelection.collapsed(offset: index + 3),
        quill.ChangeSource.local,
      );

      // Trigger auto-scroll after media insertion with a delay to ensure rendering
      debugPrint('Scheduling auto-scroll after media insertion');
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
      builder: (context) => _VoiceRecordingDialog(
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
      builder: (context) => _LinkDialog(
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

          print('Inserted inline link: text="$displayText", url="$url"');
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
          final migratedJson = _migrateFontSizes(json);

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

      setState(() {
        _quillController = quill.QuillController(
          document: document,
          selection: const TextSelection.collapsed(offset: 0),
        );
        _quillController.addListener(_onContentChanged);
        _quillController.addListener(_checkForSlashCommand);
        _quillController.addListener(_handleScrollOnDelete);
        _quillController.addListener(_trackMediaChanges);
      });

      // Request focus after loading to show keyboard
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
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
              debugPrint('Error parsing custom embed during init: $e');
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
              debugPrint('Error parsing media during init: $e');
            }
          }
        }
      }
      debugPrint(
        'Initialized media tracking with ${_trackedMediaFiles.length} files',
      );
    } catch (e) {
      debugPrint('Error initializing media tracking: $e');
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
              debugPrint('Error parsing custom embed in tracker: $e');
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
              debugPrint('Error parsing media in tracker: $e');
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
            debugPrint('Deleted removed media file: $filePath');
          }
        } catch (e) {
          debugPrint('Error deleting media file: $e');
        }
      }

      // Update tracked files
      _trackedMediaFiles = currentMediaFiles;
    } catch (e) {
      debugPrint('Error tracking media changes: $e');
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

    debugPrint('=== SAVING NOTE ===');
    debugPrint('Title: $title');
    debugPrint(
      'Content preview: ${content.substring(0, content.length > 200 ? 200 : content.length)}...',
    );
    debugPrint('Content length: ${content.length}');

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

    if (existingId != null) {
      savedNote = await controller.updateNote(
        id: existingId,
        title: title,
        content: content,
        lineHeightMultiplier: _originalNote?.lineHeightMultiplier,
        paragraphSpacing: _originalNote?.paragraphSpacing,
      );
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
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
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
      await NoteExportService.sharePdf(bytes, filename, context);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Exported "$filename"')));
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Widget _buildSlashMenu() {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      shadowColor: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildCompactMenuItem(Icons.image_outlined, 'Photo', () {
              _insertSlashCommand('image');
            }),
            _buildCompactMenuItem(Icons.videocam_outlined, 'Video', () {
              _insertSlashCommand('video');
            }),
            _buildCompactMenuItem(Icons.mic_outlined, 'Voice', () {
              _insertSlashCommand('voice');
            }),
            _buildCompactMenuItem(Icons.link, 'Link', () {
              _insertSlashCommand('link');
            }),
            _buildCompactMenuItem(Icons.code, 'Code', () {
              _insertSlashCommand('code');
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactMenuItem(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Future<void> _openLink(String url) async {
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
      print('Error opening link: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error opening link')));
      }
    }
  }

  /// Builds a scrollable toolbar with fade indicators to hint at more content
  Widget _buildScrollableToolbar({required Widget child}) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: const [0.0, 0.02, 0.98, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: child,
      ),
    );
  }

  /// Builds a vertical divider for the toolbar to separate groups
  Widget _buildToolbarDivider() {
    return Container(
      height: 24,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
    );
  }

  Widget _buildFontSizeDropdown() {
    // Common font sizes like in Word (8, 9, 10, 11, 12, 14, 16, 18, 20, 24, 28, 32, 36, 48, 72)
    final fontSizes = [
      8,
      9,
      10,
      11,
      12,
      14,
      16,
      18,
      20,
      24,
      28,
      32,
      36,
      48,
      72,
    ];

    // Get current font size from selection
    int currentSize = 16; // Default size

    try {
      final style = _quillController.getSelectionStyle();
      final sizeAttr = style.attributes[quill.Attribute.size.key]?.value;

      if (sizeAttr != null) {
        if (sizeAttr is String) {
          // Extract numeric value from size attribute (handles both "18" and "18px")
          final numStr = sizeAttr.replaceAll(RegExp(r'[^0-9]'), '');
          final parsed = int.tryParse(numStr);
          if (parsed != null && fontSizes.contains(parsed)) {
            currentSize = parsed;
          }
        } else if (sizeAttr is num) {
          // Handle numeric values directly
          final parsed = sizeAttr.toInt();
          if (fontSizes.contains(parsed)) {
            currentSize = parsed;
          }
        }
      }
    } catch (e) {
      // Ignore errors and use default
    }

    return PopupMenuButton<int>(
      tooltip: 'Font size',
      initialValue: currentSize,
      offset: const Offset(0, 40),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$currentSize',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 14),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => fontSizes.map((size) {
        return PopupMenuItem<int>(
          value: size,
          child: Text(
            '$size',
            style: TextStyle(
              fontSize: 14,
              fontWeight: size == currentSize
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
      onSelected: (newSize) {
        // Apply font size using Quill's size attribute
        _quillController.formatSelection(
          quill.Attribute.fromKeyValue('size', '$newSize'),
        );
        setState(() {}); // Refresh to show new size
      },
    );
  }

  Widget _buildHeaderStyleDropdown() {
    final headers = [
      (label: 'Normal', value: 0),
      (label: 'Header 1', value: 1),
      (label: 'Header 2', value: 2),
      (label: 'Header 3', value: 3),
    ];

    // Get current header style
    int currentHeader = 0;
    try {
      final style = _quillController.getSelectionStyle();
      final headerAttr = style.attributes[quill.Attribute.header.key]?.value;
      if (headerAttr != null) {
        if (headerAttr is int) {
          currentHeader = headerAttr;
        }
      }
    } catch (e) {
      // Ignore errors and use default
    }

    final currentLabel = headers
        .firstWhere((h) => h.value == currentHeader, orElse: () => headers[0])
        .label;

    return PopupMenuButton<int>(
      tooltip: 'Header style',
      offset: const Offset(0, 40),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentLabel,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 14),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => headers.map((header) {
        return PopupMenuItem<int>(
          value: header.value,
          child: Text(
            header.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: header.value == currentHeader
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
      onSelected: (headerLevel) {
        if (headerLevel == 0) {
          // Remove header attribute
          _quillController.formatSelection(quill.Attribute.header);
        } else {
          // Apply header attribute
          _quillController.formatSelection(
            quill.Attribute.fromKeyValue('header', headerLevel),
          );
        }
        setState(() {});
      },
    );
  }

  Widget _buildFontFamilyDropdown() {
    final fontFamilies = [
      'Roboto',
      'Courier',
      'Monospace',
      'Sans-serif',
      'Serif',
    ];

    // Get current font family
    String currentFamily = 'Roboto';
    try {
      final style = _quillController.getSelectionStyle();
      final fontAttr = style.attributes[quill.Attribute.font.key]?.value;
      if (fontAttr != null && fontAttr is String) {
        currentFamily = fontAttr;
      }
    } catch (e) {
      // Ignore errors and use default
    }

    return PopupMenuButton<String>(
      tooltip: 'Font family',
      offset: const Offset(0, 40),
      child: Container(
        height: 36,
        constraints: const BoxConstraints(maxWidth: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                currentFamily,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 14),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => fontFamilies.map((family) {
        return PopupMenuItem<String>(
          value: family,
          child: Text(
            family,
            style: TextStyle(
              fontSize: 14,
              fontFamily: family,
              fontWeight: family == currentFamily
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
      onSelected: (newFamily) {
        _quillController.formatSelection(
          quill.Attribute.fromKeyValue('font', newFamily),
        );
        setState(() {});
      },
    );
  }

  Widget _buildLineHeightDropdown() {
    final lineHeights = [1.0, 1.2, 1.5, 1.8, 2.0, 2.2, 2.5, 3.0];
    final currentHeight = _originalNote?.lineHeightMultiplier ?? 1.5;

    return PopupMenuButton<double>(
      tooltip: 'Line height',
      offset: const Offset(0, 40),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${currentHeight.toStringAsFixed(1)}x',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 14),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => lineHeights.map((height) {
        return PopupMenuItem<double>(
          value: height,
          child: Text(
            '${height.toStringAsFixed(1)}x',
            style: TextStyle(
              fontSize: 14,
              fontWeight: (height - currentHeight).abs() < 0.01
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
      onSelected: (newHeight) {
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
    );
  }

  Widget _buildParagraphSpacingDropdown() {
    final spacings = [0.0, 4.0, 8.0, 12.0, 16.0, 24.0];
    final currentSpacing = _originalNote?.paragraphSpacing ?? 8.0;

    return PopupMenuButton<double>(
      tooltip: 'Paragraph spacing',
      offset: const Offset(0, 40),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${currentSpacing.toStringAsFixed(0)}pt',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 14),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => spacings.map((spacing) {
        return PopupMenuItem<double>(
          value: spacing,
          child: Text(
            '${spacing.toStringAsFixed(0)}pt',
            style: TextStyle(
              fontSize: 14,
              fontWeight: (spacing - currentSpacing).abs() < 0.01
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
      onSelected: (newSpacing) {
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
    );
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
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
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
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
              IconButton(
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
            IconButton(
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
                        ).colorScheme.outlineVariant.withOpacity(0.5),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Primary toolbar - essential commands with scroll indicator
                      _buildScrollableToolbar(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 8),
                            // More options toggle button - at the beginning for visibility
                            IconButton(
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
                            _buildToolbarDivider(),
                            // Font family dropdown - first, like Google Docs
                            _buildFontFamilyDropdown(),
                            _buildToolbarDivider(),
                            // Font size dropdown - numeric sizes like Word
                            _buildFontSizeDropdown(),
                            _buildToolbarDivider(),
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
                            _buildToolbarDivider(),
                            // Header style dropdown - paragraph formatting
                            _buildHeaderStyleDropdown(),
                            _buildToolbarDivider(),
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
                        _buildScrollableToolbar(
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
                              _buildToolbarDivider(),
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
                              _buildToolbarDivider(),
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
                              _buildToolbarDivider(),
                              _buildLineHeightDropdown(),
                              _buildParagraphSpacingDropdown(),
                              _buildToolbarDivider(),
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
                              _buildToolbarDivider(),
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
              // Quill editor
              Expanded(
                child: Stack(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onLongPress: () {
                        // Check if cursor is on a link
                        final selection = _quillController.selection;
                        if (selection.isValid) {
                          final offset = selection.baseOffset;
                          if (offset > 0) {
                            final checkOffset = offset - 1;
                            final leaf = _quillController.document.queryChild(
                              checkOffset,
                            );
                            if (leaf.node != null) {
                              final style = leaf.node!.style;
                              final linkAttr =
                                  style.attributes[quill.Attribute.link.key];
                              if (linkAttr != null && linkAttr.value != null) {
                                _openLink(linkAttr.value.toString());
                              }
                            }
                          }
                        }
                      },
                      child: quill.QuillEditor(
                        focusNode: _focusNode,
                        scrollController: _scrollController,
                        controller: _quillController,
                        config: quill.QuillEditorConfig(
                          customStyles: quill.DefaultStyles(
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
                              ? 'Type "/" for media or use markdown syntax'
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
                        child: _buildSlashMenu(),
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

/// Dialog for inserting a link
class _LinkDialog extends StatefulWidget {
  final Function(String url, String text) onInsert;

  const _LinkDialog({required this.onInsert});

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  final _urlController = TextEditingController();
  final _textController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Insert Link'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'URL',
              hintText: 'https://example.com',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            decoration: const InputDecoration(
              labelText: 'Link Text (optional)',
              hintText: 'Click here',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_urlController.text.trim().isNotEmpty) {
              widget.onInsert(
                _urlController.text.trim(),
                _textController.text.trim(),
              );
              Navigator.of(context).pop();
            }
          },
          child: const Text('Insert'),
        ),
      ],
    );
  }
}

/// Dialog for recording voice notes
class _VoiceRecordingDialog extends StatefulWidget {
  final MediaService mediaService;
  final Function(File) onRecordingComplete;

  const _VoiceRecordingDialog({
    required this.mediaService,
    required this.onRecordingComplete,
  });

  @override
  State<_VoiceRecordingDialog> createState() => _VoiceRecordingDialogState();
}

class _VoiceRecordingDialogState extends State<_VoiceRecordingDialog> {
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  Timer? _durationTimer;
  Duration _recordingDuration = Duration.zero;

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final success = await widget.mediaService.startRecording();
    if (success && mounted) {
      setState(() {
        _isRecording = true;
        _recordingStartTime = DateTime.now();
        _recordingDuration = Duration.zero;
      });

      // Update duration every second
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && _recordingStartTime != null) {
          setState(() {
            _recordingDuration = DateTime.now().difference(
              _recordingStartTime!,
            );
          });
        }
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to start recording. Check microphone permission.',
          ),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _stopRecording() async {
    _durationTimer?.cancel();
    final file = await widget.mediaService.stopRecording();
    if (file != null && mounted) {
      widget.onRecordingComplete(file);
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to save recording')));
      Navigator.pop(context);
    }
  }

  Future<void> _cancelRecording() async {
    _durationTimer?.cancel();
    await widget.mediaService.cancelRecording();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record Voice Note'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isRecording) ...[
            const SizedBox(height: 20),
            Icon(
              Icons.mic,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 20),
            Text(
              _formatDuration(_recordingDuration),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            const Text('Recording...'),
          ] else ...[
            const SizedBox(height: 20),
            Icon(
              Icons.mic_none,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            const Text('Tap the microphone to start recording'),
          ],
        ],
      ),
      actions: [
        if (!_isRecording) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: _startRecording,
            icon: const Icon(Icons.mic),
            label: const Text('Start Recording'),
          ),
        ] else ...[
          TextButton(onPressed: _cancelRecording, child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: _stopRecording,
            icon: const Icon(Icons.stop),
            label: const Text('Stop & Save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
          ),
        ],
      ],
    );
  }
}
