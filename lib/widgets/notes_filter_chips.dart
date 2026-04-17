import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/notes_controller.dart';

class NotesFilterChips extends ConsumerWidget {
  const NotesFilterChips({super.key});

  static const _sortOptions = {
    'date_modified': 'Last Modified',
    'date_created': 'Created',
    'alphabetical': 'A-Z',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final sortBy = ref.watch(notesSortByProvider);

    return Semantics(
      container: true,
      label: 'Note filters',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            // Sort chips (scrollable)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 16.0),
                child: Row(
                  children: [
                    // Sort by (InputChip with menu)
                    PopupMenuButton<String>(
                      initialValue: sortBy,
                      onSelected: (value) {
                        ref.read(notesSortByProvider.notifier).setSort(value);
                      },
                      position: PopupMenuPosition.under,
                      popUpAnimationStyle: const AnimationStyle(
                        duration: Duration(milliseconds: 100),
                      ),
                      itemBuilder: (context) => [
                        ..._sortOptions.entries.map(
                          (e) =>
                              PopupMenuItem(value: e.key, child: Text(e.value)),
                        ),
                      ],
                      child: IgnorePointer(
                        child: AnimatedScale(
                          scale: sortBy != 'date_modified' ? 1.03 : 1.0,
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOut,
                          child: FilterChip(
                            label: Text(_getSortLabel(sortBy)),
                            avatar: const Icon(Icons.sort, size: 18),
                            selected: sortBy != 'date_modified',
                            showCheckmark: false,
                            side: BorderSide.none,
                            backgroundColor: colorScheme.surfaceContainerHigh,
                            selectedColor: colorScheme.primaryContainer,
                            labelStyle: TextStyle(
                              color: sortBy != 'date_modified'
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurfaceVariant,
                              fontWeight: sortBy != 'date_modified'
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            iconTheme: IconThemeData(
                              color: sortBy != 'date_modified'
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurfaceVariant,
                            ),
                            onSelected: (_) {}, // Handled by PopupMenuButton
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // View mode toggle (pinned to the right)
            Padding(
              padding: const EdgeInsets.only(left: 8.0, right: 16.0),
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                segments: const [
                  ButtonSegment(
                    value: 'grid',
                    icon: Icon(Icons.grid_view, size: 18),
                  ),
                  ButtonSegment(
                    value: 'list',
                    icon: Icon(Icons.view_list, size: 18),
                  ),
                  ButtonSegment(
                    value: 'freeform',
                    icon: Icon(Icons.space_dashboard_outlined, size: 18),
                  ),
                ],
                selected: {ref.watch(notesViewModeProvider)},
                onSelectionChanged: (selected) {
                  ref
                      .read(notesViewModeProvider.notifier)
                      .update(selected.first);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSortLabel(String key) {
    return _sortOptions[key] ?? 'Sort';
  }
}
