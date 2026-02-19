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
import '../utils/mention_parser.dart';
import '../utils/mention_navigator.dart';

/// A widget that displays backlinks (items referencing the current item).
///
/// Shows a list of tasks and notes that contain mention links pointing
/// to the specified item.
class BacklinksSection extends ConsumerWidget {
  /// The ID of the current item
  final String itemId;

  /// The type of the current item: 'task' or 'note'
  final String itemType;

  const BacklinksSection({
    super.key,
    required this.itemId,
    required this.itemType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Collect all backlinks
    final List<_BacklinkItem> backlinks = [];

    if (itemType == 'task') {
      // Notes that link to this task
      final linkingNotes = BacklinksProvider.getNotesLinkingToTask(ref, itemId);
      for (final note in linkingNotes) {
        backlinks.add(
          _BacklinkItem(
            id: note.id,
            title: note.title,
            type: 'note',
            icon: Icons.description_outlined,
          ),
        );
      }
      // Tasks that link to this task
      final linkingTasks = BacklinksProvider.getTasksLinkingToTask(ref, itemId);
      for (final task in linkingTasks) {
        backlinks.add(
          _BacklinkItem(
            id: task.id,
            title: task.text,
            type: 'task',
            icon: Icons.check_circle_outline,
          ),
        );
      }
    } else {
      // Tasks that link to this note
      final linkingTasks = BacklinksProvider.getTasksLinkingToNote(ref, itemId);
      for (final task in linkingTasks) {
        backlinks.add(
          _BacklinkItem(
            id: task.id,
            title: task.text,
            type: 'task',
            icon: Icons.check_circle_outline,
          ),
        );
      }
      // Notes that link to this note
      final linkingNotes = BacklinksProvider.getNotesLinkingToNote(ref, itemId);
      for (final note in linkingNotes) {
        backlinks.add(
          _BacklinkItem(
            id: note.id,
            title: note.title,
            type: 'note',
            icon: Icons.description_outlined,
          ),
        );
      }
    }

    if (backlinks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Icon(Icons.link, size: 16, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Linked by (${backlinks.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        ...backlinks.map(
          (backlink) =>
              _buildBacklinkTile(context, ref, backlink, colorScheme, theme),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildBacklinkTile(
    BuildContext context,
    WidgetRef ref,
    _BacklinkItem backlink,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    return InkWell(
      onTap: () {
        MentionNavigator.navigateToMention(
          context,
          ref,
          MentionLink(
            title: backlink.title,
            type: backlink.type,
            id: backlink.id,
            start: 0,
            end: 0,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(
              backlink.icon,
              size: 18,
              color: backlink.type == 'task'
                  ? colorScheme.primary
                  : colorScheme.tertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                backlink.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: backlink.type == 'task'
                      ? colorScheme.primary
                      : colorScheme.tertiary,
                  decoration: TextDecoration.underline,
                  decorationStyle: TextDecorationStyle.dotted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color:
                    (backlink.type == 'task'
                            ? colorScheme.primaryContainer
                            : colorScheme.tertiaryContainer)
                        .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                backlink.type == 'task' ? 'Task' : 'Note',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: backlink.type == 'task'
                      ? colorScheme.primary
                      : colorScheme.tertiary,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BacklinkItem {
  final String id;
  final String title;
  final String type;
  final IconData icon;

  const _BacklinkItem({
    required this.id,
    required this.title,
    required this.type,
    required this.icon,
  });
}
