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
import '../utils/note_colors.dart';
import '../widgets/note_preview_card_markdown.dart';
import '../widgets/notes_filter_chips.dart';
import 'home_screen_notifiers.dart';
import 'quill_note_editor_screen.dart';
import '../providers/app_providers.dart';
import '../widgets/common/common.dart';
import '../utils/state_notifiers.dart';

/// Provider for notes search mode
final notesSearchModeProvider = stateProvider<bool>(false);

/// Provider for notes view mode (grid or list)
final notesViewModeProvider = stateProvider<String>('grid');

/// Main notes screen showing list of all notes
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  @override
  Widget build(BuildContext context) {
    final filteredNotesAsync = ref.watch(filteredNotesProvider);
    final selectedFolderId = ref.watch(selectedNoteFolderProvider);
    final spacing = ref.watch(adaptiveSpacingProvider);

    return filteredNotesAsync.when(
      data: (notes) => _buildBody(notes, selectedFolderId == null),
      loading: () => const Center(child: CircularProgressIndicator()),
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
    final isMultiSelect = ref.watch(notesMultiSelectModeProvider);
    final selectedNoteIds = ref.watch(selectedNoteIdsProvider);

    return Column(
      children: [
        const NotesFilterChips(),
        Expanded(
          child: notes.isEmpty
              ? _buildEmptyState()
              : viewMode == 'grid'
              ? _buildGridView(notes, isAllNotesView)
              : _buildListView(notes, isAllNotesView),
        ),
        if (isMultiSelect) _buildBulkActionBar(notes, selectedNoteIds),
      ],
    );
  }

  /// Build grid view (original MasonryGridView layout)
  Widget _buildGridView(List<Note> notes, bool isAllNotesView) {
    final spacing = ref.watch(adaptiveSpacingProvider);
    final isMultiSelect = ref.watch(notesMultiSelectModeProvider);
    final selectedNoteIds = ref.watch(selectedNoteIdsProvider);
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        // Detect pull-to-search gesture
        if (scrollNotification is ScrollUpdateNotification) {
          if (scrollNotification.metrics.pixels < -20) {
            // Trigger search mode
            ref.read(notesSearchModeProvider.notifier).update(true);
            return true; // Consume the notification
          }
        }

        // Also listen for overscroll notifications
        if (scrollNotification is OverscrollNotification) {
          if (scrollNotification.overscroll < -20) {
            ref.read(notesSearchModeProvider.notifier).update(true);
            return true;
          }
        }

        return false;
      },
      child: MasonryGridView.count(
        padding: spacing.insets8,
        physics: const BouncingScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: spacing.s8,
        crossAxisSpacing: spacing.s8,
        itemCount: notes.length,
        itemBuilder: (context, index) {
          final note = notes[index];
          final isInVault = _isNoteInVault(note);

          return NotePreviewCard(
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
        },
      ),
    );
  }

  /// Build list view
  Widget _buildListView(List<Note> notes, bool isAllNotesView) {
    final isMultiSelect = ref.watch(notesMultiSelectModeProvider);
    final selectedNoteIds = ref.watch(selectedNoteIdsProvider);
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        // Detect pull-to-search gesture
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
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        physics: const BouncingScrollPhysics(),
        itemCount: notes.length,
        itemBuilder: (context, index) {
          final note = notes[index];
          final isInVault = _isNoteInVault(note);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: NotePreviewCard(
              note: note,
              onTap: () => _editNote(note.id),
              onPin: () => _togglePin(note.id),
              onDelete: () => _deleteNote(note.id, note.title),
              onDeleteConfirmed: () => _deleteNoteConfirmed(note.id),
              isInVault: isInVault,
              onMoveToFolder: isInVault ? null : () => _moveNoteToFolder(note),
              showFormatIndicator: isAllNotesView,
              onColorChange: (color) => _setNoteColor(note.id, color),
              selectable: isMultiSelect,
              selected: selectedNoteIds.contains(note.id),
              onSelectToggle: () => _onSelectToggle(note.id),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearchMode = ref.watch(notesSearchModeProvider);
    final searchQuery = ref.watch(notesSearchQueryProvider);
    final spacing = ref.watch(adaptiveSpacingProvider);

    return Center(
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
        ],
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
    int? pickedColor = await showModalBottomSheet<int?>(
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
                children: kNoteColorPalette.map((option) {
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
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    // -1 sentinel = "Default" (clear color)
    if (pickedColor == null || !mounted) return;
    final colorValue = pickedColor == -1 ? null : pickedColor;
    await ref
        .read(notesControllerProvider.notifier)
        .bulkSetColor(selectedNoteIds, colorValue);
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
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => QuillNoteEditorScreen(noteId: noteId),
        ),
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
