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
import '../models/note.dart';
import '../providers/app_providers.dart';
import '../providers/notes_providers.dart';
import '../utils/date_search_parser.dart';
import '../utils/mention_parser.dart';

/// A search result item that can be either a task or a note.
class MentionSearchItem {
  final String id;
  final String title;
  final String type; // 'task' or 'note'
  final String? subtitle;
  final IconData icon;

  const MentionSearchItem({
    required this.id,
    required this.title,
    required this.type,
    this.subtitle,
    required this.icon,
  });
}

/// Overlay popup that shows mention autocomplete suggestions.
///
/// Appears when the user types @ in a text field, showing matching tasks
/// and notes that can be inserted as mention links.
class MentionAutocompletePopup {
  OverlayEntry? _overlayEntry;
  final BuildContext context;
  final WidgetRef ref;
  final void Function(MentionSearchItem item) onItemSelected;

  /// Optional: ID of the item being edited (so it doesn't suggest itself)
  final String? excludeId;

  MentionAutocompletePopup({
    required this.context,
    required this.ref,
    required this.onItemSelected,
    this.excludeId,
  });

  bool get isVisible => _overlayEntry != null;

  /// Shows or updates the autocomplete popup with results matching [query].
  void show(String query) {
    final items = _searchItems(query);
    if (items.isEmpty) {
      hide();
      return;
    }

    _overlayEntry?.remove();

    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    _overlayEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: 20,
        right: 20,
        // Position above keyboard
        top: (screenHeight - keyboardHeight) * 0.2,
        child: _MentionPopupContent(
          items: items,
          query: query,
          onItemSelected: (item) {
            hide();
            onItemSelected(item);
          },
          onDismiss: hide,
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  /// Hides the autocomplete popup.
  void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// Searches tasks and notes matching the query.
  List<MentionSearchItem> _searchItems(String query) {
    final results = <MentionSearchItem>[];

    // Search tasks
    final tasks = ref.read(tasksProvider);
    final activeTasks = tasks
        .where((t) => !t.isDeleted && !t.isCompleted)
        .toList();

    if (query.isEmpty) {
      // Show recent tasks (up to 5)
      for (final task in activeTasks.take(5)) {
        if (task.id == excludeId) continue;
        results.add(
          MentionSearchItem(
            id: task.id,
            title: task.text,
            type: 'task',
            subtitle: task.dueDate != null
                ? 'Due: ${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}'
                : null,
            icon: Icons.check_circle_outline,
          ),
        );
      }
    } else {
      // Fuzzy search tasks
      final matchingTasks = FuzzySearch.filter(
        items: activeTasks,
        query: query,
        getText: (t) => t.text,
        minSimilarity: 0.4,
      );
      for (final task in matchingTasks.take(5)) {
        if (task.id == excludeId) continue;
        results.add(
          MentionSearchItem(
            id: task.id,
            title: task.text,
            type: 'task',
            subtitle: task.dueDate != null
                ? 'Due: ${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}'
                : null,
            icon: Icons.check_circle_outline,
          ),
        );
      }
    }

    // Search notes
    final notesAsync = ref.read(notesProvider);
    final notes = notesAsync.value ?? const <Note>[];
    final activeNotes = notes.where((n) => !n.isDeleted).toList();

    if (query.isEmpty) {
      // Show recent notes (up to 5)
      for (final note in activeNotes.take(5)) {
        if (note.id == excludeId) continue;
        results.add(
          MentionSearchItem(
            id: note.id,
            title: note.title,
            type: 'note',
            subtitle: _truncateContent(note.content),
            icon: Icons.description_outlined,
          ),
        );
      }
    } else {
      // Fuzzy search notes
      final matchingNotes = FuzzySearch.filter(
        items: activeNotes,
        query: query,
        getText: (n) => n.title,
        minSimilarity: 0.4,
      );
      for (final note in matchingNotes.take(5)) {
        if (note.id == excludeId) continue;
        results.add(
          MentionSearchItem(
            id: note.id,
            title: note.title,
            type: 'note',
            subtitle: _truncateContent(note.content),
            icon: Icons.description_outlined,
          ),
        );
      }
    }

    return results;
  }

  String? _truncateContent(String content) {
    if (content.isEmpty) return null;
    // Skip Quill JSON content
    if (content.trimLeft().startsWith('[')) return null;
    // Strip mention format for display
    final cleaned = content.replaceAllMapped(
      MentionParser.mentionPattern,
      (m) => '@${m.group(1)}',
    );
    // Strip first line (title) and take a preview
    final lines = cleaned.split('\n');
    final preview = lines.length > 1
        ? lines.skip(1).join(' ').trim()
        : cleaned.trim();
    if (preview.isEmpty) return null;
    return preview.length > 60 ? '${preview.substring(0, 60)}...' : preview;
  }
}

/// The actual popup content widget.
class _MentionPopupContent extends StatelessWidget {
  final List<MentionSearchItem> items;
  final String query;
  final void Function(MentionSearchItem) onItemSelected;
  final VoidCallback onDismiss;

  const _MentionPopupContent({
    required this.items,
    required this.query,
    required this.onItemSelected,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Group items by type
    final tasks = items.where((i) => i.type == 'task').toList();
    final notes = items.where((i) => i.type == 'note').toList();

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 350),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.alternate_email,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      query.isEmpty
                          ? 'Link to a task or note'
                          : 'Results for "@$query"',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onDismiss,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Results list
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  if (tasks.isNotEmpty) ...[
                    _buildSectionHeader(context, 'Tasks', Icons.task_alt),
                    ...tasks.map((item) => _buildResultItem(context, item)),
                  ],
                  if (notes.isNotEmpty) ...[
                    _buildSectionHeader(
                      context,
                      'Notes',
                      Icons.description_outlined,
                    ),
                    ...notes.map((item) => _buildResultItem(context, item)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(BuildContext context, MentionSearchItem item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: () => onItemSelected(item),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              item.icon,
              size: 20,
              color: item.type == 'task'
                  ? colorScheme.primary
                  : colorScheme.tertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Type badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color:
                    (item.type == 'task'
                            ? colorScheme.primaryContainer
                            : colorScheme.tertiaryContainer)
                        .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item.type == 'task' ? 'Task' : 'Note',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: item.type == 'task'
                      ? colorScheme.primary
                      : colorScheme.tertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
