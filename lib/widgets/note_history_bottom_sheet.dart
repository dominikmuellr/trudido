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
import '../models/note_history.dart';
import '../providers/app_providers.dart';
import '../providers/note_history_provider.dart';
import '../services/storage_service.dart';
import '../theme/spacing_tokens.dart';

/// A bottom sheet that displays a chronological edit history for a note.
/// Entries can be previewed (temporary) or restored (replaces current content).
class NoteHistoryBottomSheet extends ConsumerWidget {
  final String noteId;
  final String noteTitle;

  /// Called when the user picks a version.
  /// [permanent] = true means the user wants to restore (overwrite current content).
  /// [permanent] = false means just a temporary preview.
  final Function(String? content, {required bool permanent}) onRestore;

  const NoteHistoryBottomSheet({
    super.key,
    required this.noteId,
    required this.noteTitle,
    required this.onRestore,
  });

  bool _use24Hour(WidgetRef ref, BuildContext context) {
    final prefs = ref.watch(preferencesStateProvider);
    return prefs.resolveUse24Hour(MediaQuery.of(context).alwaysUse24HourFormat);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(noteHistoryProvider(noteId));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final use24Hour = _use24Hour(ref, context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit History',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SpacingGap.gapV4,
                          Text(
                            noteTitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Clear history button (only when history exists)
                    historyAsync.maybeWhen(
                      data: (history) => history.isNotEmpty
                          ? _ClearHistoryButton(
                              noteId: noteId,
                              onCleared: () => Navigator.of(context).pop(),
                            )
                          : const SizedBox.shrink(),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // History list
              Expanded(
                child: historyAsync.when(
                  data: (history) {
                    if (history.isEmpty) {
                      return _buildEmptyState(theme, colorScheme);
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        return _HistoryEntryTile(
                          entry: history[index],
                          isLatest: index == 0,
                          use24Hour: use24Hour,
                          onView: () {
                            Navigator.of(context).pop();
                            onRestore(
                              history[index].contentBefore,
                              permanent: false,
                            );
                          },
                          onRestore: () {
                            Navigator.of(context).pop();
                            onRestore(
                              history[index].contentBefore,
                              permanent: true,
                            );
                          },
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(
                    child: Text(
                      'Failed to load history',
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          SpacingGap.gapV16,
          Text(
            'No edit history yet',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SpacingGap.gapV8,
          Text(
            'Changes to this note will appear here',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClearHistoryButton extends ConsumerWidget {
  final String noteId;
  final VoidCallback onCleared;

  const _ClearHistoryButton({required this.noteId, required this.onCleared});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.delete_sweep_outlined),
      tooltip: 'Clear history',
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Clear Edit History?'),
            content: const Text(
              'All saved edit history for this note will be permanently deleted.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.error,
                ),
                child: const Text('Clear'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await StorageService.deleteNoteHistoryForNote(noteId);
          ref.invalidate(noteHistoryProvider(noteId));
          onCleared();
        }
      },
    );
  }
}

class _HistoryEntryTile extends StatelessWidget {
  final NoteHistoryEntry entry;
  final bool isLatest;
  final bool use24Hour;
  final VoidCallback onView;
  final VoidCallback onRestore;

  const _HistoryEntryTile({
    required this.entry,
    required this.isLatest,
    required this.use24Hour,
    required this.onView,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timestamp row
            Row(
              children: [
                Icon(
                  Icons.history,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  entry.formatTimestamp(use24Hour: use24Hour),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                if (isLatest)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Latest',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),

            SpacingGap.gapV6,

            // Change summary
            Text(
              entry.changeSummary,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            SpacingGap.gapV6,

            // Content preview
            if (entry.contentBeforePreview.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  entry.contentBeforePreview,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            SpacingGap.gapV8,

            // Action row: Preview (no save) | Restore (permanent)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onView, child: const Text('Preview')),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: onRestore,
                  child: const Text('Restore'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the note history bottom sheet.
void showNoteHistoryBottomSheet({
  required BuildContext context,
  required String noteId,
  required String noteTitle,
  required Function(String? content, {required bool permanent}) onRestore,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => NoteHistoryBottomSheet(
      noteId: noteId,
      noteTitle: noteTitle,
      onRestore: onRestore,
    ),
  );
}
