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

import '../controllers/task_controller.dart';
import '../controllers/event_controller.dart';
import '../providers/app_providers.dart';
import '../repositories/notes_repository.dart';
import '../models/todo.dart';
import '../models/event.dart' as app_event;
import '../models/note.dart';
import '../widgets/hybrid_todo_item.dart';
import '../widgets/note_preview_card_markdown.dart';
import '../screens/home_screen_notifiers.dart';
import '../screens/task_editor_screen.dart';
import '../screens/event_editor_screen.dart';
import '../screens/quill_note_editor_screen.dart';
import '../theme/spacing_tokens.dart';
import '../widgets/common/common.dart';

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

/// The single most recently updated note (first from the sorted notes list).
final overviewLatestNoteProvider = Provider<AsyncValue<Note?>>((ref) {
  return ref.watch(notesProvider).whenData((notes) {
    if (notes.isEmpty) return null;
    return notes.first;
  });
});

class OverviewTab extends ConsumerWidget {
  const OverviewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = ref.watch(adaptiveSpacingProvider);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: spacing.insets16,
      children: [
        // Progress card
        _ProgressSection(),
        SizedBox(height: spacing.s16),
        // Pending todos
        _TodosSection(),
        SizedBox(height: spacing.s16),
        // Upcoming events
        _EventsSection(),
        SizedBox(height: spacing.s16),
        // Latest note
        _LatestNoteSection(),
        SizedBox(height: spacing.s16),
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
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('MMM d');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Upcoming Events',
          icon: Icons.event,
          onSeeAll: () => ref.read(currentTabProvider.notifier).setTab(2),
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
// Latest Note
// ---------------------------------------------------------------------------
class _LatestNoteSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteAsync = ref.watch(overviewLatestNoteProvider);
    final spacing = ref.watch(adaptiveSpacingProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Latest Note',
          icon: Icons.note,
          onSeeAll: () => ref.read(currentTabProvider.notifier).setTab(3),
        ),
        SizedBox(height: spacing.s8),
        noteAsync.when(
          data: (note) {
            if (note == null) {
              return _EmptyCard(icon: Icons.note_add, message: 'No notes yet');
            }
            return NotePreviewCard(
              note: note,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => QuillNoteEditorScreen(noteId: note.id),
                  ),
                );
              },
              onPin: () {},
              onDelete: () {},
              onDeleteConfirmed: () {},
              isInVault: false,
              isGridView: false,
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
// Shared helpers
// ---------------------------------------------------------------------------
class _SectionHeader extends ConsumerWidget {
  final String title;
  final IconData icon;
  final VoidCallback onSeeAll;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.onSeeAll,
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
