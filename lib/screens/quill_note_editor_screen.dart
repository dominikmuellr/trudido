import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/note.dart';
import '../controllers/notes_controller.dart';
import '../repositories/notes_repository.dart';
import '../utils/markdown_to_quill_converter.dart';
import '../services/media_service.dart';
import '../widgets/media_embed_builder.dart';

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
          // Calculate approximate vertical position based on line count
          final textBeforeCursor = text.substring(0, cursorPosition);
          final lineCount = '\n'.allMatches(textBeforeCursor).length;
          final lineHeight = 24.0; // Approximate line height
          final calculatedTop = 16 + (lineCount * lineHeight);

          // Clamp between 50 and 300 to keep it visible
          final clampedTop = calculatedTop.clamp(50.0, 300.0);

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
        title: Text(type == MediaType.photo ? 'Add Photo' : 'Add Video'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                type == MediaType.photo
                    ? Icons.photo_library
                    : Icons.video_library,
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
                type == MediaType.photo ? Icons.camera_alt : Icons.videocam,
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
          _quillController.document.insert(index, text.isNotEmpty ? text : url);
          // TODO: Add link attribute when Quill supports it properly
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
    // Find the first non-empty line
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
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
      return Colors.green;
    } else if (_saveStatus.contains('failed')) {
      return Colors.red;
    }
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  Widget _buildSlashMenu() {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
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
            _buildCompactMenuItem(Icons.photo_library, 'Media', () {
              _insertSlashCommand('image');
            }),
            _buildCompactMenuItem(Icons.mic, 'Voice', () {
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
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
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
          ],
        ),
        body: Column(
          children: [
            // Main toolbar row
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Primary toolbar - essential commands
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Font family dropdown - first, like Google Docs
                        quill.QuillToolbarFontFamilyButton(
                          controller: _quillController,
                          options:
                              const quill.QuillToolbarFontFamilyButtonOptions(),
                        ),
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
                        quill.QuillToolbarSelectHeaderStyleDropdownButton(
                          controller: _quillController,
                          options:
                              const quill.QuillToolbarSelectHeaderStyleDropdownButtonOptions(),
                        ),
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
                        // Link
                        quill.QuillToolbarLinkStyleButton(
                          controller: _quillController,
                          options:
                              const quill.QuillToolbarLinkStyleButtonOptions(),
                        ),
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
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  // Request focus when tapping anywhere in the editor area
                  _focusNode.requestFocus();
                },
                child: Stack(
                  children: [
                    quill.QuillEditor(
                      scrollController: _scrollController,
                      focusNode: _focusNode,
                      controller: _quillController,
                      config: quill.QuillEditorConfig(
                        embedBuilders: [MediaEmbedBuilder()],
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 16,
                          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
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
            const Icon(Icons.mic, size: 64, color: Colors.red),
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ],
    );
  }
}
