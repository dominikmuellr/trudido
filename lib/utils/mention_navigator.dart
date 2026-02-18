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
import '../models/todo.dart';
import '../models/note.dart';
import '../providers/app_providers.dart';
import '../repositories/notes_repository.dart';
import '../controllers/task_controller.dart';
import '../utils/mention_parser.dart';
import '../screens/task_editor_screen.dart';
import '../screens/note_preview_screen.dart';
import 'animated_navigation.dart';

/// Handles navigation when a mention link is tapped.
///
/// Resolves the mention's ID to the actual task or note and navigates
/// to the appropriate screen.
class MentionNavigator {
  /// Navigate to the item referenced by a mention link.
  static void navigateToMention(
    BuildContext context,
    WidgetRef ref,
    MentionLink mention,
  ) {
    if (mention.isTask) {
      _navigateToTask(context, ref, mention.id);
    } else if (mention.isNote) {
      _navigateToNote(context, ref, mention.id);
    }
  }

  static void _navigateToTask(
    BuildContext context,
    WidgetRef ref,
    String taskId,
  ) {
    final tasks = ref.read(tasksProvider);
    final task = tasks.cast<Todo?>().firstWhere(
      (t) => t!.id == taskId,
      orElse: () => null,
    );

    if (task == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task not found or has been deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    AnimatedNavigation.pushContainerTransform(
      context,
      TaskEditorScreen(
        todo: task,
        onSave: (updatedTodo) {
          ref.read(taskControllerProvider.notifier).update(updatedTodo);
        },
      ),
    );
  }

  static void _navigateToNote(
    BuildContext context,
    WidgetRef ref,
    String noteId,
  ) {
    final notesAsync = ref.read(notesProvider);
    final notes = notesAsync.value ?? [];
    final note = notes.cast<Note?>().firstWhere(
      (n) => n!.id == noteId,
      orElse: () => null,
    );

    if (note == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note not found or has been deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    AnimatedNavigation.pushContainerTransform(
      context,
      NotePreviewScreen(note: note),
    );
  }
}

/// Provider that computes backlinks for a given item.
///
/// Backlinks are mentions of an item (task or note) found in other items'
/// text content.
class BacklinksProvider {
  /// Find all notes that mention a specific task.
  static List<Note> getNotesLinkingToTask(WidgetRef ref, String taskId) {
    final notesAsync = ref.read(notesProvider);
    final notes = notesAsync.value ?? [];

    return notes.where((note) {
      if (note.isDeleted) return false;
      final mentionedTaskIds = MentionParser.extractTaskIds(note.content);
      return mentionedTaskIds.contains(taskId);
    }).toList();
  }

  /// Find all tasks that mention a specific note.
  static List<Todo> getTasksLinkingToNote(WidgetRef ref, String noteId) {
    final tasks = ref.read(tasksProvider);

    return tasks.where((task) {
      if (task.isDeleted) return false;
      final notes = task.notes ?? '';
      final mentionedNoteIds = MentionParser.extractNoteIds(notes);
      return mentionedNoteIds.contains(noteId);
    }).toList();
  }

  /// Find all notes that mention a specific note.
  static List<Note> getNotesLinkingToNote(WidgetRef ref, String noteId) {
    final notesAsync = ref.read(notesProvider);
    final notes = notesAsync.value ?? [];

    return notes.where((note) {
      if (note.isDeleted || note.id == noteId) return false;
      final mentionedNoteIds = MentionParser.extractNoteIds(note.content);
      return mentionedNoteIds.contains(noteId);
    }).toList();
  }

  /// Find all tasks that mention a specific task.
  static List<Todo> getTasksLinkingToTask(WidgetRef ref, String taskId) {
    final tasks = ref.read(tasksProvider);

    return tasks.where((task) {
      if (task.isDeleted || task.id == taskId) return false;
      final notes = task.notes ?? '';
      final mentionedTaskIds = MentionParser.extractTaskIds(notes);
      return mentionedTaskIds.contains(taskId);
    }).toList();
  }
}
