import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/note.dart';
import '../controllers/notes_controller.dart';
import '../repositories/notes_repository.dart';
import '../repositories/note_folder_repository.dart';
import '../services/note_export_service.dart';
import '../utils/markdown_to_quill_converter.dart';
import '../services/media_service.dart';
import '../widgets/media_embed_builder.dart';
import '../widgets/link_embed_builder.dart';

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
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isEditing = false;
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

  @override
  void initState() {
    super.initState();
    // Initialize with empty document
    _quillController = quill.QuillController.basic();
    _loadNote();
    _quillController.addListener(_onContentChanged);
    _quillController.addListener(_checkForSlashCommand);
    _quillController.addListener(_handleScrollOnDelete);
    _quillController.addListener(_trackMediaChanges);
    _quillController.addListener(_handleMarkdownShortcuts);
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
          // Legacy markdown format - convert to Quill
          // Combine title and content with title as first line
          final titleAndContent =
              '${_originalNote!.title}\n${_originalNote!.content}';
          document = MarkdownToQuillConverter.markdownToDocument(
            titleAndContent,
          );
        }
      } catch (e) {
        // If JSON parsing fails, treat as markdown
        final titleAndContent =
            '${_originalNote!.title}\n${_originalNote!.content}';
        document = MarkdownToQuillConverter.markdownToDocument(titleAndContent);
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
        _isEditing = true;
      });

      // Request focus after loading to show keyboard
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  /// Extract the first line of the document as the title
  String _getTitleFromDocument() {
    final plainText = _quillController.document.toPlainText();
    final lines = plainText.split('\n');
    // Find the first non-empty line that isn't just embed placeholders
    String? firstNonEmptyLine;
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        // Check if line contains only embed placeholder characters (U+FFFC)
        final hasOnlyPlaceholders = trimmed.runes.every((r) => r == 0xFFFC);
        if (!hasOnlyPlaceholders) {
          return trimmed;
        } else if (firstNonEmptyLine == null) {
          firstNonEmptyLine = trimmed;
        }
      }
    }

    // If we only found placeholder lines, check if document has media embeds
    if (firstNonEmptyLine != null) {
      final delta = _quillController.document.toDelta();
      bool hasMedia = false;

      for (var op in delta.toList()) {
        if (op.data is Map) {
          final data = op.data as Map;
          if (data.containsKey('custom')) {
            try {
              final customData =
                  jsonDecode(data['custom'] as String) as Map<String, dynamic>;
              if (customData.containsKey('media')) {
                hasMedia = true;
                break;
              }
            } catch (e) {
              // Ignore decode errors
            }
          }
        }
      }

      if (hasMedia) {
        // Return "Media" as title for media-only notes
        return 'Media';
      }
    }

    // Return empty string to allow notes without titles
    return '';
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
    // Get title from first line of document
    final title = _getTitleFromDocument();

    // Store Quill document as JSON to preserve all formatting
    final content = jsonEncode(_quillController.document.toDelta().toJson());

    debugPrint('=== SAVING NOTE ===');
    debugPrint('Title: $title');
    debugPrint(
      'Content preview: ${content.substring(0, content.length > 200 ? 200 : content.length)}...',
    );
    debugPrint('Content length: ${content.length}');

    if (_quillController.document.toPlainText().trim().isEmpty) {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enter some content'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
      throw Exception('Content cannot be empty');
    }

    final controller = ref.read(notesControllerProvider.notifier);
    Note? savedNote;
    final existingId = _originalNote?.id ?? widget.noteId;

    if (existingId != null) {
      savedNote = await controller.updateNote(
        id: existingId,
        title: title,
        content: content,
      );
      _isEditing = true;
    } else {
      savedNote = await controller.createNote(
        title: title,
        content: content,
        folderId: widget.initialFolderId,
      );
      _isEditing = true;
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
        await launchUrl(uri);
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

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _quillController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _mediaService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _getTitleFromDocument();

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
          title: Text(
            title == 'Untitled' || title.isEmpty
                ? (_isEditing ? 'Edit Note' : 'New Note')
                : title,
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
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Export',
              onPressed: () => _showExportOptions(),
            ),
          ],
        ),
        body: Column(
          children: [
            // Main toolbar row
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
              ),
              child: Column(
                children: [
                  // Primary toolbar - essential commands
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        // Font family dropdown - first, like Google Docs
                        _buildFontFamilyDropdown(),
                        const SizedBox(width: 8),
                        // Font size dropdown - numeric sizes like Word
                        _buildFontSizeDropdown(),
                        const SizedBox(width: 8),
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
                        const SizedBox(width: 8),
                        // Header style dropdown - paragraph formatting
                        _buildHeaderStyleDropdown(),
                        const SizedBox(width: 8),
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
                        const SizedBox(width: 8),
                        // More options toggle button
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
                          },
                        ),
                      ],
                    ),
                  ),
                  // Secondary toolbar - additional commands (collapsible)
                  if (_showMoreToolbar)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
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
                          const SizedBox(width: 4),
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
                          const SizedBox(width: 4),
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
                          const SizedBox(width: 4),
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
                          const SizedBox(width: 4),
                          quill.QuillToolbarClearFormatButton(
                            controller: _quillController,
                            options:
                                const quill.QuillToolbarClearFormatButtonOptions(),
                          ),
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
                        embedBuilders: [
                          MediaEmbedBuilder(),
                          LinkEmbedBuilder(),
                        ],
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 16,
                          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
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
