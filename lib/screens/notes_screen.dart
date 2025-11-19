import 'package:flutter/material.dart';
import 'package:trudido/utils/responsive_size.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../models/note.dart';
import '../controllers/notes_controller.dart';
import '../repositories/notes_repository.dart';
import '../repositories/note_folder_repository.dart';
import '../services/vault_auth_service.dart';
import '../widgets/note_preview_card_markdown.dart';
import 'quill_note_editor_screen.dart';

/// Provider for notes search mode
final notesSearchModeProvider = StateProvider<bool>((ref) => false);

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
            const SizedBox(height: 16),
            Text(
              'Error loading notes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
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
    if (notes.isEmpty) {
      final isSearchMode = ref.watch(notesSearchModeProvider);
      final searchQuery = ref.watch(notesSearchQueryProvider);

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaledIcon(
              isSearchMode ? Icons.search : Icons.note_add,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              isSearchMode && searchQuery.isNotEmpty
                  ? 'No notes found'
                  : 'No notes yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
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

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        // Detect pull-to-search gesture
        if (scrollNotification is ScrollUpdateNotification) {
          // Check if user is pulling down at the top (overscroll)
          if (scrollNotification.metrics.pixels < -20) {
            // Trigger search mode
            ref.read(notesSearchModeProvider.notifier).state = true;
            return true; // Consume the notification
          }
        }

        // Also listen for overscroll notifications
        if (scrollNotification is OverscrollNotification) {
          if (scrollNotification.overscroll < -20) {
            ref.read(notesSearchModeProvider.notifier).state = true;
            return true;
          }
        }

        return false;
      },
      child: MasonryGridView.count(
        padding: const EdgeInsets.all(8),
        physics: const BouncingScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
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
          );
        },
      ),
    );
  }

  void _editNote(String noteId) async {
    // Check if note belongs to vault folder and require auth
    final note = await ref.read(notesRepositoryProvider).getNoteById(noteId);
    if (note != null && note.folderId != null) {
      final folderRepo = NoteFolderRepository();
      final folder = folderRepo.getNoteFolderById(note.folderId!);

      if (folder != null && folder.isVault) {
        // Require authentication (biometric + password fallback) for vault notes
        final authenticated = await VaultAuthService.authenticate(
          context: context,
          folderId: folder.id,
          folderName: folder.name,
          useBiometric: folder.useBiometric,
          hasPassword: folder.hasPassword,
        );

        if (!authenticated) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Authentication required to access vault notes'),
                backgroundColor: Colors.red,
              ),
            );
          }
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

  Future<void> _deleteNoteConfirmed(String noteId) async {
    // Check if note belongs to vault folder and require auth for deletion
    final note = await ref.read(notesRepositoryProvider).getNoteById(noteId);
    if (note != null && note.folderId != null) {
      final folderRepo = NoteFolderRepository();
      final folder = folderRepo.getNoteFolderById(note.folderId!);

      if (folder != null && folder.isVault) {
        // Require authentication for vault note deletion (extra security for destructive action)
        final authenticated = await VaultAuthService.authenticate(
          context: context,
          folderId: folder.id,
          folderName: folder.name,
          useBiometric: folder.useBiometric,
          hasPassword: folder.hasPassword,
        );

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
        // Require authentication for vault note deletion (extra security for destructive action)
        final authenticated = await VaultAuthService.authenticate(
          context: context,
          folderId: folder.id,
          folderName: folder.name,
          useBiometric: folder.useBiometric,
          hasPassword: folder.hasPassword,
        );

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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete "$noteTitle"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
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
          TextButton(
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
        // Require authentication for vault access
        final authenticated = await VaultAuthService.authenticate(
          context: context,
          folderId: targetFolder.id,
          folderName: targetFolder.name,
          useBiometric: targetFolder.useBiometric,
          hasPassword: targetFolder.hasPassword,
        );

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
