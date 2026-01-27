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
import '../providers/note_history_provider.dart';
import '../widgets/common/common.dart';

/// Slash command menu for quick media/content insertion
class SlashCommandMenu extends StatelessWidget {
  final VoidCallback onInsertImage;
  final VoidCallback onInsertVideo;
  final VoidCallback onInsertVoice;
  final VoidCallback onInsertLink;
  final VoidCallback onInsertCode;

  const SlashCommandMenu({
    super.key,
    required this.onInsertImage,
    required this.onInsertVideo,
    required this.onInsertVoice,
    required this.onInsertLink,
    required this.onInsertCode,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      shadowColor: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _SlashMenuItem(
              icon: Icons.image_outlined,
              label: 'Photo',
              onTap: onInsertImage,
            ),
            _SlashMenuItem(
              icon: Icons.videocam_outlined,
              label: 'Video',
              onTap: onInsertVideo,
            ),
            _SlashMenuItem(
              icon: Icons.mic_outlined,
              label: 'Voice',
              onTap: onInsertVoice,
            ),
            _SlashMenuItem(
              icon: Icons.link,
              label: 'Link',
              onTap: onInsertLink,
            ),
            _SlashMenuItem(
              icon: Icons.code,
              label: 'Code',
              onTap: onInsertCode,
            ),
          ],
        ),
      ),
    );
  }
}

class _SlashMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SlashMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ExpressiveInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// Floating history controls for undo/redo/history in note editor
class FloatingHistoryControls extends ConsumerWidget {
  final String? noteId;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback onShowHistory;

  const FloatingHistoryControls({
    super.key,
    required this.noteId,
    this.onUndo,
    this.onRedo,
    required this.onShowHistory,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canUndo = noteId != null
        ? ref.watch(canUndoProvider(noteId!))
        : false;
    final canRedo = noteId != null
        ? ref.watch(canRedoProvider(noteId!))
        : false;

    // Check if viewing a past version (not at live)
    final historyPosition = noteId != null
        ? ref.watch(currentHistoryPositionProvider(noteId!))
        : null;
    final isViewingPast =
        historyPosition != null && historyPosition.currentEntryId != null;
    final isBranchingMode = historyPosition?.isBranchingMode ?? false;

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(28),
      shadowColor: Theme.of(context).colorScheme.shadow.withOpacity(0.2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isBranchingMode
              ? Theme.of(context).colorScheme.primaryContainer
              : isViewingPast
              ? Theme.of(context).colorScheme.tertiaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isBranchingMode
                ? Theme.of(context).colorScheme.primary
                : isViewingPast
                ? Theme.of(context).colorScheme.tertiary
                : Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
            width: (isViewingPast || isBranchingMode) ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // "Branching" indicator
            if (isBranchingMode) ...[
              _buildIndicator(
                context,
                icon: Icons.call_split,
                label: 'New Branch',
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              _buildVerticalDivider(
                context,
                Theme.of(context).colorScheme.primary.withOpacity(0.5),
              ),
            ]
            // "Viewing past" indicator (only if not branching)
            else if (isViewingPast) ...[
              _buildIndicator(
                context,
                icon: Icons.history,
                label: 'Past',
                color: Theme.of(context).colorScheme.onTertiaryContainer,
              ),
              _buildVerticalDivider(
                context,
                Theme.of(context).colorScheme.tertiary.withOpacity(0.5),
              ),
            ],
            // Undo button
            ExpressiveIconButton(
              icon: Icon(
                Icons.undo_rounded,
                size: 20,
                color: canUndo
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withOpacity(0.4),
              ),
              tooltip: 'Undo',
              onPressed: canUndo ? onUndo : null,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            // Redo button
            ExpressiveIconButton(
              icon: Icon(
                Icons.redo_rounded,
                size: 20,
                color: canRedo
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withOpacity(0.4),
              ),
              tooltip: 'Redo',
              onPressed: canRedo ? onRedo : null,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            // Divider
            _buildVerticalDivider(
              context,
              Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
            ),
            // History button
            ExpressiveIconButton(
              icon: Icon(
                Icons.history_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              tooltip: 'View history',
              onPressed: onShowHistory,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicator(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider(BuildContext context, Color color) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: color,
    );
  }
}
