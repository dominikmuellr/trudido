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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trudido/utils/responsive_size.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../models/note.dart';
import '../controllers/notes_controller.dart';
import '../providers/notes_providers.dart';
import '../repositories/notes_repository.dart';
import '../repositories/note_folder_repository.dart';
import '../services/vault_auth_service.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import '../utils/note_colors.dart';
import '../widgets/note_preview_card_markdown.dart';
import '../widgets/notes_filter_chips.dart';
import 'home_screen_notifiers.dart';
import 'quill_note_editor_screen.dart';
import '../providers/app_providers.dart';
import '../widgets/common/common.dart';
import '../utils/state_notifiers.dart';
import '../utils/animated_navigation.dart';
import '../widgets/skeleton_loading.dart';
import '../widgets/note_content_view.dart';

/// Provider for notes search mode
final notesSearchModeProvider = stateProvider<bool>(false);

/// Main notes screen showing list of all notes
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _staggerController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  // ─── Grid drag-and-drop state ─────────────────────────────────────────
  String? _draggedNoteId; // ID of the note being dragged
  String? _dragHoverNoteId; // ID of the note being hovered over
  List<Note>?
  _optimisticNotes; // Optimistic reorder result to prevent snap-back

  // ─── Freeform canvas state ────────────────────────────────────────────
  final TransformationController _freeformTransformController =
      TransformationController();
  final Map<String, Offset> _livePositions = {};
  String? _movingNoteId;
  Offset? _dragStartCanvasPos; // canvas position of note when drag began
  Offset? _dragStartScreenPos; // screen position when drag began
  List<Note> _freeformNotes = []; // cached for hit-testing
  bool _freeformInitialized = false;

  /// LOD levels: 0 = full cards, 1 = title bubbles, 2 = dots
  int _lodLevel = 0;
  static const double _lodBubbleThreshold = 0.65;
  static const double _lodDotThreshold = 0.25;
  String? _lastFolderId; // track folder changes for freeform reset

  // ─── Custom pinch/pan gesture state ───────────────────────────────────
  Offset? _gestureLastFocal;
  double? _gestureLastScale;
  Offset? _scaleStartPoint; // to detect taps vs drags
  bool _scaleHadSignificantMove = false;
  Timer? _longPressTimer; // for detecting long-press on freeform notes

  void _clearDragState() {
    if (_draggedNoteId != null || _dragHoverNoteId != null) {
      setState(() {
        _draggedNoteId = null;
        _dragHoverNoteId = null;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _freeformTransformController.addListener(_onCanvasTransformChanged);
  }

  @override
  void didChangeMetrics() {
    _updateSystemUI();
  }

  void _updateSystemUI() {
    if (!mounted) return;
    final orientation = MediaQuery.orientationOf(context);
    final viewMode = ref.read(notesViewModeProvider);
    if (orientation == Orientation.landscape && viewMode == 'freeform') {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _onCanvasTransformChanged() {
    final scale = _freeformTransformController.value.storage[0];
    final newLevel = scale >= _lodBubbleThreshold
        ? 0 // full cards
        : scale >= _lodDotThreshold
        ? 1 // title bubbles
        : 2; // dots
    if (newLevel != _lodLevel) {
      setState(() => _lodLevel = newLevel);
    }
  }

  // ── Freeform drag helpers ──
  void _onFreeformDragEnd(String noteId) {
    final finalPos = _livePositions[noteId];
    if (finalPos != null) {
      ref
          .read(noteFreeformPositionsProvider.notifier)
          .updatePosition(noteId, finalPos);
    }
    _dragStartCanvasPos = null;
    _dragStartScreenPos = null;
    setState(() => _movingNoteId = null);
  }

  void _showFreeformContextMenu(Note note, Offset screenPosition) {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      screenPosition & const Size(1, 1),
      Offset.zero & overlay.size,
    );
    final isInVault = _isNoteInVault(note);

    showMenu<void>(
      context: context,
      position: position,
      items: [
        PopupMenuItem<void>(
          onTap: () => _editNote(note.id),
          child: const ListTile(
            leading: Icon(Icons.edit),
            title: Text('Edit'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem<void>(
          onTap: () => _togglePin(note.id),
          child: ListTile(
            leading: Icon(
              note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            ),
            title: Text(note.isPinned ? 'Unpin' : 'Pin'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem<void>(
          onTap: () {
            final ctx = context;
            Future.microtask(() {
              if (ctx.mounted) _showFreeformColorPicker(ctx, note);
            });
          },
          child: ListTile(
            leading: Icon(
              Icons.palette_outlined,
              color: resolveNoteColor(
                note.colorValue,
                Theme.of(context).brightness,
              ),
            ),
            title: const Text('Card color'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (!isInVault)
          PopupMenuItem<void>(
            onTap: () => _moveNoteToFolder(note),
            child: const ListTile(
              leading: Icon(Icons.drive_file_move_outline),
              title: Text('Move to Folder'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        PopupMenuItem<void>(
          onTap: () => _deleteNote(note.id, note.title),
          child: const ListTile(
            leading: Icon(Icons.delete, color: Colors.red),
            title: Text('Delete', style: TextStyle(color: Colors.red)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  void _showFreeformColorPicker(BuildContext context, Note note) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Card color', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ...kNoteColorPalette.map((option) {
                    final brightness = Theme.of(ctx).brightness;
                    final isSelected = option.index == note.colorValue;
                    final swatchColor =
                        option.colorForBrightness(brightness) ??
                        Theme.of(ctx).colorScheme.surfaceContainerHighest;
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _setNoteColor(note.id, option.index);
                      },
                      child: Tooltip(
                        message: option.label,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: swatchColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(ctx).colorScheme.primary
                                  : Theme.of(ctx).colorScheme.outline
                                        .withValues(alpha: 0.4),
                              width: isSelected ? 3 : 1.5,
                            ),
                          ),
                          child: option.index == null
                              ? Icon(
                                  Icons.format_color_reset,
                                  size: 20,
                                  color: Theme.of(
                                    ctx,
                                  ).colorScheme.onSurfaceVariant,
                                )
                              : isSelected
                              ? Icon(
                                  Icons.check,
                                  size: 20,
                                  color: swatchColor.computeLuminance() > 0.5
                                      ? Colors.black87
                                      : Colors.white,
                                )
                              : null,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Convert a screen-space point to canvas coordinates using the current
  /// transform matrix, then check if any note's draggable area contains it.
  String? _hitTestNoteAtScreen(Offset screenPoint) {
    final inverse = Matrix4.inverted(_freeformTransformController.value);
    final canvasPoint = MatrixUtils.transformPoint(inverse, screenPoint);

    // Determine sizes based on current LOD level
    final double w;
    final double h;
    if (_lodLevel == 0) {
      w = _freeformCardWidth;
      h = 28; // grip bar height only
    } else if (_lodLevel == 1) {
      w = _freeformBubbleWidth;
      h = _freeformBubbleHeight;
    } else {
      w = _freeformDotSize;
      h = _freeformDotSize;
    }

    // Iterate in reverse to match visual stacking (last painted = on top)
    for (int i = _freeformNotes.length - 1; i >= 0; i--) {
      final note = _freeformNotes[i];
      final pos = _livePositions[note.id];
      if (pos == null) continue;
      final rect = Rect.fromLTWH(pos.dx, pos.dy, w, h);
      if (rect.contains(canvasPoint)) return note.id;
    }
    return null;
  }

  /// Inverse-transform a screen point to canvas coordinates and check if any
  /// note card (full area, not just grip) contains it. Returns the note id.
  String? _hitTestNoteCardAtScreen(Offset screenPoint) {
    final inverse = Matrix4.inverted(_freeformTransformController.value);
    final canvasPoint = MatrixUtils.transformPoint(inverse, screenPoint);

    final double w;
    final double h;
    if (_lodLevel == 0) {
      w = _freeformCardWidth;
      h = 200; // approximate full card height
    } else if (_lodLevel == 1) {
      w = _freeformBubbleWidth;
      h = _freeformBubbleHeight;
    } else {
      w = _freeformDotSize;
      h = _freeformDotSize;
    }

    // Iterate in reverse to match visual stacking (last painted = on top)
    for (int i = _freeformNotes.length - 1; i >= 0; i--) {
      final note = _freeformNotes[i];
      final pos = _livePositions[note.id];
      if (pos == null) continue;
      final rect = Rect.fromLTWH(pos.dx, pos.dy, w, h);
      if (rect.contains(canvasPoint)) return note.id;
    }
    return null;
  }

  // ── Custom pinch-to-zoom & pan handlers ──
  void _onCanvasScaleStart(ScaleStartDetails details) {
    _scaleStartPoint = details.localFocalPoint;
    _scaleHadSignificantMove = false;
    // Single-finger: check if touching a note drag area
    if (details.pointerCount == 1) {
      final noteId = _hitTestNoteAtScreen(details.localFocalPoint);
      if (noteId != null) {
        _dragStartCanvasPos = _livePositions[noteId] ?? const Offset(800, 400);
        _dragStartScreenPos = details.localFocalPoint;
        setState(() => _movingNoteId = noteId);
        HapticFeedback.selectionClick();
        _longPressTimer?.cancel();
        return;
      }
    }
    _gestureLastFocal = details.localFocalPoint;
    _gestureLastScale = 1.0;
  }

  void _onCanvasScaleUpdate(ScaleUpdateDetails details) {
    // Track whether finger moved significantly (to distinguish tap from drag)
    if (!_scaleHadSignificantMove && _scaleStartPoint != null) {
      final delta = (details.localFocalPoint - _scaleStartPoint!).distance;
      if (delta > 10) {
        _scaleHadSignificantMove = true;
        _longPressTimer?.cancel();
      }
    }

    // Handle note dragging
    if (_movingNoteId != null) {
      if (_dragStartCanvasPos == null || _dragStartScreenPos == null) return;
      final scale = _freeformTransformController.value.storage[0];
      final offsetFromOrigin = details.localFocalPoint - _dragStartScreenPos!;
      final rawPos = _dragStartCanvasPos! + offsetFromOrigin / scale;

      // Clamp within canvas bounds (6000x6000), leaving room for the note widget
      const canvasSize = 6000.0;
      const margin = 20.0;
      final noteW = _lodLevel == 0
          ? _freeformCardWidth
          : _lodLevel == 1
          ? _freeformBubbleWidth
          : _freeformDotSize;
      final noteH = _lodLevel == 0
          ? 180.0
          : _lodLevel == 1
          ? _freeformBubbleHeight
          : _freeformDotSize;
      final clampedPos = Offset(
        rawPos.dx.clamp(margin, canvasSize - noteW - margin),
        rawPos.dy.clamp(margin, canvasSize - noteH - margin),
      );

      setState(() {
        _livePositions[_movingNoteId!] = clampedPos;
      });
      return;
    }

    if (_gestureLastFocal == null) return;

    final matrix = _freeformTransformController.value.clone();
    final currentScale = matrix.storage[0];

    // Incremental scale factor since last frame
    final incrementalScale = details.scale / _gestureLastScale!;
    final newScale = (currentScale * incrementalScale).clamp(0.05, 2.5);
    final actualScaleFactor = newScale / currentScale;

    // Incremental focal point movement
    final focalDelta = details.localFocalPoint - _gestureLastFocal!;

    // Current translation
    final tx = matrix.storage[12];
    final ty = matrix.storage[13];

    // Scale around the current focal point, then apply pan delta
    final focal = details.localFocalPoint;
    final newTx =
        focal.dx * (1 - actualScaleFactor) +
        tx * actualScaleFactor +
        focalDelta.dx;
    final newTy =
        focal.dy * (1 - actualScaleFactor) +
        ty * actualScaleFactor +
        focalDelta.dy;

    final newMatrix = Matrix4.identity()
      ..setEntry(0, 0, newScale)
      ..setEntry(1, 1, newScale)
      ..setEntry(0, 3, newTx)
      ..setEntry(1, 3, newTy);

    _freeformTransformController.value = newMatrix;

    _gestureLastFocal = details.localFocalPoint;
    _gestureLastScale = details.scale;
  }

  void _onCanvasScaleEnd(ScaleEndDetails details) {
    _longPressTimer?.cancel();
    if (_movingNoteId != null) {
      _onFreeformDragEnd(_movingNoteId!);
    } else if (!_scaleHadSignificantMove && _scaleStartPoint != null) {
      // Gesture was a tap — check if a note card is under the finger
      final noteId = _hitTestNoteCardAtScreen(_scaleStartPoint!);
      if (noteId != null) {
        _showNoteQuickView(_freeformNotes.firstWhere((n) => n.id == noteId));
      }
    }
    _gestureLastFocal = null;
    _gestureLastScale = null;
    _scaleStartPoint = null;
  }

  // ── Raw pointer handlers for long-press context menu ──
  Offset? _longPressStartGlobal;

  void _onFreeformPointerDown(PointerDownEvent event) {
    _longPressTimer?.cancel();
    _longPressStartGlobal = event.position;
    final localPoint = event.localPosition;
    _longPressTimer = Timer(const Duration(milliseconds: 500), () {
      if (_movingNoteId != null) return;
      final noteId = _hitTestNoteCardAtScreen(localPoint);
      if (noteId != null) {
        HapticFeedback.mediumImpact();
        final note = _freeformNotes.firstWhere((n) => n.id == noteId);
        _showFreeformContextMenu(note, event.position);
      }
    });
  }

  void _onFreeformPointerMove(PointerMoveEvent event) {
    if (_longPressStartGlobal != null) {
      final delta = (event.position - _longPressStartGlobal!).distance;
      if (delta > 10) {
        _longPressTimer?.cancel();
        _longPressStartGlobal = null;
      }
    }
  }

  void _onFreeformPointerUp(PointerUpEvent event) {
    _longPressTimer?.cancel();
    _longPressStartGlobal = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Restore system UI when leaving the screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _longPressTimer?.cancel();
    _freeformTransformController.removeListener(_onCanvasTransformChanged);
    _staggerController.dispose();
    _freeformTransformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotesAsync = ref.watch(filteredNotesProvider);
    final selectedFolderId = ref.watch(selectedNoteFolderProvider);
    final spacing = ref.watch(adaptiveSpacingProvider);

    return filteredNotesAsync.when(
      data: (notes) => _buildBody(notes, selectedFolderId == null),
      loading: () => const SkeletonNoteList(),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaledIcon(
              Icons.warning,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            spacing.gapV16,
            Text(
              'Error loading notes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            spacing.gapV8,
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            spacing.gapV16,
            FilledButton(
              onPressed: () => ref.refresh(notesProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<Note> notes, bool isAllNotesView) {
    final viewMode = ref.watch(notesViewModeProvider);
    // Update immersive mode whenever viewMode or orientation changes
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateSystemUI());
    final isMultiSelect = ref.watch(notesMultiSelectModeProvider);
    final selectedNoteIds = ref.watch(selectedNoteIdsProvider);
    // Use optimistic notes if available (prevents D&D snap-back)
    final effectiveNotes = _optimisticNotes ?? notes;
    // Clear optimistic state once the provider catches up
    if (_optimisticNotes != null &&
        notes.length == _optimisticNotes!.length &&
        notes.isNotEmpty &&
        notes.first.id == _optimisticNotes!.first.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _optimisticNotes = null);
      });
    }

    // Reset freeform state when folder changes
    final currentFolderId = ref.watch(selectedNoteFolderProvider);
    if (_lastFolderId != null && _lastFolderId != currentFolderId) {
      _freeformInitialized = false;
      _livePositions.clear();
      _movingNoteId = null;
    }
    _lastFolderId = currentFolderId;

    return Column(
      children: [
        if (viewMode != 'freeform') const NotesFilterChips(),
        Expanded(
          child: effectiveNotes.isEmpty
              ? _buildEmptyState()
              : viewMode == 'grid'
              ? _buildGridView(effectiveNotes, isAllNotesView)
              : viewMode == 'freeform'
              ? _buildFreeformView(effectiveNotes, isAllNotesView)
              : _buildListView(effectiveNotes, isAllNotesView),
        ),
        if (isMultiSelect) _buildBulkActionBar(effectiveNotes, selectedNoteIds),
      ],
    );
  }

  /// Build grid view with drag-and-drop reordering
  Widget _buildGridView(List<Note> notes, bool isAllNotesView) {
    final spacing = ref.watch(adaptiveSpacingProvider);
    final isMultiSelect = ref.watch(notesMultiSelectModeProvider);
    final selectedNoteIds = ref.watch(selectedNoteIdsProvider);

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        if (scrollNotification is ScrollUpdateNotification) {
          if (scrollNotification.metrics.pixels < -20) {
            ref.read(notesSearchModeProvider.notifier).update(true);
            return true;
          }
        }
        if (scrollNotification is OverscrollNotification) {
          if (scrollNotification.overscroll < -20) {
            ref.read(notesSearchModeProvider.notifier).update(true);
            return true;
          }
        }
        return false;
      },
      child: MasonryGridView.count(
        padding: spacing.insets8.copyWith(
          bottom:
              ref.watch(
                preferencesStateProvider.select((p) => p.floatingNavBar),
              )
              ? 96
              : spacing.s8,
        ),
        physics: const BouncingScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: spacing.s8,
        crossAxisSpacing: spacing.s8,
        itemCount: notes.length,
        itemBuilder: (context, index) {
          final note = notes[index];
          final isInVault = _isNoteInVault(note);
          final isDragging = _draggedNoteId != null;
          final isHovered = _dragHoverNoteId == note.id;

          final card = NotePreviewCard(
            note: note,
            onTap: () => _editNote(note.id),
            onPin: () => _togglePin(note.id),
            onDelete: () => _deleteNote(note.id, note.title),
            onDeleteConfirmed: () => _deleteNoteConfirmed(note.id),
            isInVault: isInVault,
            onMoveToFolder: isInVault ? null : () => _moveNoteToFolder(note),
            showFormatIndicator: isAllNotesView,
            isGridView: true,
            onColorChange: (color) => _setNoteColor(note.id, color),
            selectable: isMultiSelect,
            selected: selectedNoteIds.contains(note.id),
            onSelectToggle: () => _onSelectToggle(note.id),
          );

          return DragTarget<String>(
            onWillAcceptWithDetails: (details) {
              if (_draggedNoteId == null) return false;
              if (details.data == note.id) return false; // don't accept self
              final draggedNote = notes.firstWhere(
                (n) => n.id == _draggedNoteId,
                orElse: () => note,
              );
              return draggedNote.isPinned == note.isPinned;
            },
            onMove: (details) {
              if (_dragHoverNoteId != note.id) {
                setState(() => _dragHoverNoteId = note.id);
              }
            },
            onLeave: (_) {
              if (_dragHoverNoteId == note.id) {
                setState(() => _dragHoverNoteId = null);
              }
            },
            onAcceptWithDetails: (details) {
              // Build the reordered list and persist
              final dragIdx = notes.indexWhere((n) => n.id == details.data);
              if (dragIdx == -1) return;
              final reordered = List<Note>.from(notes);
              final item = reordered.removeAt(dragIdx);
              // Find the target note in the modified list (indices shifted after removal)
              final insertIdx = reordered.indexWhere((n) => n.id == note.id);
              reordered.insert(
                insertIdx >= 0 ? insertIdx : reordered.length,
                item,
              );
              setState(() => _optimisticNotes = reordered);
              ref
                  .read(notesControllerProvider.notifier)
                  .commitReorder(reordered);
              _clearDragState();
            },
            builder: (context, candidateData, rejectedData) {
              // Wrap card to show highlight when hovered during drag
              Widget styledCard = card;
              if (isHovered && isDragging) {
                styledCard = Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2.5,
                    ),
                  ),
                  child: card,
                );
              }

              return LongPressDraggable<String>(
                data: note.id,
                delay: const Duration(milliseconds: 300),
                hapticFeedbackOnStart: true,
                maxSimultaneousDrags: isMultiSelect ? 0 : 1,
                onDragStarted: () {
                  setState(() {
                    _draggedNoteId = note.id;
                    _dragHoverNoteId = null;
                  });
                  HapticFeedback.mediumImpact();
                },
                onDragEnd: (_) => _clearDragState(),
                onDraggableCanceled: (_, _) => _clearDragState(),
                feedback: Material(
                  elevation: 12,
                  shadowColor: Theme.of(
                    context,
                  ).colorScheme.shadow.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.44,
                    child: Transform.scale(scale: 1.05, child: card),
                  ),
                ),
                childWhenDragging: Opacity(opacity: 0.35, child: card),
                child: AnimatedScale(
                  scale: isHovered && isDragging ? 0.92 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: styledCard,
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Build list view with drag-and-drop reordering
  Widget _buildListView(List<Note> notes, bool isAllNotesView) {
    final isMultiSelect = ref.watch(notesMultiSelectModeProvider);
    final selectedNoteIds = ref.watch(selectedNoteIdsProvider);
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        if (scrollNotification is ScrollUpdateNotification) {
          if (scrollNotification.metrics.pixels < -20) {
            ref.read(notesSearchModeProvider.notifier).update(true);
            return true;
          }
        }
        if (scrollNotification is OverscrollNotification) {
          if (scrollNotification.overscroll < -20) {
            ref.read(notesSearchModeProvider.notifier).update(true);
            return true;
          }
        }
        return false;
      },
      child: ReorderableListView.builder(
        padding: const EdgeInsets.all(8),
        physics: const BouncingScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: notes.length,
        onReorder: (oldIndex, newIndex) {
          // ReorderableListView adjusts newIndex when dragging downward
          final adjusted = newIndex > oldIndex ? newIndex - 1 : newIndex;
          // Guard: don't allow crossing pinned/unpinned boundary
          final oldPinned = notes[oldIndex].isPinned;
          final targetPinned = adjusted < notes.length
              ? notes[adjusted].isPinned
              : notes.last.isPinned;
          if (oldPinned != targetPinned) return;

          // Build the reordered list and persist it
          final reordered = List<Note>.from(notes);
          final item = reordered.removeAt(oldIndex);
          reordered.insert(adjusted, item);
          setState(() => _optimisticNotes = reordered);
          ref.read(notesControllerProvider.notifier).commitReorder(reordered);
        },
        itemBuilder: (context, index) {
          final note = notes[index];
          final isInVault = _isNoteInVault(note);

          return ReorderableDragStartListener(
            key: ValueKey(note.id),
            index: index,
            child: _StaggeredItem(
              controller: _staggerController,
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: NotePreviewCard(
                  note: note,
                  onTap: () => _editNote(note.id),
                  onPin: () => _togglePin(note.id),
                  onDelete: () => _deleteNote(note.id, note.title),
                  onDeleteConfirmed: () => _deleteNoteConfirmed(note.id),
                  isInVault: isInVault,
                  onMoveToFolder: isInVault
                      ? null
                      : () => _moveNoteToFolder(note),
                  showFormatIndicator: isAllNotesView,
                  onColorChange: (color) => _setNoteColor(note.id, color),
                  selectable: isMultiSelect,
                  selected: selectedNoteIds.contains(note.id),
                  onSelectToggle: () => _onSelectToggle(note.id),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Freeform canvas view ─────────────────────────────────────────────

  static const double _freeformCardWidth = 180.0;
  static const double _freeformBubbleWidth = 140.0;
  static const double _freeformBubbleHeight = 44.0;
  static const double _freeformDotSize = 32.0;

  /// Build freeform canvas view with pan/zoom and freely movable note cards
  Widget _buildFreeformView(List<Note> notes, bool isAllNotesView) {
    final isMultiSelect = ref.watch(notesMultiSelectModeProvider);
    final selectedNoteIds = ref.watch(selectedNoteIdsProvider);
    final positions = ref.watch(noteFreeformPositionsProvider);
    final links = ref.watch(noteFreeformLinksProvider);

    // Cache notes for manual hit-testing in gesture callbacks
    _freeformNotes = notes;

    // Ensure all notes have positions (auto-place missing ones)
    if (!_freeformInitialized) {
      _freeformInitialized = true;
      _freeformTransformController.value = Matrix4.identity()
        ..setTranslationRaw(-700.0, -300.0, 0.0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(noteFreeformPositionsProvider.notifier)
            .ensurePositions(notes.map((n) => n.id).toList());
      });
    }

    // Seed live positions from provider (only for notes not currently being moved)
    for (final note in notes) {
      if (note.id != _movingNoteId && positions.containsKey(note.id)) {
        _livePositions[note.id] = positions[note.id]!;
      }
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onFreeformPointerDown,
          onPointerMove: _onFreeformPointerMove,
          onPointerUp: _onFreeformPointerUp,
          onPointerCancel: (_) => _longPressTimer?.cancel(),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onScaleStart: _onCanvasScaleStart,
            onScaleUpdate: _onCanvasScaleUpdate,
            onScaleEnd: _onCanvasScaleEnd,
            child: ClipRect(
              child: AnimatedBuilder(
                animation: _freeformTransformController,
                builder: (context, child) => Transform(
                  transform: _freeformTransformController.value,
                  alignment: Alignment.topLeft,
                  child: child,
                ),
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: 6000,
                  minHeight: 6000,
                  maxWidth: 6000,
                  maxHeight: 6000,
                  child: Stack(
                    children: [
                      // Connection lines layer (below cards)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _NoteConnectionsPainter(
                            positions: _livePositions,
                            links: links,
                            cardWidth: _lodLevel == 0
                                ? _freeformCardWidth
                                : _lodLevel == 1
                                ? _freeformBubbleWidth
                                : _freeformDotSize,
                            cardHeight: _lodLevel == 0
                                ? 150.0
                                : _lodLevel == 1
                                ? _freeformBubbleHeight
                                : _freeformDotSize,
                            lineColor: colorScheme.primary.withValues(
                              alpha: _lodLevel == 0 ? 0.3 : 0.6,
                            ),
                            dotColor: colorScheme.primary.withValues(
                              alpha: _lodLevel == 0 ? 0.5 : 0.8,
                            ),
                            strokeWidth: _lodLevel == 0
                                ? 1.5
                                : _lodLevel == 1
                                ? 2.5
                                : 3.5,
                          ),
                        ),
                      ),
                      // Note cards layer
                      for (final note in notes)
                        _buildFreeformNoteCard(
                          note,
                          isAllNotesView,
                          isMultiSelect,
                          selectedNoteIds,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // ── Vertical zoom slider ──
        Positioned(
          left: 12,
          bottom: 80,
          child: _FreeformZoomSlider(
            transformController: _freeformTransformController,
            colorScheme: colorScheme,
          ),
        ),
      ],
    );
  }

  Widget _buildFreeformNoteCard(
    Note note,
    bool isAllNotesView,
    bool isMultiSelect,
    Set<String> selectedNoteIds,
  ) {
    final pos = _livePositions[note.id] ?? const Offset(800, 400);
    final isMoving = _movingNoteId == note.id;

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: AnimatedScale(
        scale: isMoving ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: _lodLevel == 0
            ? _buildFreeformFullCard(
                note,
                isAllNotesView,
                isMultiSelect,
                selectedNoteIds,
              )
            : _lodLevel == 1
            ? _buildFreeformBubble(note)
            : _buildFreeformDot(note),
      ),
    );
  }

  /// Full card mode (scale >= threshold) with a drag handle bar on top
  Widget _buildFreeformFullCard(
    Note note,
    bool isAllNotesView,
    bool isMultiSelect,
    Set<String> selectedNoteIds,
  ) {
    final isInVault = _isNoteInVault(note);
    final brightness = Theme.of(context).brightness;
    final colorScheme = Theme.of(context).colorScheme;
    final cardBg =
        resolveNoteColor(note.colorValue, brightness) ??
        colorScheme.surfaceContainerHigh;
    final gripColor = cardBg.computeLuminance() > 0.35
        ? Colors.black.withValues(alpha: 0.15)
        : Colors.white.withValues(alpha: 0.25);

    return SizedBox(
      width: _freeformCardWidth,
      child: Stack(
        children: [
          // ── Card body ──
          IgnorePointer(
            child: NotePreviewCard(
              note: note,
              onTap: () {},
              onPin: () => _togglePin(note.id),
              onDelete: () => _deleteNote(note.id, note.title),
              onDeleteConfirmed: () => _deleteNoteConfirmed(note.id),
              isInVault: isInVault,
              onMoveToFolder: isInVault ? null : () => _moveNoteToFolder(note),
              showFormatIndicator: isAllNotesView,
              isGridView: true,
              onColorChange: (color) => _setNoteColor(note.id, color),
              selectable: isMultiSelect,
              selected: selectedNoteIds.contains(note.id),
              onSelectToggle: () => _onSelectToggle(note.id),
            ),
          ),
          // ── Drag grip visual indicator (top of the card) ──
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: IgnorePointer(
              child: Container(
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 24,
                    height: 3,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: gripColor,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact bubble mode (scale < threshold) — title only, whole bubble draggable
  Widget _buildFreeformBubble(Note note) {
    final brightness = Theme.of(context).brightness;
    final colorScheme = Theme.of(context).colorScheme;
    final cardBg =
        resolveNoteColor(note.colorValue, brightness) ??
        colorScheme.surfaceContainerHigh;
    final onCardColor = cardBg.computeLuminance() > 0.35
        ? const Color(0xDD000000)
        : Colors.white;

    return Container(
      width: _freeformBubbleWidth,
      height: _freeformBubbleHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: note.isPinned
              ? colorScheme.primary.withValues(alpha: 0.5)
              : colorScheme.outlineVariant,
          width: note.isPinned ? 1.5 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          note.title.isEmpty ? '(No title)' : note.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: onCardColor,
            fontWeight: FontWeight.w500,
            fontStyle: note.title.isEmpty ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
    );
  }

  /// Dot mode (extreme zoom-out) — small colored circle, draggable
  Widget _buildFreeformDot(Note note) {
    final brightness = Theme.of(context).brightness;
    final colorScheme = Theme.of(context).colorScheme;
    final cardBg =
        resolveNoteColor(note.colorValue, brightness) ?? colorScheme.primary;

    return Container(
      width: _freeformDotSize,
      height: _freeformDotSize,
      decoration: BoxDecoration(
        color: cardBg,
        shape: BoxShape.circle,
        border: Border.all(
          color: note.isPinned
              ? colorScheme.primary
              : colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: note.isPinned ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: cardBg.withValues(alpha: 0.4),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  /// Get the center of the current freeform viewport in canvas coordinates.
  Offset _getFreeformViewportCenter() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return const Offset(900, 500);
    final size = renderBox.size;
    final inverse = Matrix4.inverted(_freeformTransformController.value);
    return MatrixUtils.transformPoint(
      inverse,
      Offset(size.width / 2, size.height / 2),
    );
  }

  // ─── Note Quick View Popup ────────────────────────────────────────────

  void _showNoteQuickView(Note note) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    AnimatedDialog.show(
      context: context,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: screenWidth * 0.85,
            constraints: BoxConstraints(maxHeight: screenHeight * 0.65),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.shadow.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                    child: Row(
                      children: [
                        if (note.isPinned)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.push_pin,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            note.title.isNotEmpty ? note.title : 'Untitled',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.open_in_full, size: 20),
                          tooltip: 'Open in editor',
                          onPressed: () {
                            Navigator.of(context).pop();
                            _editNote(note.id);
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: NoteContentView(note: note),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearchMode = ref.watch(notesSearchModeProvider);
    final searchQuery = ref.watch(notesSearchQueryProvider);
    final spacing = ref.watch(adaptiveSpacingProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaledIcon(
              isSearchMode ? Icons.search : Icons.note_add,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            spacing.gapV16,
            Text(
              isSearchMode && searchQuery.isNotEmpty
                  ? 'No notes found'
                  : 'No notes yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            spacing.gapV8,
            Text(
              isSearchMode && searchQuery.isNotEmpty
                  ? 'Try a different search term'
                  : 'Create rich text notes with media, voice recordings, and markdown support',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (!isSearchMode) ...[
              spacing.gapV24,
              FloatingActionButton.extended(
                onPressed: () {
                  final selectedFolderId = ref.read(selectedNoteFolderProvider);
                  final folderId = selectedFolderId == 'UNFILED'
                      ? null
                      : selectedFolderId;
                  AnimatedNavigation.pushContainerTransform(
                    context,
                    QuillNoteEditorScreen(initialFolderId: folderId),
                  );
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Write your first note'),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(
                  context,
                ).colorScheme.onPrimaryContainer,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Multi-select helpers ───────────────────────────────────────────────

  void _onSelectToggle(String noteId) {
    if (!ref.read(notesMultiSelectModeProvider)) {
      ref.read(notesMultiSelectModeProvider.notifier).update(true);
    }
    ref.read(selectedNoteIdsProvider.notifier).toggle(noteId);
    HapticFeedback.selectionClick();
  }

  void _exitMultiSelect() {
    ref.read(notesMultiSelectModeProvider.notifier).update(false);
    ref.read(selectedNoteIdsProvider.notifier).clear();
  }

  Future<void> _bulkTogglePin(
    List<Note> notes,
    Set<String> selectedNoteIds,
  ) async {
    final allPinned = selectedNoteIds.every(
      (id) => notes.any((n) => n.id == id && n.isPinned),
    );
    await ref
        .read(notesControllerProvider.notifier)
        .bulkSetPin(selectedNoteIds, !allPinned);
    _exitMultiSelect();
  }

  Widget _buildBulkActionBar(List<Note> notes, Set<String> selectedNoteIds) {
    final cs = Theme.of(context).colorScheme;
    final allSelected = selectedNoteIds.length == notes.length;

    return Material(
      elevation: 8,
      color: cs.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              // Select all / deselect all
              TextButton(
                onPressed: () {
                  if (allSelected) {
                    ref.read(selectedNoteIdsProvider.notifier).clear();
                  } else {
                    ref
                        .read(selectedNoteIdsProvider.notifier)
                        .selectAll(notes.map((n) => n.id));
                  }
                },
                child: Text(allSelected ? 'None' : 'All'),
              ),
              Text(
                '${selectedNoteIds.length} selected',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: cs.onSurface),
              ),
              const Spacer(),
              // Pin / Unpin
              Builder(
                builder: (context) {
                  final allPinned =
                      selectedNoteIds.isNotEmpty &&
                      selectedNoteIds.every(
                        (id) => notes.any((n) => n.id == id && n.isPinned),
                      );
                  return IconButton(
                    icon: Icon(
                      allPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      color: selectedNoteIds.isEmpty
                          ? cs.onSurface.withValues(alpha: 0.3)
                          : cs.primary,
                    ),
                    tooltip: allPinned ? 'Unpin' : 'Pin',
                    onPressed: selectedNoteIds.isEmpty
                        ? null
                        : () => _bulkTogglePin(notes, selectedNoteIds),
                  );
                },
              ),
              // Color picker
              IconButton(
                icon: Icon(
                  Icons.palette_outlined,
                  color: selectedNoteIds.isEmpty
                      ? cs.onSurface.withValues(alpha: 0.3)
                      : cs.primary,
                ),
                tooltip: 'Set color',
                onPressed: selectedNoteIds.isEmpty
                    ? null
                    : () => _showBulkColorPicker(selectedNoteIds),
              ),
              // Delete
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: selectedNoteIds.isEmpty
                      ? cs.onSurface.withValues(alpha: 0.3)
                      : cs.error,
                ),
                tooltip: 'Move to Bin',
                onPressed: selectedNoteIds.isEmpty
                    ? null
                    : () => _showBulkDeleteConfirmation(selectedNoteIds),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showBulkColorPicker(Set<String> selectedNoteIds) async {
    // -1 = Default (clear), -2 = custom colour wheel
    final result = await showModalBottomSheet<int?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set color for ${selectedNoteIds.length} notes',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ...kNoteColorPalette.map((option) {
                    final brightness = Theme.of(ctx).brightness;
                    final swatchColor =
                        option.colorForBrightness(brightness) ??
                        Theme.of(ctx).colorScheme.surfaceContainerHighest;
                    return GestureDetector(
                      onTap: () => Navigator.pop(ctx, option.index ?? -1),
                      child: Tooltip(
                        message: option.label,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: swatchColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(
                                ctx,
                              ).colorScheme.outline.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: option.index == null
                              ? Icon(
                                  Icons.format_color_reset,
                                  size: 20,
                                  color: Theme.of(
                                    ctx,
                                  ).colorScheme.onSurfaceVariant,
                                )
                              : null,
                        ),
                      ),
                    );
                  }),
                  // Custom colour wheel swatch
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx, -2),
                    child: Tooltip(
                      message: 'Custom',
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const SweepGradient(
                            colors: [
                              Color(0xFFFF0000),
                              Color(0xFFFFFF00),
                              Color(0xFF00FF00),
                              Color(0xFF00FFFF),
                              Color(0xFF0000FF),
                              Color(0xFFFF00FF),
                              Color(0xFFFF0000),
                            ],
                          ),
                          border: Border.all(
                            color: Theme.of(
                              ctx,
                            ).colorScheme.outline.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.colorize,
                          size: 18,
                          color: Colors.white,
                          shadows: [
                            Shadow(color: Colors.black38, blurRadius: 2),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (result == null || !mounted) return;

    if (result == -2) {
      // User wants a custom colour — show the wheel dialog.
      await _showBulkCustomColorPicker(selectedNoteIds);
      return;
    }

    // -1 sentinel = "Default" (clear color)
    final colorValue = result == -1 ? null : result;
    await ref
        .read(notesControllerProvider.notifier)
        .bulkSetColor(selectedNoteIds, colorValue);
    _exitMultiSelect();
  }

  Future<void> _showBulkCustomColorPicker(Set<String> selectedNoteIds) async {
    Color pickedColor = const Color(0xFFE8DEF8);
    bool confirmed = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final lum = pickedColor.computeLuminance();
          final bool tooDark = lum < 0.06;
          final bool tooBright = lum > 0.90;
          final bool valid = !tooDark && !tooBright;
          return AlertDialog(
            title: const Text('Custom color'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ColorPicker(
                    color: pickedColor,
                    onColorChanged: (c) => setState(() => pickedColor = c),
                    pickersEnabled: const {
                      ColorPickerType.wheel: true,
                      ColorPickerType.accent: false,
                      ColorPickerType.primary: false,
                      ColorPickerType.bw: false,
                      ColorPickerType.custom: false,
                      ColorPickerType.customSecondary: false,
                    },
                    enableOpacity: false,
                    showColorCode: true,
                    colorCodeHasColor: true,
                    wheelDiameter: 280,
                  ),
                  if (!valid)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        tooDark
                            ? 'Color is too dark — pick a lighter shade'
                            : 'Color is too bright — pick a darker shade',
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.error,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: valid
                    ? () {
                        confirmed = true;
                        Navigator.pop(ctx);
                      }
                    : null,
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );

    if (!confirmed || !mounted) return;
    await ref
        .read(notesControllerProvider.notifier)
        .bulkSetColor(selectedNoteIds, pickedColor.toARGB32());
    _exitMultiSelect();
  }

  Future<void> _showBulkDeleteConfirmation(Set<String> selectedNoteIds) async {
    final count = selectedNoteIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to Bin'),
        content: Text(
          'Move $count ${count == 1 ? 'note' : 'notes'} to bin? You can restore them later.',
        ),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Move to Bin'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref
          .read(notesControllerProvider.notifier)
          .bulkDelete(selectedNoteIds);
      _exitMultiSelect();
    }
  }

  // ─── Existing methods ────────────────────────────────────────────────────

  void _editNote(String noteId) async {
    final note = await ref.read(notesRepositoryProvider).getNoteById(noteId);
    if (note != null && note.folderId != null) {
      final folderRepo = NoteFolderRepository();
      final folder = folderRepo.getNoteFolderById(note.folderId!);

      if (folder != null && folder.isVault) {
        final ctx = context;
        if (!ctx.mounted) return;
        // Require authentication (biometric + password fallback) for vault notes
        final authenticated = await VaultAuthService.authenticate(
          context: ctx,
          folderId: folder.id,
          folderName: folder.name,
          useBiometric: folder.useBiometric,
          hasPassword: folder.hasPassword,
        );

        if (!ctx.mounted) return;
        if (!authenticated) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(
              content: Text('Authentication required to access vault notes'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    }

    if (mounted) {
      AnimatedNavigation.pushContainerTransform(
        context,
        QuillNoteEditorScreen(noteId: noteId),
      );
    }
  }

  Future<void> _togglePin(String noteId) async {
    await ref.read(notesControllerProvider.notifier).togglePin(noteId);
  }

  Future<void> _setNoteColor(String noteId, int? colorValue) async {
    await ref
        .read(notesProvider.notifier)
        .updateNote(id: noteId, colorValue: colorValue);
  }

  Future<void> _deleteNoteConfirmed(String noteId) async {
    // Check if note belongs to vault folder and require auth for deletion
    final note = await ref.read(notesRepositoryProvider).getNoteById(noteId);
    if (note != null && note.folderId != null) {
      final folderRepo = NoteFolderRepository();
      final folder = folderRepo.getNoteFolderById(note.folderId!);

      if (folder != null && folder.isVault) {
        if (!mounted) return;
        // Require authentication for vault note deletion (extra security for destructive action)
        final authenticated = await VaultAuthService.authenticate(
          context: context,
          folderId: folder.id,
          folderName: folder.name,
          useBiometric: folder.useBiometric,
          hasPassword: folder.hasPassword,
        );

        if (!mounted) return;
        if (!authenticated) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Authentication required to delete vault notes'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }
    }

    // Direct deletion without confirmation dialog (for swipe gestures)
    final success = await ref
        .read(notesControllerProvider.notifier)
        .deleteNote(noteId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteNote(String noteId, String noteTitle) async {
    // Check if note belongs to vault folder and require auth first
    final note = await ref.read(notesRepositoryProvider).getNoteById(noteId);
    if (note != null && note.folderId != null) {
      final folderRepo = NoteFolderRepository();
      final folder = folderRepo.getNoteFolderById(note.folderId!);

      if (folder != null && folder.isVault) {
        if (!mounted) return;
        // Require authentication for vault note deletion (extra security for destructive action)
        final authenticated = await VaultAuthService.authenticate(
          context: context,
          folderId: folder.id,
          folderName: folder.name,
          useBiometric: folder.useBiometric,
          hasPassword: folder.hasPassword,
        );

        if (!mounted) return;
        if (!authenticated) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Authentication required to delete vault notes'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Bin'),
        content: Text(
          'Move "$noteTitle" to bin? You can restore it later from the Bin.',
        ),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Move to Bin'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(notesControllerProvider.notifier)
          .deleteNote(noteId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  /// Check if a note is in a vault folder
  bool _isNoteInVault(Note note) {
    if (note.folderId == null) return false;

    final folderRepo = NoteFolderRepository();
    final folder = folderRepo.getNoteFolderById(note.folderId!);

    return folder?.isVault ?? false;
  }

  /// Show folder selection dialog and move note to selected folder
  Future<void> _moveNoteToFolder(Note note) async {
    final folderRepo = NoteFolderRepository();
    final allFolders = await folderRepo.getAllNoteFolders();

    if (!mounted) return;
    // Show folder selection dialog
    final selectedFolderId = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Folder'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Option to remove from folder
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('No Folder'),
                selected: note.folderId == null,
                onTap: () => Navigator.of(
                  context,
                ).pop(''), // Empty string means remove folder
              ),
              const Divider(),
              // All available folders
              ...allFolders.where((f) => f.id != note.folderId).map((folder) {
                return ListTile(
                  leading: Icon(
                    folder.isVault ? Icons.lock : Icons.folder,
                    color: folder.isVault
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(folder.name),
                  onTap: () => Navigator.of(context).pop(folder.id),
                );
              }),
            ],
          ),
        ),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    // If dialog was cancelled or no selection made
    if (selectedFolderId == null) return;

    // Check if moving to a vault folder - require authentication
    if (selectedFolderId.isNotEmpty) {
      final targetFolder = folderRepo.getNoteFolderById(selectedFolderId);

      if (targetFolder != null && targetFolder.isVault) {
        if (!mounted) return;
        // Require authentication for vault access
        final authenticated = await VaultAuthService.authenticate(
          context: context,
          folderId: targetFolder.id,
          folderName: targetFolder.name,
          useBiometric: targetFolder.useBiometric,
          hasPassword: targetFolder.hasPassword,
        );

        if (!mounted) return;
        if (!authenticated) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Authentication required to move note to vault'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }
    }

    // Update the note's folder
    final success = await ref
        .read(notesControllerProvider.notifier)
        .updateNoteFolder(
          note.id,
          selectedFolderId.isEmpty ? null : selectedFolderId,
        );

    if (mounted) {
      if (success) {
        final folderName = selectedFolderId.isEmpty
            ? 'No Folder'
            : folderRepo.getNoteFolderById(selectedFolderId)?.name ?? 'Unknown';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Note moved to $folderName'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to move note'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Staggered entrance animation for note items
// ---------------------------------------------------------------------------
class _StaggeredItem extends StatelessWidget {
  final AnimationController controller;
  final int index;
  final Widget child;

  const _StaggeredItem({
    required this.controller,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.07).clamp(0.0, 0.6);
    final end = (start + 0.4).clamp(0.0, 1.0);
    final curve = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOut),
    );

    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }
}

// ============================================================================
// Freeform Zoom Button
// ============================================================================

class _FreeformZoomSlider extends StatefulWidget {
  final TransformationController transformController;
  final ColorScheme colorScheme;

  const _FreeformZoomSlider({
    required this.transformController,
    required this.colorScheme,
  });

  @override
  State<_FreeformZoomSlider> createState() => _FreeformZoomSliderState();
}

class _FreeformZoomSliderState extends State<_FreeformZoomSlider> {
  static const double _minScale = 0.05;
  static const double _maxScale = 2.5;

  double _scaleToSlider(double scale) {
    return (scale.clamp(_minScale, _maxScale) - _minScale) /
        (_maxScale - _minScale);
  }

  double _sliderToScale(double t) {
    return _minScale + t * (_maxScale - _minScale);
  }

  void _onChanged(double t) {
    final matrix = widget.transformController.value;
    final currentScale = matrix.storage[0];
    final newScale = _sliderToScale(t).clamp(_minScale, _maxScale);
    if ((newScale - currentScale).abs() < 0.001) return;

    final RenderBox? box = context.findAncestorRenderObjectOfType<RenderBox>();
    final focal = box != null
        ? Offset(box.size.width / 2, box.size.height / 2)
        : const Offset(200, 400);

    final tx = matrix.storage[12];
    final ty = matrix.storage[13];
    final f = newScale / currentScale;

    widget.transformController.value = Matrix4.identity()
      ..setEntry(0, 0, newScale)
      ..setEntry(1, 1, newScale)
      ..setEntry(0, 3, focal.dx - f * (focal.dx - tx))
      ..setEntry(1, 3, focal.dy - f * (focal.dy - ty));
  }

  @override
  void initState() {
    super.initState();
    widget.transformController.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    widget.transformController.removeListener(_onTransformChanged);
    super.dispose();
  }

  void _onTransformChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    final currentScale = widget.transformController.value.storage[0];
    final sliderValue = _scaleToSlider(currentScale);

    return Material(
      color: cs.surfaceContainerHigh,
      elevation: 2,
      shadowColor: cs.shadow.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: cs.onSurfaceVariant),
            SizedBox(
              height: 140,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                  activeTrackColor: cs.primary,
                  inactiveTrackColor: cs.outlineVariant.withValues(alpha: 0.4),
                  thumbColor: cs.primary,
                  overlayColor: cs.primary.withValues(alpha: 0.12),
                ),
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Slider(
                    value: sliderValue.clamp(0.0, 1.0),
                    onChanged: _onChanged,
                  ),
                ),
              ),
            ),
            Icon(Icons.remove, size: 16, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Freeform Note Connection Lines Painter
// ============================================================================

class _NoteConnectionsPainter extends CustomPainter {
  final Map<String, Offset> positions;
  final Map<String, Set<String>> links;
  final double cardWidth;
  final double cardHeight;
  final Color lineColor;
  final Color dotColor;
  final double strokeWidth;

  _NoteConnectionsPainter({
    required this.positions,
    required this.links,
    required this.cardWidth,
    required this.cardHeight,
    required this.lineColor,
    required this.dotColor,
    this.strokeWidth = 1.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (links.isEmpty) return;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    final halfW = cardWidth / 2;
    final halfH = cardHeight / 2;
    final dotRadius = strokeWidth * 2;

    // Deduplicate: only draw one line per pair
    final drawn = <String>{};

    for (final entry in links.entries) {
      final srcPos = positions[entry.key];
      if (srcPos == null) continue;
      final srcCenter = srcPos + Offset(halfW, halfH);

      for (final targetId in entry.value) {
        // Create sorted pair key to avoid drawing A→B and B→A
        final pairKey = entry.key.compareTo(targetId) < 0
            ? '${entry.key}|$targetId'
            : '$targetId|${entry.key}';
        if (drawn.contains(pairKey)) continue;
        drawn.add(pairKey);

        final tgtPos = positions[targetId];
        if (tgtPos == null) continue;
        final tgtCenter = tgtPos + Offset(halfW, halfH);

        // Draw cubic bezier
        final dx = (tgtCenter.dx - srcCenter.dx).abs() * 0.4;
        final dy = (tgtCenter.dy - srcCenter.dy).abs() * 0.4;
        final cp1 = Offset(srcCenter.dx + dx, srcCenter.dy + dy);
        final cp2 = Offset(tgtCenter.dx - dx, tgtCenter.dy - dy);

        final path = Path()
          ..moveTo(srcCenter.dx, srcCenter.dy)
          ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, tgtCenter.dx, tgtCenter.dy);
        canvas.drawPath(path, linePaint);

        // Draw dots at connection points
        canvas.drawCircle(srcCenter, dotRadius, dotPaint);
        canvas.drawCircle(tgtCenter, dotRadius, dotPaint);

        // Draw small arrowhead at target end
        _drawArrowhead(canvas, cp2, tgtCenter, dotPaint);
      }
    }
  }

  void _drawArrowhead(Canvas canvas, Offset from, Offset to, Paint paint) {
    final direction = to - from;
    final len = direction.distance;
    if (len < 1) return;
    final unit = direction / len;
    final perp = Offset(-unit.dy, unit.dx);

    const arrowSize = 8.0;
    final tip = to;
    final left = tip - unit * arrowSize + perp * (arrowSize * 0.5);
    final right = tip - unit * arrowSize - perp * (arrowSize * 0.5);

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _NoteConnectionsPainter oldDelegate) {
    return positions != oldDelegate.positions ||
        links != oldDelegate.links ||
        lineColor != oldDelegate.lineColor;
  }
}
