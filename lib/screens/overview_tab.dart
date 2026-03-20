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
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';

import '../controllers/task_controller.dart';
import '../controllers/event_controller.dart';
import '../controllers/notes_controller.dart';
import '../providers/app_providers.dart';
import '../models/folder.dart';
import '../models/note_folder.dart';
import '../services/folder_provider.dart';
import '../screens/home_navigation_drawer.dart' show getIconDataFromName;
import '../services/greeting_service.dart';
import '../services/storage_service.dart';
import '../widgets/greeting_header.dart' show userNameProvider;
import '../providers/filter_providers.dart';
import '../providers/notes_providers.dart';
import '../repositories/note_folder_repository.dart';
import '../models/todo.dart';
import '../models/event.dart' as app_event;
import '../models/note.dart';
import '../widgets/hybrid_todo_item.dart';
import '../widgets/note_preview_card_markdown.dart';
import '../screens/home_screen_notifiers.dart';
import '../screens/task_editor_screen.dart';
import '../screens/event_editor_screen.dart';
import '../screens/quill_note_editor_screen.dart';
import '../screens/personalization_screen.dart';
import '../screens/comprehensive_notification_settings.dart';
import '../screens/app_lock_settings_page.dart';
import '../screens/data_management_screen.dart';
import '../screens/about_screen.dart';
import '../screens/experimental_settings_screen.dart';
import '../screens/defaults_settings_screen.dart';
import '../screens/font_size_settings_screen.dart';
import '../screens/custom_theme_list_screen.dart';
import '../screens/calendar_sync_settings_screen.dart';
import '../screens/holiday_calendar_settings_screen.dart';
import '../screens/backup_settings_page.dart';
import '../screens/bin_settings_screen.dart';
import '../theme/spacing_tokens.dart';
import '../widgets/common/common.dart';

/// Live clock that emits the current time and refreshes every minute.
final liveTimeProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  await for (final _ in Stream.periodic(const Duration(minutes: 1))) {
    yield DateTime.now();
  }
});

/// Shows up to 5 incomplete todos sorted by due date (soonest first), then no-date.
final overviewTodosProvider = Provider<List<Todo>>((ref) {
  final tasks = ref.watch(incompleteTasksProvider);
  final sorted = [...tasks]
    ..sort((a, b) {
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    });
  return sorted.take(5).toList();
});

/// Shows up to 5 upcoming / ongoing events that haven't ended yet.
final overviewEventsProvider = Provider<List<app_event.Event>>((ref) {
  final events = ref.watch(eventsProvider);
  final upcoming = events.where((e) => !e.isCompleted && !e.hasEnded).toList()
    ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
  return upcoming.take(5).toList();
});

/// The 2 most recently updated notes (excluding vault notes).
final overviewLatestNotesProvider = Provider<AsyncValue<List<Note>>>((ref) {
  final notesAsync = ref.watch(notesProvider);
  final foldersAsync = ref.watch(noteFoldersProvider);

  return notesAsync.whenData((notes) {
    if (notes.isEmpty) return [];

    // Get vault folder IDs for filtering
    final vaultFolderIds =
        foldersAsync.value
            ?.where((folder) => folder.isVault)
            .map((folder) => folder.id)
            .toSet() ??
        const {};

    // Filter out notes that belong to vault folders
    final nonVaultNotes = notes.where((note) {
      return note.folderId == null || !vaultFolderIds.contains(note.folderId);
    }).toList();

    return nonVaultNotes.take(2).toList();
  });
});

/// Unified folder shortcut entry covering both task and note folders.
enum _FolderType { task, notes }

class _FolderShortcut {
  final String id;
  final String name;
  final String? iconName;
  final int? folderColor;
  final DateTime updatedAt;
  final _FolderType type;

  const _FolderShortcut({
    required this.id,
    required this.name,
    this.iconName,
    this.folderColor,
    required this.updatedAt,
    required this.type,
  });

  factory _FolderShortcut.fromTask(Folder f) => _FolderShortcut(
    id: f.id,
    name: f.name,
    iconName: f.icon,
    folderColor: f.color,
    updatedAt: f.updatedAt,
    type: _FolderType.task,
  );

  factory _FolderShortcut.fromNote(NoteFolder f) => _FolderShortcut(
    id: f.id,
    name: f.name,
    updatedAt: f.updatedAt,
    type: _FolderType.notes,
  );
}

/// Top 3 most-recently-updated non-vault folders (task + note mixed).
final overviewFolderShortcutsProvider = Provider<List<_FolderShortcut>>((ref) {
  final taskFolders = ref.watch(folderNotifierProvider).value ?? [];
  final noteFolders = ref.watch(noteFoldersProvider).value ?? [];
  final shortcuts = [
    ...taskFolders.where((f) => !f.isVault).map(_FolderShortcut.fromTask),
    ...noteFolders.where((f) => !f.isVault).map(_FolderShortcut.fromNote),
  ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return shortcuts.take(3).toList();
});

class OverviewTab extends ConsumerWidget {
  const OverviewTab({super.key});

  static const _sectionLabels = {
    'clock': 'Clock',
    'greeting': 'Greeting',
    'folder_shortcuts': 'Folder Shortcuts',
    'progress': 'Task Progress',
    'todos': 'Pending Todos',
    'events': 'Upcoming Events',
    'latest_notes': 'Latest Notes',
    'recent_settings': 'Quick Settings',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = ref.watch(adaptiveSpacingProvider);
    final sectionOrder = ref.watch(overviewSectionOrderProvider);
    final hiddenSections = ref.watch(overviewHiddenSectionsProvider);
    final taskStats = ref.watch(taskStatisticsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: spacing.insets16,
      children: [
        StaggeredGrid.count(
          crossAxisCount: 2,
          mainAxisSpacing: spacing.s16,
          crossAxisSpacing: spacing.s16,
          children: [
            for (final section in sectionOrder)
              if (!hiddenSections.contains(section) &&
                  !(section == 'progress' && taskStats.total == 0))
                StaggeredGridTile.fit(
                  crossAxisCellCount: _crossAxisCount(section),
                  child: _buildSection(section),
                ),
          ],
        ),
        SizedBox(height: spacing.s16),
        // Config button at the bottom
        Center(
          child: SizedBox(
            width: 36,
            height: 36,
            child: IconButton.filledTonal(
              icon: const Icon(Icons.tune, size: 16),
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
              ),
              onPressed: () =>
                  _showSectionOrderDialog(context, ref, sectionOrder),
            ),
          ),
        ),
        SizedBox(height: spacing.s8),
      ],
    );
  }

  Widget _buildSection(String section) {
    switch (section) {
      case 'clock':
        return _ClockSection();
      case 'greeting':
        return _GreetingSection();
      case 'folder_shortcuts':
        return _BentoCard(child: _FolderShortcutsSection());
      case 'progress':
        return _ProgressSection();
      case 'todos':
        return _BentoCard(child: _TodosSection());
      case 'events':
        return _BentoCard(child: _EventsSection());
      case 'latest_notes':
        return _BentoCard(child: _LatestNotesSection());
      case 'recent_settings':
        return _BentoCard(child: _RecentSettingsSection());
      default:
        return const SizedBox.shrink();
    }
  }

  int _crossAxisCount(String section) {
    return 2;
  }

  void _showSectionOrderDialog(
    BuildContext context,
    WidgetRef ref,
    List<String> currentOrder,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final order = [...currentOrder];
    // Use local copy of hidden state so setState drives the UI immediately
    var hidden = ref.read(overviewHiddenSectionsProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Customize Sections',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: order.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = order.removeAt(oldIndex);
                        order.insert(newIndex, item);
                      });
                      ref.read(overviewSectionOrderProvider.notifier).reorder([
                        ...order,
                      ]);
                    },
                    itemBuilder: (context, index) {
                      final section = order[index];
                      final isVisible = !hidden.contains(section);
                      return ListTile(
                        key: ValueKey(section),
                        leading: Icon(
                          Icons.drag_indicator,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        title: Text(
                          _sectionLabels[section] ?? section,
                          style: TextStyle(
                            color: isVisible
                                ? colorScheme.onSurface
                                : colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                        dense: true,
                        trailing: Switch(
                          value: isVisible,
                          onChanged: (_) {
                            setState(() {
                              final next = {...hidden};
                              if (next.contains(section)) {
                                next.remove(section);
                              } else {
                                next.add(section);
                              }
                              hidden = next;
                            });
                            ref
                                .read(overviewHiddenSectionsProvider.notifier)
                                .toggle(section);
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Clock
// ---------------------------------------------------------------------------
class _ClockSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(liveTimeProvider).value ?? DateTime.now();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = ref.watch(adaptiveSpacingProvider);
    final preferences = ref.watch(preferencesStateProvider);
    final systemUse24Hour = MediaQuery.of(context).alwaysUse24HourFormat;
    final use24Hour = preferences.resolveUse24Hour(systemUse24Hour);
    final timeStr = DateFormat(use24Hour ? 'HH:mm' : 'hh:mm a').format(now);

    return Padding(
      padding: EdgeInsets.only(top: spacing.s4, bottom: spacing.s4),
      child: Text(
        timeStr,
        style: theme.textTheme.displayMedium?.copyWith(
          fontWeight: FontWeight.w200,
          color: colorScheme.primary,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Greeting
// ---------------------------------------------------------------------------
class _GreetingSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = ref.watch(userNameProvider);
    final now = ref.watch(liveTimeProvider).value ?? DateTime.now();
    final hour = now.hour;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = ref.watch(adaptiveSpacingProvider);
    final preferences = ref.watch(preferencesStateProvider);
    final languageIndex = preferences.greetingLanguage;

    final greeting = GreetingService.getGreeting(
      hour: hour,
      languageIndex: languageIndex,
      userName: userName,
    );
    final subtitle = GreetingService.getTasksSubtitle(
      hour: hour,
      languageIndex: languageIndex,
    );

    return GestureDetector(
      onTap: () => _showNameDialog(context, ref, userName),
      child: Padding(
        padding: EdgeInsets.only(top: spacing.s4, bottom: spacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greeting,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
            SizedBox(height: spacing.s4),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNameDialog(
    BuildContext context,
    WidgetRef ref,
    String currentName,
  ) async {
    final displayName =
        (currentName == '_SKIP_NAME_' || currentName == '_CLEARED_NAME_')
        ? ''
        : currentName;

    final savedName = await showDialog<String>(
      context: context,
      builder: (context) => _NameEditDialog(initialName: displayName),
    );

    if (savedName == null) return;
    final stored = savedName.isEmpty ? '_CLEARED_NAME_' : savedName;
    await StorageService.setUserName(stored);
    if (context.mounted) ref.read(userNameProvider.notifier).update(stored);
  }
}

/// Owns the TextEditingController so Flutter disposes it after the dismiss
/// animation finishes (in State.dispose), not as soon as showDialog resolves.
class _NameEditDialog extends StatefulWidget {
  final String initialName;
  const _NameEditDialog({required this.initialName});

  @override
  State<_NameEditDialog> createState() => _NameEditDialogState();
}

class _NameEditDialogState extends State<_NameEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Your name'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Enter your name'),
        textCapitalization: TextCapitalization.words,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Progress
// ---------------------------------------------------------------------------
class _ProgressSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(taskStatisticsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = ref.watch(adaptiveSpacingProvider);

    if (stats.total == 0) return const SizedBox.shrink();

    final isComplete = stats.completionRate >= 1.0;

    // Compact "all done" banner when 100% complete
    if (isComplete) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: SpacingBorderRadius.lg),
        color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
        child: ExpressiveInkWell(
          borderRadius: SpacingBorderRadius.lg,
          onTap: () => ref.read(currentTabProvider.notifier).setTab(1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: colorScheme.secondary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'All ${stats.total} tasks done!',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (stats.streakDays > 0)
                  Text(
                    '${stats.streakDays}d streak 🔥',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSecondaryContainer.withValues(
                        alpha: 0.8,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: SpacingBorderRadius.lg),
      color: colorScheme.primaryContainer.withValues(alpha: 0.35),
      child: ExpressiveInkWell(
        borderRadius: SpacingBorderRadius.lg,
        onTap: () => ref.read(currentTabProvider.notifier).setTab(1),
        child: Padding(
          padding: spacing.insets16,
          child: Row(
            children: [
              // Circular progress
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: stats.completionRate,
                      strokeWidth: 5,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                    ),
                    Text(
                      '${(stats.completionRate * 100).toInt()}%',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: spacing.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Task Progress',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: spacing.s4),
                    Text(
                      '${stats.completed} of ${stats.total} completed'
                      '${stats.overdue > 0 ? ' · ${stats.overdue} overdue' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (stats.streakDays > 0) ...[
                      SizedBox(height: spacing.s4),
                      Text(
                        '${stats.streakDays} day streak',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pending Todos
// ---------------------------------------------------------------------------
class _TodosSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todos = ref.watch(overviewTodosProvider);
    final spacing = ref.watch(adaptiveSpacingProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Pending Todos',
          icon: Icons.checklist,
          onSeeAll: () => ref.read(currentTabProvider.notifier).setTab(1),
        ),
        SizedBox(height: spacing.s8),
        if (todos.isEmpty)
          _EmptyCard(
            icon: Icons.check_circle_outline,
            message: 'All caught up!',
          )
        else
          ...todos.map(
            (todo) => Padding(
              padding: EdgeInsets.only(bottom: spacing.s4),
              child: HybridTodoItem(
                todo: todo,
                onToggle: () => ref
                    .read(taskControllerProvider.notifier)
                    .toggleComplete(todo.id),
                onEdit: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TaskEditorScreen(
                        todo: todo,
                        onSave: (updated) => ref
                            .read(taskControllerProvider.notifier)
                            .update(updated),
                      ),
                    ),
                  );
                },
                onDelete: () =>
                    ref.read(taskControllerProvider.notifier).delete(todo.id),
                onSelectToggle: () {},
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Upcoming Events
// ---------------------------------------------------------------------------
class _EventsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(overviewEventsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = ref.watch(adaptiveSpacingProvider);
    final preferences = ref.watch(preferencesStateProvider);
    final systemUse24Hour = MediaQuery.of(context).alwaysUse24HourFormat;
    final use24Hour = preferences.resolveUse24Hour(systemUse24Hour);
    final timeFormat = DateFormat(use24Hour ? 'HH:mm' : 'hh:mm a');
    final dateFormat = DateFormat('MMM d');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Upcoming Events',
          icon: Icons.event,
          onSeeAll: () => ref.read(currentTabProvider.notifier).setTab(1),
        ),
        SizedBox(height: spacing.s8),
        if (events.isEmpty)
          _EmptyCard(icon: Icons.event_available, message: 'No upcoming events')
        else
          ...events.map((event) {
            final eventColor = event.color != null
                ? Color(event.color!)
                : colorScheme.tertiary;
            final isAllDay = event.isAllDay;
            final timeText = isAllDay
                ? 'All day'
                : '${timeFormat.format(event.startDateTime)} – ${timeFormat.format(event.endDateTime)}';
            final dateText = event.isMultiDay
                ? '${dateFormat.format(event.startDateTime)} – ${dateFormat.format(event.endDateTime)}'
                : dateFormat.format(event.startDateTime);

            return Padding(
              padding: EdgeInsets.only(bottom: spacing.s4),
              child: Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: SpacingBorderRadius.md,
                ),
                clipBehavior: Clip.antiAlias,
                color: colorScheme.tertiaryContainer.withValues(alpha: 0.4),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EventEditorScreen(
                          event: event,
                          onSave: (updated) => ref
                              .read(eventControllerProvider.notifier)
                              .update(updated),
                        ),
                      ),
                    );
                  },
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Container(width: 4, color: eventColor),
                        SizedBox(width: spacing.s12),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: spacing.s12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.text,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onTertiaryContainer,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: spacing.s2),
                                Text(
                                  '$dateText · $timeText',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onTertiaryContainer
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(right: spacing.s12),
                          child: Icon(
                            Icons.event,
                            size: 20,
                            color: colorScheme.onTertiaryContainer.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Latest Notes (2 side-by-side)
// ---------------------------------------------------------------------------
class _LatestNotesSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(overviewLatestNotesProvider);
    final spacing = ref.watch(adaptiveSpacingProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Latest Notes',
          icon: Icons.note,
          onSeeAll: () => ref.read(currentTabProvider.notifier).setTab(2),
        ),
        SizedBox(height: spacing.s8),
        notesAsync.when(
          data: (notes) {
            if (notes.isEmpty) {
              return _EmptyCard(icon: Icons.note_add, message: 'No notes yet');
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < 2; i++) ...[
                  if (i > 0) SizedBox(width: spacing.s8),
                  Expanded(
                    child: i < notes.length
                        ? NotePreviewCard(
                            note: notes[i],
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => QuillNoteEditorScreen(
                                    noteId: notes[i].id,
                                  ),
                                ),
                              );
                            },
                            onPin: null,
                            onDelete: () {},
                            onDeleteConfirmed: () {},
                            isInVault: false,
                            isGridView: true,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              _EmptyCard(icon: Icons.warning, message: 'Error loading notes'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Recent Settings
// ---------------------------------------------------------------------------
class _RecentSettingsSection extends ConsumerWidget {
  static const _icons = <String, IconData>{
    'personalization': Icons.palette_outlined,
    'notifications': Icons.notifications_outlined,
    'app_lock': Icons.lock_outline,
    'data_management': Icons.storage_outlined,
    'defaults': Icons.tune_outlined,
    'about': Icons.info_outline,
    'experimental': Icons.science_outlined,
    'custom_theme': Icons.style_outlined,
    'font_size': Icons.text_fields_outlined,
    'calendar_sync': Icons.calendar_today_outlined,
    'holiday_calendar': Icons.event_outlined,
    'backup': Icons.backup_outlined,
    'bin': Icons.delete_outline,
  };

  static const _labels = <String, String>{
    'personalization': 'Personalization',
    'notifications': 'Notifications',
    'app_lock': 'App Lock',
    'data_management': 'Data Management',
    'defaults': 'Defaults',
    'about': 'About',
    'experimental': 'Experimental',
    'custom_theme': 'Custom Theme',
    'font_size': 'Font Size',
    'calendar_sync': 'Calendar Sync',
    'holiday_calendar': 'Import Calendar',
    'backup': 'Backup & Data',
    'bin': 'Bin Settings',
  };

  void _navigateTo(BuildContext context, WidgetRef ref, String key) {
    ref.read(recentSettingsProvider.notifier).record(key);
    Widget? screen;
    switch (key) {
      case 'personalization':
        screen = const PersonalizationScreen();
        break;
      case 'notifications':
        screen = const ComprehensiveNotificationSettings();
        break;
      case 'app_lock':
        screen = const AppLockSettingsPage();
        break;
      case 'data_management':
        screen = const DataManagementScreen();
        break;
      case 'defaults':
        screen = const DefaultsSettingsScreen();
        break;
      case 'about':
        screen = const AboutScreen();
        break;
      case 'experimental':
        screen = const ExperimentalSettingsScreen();
        break;
      case 'custom_theme':
        screen = const CustomThemeListScreen();
        break;
      case 'font_size':
        screen = const FontSizeSettingsScreen();
        break;
      case 'calendar_sync':
        screen = const CalendarSyncSettingsScreen();
        break;
      case 'holiday_calendar':
        screen = const HolidayCalendarSettingsScreen();
        break;
      case 'backup':
        screen = const BackupSettingsPage();
        break;
      case 'bin':
        screen = const BinSettingsScreen();
        break;
    }
    if (screen != null && context.mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen!));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentSettingsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final spacing = ref.watch(adaptiveSpacingProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Quick Settings',
          icon: Icons.settings_outlined,
          onSeeAll: () {},
          trailing: const SizedBox.shrink(),
        ),
        SizedBox(height: spacing.s8),
        if (recent.isEmpty)
          Text(
            'Recently visited settings will appear here.',
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: recent.map((key) {
                final icon = _icons[key];
                final label = _labels[key];
                if (icon == null || label == null) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: EdgeInsets.only(right: spacing.s8),
                  child: ActionChip(
                    avatar: Icon(icon, size: 16, color: colorScheme.primary),
                    label: Text(label),
                    onPressed: () => _navigateTo(context, ref, key),
                    backgroundColor: colorScheme.surfaceContainerLow,
                    side: BorderSide(
                      color: colorScheme.outlineVariant,
                      width: 0.5,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Folder Shortcuts
// ---------------------------------------------------------------------------
class _FolderShortcutsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shortcuts = ref.watch(overviewFolderShortcutsProvider);
    final spacing = ref.watch(adaptiveSpacingProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Folder Shortcuts',
          icon: Icons.folder_outlined,
          onSeeAll: () {},
          trailing: const SizedBox.shrink(),
        ),
        SizedBox(height: spacing.s8),
        if (shortcuts.isEmpty)
          _EmptyCard(icon: Icons.folder_off_outlined, message: 'No folders yet')
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final folder in shortcuts)
                  Padding(
                    padding: EdgeInsets.only(right: spacing.s8),
                    child: _FolderShortcutChip(folder: folder),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FolderShortcutChip extends ConsumerWidget {
  final _FolderShortcut folder;
  const _FolderShortcutChip({required this.folder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = ref.watch(adaptiveSpacingProvider);

    final iconData = folder.type == _FolderType.task
        ? getIconDataFromName(folder.iconName)
        : Icons.description_outlined;
    final iconColor =
        folder.type == _FolderType.task && folder.folderColor != null
        ? Color(folder.folderColor!)
        : colorScheme.primary;

    final chipColor = Color.alphaBlend(
      iconColor.withValues(alpha: 0.12),
      colorScheme.surfaceContainerLow,
    );

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: chipColor,
      shape: RoundedRectangleBorder(borderRadius: SpacingBorderRadius.md),
      child: ExpressiveInkWell(
        borderRadius: SpacingBorderRadius.md,
        onTap: () {
          if (folder.type == _FolderType.task) {
            ref.read(selectedFolderProvider.notifier).update(folder.id);
            ref.read(currentTabProvider.notifier).setTab(1);
          } else {
            ref.read(selectedNoteFolderProvider.notifier).update(folder.id);
            ref.read(currentTabProvider.notifier).setTab(2);
          }
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.s16,
            vertical: spacing.s8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconData, size: 18, color: iconColor),
              SizedBox(width: spacing.s8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    folder.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    folder.type == _FolderType.task ? 'Tasks' : 'Notes',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------
class _SectionHeader extends ConsumerWidget {
  final String title;
  final IconData icon;
  final VoidCallback onSeeAll;
  final Widget? trailing;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.onSeeAll,
    this.trailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          trailing!
        else
          ExpressiveTextButton(
            onPressed: onSeeAll,
            child: Text(
              'See all',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: SpacingBorderRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: colorScheme.onSurfaceVariant, size: 20),
            const SizedBox(width: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bento Card container
// ---------------------------------------------------------------------------
class _BentoCard extends ConsumerWidget {
  final Widget child;
  const _BentoCard({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final preferences = ref.watch(preferencesStateProvider);
    final bgColor = isDark
        ? colorScheme.surfaceContainerLow
        : Color.alphaBlend(
            colorScheme.primary.withValues(alpha: 0.07),
            colorScheme.surfaceContainerLow,
          );

    // Check if AMOLED black theme and monochrome color are both active
    final isAmoledBlack = preferences.useBlackTheme && isDark;
    final isMonochrome = preferences.accentColorSeed == 0xFF9E9E9E;
    final shouldRemoveBorder = isAmoledBlack && isMonochrome;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: shouldRemoveBorder
            ? BorderSide.none
            : BorderSide(
                color: isDark
                    ? colorScheme.outlineVariant
                    : colorScheme.primary.withValues(alpha: 0.18),
                width: 0.5,
              ),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}
