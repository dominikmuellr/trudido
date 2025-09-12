import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/note.dart';
import '../controllers/notes_controller.dart';
import '../repositories/notes_repository.dart';
import '../widgets/note_preview_card_markdown.dart';
import '../widgets/notes_onboarding_tooltip.dart';
import 'note_editor_screen.dart';
import 'note_preview_screen.dart';

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

    return filteredNotesAsync.when(
      data: (notes) => _buildBody(notes),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIcons.warning(),
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

  Widget _buildBody(List<Note> notes) {
    if (notes.isEmpty) {
      final isSearchMode = ref.watch(notesSearchModeProvider);
      final searchQuery = ref.watch(notesSearchQueryProvider);
      
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearchMode 
                ? PhosphorIcons.magnifyingGlass() 
                : PhosphorIcons.noteBlank(),
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
                  : 'Tap the + button to create your first note',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return NotesOnboardingTooltip(
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: notes.length,
        itemBuilder: (context, index) {
          return NotePreviewCard(
            note: notes[index],
            onTap: () => _previewNote(notes[index]),
            onLongPress: () => _editNote(notes[index].id),
            onPin: () => _togglePin(notes[index].id),
            onDelete: () => _deleteNote(notes[index].id, notes[index].title),
            onDeleteConfirmed: () => _deleteNoteConfirmed(notes[index].id),
          );
        },
      ),
    );
  }

  void _previewNote(Note note) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NotePreviewScreen(note: note),
      ),
    );
  }

  void _editNote(String noteId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NoteEditorScreen(noteId: noteId),
      ),
    );
  }

  Future<void> _togglePin(String noteId) async {
    await ref.read(notesControllerProvider.notifier).togglePin(noteId);
  }

  Future<void> _deleteNoteConfirmed(String noteId) async {
    // Direct deletion without confirmation dialog (for swipe gestures)
    final success = await ref.read(notesControllerProvider.notifier).deleteNote(noteId);
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
      final success = await ref.read(notesControllerProvider.notifier).deleteNote(noteId);
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
}
