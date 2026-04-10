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

import 'package:intl/intl.dart';

import '../models/todo.dart';
import '../models/event.dart' as app_event;
import '../providers/filter_providers.dart';
import '../providers/settings_search_provider.dart';
import '../providers/app_providers.dart';
import '../controllers/task_controller.dart';
import '../controllers/notes_controller.dart';
import '../controllers/preferences_controller.dart';
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
  final void Function(app_event.Event event) onEditEvent;
  final void Function(app_event.Event event) onDeleteEvent;
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
    required this.onEditEvent,
    required this.onDeleteEvent,
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
    final filteredEvents = ref.watch(filteredEventsProvider);
    final filteredNotesAsync = ref.watch(filteredNotesProvider);
    final filteredSettings = ref.watch(filteredSettingsProvider);
    final filteredFoldersAsync = ref.watch(filteredFoldersProvider);
    final filteredNoteFoldersAsync = ref.watch(filteredNoteFoldersProvider);
    final searchDate = ref.watch(searchDateProvider);
    final tasksForDate = ref.watch(tasksForSearchDateProvider);
    final eventsForDate = ref.watch(eventsForSearchDateProvider);
    final isOverdue = ref.watch(isOverdueSearchProvider);
    final overdueTasks = ref.watch(overdueTasksProvider);
    final overdueEvents = ref.watch(overdueEventsProvider);
    final scope = ref.watch(searchScopeProvider);

    // Counts for non-vault folders
    final nonVaultFolderCount =
        filteredFoldersAsync.value?.where((f) => !f.isVault).length ?? 0;
    final nonVaultNoteFolderCount =
        filteredNoteFoldersAsync.value?.where((f) => !f.isVault).length ?? 0;

    bool inScope(String key) => scope.isEmpty || scope.contains(key);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Empty state with search history
          if (searchQuery.isEmpty) _buildEmptyState(context, ref),

          // Scope filter chips (shown when there's a text query, no date/overdue)
          if (searchQuery.isNotEmpty && searchDate == null && !isOverdue)
            _buildScopeChips(context, ref, scope),

          // Result count summary
          if (searchQuery.isNotEmpty && searchDate == null && !isOverdue)
            _buildResultsSummary(
              context,
              taskCount: inScope('tasks') ? filteredTasks.length : 0,
              eventCount: inScope('events') ? filteredEvents.length : 0,
              noteCount: inScope('notes')
                  ? (filteredNotesAsync.value?.length ?? 0)
                  : 0,
              folderCount: inScope('folders') ? nonVaultFolderCount : 0,
              noteFolderCount: inScope('folders') ? nonVaultNoteFolderCount : 0,
              settingCount: inScope('settings') ? filteredSettings.length : 0,
            ),

          // Overdue keyword results
          if (isOverdue)
            _buildOverdueResults(context, ref, overdueTasks, overdueEvents),

          // Date search results
          if (searchDate != null && !isOverdue)
            _buildDateSearchResults(
              context,
              ref,
              searchDate,
              tasksForDate,
              eventsForDate,
            ),

          // Regular search results (only show if not a date/overdue search)
          if (searchDate == null && !isOverdue) ...[
            // Tasks section
            if (searchQuery.isNotEmpty &&
                filteredTasks.isNotEmpty &&
                inScope('tasks'))
              _buildTasksSection(context, ref, filteredTasks, searchQuery),

            // Events section
            if (searchQuery.isNotEmpty &&
                filteredEvents.isNotEmpty &&
                inScope('events'))
              _buildEventsSection(context, ref, filteredEvents, searchQuery),

            // Notes section
            if (searchQuery.isNotEmpty && inScope('notes'))
              _buildNotesSection(context, filteredNotesAsync, searchQuery),

            // Folders section (exclude vault folders)
            if (searchQuery.isNotEmpty && inScope('folders'))
              _buildFoldersSection(
                context,
                ref,
                filteredFoldersAsync,
                searchQuery,
              ),

            // Note Folders section (exclude vault folders)
            if (searchQuery.isNotEmpty && inScope('folders'))
              _buildNoteFoldersSection(
                context,
                ref,
                filteredNoteFoldersAsync,
                searchQuery,
              ),

            // Settings section
            if (searchQuery.isNotEmpty &&
                filteredSettings.isNotEmpty &&
                inScope('settings'))
              _buildSettingsSection(
                context,
                ref,
                filteredSettings,
                searchQuery,
              ),
          ],

          // No results found (only for non-date, non-overdue searches)
          if (searchDate == null &&
              !isOverdue &&
              searchQuery.isNotEmpty &&
              filteredTasks.isEmpty &&
              filteredEvents.isEmpty &&
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

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    final history = ref.watch(preferencesStateProvider).searchHistory;

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
              'Find tasks, events, notes, folders, and settings\nTry "today", "tomorrow", "overdue", or a date',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (history.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent searches',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref
                        .read(preferencesControllerProvider)
                        .clearSearchHistory(),
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: history
                    .map(
                      (q) => ActionChip(
                        label: Text(q),
                        onPressed: () {
                          searchController.text = q;
                          searchController.selection =
                              TextSelection.fromPosition(
                                TextPosition(offset: q.length),
                              );
                          ref.read(searchQueryProvider.notifier).update(q);
                          ref.read(notesSearchQueryProvider.notifier).update(q);
                          ref
                              .read(settingsSearchQueryProvider.notifier)
                              .update(q);
                          ref
                              .read(folderSearchQueryProvider.notifier)
                              .update(q);
                          ref
                              .read(noteFolderSearchQueryProvider.notifier)
                              .update(q);
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
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
    List<app_event.Event> eventsForDate,
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
          const SizedBox(height: 8),
        ],

        // Events on this date
        if (eventsForDate.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Events on this date (${eventsForDate.length})',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          ...eventsForDate.map(
            (event) => _buildEventListTile(context, ref, event),
          ),
        ],

        if (tasksForDate.isEmpty && eventsForDate.isEmpty) ...[
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
                    'Nothing scheduled for this date',
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
        _CappedList(
          resetKey: searchQuery,
          children: filteredTasks
              .map(
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
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildEventsSection(
    BuildContext context,
    WidgetRef ref,
    List<app_event.Event> filteredEvents,
    String searchQuery,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Events (${filteredEvents.length})',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        _CappedList(
          resetKey: searchQuery,
          children: filteredEvents
              .map(
                (event) =>
                    _buildEventListTile(context, ref, event, searchQuery),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildEventListTile(
    BuildContext context,
    WidgetRef ref,
    app_event.Event event, [
    String? searchQuery,
  ]) {
    final colorScheme = Theme.of(context).colorScheme;
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('MMM d');

    final timeText = event.isAllDay
        ? 'All day'
        : '${timeFormat.format(event.startDateTime)} – ${timeFormat.format(event.endDateTime)}';
    final dateText = event.isMultiDay
        ? '${dateFormat.format(event.startDateTime)} – ${dateFormat.format(event.endDateTime)}'
        : dateFormat.format(event.startDateTime);

    return ListTile(
      leading: Icon(Icons.event, color: colorScheme.tertiary),
      title: searchQuery != null && searchQuery.isNotEmpty
          ? RichText(
              text: _highlightText(
                event.text,
                searchQuery,
                context,
                baseStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  decoration: event.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            )
          : Text(
              event.text,
              style: TextStyle(
                decoration: event.isCompleted
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
      subtitle: Text(
        event.location != null && event.location!.isNotEmpty
            ? '$dateText · $timeText · ${event.location}'
            : '$dateText · $timeText',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => onEditEvent(event),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline, color: colorScheme.error, size: 20),
        onPressed: () => onDeleteEvent(event),
      ),
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
            _CappedList(
              resetKey: searchQuery,
              children: notes
                  .map(
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
                  )
                  .toList(),
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
    String searchQuery,
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
            _CappedList(
              resetKey: searchQuery,
              children: nonVaultFolders
                  .map(
                    (folder) => ListTile(
                      leading: Icon(
                        getIconDataFromName(folder.icon),
                        color: Color(folder.color),
                      ),
                      title: RichText(
                        text: _highlightText(
                          folder.name,
                          searchQuery,
                          context,
                          baseStyle: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      subtitle:
                          folder.description != null &&
                              folder.description!.isNotEmpty
                          ? Text(folder.description!)
                          : null,
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _navigateToFolder(ref, folder.id),
                    ),
                  )
                  .toList(),
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
    String searchQuery,
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
            _CappedList(
              resetKey: searchQuery,
              children: nonVaultNoteFolders
                  .map(
                    (folder) => ListTile(
                      leading: Icon(
                        Icons.folder_special,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: RichText(
                        text: _highlightText(
                          folder.name,
                          searchQuery,
                          context,
                          baseStyle: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      subtitle:
                          folder.description != null &&
                              folder.description!.isNotEmpty
                          ? Text(folder.description!)
                          : null,
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _navigateToNoteFolder(ref, folder.id),
                    ),
                  )
                  .toList(),
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
    WidgetRef ref,
    List<dynamic> filteredSettings,
    String searchQuery,
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
        _CappedList(
          resetKey: searchQuery,
          children: filteredSettings
              .map(
                (setting) => _buildSettingTile(
                  context,
                  ref,
                  setting as SettingsItem,
                  searchQuery,
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildSettingTile(
    BuildContext context,
    WidgetRef ref,
    SettingsItem setting,
    String searchQuery,
  ) {
    final isToggle = setting.toggleKey != null;
    final bool currentValue = isToggle
        ? _readToggle(ref, setting.toggleKey!)
        : false;

    return ListTile(
      leading: Icon(setting.icon),
      title: RichText(
        text: _highlightText(
          setting.title,
          searchQuery,
          context,
          baseStyle: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
      subtitle: Text(setting.subtitle),
      trailing: isToggle
          ? Switch(
              value: currentValue,
              onChanged: (value) =>
                  _writeToggle(ref, setting.toggleKey!, value),
            )
          : const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: isToggle
          ? () => _writeToggle(ref, setting.toggleKey!, !currentValue)
          : () => onNavigateToSetting(setting.route),
    );
  }

  /// Read the current boolean value for a toggle key.
  bool _readToggle(WidgetRef ref, String key) {
    final prefs = ref.watch(preferencesStateProvider);
    return switch (key) {
      'hapticsEnabled' => prefs.hapticsEnabled,
      'showSearchBar' => prefs.showSearchBar,
      'floatingNavBar' => prefs.floatingNavBar,
      'showOverviewTab' => prefs.showOverviewTab,
      'compactDensity' => prefs.compactDensity,
      'compactNotesView' => prefs.compactNotesView,
      'hideNavLabels' => prefs.hideNavLabels,
      'blackoutRecents' => prefs.blackoutRecents,
      'enableBin' => prefs.enableBin,
      'useQuickInputBar' => prefs.useQuickInputBar,
      'enableNoteHistory' => prefs.enableNoteHistory,
      'autoCompleteEvents' => prefs.autoCompleteEvents,
      _ => false,
    };
  }

  /// Write a new boolean value for a toggle key.
  void _writeToggle(WidgetRef ref, String key, bool value) {
    final ctrl = ref.read(preferencesControllerProvider);
    switch (key) {
      case 'hapticsEnabled':
        ctrl.toggleHaptics();
      case 'showSearchBar':
        ctrl.toggleShowSearchBar();
      case 'floatingNavBar':
        ctrl.toggleFloatingNavBar();
      case 'showOverviewTab':
        ctrl.toggleShowOverviewTab();
      case 'compactDensity':
        ctrl.toggleCompactDensity();
      case 'compactNotesView':
        ctrl.toggleCompactNotesView();
      case 'hideNavLabels':
        ctrl.toggleHideNavLabels();
      case 'blackoutRecents':
        ctrl.toggleBlackoutRecents();
      case 'enableBin':
        ctrl.setEnableBin(value);
      case 'useQuickInputBar':
        ctrl.toggleQuickInputBar();
      case 'enableNoteHistory':
        ctrl.toggleNoteHistory();
      case 'autoCompleteEvents':
        ctrl.toggleAutoCompleteEvents();
    }
  }

  void _navigateToFolder(WidgetRef ref, String folderId) {
    ref.read(searchModeProvider.notifier).update(false);
    searchController.clear();
    ref.read(searchQueryProvider.notifier).update('');
    ref.read(notesSearchQueryProvider.notifier).update('');
    ref.read(settingsSearchQueryProvider.notifier).update('');
    ref.read(folderSearchQueryProvider.notifier).update('');
    ref.read(searchScopeProvider.notifier).update(<String>{});
    ref.read(selectedFolderProvider.notifier).update(folderId);
    ref.read(currentTabProvider.notifier).setTab(1);
  }

  void _navigateToNoteFolder(WidgetRef ref, String folderId) {
    ref.read(searchModeProvider.notifier).update(false);
    searchController.clear();
    ref.read(searchQueryProvider.notifier).update('');
    ref.read(notesSearchQueryProvider.notifier).update('');
    ref.read(settingsSearchQueryProvider.notifier).update('');
    ref.read(folderSearchQueryProvider.notifier).update('');
    ref.read(noteFolderSearchQueryProvider.notifier).update('');
    ref.read(searchScopeProvider.notifier).update(<String>{});
    ref.read(selectedNoteFolderProvider.notifier).update(folderId);
    ref.read(currentTabProvider.notifier).setTab(2);
  }

  // ─────────────────────────────────────────────────────────────────────
  // New helper widgets
  // ─────────────────────────────────────────────────────────────────────

  /// Scope filter chips for narrowing search results by category.
  Widget _buildScopeChips(
    BuildContext context,
    WidgetRef ref,
    Set<String> scope,
  ) {
    const categories = [
      ('tasks', 'Tasks', Icons.check_circle_outline),
      ('events', 'Events', Icons.event_outlined),
      ('notes', 'Notes', Icons.note_outlined),
      ('folders', 'Folders', Icons.folder_outlined),
      ('settings', 'Settings', Icons.settings_outlined),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: categories.map((cat) {
          final (key, label, icon) = cat;
          final selected = scope.contains(key);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(label),
              avatar: Icon(icon, size: 18),
              selected: selected,
              showCheckmark: false,
              onSelected: (val) {
                final current = Set<String>.from(scope);
                if (val) {
                  current.add(key);
                } else {
                  current.remove(key);
                }
                ref.read(searchScopeProvider.notifier).update(current);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Result count summary line.
  Widget _buildResultsSummary(
    BuildContext context, {
    required int taskCount,
    required int eventCount,
    required int noteCount,
    required int folderCount,
    required int noteFolderCount,
    required int settingCount,
  }) {
    final parts = <String>[];
    if (taskCount > 0) parts.add('$taskCount task${taskCount == 1 ? '' : 's'}');
    if (eventCount > 0) {
      parts.add('$eventCount event${eventCount == 1 ? '' : 's'}');
    }
    if (noteCount > 0) parts.add('$noteCount note${noteCount == 1 ? '' : 's'}');
    final totalFolders = folderCount + noteFolderCount;
    if (totalFolders > 0) {
      parts.add('$totalFolders folder${totalFolders == 1 ? '' : 's'}');
    }
    if (settingCount > 0) {
      parts.add('$settingCount setting${settingCount == 1 ? '' : 's'}');
    }
    if (parts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(
        parts.join(' · '),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// Overdue tasks and events section (triggered by "overdue" keyword).
  Widget _buildOverdueResults(
    BuildContext context,
    WidgetRef ref,
    List<Todo> overdueTasks,
    List<app_event.Event> overdueEvents,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    if (overdueTasks.isEmpty && overdueEvents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.check_circle, size: 64, color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'All caught up!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No overdue tasks or events',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 20,
                color: colorScheme.error,
              ),
              const SizedBox(width: 8),
              Text(
                'Overdue',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.error,
                ),
              ),
            ],
          ),
        ),
        if (overdueTasks.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Tasks (${overdueTasks.length})',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          ...overdueTasks.map(
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
        ],
        if (overdueEvents.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Events (${overdueEvents.length})',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          ...overdueEvents.map(
            (event) => _buildEventListTile(context, ref, event),
          ),
        ],
      ],
    );
  }

  /// Highlights occurrences of [query] within [text] using primaryContainer.
  TextSpan _highlightText(
    String text,
    String query,
    BuildContext context, {
    TextStyle? baseStyle,
  }) {
    final style = baseStyle ?? Theme.of(context).textTheme.bodyLarge;
    if (query.isEmpty) return TextSpan(text: text, style: style);

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start), style: style));
        }
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: style));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style:
              style?.copyWith(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ) ??
              TextStyle(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
        ),
      );
      start = index + query.length;
    }

    if (spans.isEmpty) return TextSpan(text: text, style: style);
    return TextSpan(children: spans);
  }
}

/// A widget that shows at most [maxVisible] children and a "Show more" button.
/// Resets to collapsed state whenever [resetKey] changes (e.g. the search query).
class _CappedList extends StatefulWidget {
  final List<Widget> children;
  final int maxVisible;
  final String resetKey;

  const _CappedList({
    required this.children,
    this.maxVisible = 10,
    this.resetKey = '',
  });

  @override
  State<_CappedList> createState() => _CappedListState();
}

class _CappedListState extends State<_CappedList> {
  bool _expanded = false;
  String _lastResetKey = '';

  @override
  Widget build(BuildContext context) {
    // Auto-collapse when the query (resetKey) changes
    if (widget.resetKey != _lastResetKey) {
      _expanded = false;
      _lastResetKey = widget.resetKey;
    }

    final total = widget.children.length;
    final capped = !_expanded && total > widget.maxVisible;
    final visible = capped
        ? widget.children.take(widget.maxVisible).toList()
        : widget.children;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...visible,
        if (capped)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextButton(
              onPressed: () => setState(() => _expanded = true),
              child: Text('Show ${total - widget.maxVisible} more'),
            ),
          ),
      ],
    );
  }
}
