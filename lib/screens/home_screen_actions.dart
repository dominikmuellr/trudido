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

import '../controllers/notes_controller.dart';
import '../controllers/task_controller.dart';
import '../models/todo.dart';
import '../providers/filter_providers.dart';
import '../providers/settings_search_provider.dart';
import '../repositories/note_folder_repository.dart';
import '../services/folder_provider.dart';
import '../services/vault_auth_service.dart';
import '../utils/animated_navigation.dart';
import '../widgets/fab_menu.dart';
import 'about_screen.dart';
import 'app_lock_settings_page.dart';
import 'comprehensive_notification_settings.dart';
import 'data_management_screen.dart';
import 'experimental_settings_screen.dart';
import 'home_screen_notifiers.dart';
import 'note_folder_dialogs.dart';
import 'notes_folder_management_screen.dart';
import 'personalization_screen.dart';
import 'quill_note_editor_screen.dart';
import 'settings_screen.dart';
import 'task_editor_screen.dart';
import 'template_management_screen.dart';
import '../widgets/common/common.dart';

/// Mixin providing action handlers for HomeScreen
/// Separates action logic from UI building
mixin HomeScreenActions<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// Override in implementing class to provide search controller
  TextEditingController get searchController;

  /// Show add task dialog
  void showAddTaskDialog({DateTime? initialDate, String? presetTitle}) {
    final viewType = ref.read(taskViewTypeProvider);
    final selectedDate = ref.read(selectedCalendarDateProvider);

    final DateTime? preset =
        initialDate ??
        ((viewType == TaskViewType.calendar && selectedDate != null)
            ? selectedDate
            : null);

    AnimatedNavigation.pushContainerTransform(
      context,
      TaskEditorScreen(
        presetDueDate: preset,
        presetTitle: presetTitle,
        onSave: (todo) {
          ref.read(taskControllerProvider.notifier).add(todo);
        },
      ),
    );
  }

  /// Show edit task dialog
  void showEditTaskDialog(Todo task) {
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

  /// Delete task with confirmation dialog
  void deleteTaskWithConfirmation(Todo task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Bin'),
        content: Text(
          'Move "${task.text}" to bin? You can restore it later from the Bin.',
        ),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ExpressiveTextButton(
            onPressed: () {
              ref.read(taskControllerProvider.notifier).delete(task.id);
              Navigator.pop(context);
            },
            child: const Text('Move to Bin'),
          ),
        ],
      ),
    );
  }

  /// Edit note from search results
  Future<void> editNoteInSearch(String noteId) async {
    AnimatedNavigation.pushContainerTransform(
      context,
      QuillNoteEditorScreen(noteId: noteId),
    );
  }

  /// Toggle note pin status
  void toggleNotePin(String noteId) {
    ref.read(notesControllerProvider.notifier).togglePin(noteId);
  }

  /// Delete note with confirmation dialog
  void deleteNoteInSearch(String noteId, String noteTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Bin'),
        content: Text(
          'Move "$noteTitle" to bin? You can restore it later from the Bin.',
        ),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ExpressiveTextButton(
            onPressed: () {
              deleteNoteConfirmed(noteId);
              Navigator.pop(context);
            },
            child: const Text('Move to Bin'),
          ),
        ],
      ),
    );
  }

  /// Delete note (confirmed)
  void deleteNoteConfirmed(String noteId) {
    ref.read(notesControllerProvider.notifier).deleteNote(noteId);
  }

  /// Create note with optional preset title
  void createNewNoteWithTitle({String? presetTitle}) {
    final selectedFolderId = ref.read(selectedNoteFolderProvider);

    AnimatedNavigation.pushContainerTransform(
      context,
      QuillNoteEditorScreen(
        initialFolderId: selectedFolderId,
        initialTitle: presetTitle,
      ),
    );
  }

  /// Quick save note directly without opening editor
  Future<void> quickSaveNote(String text) async {
    if (text.isEmpty) return;

    final selectedFolderId = ref.read(selectedNoteFolderProvider);
    final controller = ref.read(notesControllerProvider.notifier);

    await controller.createNote(
      title: 'Quick Note',
      content: text,
      folderId: selectedFolderId,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quick note saved'),
          duration: Duration(milliseconds: 1500),
        ),
      );
    }
  }

  /// Create a new note in selected folder
  void createNewNote() {
    final selectedFolderId = ref.read(selectedNoteFolderProvider);

    AnimatedNavigation.pushContainerTransform(
      context,
      QuillNoteEditorScreen(initialFolderId: selectedFolderId),
    );
  }

  /// Create a new vault note with authentication
  Future<void> createVaultNote() async {
    final foldersAsync = ref.read(noteFoldersProvider);
    final folders = foldersAsync.value ?? [];
    final vaultFolders = folders.where((f) => f.isVault).toList();

    if (vaultFolders.isEmpty) {
      if (!mounted) return;

      await AnimatedNavigation.pushContainerTransform(
        context,
        const NotesFolderManagementScreen(),
      );
      return;
    }

    final lastVaultId = ref.read(lastAccessedVaultProvider);
    final defaultVault = lastVaultId != null
        ? vaultFolders.firstWhere(
            (v) => v.id == lastVaultId,
            orElse: () => vaultFolders.first,
          )
        : vaultFolders.first;

    if (!defaultVault.hasPassword) {
      if (!mounted) return;

      final setupSuccess = await showVaultSetupDialogWithPassword(
        context,
        ref,
        defaultVault,
      );

      if (!setupSuccess) return;

      ref.invalidate(noteFoldersProvider);
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (!context.mounted) return;
    
    final authContext = context;
    final authenticated = await VaultAuthService.authenticate(
      context: authContext,
      folderId: defaultVault.id,
      folderName: defaultVault.name,
      useBiometric: defaultVault.useBiometric,
      hasPassword: defaultVault.hasPassword,
    );

    if (!authenticated) return;

    ref.read(lastAccessedVaultProvider.notifier).update(defaultVault.id);

    if (!mounted) return;

    AnimatedNavigation.pushContainerTransform(
      context,
      QuillNoteEditorScreen(initialFolderId: defaultVault.id),
    );
  }

  /// Show template selection screen
  void showTemplateSelection() {
    AnimatedNavigation.pushContainerTransform(
      context,
      const TemplateManagementScreen(),
    );
  }

  /// Lock the current vault
  void lockVault() {
    ref.read(selectedNoteFolderProvider.notifier).update(null);
    ref.read(fabMenuExpandedProvider.notifier).update(false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vault locked'),
        duration: Duration(milliseconds: 1500),
      ),
    );
  }

  /// Trigger search mode
  void triggerSearch() {
    ref.read(searchModeProvider.notifier).update(true);
    ref.read(fabMenuExpandedProvider.notifier).update(false);
  }

  /// Navigate to a specific settings page
  void navigateToSetting(String route) {
    // Exit search mode first
    ref.read(searchModeProvider.notifier).update(false);
    searchController.clear();
    ref.read(searchQueryProvider.notifier).update('');
    ref.read(notesSearchQueryProvider.notifier).update('');
    ref.read(settingsSearchQueryProvider.notifier).update('');
    ref.read(folderSearchQueryProvider.notifier).update('');
    ref.read(noteFolderSearchQueryProvider.notifier).update('');

    switch (route) {
      case 'personalization':
        AnimatedNavigation.push(context, const PersonalizationScreen());
        break;
      case 'notifications':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ComprehensiveNotificationSettings(),
          ),
        );
        break;
      case 'app_lock':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const AppLockSettingsPage()),
        );
        break;
      case 'data_management':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const DataManagementScreen()),
        );
        break;
      case 'about':
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => const AboutScreen()));
        break;
      case 'support':
        AnimatedNavigation.push(context, const SettingsScreen());
        break;
      case 'experimental':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ExperimentalSettingsScreen(),
          ),
        );
        break;
      default:
        AnimatedNavigation.push(context, const SettingsScreen());
    }
  }

  /// Clear vault folder selection if currently viewing a vault
  void clearVaultSelectionIfNeeded() {
    final selectedFolderId = ref.read(selectedNoteFolderProvider);
    if (selectedFolderId != null) {
      final foldersAsync = ref.read(noteFoldersProvider);
      final folders = foldersAsync.value ?? [];
      final folder = folders.where((f) => f.id == selectedFolderId).firstOrNull;

      if (folder != null && folder.isVault) {
        ref.read(selectedNoteFolderProvider.notifier).update(null);
      }
    }
  }

  /// Open personalization screen
  void openPersonalizationScreen(VoidCallback onReturn) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => const PersonalizationScreen(),
          ),
        )
        .then((_) => onReturn());
  }
}
