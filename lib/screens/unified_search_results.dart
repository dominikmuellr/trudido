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
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/todo.dart';
import '../providers/filter_providers.dart';
import '../providers/settings_search_provider.dart';
import '../controllers/task_controller.dart';
import '../controllers/notes_controller.dart';
import '../services/folder_provider.dart';
import '../repositories/note_folder_repository.dart';
import '../widgets/hybrid_todo_item.dart';
import '../widgets/note_preview_card_markdown.dart';
import 'home_screen_notifiers.dart';
import 'home_navigation_drawer.dart';

/// Unified search results widget displaying tasks, notes, folders, and settings.
class UnifiedSearchResults extends ConsumerWidget {
  final TextEditingController searchController;
  final void Function({DateTime? initialDate}) onAddTask;
  final void Function(Todo task) onEditTask;
  final void Function(Todo task) onDeleteTask;
  final void Function(String noteId) onEditNote;
  final void Function(String noteId) onToggleNotePin;
  final void Function(String noteId, String noteTitle) onDeleteNote;
  final void Function(String noteId) onDeleteNoteConfirmed;
  final void Function(String route) onNavigateToSetting;

  const UnifiedSearchResults({
    super.key,
    required this.searchController,
    required this.onAddTask,
    required this.onEditTask,
    required this.onDeleteTask,
    required this.onEditNote,
    required this.onToggleNotePin,
    required this.onDeleteNote,
    required this.onDeleteNoteConfirmed,
    required this.onNavigateToSetting,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(searchQueryProvider);
    final filteredTasks = ref.watch(filteredTasksProvider);
    final filteredNotesAsync = ref.watch(filteredNotesProvider);
    final filteredSettings = ref.watch(filteredSettingsProvider);
    final filteredFoldersAsync = ref.watch(filteredFoldersProvider);
    final filteredNoteFoldersAsync = ref.watch(filteredNoteFoldersProvider);
    final searchDate = ref.watch(searchDateProvider);
    final tasksForDate = ref.watch(tasksForSearchDateProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Empty state
          if (searchQuery.isEmpty) _buildEmptyState(context),

          // Date search results
          if (searchDate != null)
            _buildDateSearchResults(context, ref, searchDate, tasksForDate),

          // Regular search results (only show if not a date search)
          if (searchDate == null) ...[
            // Tasks section
            if (searchQuery.isNotEmpty && filteredTasks.isNotEmpty)
              _buildTasksSection(context, ref, filteredTasks, searchQuery),

            // Notes section
            if (searchQuery.isNotEmpty)
              _buildNotesSection(context, filteredNotesAsync, searchQuery),

            // Folders section (exclude vault folders)
            if (searchQuery.isNotEmpty)
              _buildFoldersSection(context, ref, filteredFoldersAsync),

            // Note Folders section (exclude vault folders)
            if (searchQuery.isNotEmpty)
              _buildNoteFoldersSection(context, ref, filteredNoteFoldersAsync),

            // Settings section
            if (searchQuery.isNotEmpty && filteredSettings.isNotEmpty)
              _buildSettingsSection(context, filteredSettings),
          ],

          // No results found (only for non-date searches)
          if (searchDate == null &&
              searchQuery.isNotEmpty &&
              filteredTasks.isEmpty &&
              filteredSettings.isEmpty &&
              (filteredNotesAsync.value?.isEmpty ?? true) &&
              (filteredFoldersAsync.value?.where((f) => !f.isVault).isEmpty ??
                  true) &&
              (filteredNoteFoldersAsync.value
                      ?.where((f) => !f.isVault)
                      .isEmpty ??
                  true))
            _buildNoResultsState(context),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Search Trudido',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Find tasks, notes, folders, and settings\nOr search by date (e.g., 25.12.2024)',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSearchResults(
    BuildContext context,
    WidgetRef ref,
    DateTime searchDate,
    List<Todo> tasksForDate,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '${searchDate.day}.${searchDate.month}.${searchDate.year}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: OutlinedButton.icon(
            onPressed: () => onAddTask(initialDate: searchDate),
            icon: const Icon(Icons.add),
            label: const Text('Add task for this date'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
        if (tasksForDate.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Tasks on this date (${tasksForDate.length})',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          ...tasksForDate.map(
            (task) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: HybridTodoItem(
                todo: task,
                onToggle: () => ref
                    .read(taskControllerProvider.notifier)
                    .toggleComplete(task.id),
                onEdit: () => onEditTask(task),
                onDelete: () => onDeleteTask(task),
                selectable: false,
                onSelectToggle: () {},
              ),
            ),
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.event_available,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No tasks scheduled for this date',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTasksSection(
    BuildContext context,
    WidgetRef ref,
    List<Todo> filteredTasks,
    String searchQuery,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Tasks (${filteredTasks.length})',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        ...filteredTasks.map(
          (task) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: HybridTodoItem(
              todo: task,
              onToggle: () => ref
                  .read(taskControllerProvider.notifier)
                  .toggleComplete(task.id),
              onEdit: () => onEditTask(task),
              onDelete: () => onDeleteTask(task),
              selectable: false,
              onSelectToggle: () {},
              searchHighlight: searchQuery,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection(
    BuildContext context,
    AsyncValue<dynamic> filteredNotesAsync,
    String searchQuery,
  ) {
    return filteredNotesAsync.when(
      data: (notes) {
        if (notes.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Notes (${notes.length})',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            ...notes.map(
              (note) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: NotePreviewCard(
                  note: note,
                  onTap: () => onEditNote(note.id),
                  onPin: () => onToggleNotePin(note.id),
                  onDelete: () => onDeleteNote(note.id, note.title),
                  onDeleteConfirmed: () => onDeleteNoteConfirmed(note.id),
                  isInVault: note.folderId != null,
                  showFormatIndicator: true,
                  searchHighlight: searchQuery,
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, stackTrace) => const SizedBox.shrink(),
    );
  }

  Widget _buildFoldersSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<dynamic> filteredFoldersAsync,
  ) {
    return filteredFoldersAsync.when(
      data: (allFolders) {
        final nonVaultFolders = allFolders
            .where((folder) => !folder.isVault)
            .toList();
        if (nonVaultFolders.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Folders (${nonVaultFolders.length})',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            ...nonVaultFolders.map(
              (folder) => ListTile(
                leading: Icon(
                  getIconDataFromName(folder.icon),
                  color: Color(folder.color),
                ),
                title: Text(folder.name),
                subtitle:
                    folder.description != null && folder.description!.isNotEmpty
                    ? Text(folder.description!)
                    : null,
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _navigateToFolder(ref, folder.id),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, stackTrace) => const SizedBox.shrink(),
    );
  }

  Widget _buildNoteFoldersSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<dynamic> filteredNoteFoldersAsync,
  ) {
    return filteredNoteFoldersAsync.when(
      data: (allNoteFolders) {
        final nonVaultNoteFolders = allNoteFolders
            .where((folder) => !folder.isVault)
            .toList();
        if (nonVaultNoteFolders.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Note Folders (${nonVaultNoteFolders.length})',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            ...nonVaultNoteFolders.map(
              (folder) => ListTile(
                leading: Icon(
                  Icons.folder_special,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(folder.name),
                subtitle:
                    folder.description != null && folder.description!.isNotEmpty
                    ? Text(folder.description!)
                    : null,
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _navigateToNoteFolder(ref, folder.id),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, stackTrace) => const SizedBox.shrink(),
    );
  }

  Widget _buildSettingsSection(
    BuildContext context,
    List<dynamic> filteredSettings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Settings (${filteredSettings.length})',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        ...filteredSettings.map(
          (setting) => ListTile(
            leading: Icon(setting.icon),
            title: Text(setting.title),
            subtitle: Text(setting.subtitle),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => onNavigateToSetting(setting.route),
          ),
        ),
      ],
    );
  }

  void _navigateToFolder(WidgetRef ref, String folderId) {
    ref.read(searchModeProvider.notifier).update(false);
    searchController.clear();
    ref.read(searchQueryProvider.notifier).update('');
    ref.read(notesSearchQueryProvider.notifier).update('');
    ref.read(settingsSearchQueryProvider.notifier).update('');
    ref.read(folderSearchQueryProvider.notifier).update('');
    ref.read(selectedFolderProvider.notifier).update(folderId);
    ref.read(currentTabProvider.notifier).setTab(0);
  }

  void _navigateToNoteFolder(WidgetRef ref, String folderId) {
    ref.read(searchModeProvider.notifier).update(false);
    searchController.clear();
    ref.read(searchQueryProvider.notifier).update('');
    ref.read(notesSearchQueryProvider.notifier).update('');
    ref.read(settingsSearchQueryProvider.notifier).update('');
    ref.read(folderSearchQueryProvider.notifier).update('');
    ref.read(noteFolderSearchQueryProvider.notifier).update('');
    ref.read(selectedNoteFolderProvider.notifier).update(folderId);
    ref.read(currentTabProvider.notifier).setTab(1);
  }
}
