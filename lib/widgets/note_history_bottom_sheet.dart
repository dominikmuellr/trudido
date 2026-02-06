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
import '../models/note_history.dart';
import '../models/note_history_tree.dart';
import '../providers/app_providers.dart';
import '../providers/note_history_provider.dart';
import '../theme/spacing_tokens.dart';
import '../widgets/common/common.dart';

/// Colors for different branches in the history tree.
const List<Color> _branchColors = [
  Colors.blue,
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.teal,
  Colors.pink,
  Colors.indigo,
  Colors.amber,
];

/// A bottom sheet that displays the full edit history for a note's content.
/// Supports branching history with side-by-side branch visualization.
class NoteHistoryBottomSheet extends ConsumerStatefulWidget {
  final String noteId;
  final String noteTitle;
  final Function(String? restoredContent) onRestore;

  const NoteHistoryBottomSheet({
    super.key,
    required this.noteId,
    required this.noteTitle,
    required this.onRestore,
  });

  @override
  ConsumerState<NoteHistoryBottomSheet> createState() =>
      _NoteHistoryBottomSheetState();
}

class _NoteHistoryBottomSheetState
    extends ConsumerState<NoteHistoryBottomSheet> {
  bool _showTreeView = true;

  bool get _use24Hour {
    final prefs = ref.watch(preferencesStateProvider);
    return prefs.resolveUse24Hour(MediaQuery.of(context).alwaysUse24HourFormat);
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(noteHistoryProvider(widget.noteId));
    final tree = ref.watch(historyTreeProvider(widget.noteId));
    final currentPosition = ref.watch(
      currentHistoryPositionProvider(widget.noteId),
    );
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Note History',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        // Toggle between tree view and list view
                        if (tree != null)
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: true,
                                icon: Icon(Icons.account_tree, size: 18),
                                tooltip: 'Tree view',
                              ),
                              ButtonSegment(
                                value: false,
                                icon: Icon(Icons.list, size: 18),
                                tooltip: 'List view',
                              ),
                            ],
                            selected: {_showTreeView},
                            onSelectionChanged: (value) {
                              setState(() {
                                _showTreeView = value.first;
                              });
                            },
                            style: ButtonStyle(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                      ],
                    ),
                    SpacingGap.gapV4,
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.noteTitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (tree != null && tree.branchPoints.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.call_split,
                                  size: 14,
                                  color: colorScheme.onTertiaryContainer,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${tree.branchPoints.length} branch${tree.branchPoints.length > 1 ? 'es' : ''}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onTertiaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    SpacingGap.gapV4,
                    Text(
                      'Tap an entry to navigate to that version',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(),

              // History list or tree
              Expanded(
                child: historyAsync.when(
                  data: (history) {
                    if (history.isEmpty) {
                      return _buildEmptyState(colorScheme, theme);
                    }

                    if (_showTreeView && tree != null) {
                      return _buildBranchView(context, tree, currentPosition);
                    } else {
                      return _buildListView(
                        context,
                        history,
                        currentPosition,
                        scrollController,
                      );
                    }
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
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

  Widget _buildEmptyState(ColorScheme colorScheme, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
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
            'Changes to notes will appear here',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(
    BuildContext context,
    List<NoteHistoryEntry> history,
    NoteHistoryState? currentPosition,
    ScrollController scrollController,
  ) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final entry = history[index];
        final isCurrentPosition = currentPosition?.currentEntryId == entry.id;
        return _HistoryEntryTile(
          entry: entry,
          isLatest: index == 0,
          isCurrentPosition: isCurrentPosition,
          branchColor: _branchColors[0],
          use24Hour: _use24Hour,
          onTap: () => _showEntryOptions(entry),
        );
      },
    );
  }

  /// Build the side-by-side branch view with clear branch origins
  Widget _buildBranchView(
    BuildContext context,
    HistoryTree tree,
    NoteHistoryState? currentPosition,
  ) {
    // Get branch data with divergence info
    final branchData = _collectBranchData(tree);

    if (branchData.isEmpty) {
      return const Center(child: Text('No history'));
    }

    final screenWidth = MediaQuery.of(context).size.width;
    // Each branch takes ~50% of width, minimum 160px
    final branchWidth = (screenWidth - 32) / 2;
    final effectiveBranchWidth = branchWidth.clamp(160.0, 300.0);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: branchData.asMap().entries.map((branchEntry) {
          final branchIndex = branchEntry.key;
          final data = branchEntry.value;
          final branchColor = _branchColors[branchIndex % _branchColors.length];

          return Container(
            width: effectiveBranchWidth,
            margin: EdgeInsets.only(
              right: branchIndex < branchData.length - 1 ? 8 : 0,
            ),
            child: _buildBranchColumn(
              context,
              data,
              branchIndex,
              branchColor,
              currentPosition,
              tree,
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Data about a branch including its divergence point
  ({
    List<NoteHistoryEntry> entries,
    NoteHistoryEntry? divergesFrom,
    String? parentBranchName,
    int parentBranchIndex,
  })
  _createBranchData(
    List<NoteHistoryEntry> entries,
    NoteHistoryEntry? divergesFrom,
    String? parentBranchName,
    int parentBranchIndex,
  ) {
    return (
      entries: entries,
      divergesFrom: divergesFrom,
      parentBranchName: parentBranchName,
      parentBranchIndex: parentBranchIndex,
    );
  }

  /// Collect branch data with divergence information
  /// Only creates separate branches for entries with explicit parentEntryId
  List<
    ({
      List<NoteHistoryEntry> entries,
      NoteHistoryEntry? divergesFrom,
      String? parentBranchName,
      int parentBranchIndex,
    })
  >
  _collectBranchData(HistoryTree tree) {
    final result =
        <
          ({
            List<NoteHistoryEntry> entries,
            NoteHistoryEntry? divergesFrom,
            String? parentBranchName,
            int parentBranchIndex,
          })
        >[];

    // Find all leaf nodes (endpoints of branches)
    final leaves = tree.leaves;
    if (leaves.isEmpty) return result;

    // Collect all complete paths from root to each leaf
    final allPaths = <List<NoteHistoryEntry>>[];
    for (final leaf in leaves) {
      final path = tree.getPathToNode(leaf.entry.id);
      if (path.isNotEmpty) {
        allPaths.add(path);
      }
    }

    // If only one path, it's the main timeline
    if (allPaths.length == 1) {
      result.add(_createBranchData(allPaths[0], null, null, -1));
      return result;
    }

    // Sort paths by when they start (oldest first = main)
    allPaths.sort((a, b) => a.first.timestamp.compareTo(b.first.timestamp));

    // First path is the main branch
    final mainPath = allPaths[0];
    result.add(_createBranchData(mainPath, null, null, -1));

    // For other paths, find where they diverge and only show unique entries
    for (int i = 1; i < allPaths.length; i++) {
      final path = allPaths[i];

      // Find the divergence point (last entry shared with main)
      int divergenceIndex = -1;
      NoteHistoryEntry? divergenceEntry;

      for (int j = 0; j < path.length && j < mainPath.length; j++) {
        if (path[j].id == mainPath[j].id) {
          divergenceIndex = j;
          divergenceEntry = path[j];
        } else {
          break;
        }
      }

      // Get only the entries unique to this branch (after divergence)
      final branchOnlyEntries =
          divergenceIndex >= 0 && divergenceIndex < path.length - 1
          ? path.sublist(divergenceIndex + 1)
          : path;

      // Skip if no unique entries
      if (branchOnlyEntries.isEmpty) continue;

      result.add(
        _createBranchData(branchOnlyEntries, divergenceEntry, 'Main', 0),
      );
    }

    return result;
  }

  /// Build a single branch column with origin indicator
  Widget _buildBranchColumn(
    BuildContext context,
    ({
      List<NoteHistoryEntry> entries,
      NoteHistoryEntry? divergesFrom,
      String? parentBranchName,
      int parentBranchIndex,
    })
    branchData,
    int branchIndex,
    Color branchColor,
    NoteHistoryState? currentPosition,
    HistoryTree tree,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final entries = branchData.entries;

    // Reverse to show newest at top
    final reversedEntries = entries.reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Branch header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: branchColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: branchColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: branchColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  branchIndex == 0 ? 'Main' : 'Branch ${branchIndex}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: branchColor,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        // Branch origin indicator (for non-main branches)
        if (branchData.divergesFrom != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    _branchColors[branchData.parentBranchIndex %
                            _branchColors.length]
                        .withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Arrow indicating origin
                Icon(
                  Icons.subdirectory_arrow_right,
                  size: 16,
                  color:
                      _branchColors[branchData.parentBranchIndex %
                          _branchColors.length],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Branched from ${branchData.parentBranchName}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        branchData.divergesFrom!.formatTimestamp(
                          use24Hour: _use24Hour,
                        ),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                // Connection dot
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color:
                        _branchColors[branchData.parentBranchIndex %
                            _branchColors.length],
                    shape: BoxShape.circle,
                    border: Border.all(color: branchColor, width: 2),
                  ),
                ),
              ],
            ),
          ),
          // Connecting line from origin to first entry - subtle
          Container(
            height: 8,
            width: 1,
            margin: const EdgeInsets.only(left: 10, bottom: 2),
            color: branchColor.withOpacity(0.3),
          ),
        ],

        // Branch entries
        Expanded(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: reversedEntries.length,
            itemBuilder: (context, index) {
              final entry = reversedEntries[index];
              final isCurrentPosition =
                  currentPosition?.currentEntryId == entry.id;
              final isLatest = index == 0;

              return _CompactEntryTile(
                entry: entry,
                isLatest: isLatest,
                isCurrentPosition: isCurrentPosition,
                branchColor: branchColor,
                use24Hour: _use24Hour,
                onTap: () => _showEntryOptions(entry),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Show options dialog for a history entry
  void _showEntryOptions(NoteHistoryEntry entry) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Version from ${entry.formatTimestamp(use24Hour: _use24Hour)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SpacingGap.gapV8,

            // Preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(maxHeight: 100),
              width: double.infinity,
              child: SingleChildScrollView(
                child: Text(
                  entry.contentBeforePreview.isNotEmpty
                      ? entry.contentBeforePreview
                      : '(empty)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            SpacingGap.gapV16,

            // Options
            ListTile(
              leading: Icon(Icons.visibility, color: colorScheme.primary),
              title: const Text('View this version'),
              subtitle: const Text('Temporarily view this content'),
              onTap: () {
                Navigator.of(dialogContext).pop();
                _viewEntry(entry);
              },
            ),
            ListTile(
              leading: Icon(Icons.call_split, color: colorScheme.tertiary),
              title: const Text('Create new branch'),
              subtitle: const Text(
                'Start editing from this point as a new branch',
              ),
              onTap: () {
                Navigator.of(dialogContext).pop();
                _createBranchFromEntry(entry);
              },
            ),
            ListTile(
              leading: Icon(Icons.restore, color: colorScheme.error),
              title: const Text('Restore this version'),
              subtitle: const Text(
                'Replace current content (continues main timeline)',
              ),
              onTap: () {
                Navigator.of(dialogContext).pop();
                _restoreEntry(entry);
              },
            ),

            SpacingGap.gapV8,
            // Cancel button
            SizedBox(
              width: double.infinity,
              child: ExpressiveTextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Just view the entry content (no branch creation)
  void _viewEntry(NoteHistoryEntry entry) {
    Navigator.of(context).pop();
    widget.onRestore(entry.contentBefore);
  }

  /// Create a new branch from this entry
  void _createBranchFromEntry(NoteHistoryEntry entry) {
    // Mark that we're creating a branch from this entry
    ref
        .read(noteHistoryNavigatorProvider.notifier)
        .startBranchFrom(widget.noteId, entry.id);

    Navigator.of(context).pop();
    widget.onRestore(entry.contentBefore);

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.call_split, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'New branch created. Your edits will be on this branch.',
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Restore entry (continues main timeline, no branch)
  void _restoreEntry(NoteHistoryEntry entry) {
    Navigator.of(context).pop();
    widget.onRestore(entry.contentBefore);
  }
}

/// Compact entry tile for the branch view (50% width)
class _CompactEntryTile extends StatelessWidget {
  final NoteHistoryEntry entry;
  final bool isLatest;
  final bool isCurrentPosition;
  final Color branchColor;
  final bool use24Hour;
  final VoidCallback onTap;

  const _CompactEntryTile({
    required this.entry,
    required this.isLatest,
    required this.isCurrentPosition,
    required this.branchColor,
    required this.use24Hour,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Vertical line connector with current position indicator
          SizedBox(
            width: 24,
            child: CustomPaint(
              painter: _VerticalLinePainter(
                color: branchColor,
                isCurrentPosition: isCurrentPosition,
                highlightColor: colorScheme.primary,
              ),
            ),
          ),

          // Entry card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                // Add glow effect for current position
                boxShadow: isCurrentPosition
                    ? [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Card(
                margin: EdgeInsets.zero,
                elevation: isCurrentPosition ? 2 : 0,
                color: isCurrentPosition
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: isCurrentPosition
                      ? BorderSide(color: colorScheme.primary, width: 2)
                      : BorderSide(
                          color: branchColor.withOpacity(0.3),
                          width: 1,
                        ),
                ),
                child: ExpressiveInkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Timestamp and badges
                        Row(
                          children: [
                            // Current position indicator icon
                            if (isCurrentPosition)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: colorScheme.primary,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                entry.formatTimestamp(use24Hour: use24Hour),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isCurrentPosition
                                      ? colorScheme.primary
                                      : null,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isLatest)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: branchColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'HEAD',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (isCurrentPosition && !isLatest)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'HERE',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onPrimary,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Content preview
                        Text(
                          entry.contentBeforePreview,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant.withOpacity(
                              0.8,
                            ),
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical line painter for branch connections with current position indicator
class _VerticalLinePainter extends CustomPainter {
  final Color color;
  final bool isCurrentPosition;
  final Color highlightColor;

  _VerticalLinePainter({
    required this.color,
    this.isCurrentPosition = false,
    this.highlightColor = Colors.blue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final effectiveColor = isCurrentPosition ? highlightColor : color;
    final paint = Paint()
      ..color = effectiveColor
      ..strokeWidth = isCurrentPosition ? 3 : 2
      ..style = PaintingStyle.stroke;

    final centerX = size.width / 2;

    // Vertical line
    canvas.drawLine(Offset(centerX, 0), Offset(centerX, size.height), paint);

    // Horizontal connector
    canvas.drawLine(
      Offset(centerX, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    // Node dot - larger and highlighted for current position
    final dotRadius = isCurrentPosition ? 6.0 : 4.0;
    final dotPaint = Paint()
      ..color = effectiveColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(centerX, size.height / 2), dotRadius, dotPaint);

    // Add outer ring for current position
    if (isCurrentPosition) {
      final ringPaint = Paint()
        ..color = highlightColor.withOpacity(0.3)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(centerX, size.height / 2), 10, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _VerticalLinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.isCurrentPosition != isCurrentPosition ||
        oldDelegate.highlightColor != highlightColor;
  }
}

class _HistoryEntryTile extends StatelessWidget {
  final NoteHistoryEntry entry;
  final bool isLatest;
  final bool isCurrentPosition;
  final Color? branchColor;
  final bool use24Hour;
  final VoidCallback onTap;

  const _HistoryEntryTile({
    required this.entry,
    required this.isLatest,
    required this.isCurrentPosition,
    required this.branchColor,
    required this.use24Hour,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: isCurrentPosition
          ? colorScheme.primaryContainer.withOpacity(0.5)
          : colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrentPosition
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: ExpressiveInkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Branch color indicator
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: branchColor ?? colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          entry.formatTimestamp(use24Hour: use24Hour),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isLatest) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  branchColor ?? colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'HEAD',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        if (isCurrentPosition && !isLatest) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'HERE',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.contentBeforePreview,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Navigate icon
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the note history bottom sheet for a specific note.
Future<void> showNoteHistoryBottomSheet({
  required BuildContext context,
  required String noteId,
  required String noteTitle,
  required Function(String? restoredContent) onRestore,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => NoteHistoryBottomSheet(
      noteId: noteId,
      noteTitle: noteTitle,
      onRestore: onRestore,
    ),
  );
}
