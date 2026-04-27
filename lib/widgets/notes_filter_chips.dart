import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/notes_controller.dart';
import '../providers/app_providers.dart';

class NotesFilterChips extends ConsumerWidget {
  const NotesFilterChips({super.key});

  static const String _allTagsValue = '__all_tags__';

  static const _sortOptions = {
    'date_modified': 'Last Modified',
    'date_created': 'Created',
    'alphabetical': 'A-Z',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final sortBy = ref.watch(notesSortByProvider);
    final selectedTag = ref.watch(selectedNoteTagProvider);
    final availableTags = ref.watch(availableNoteTagsProvider);
    final isSpatialCanvasEnabled = ref.watch(
      preferencesStateProvider.select((p) => p.enableSpatialCanvas),
    );
    final selectedViewMode = ref.watch(notesViewModeProvider);

    if (!isSpatialCanvasEnabled && selectedViewMode == 'spatial') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(notesViewModeProvider) == 'spatial') {
          ref.read(notesViewModeProvider.notifier).update('grid');
        }
      });
    }

    final effectiveViewMode =
        !isSpatialCanvasEnabled && selectedViewMode == 'spatial'
        ? 'grid'
        : selectedViewMode;

    final viewModeSegments = <ButtonSegment<String>>[
      const ButtonSegment(value: 'grid', icon: Icon(Icons.grid_view, size: 18)),
      const ButtonSegment(value: 'list', icon: Icon(Icons.view_list, size: 18)),
      if (isSpatialCanvasEnabled)
        const ButtonSegment(
          value: 'spatial',
          icon: Icon(Icons.space_dashboard_outlined, size: 18),
        ),
    ];

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
                    if (availableTags.isNotEmpty || selectedTag != null) ...[
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        position: PopupMenuPosition.under,
                        onSelected: (value) {
                          if (value == _allTagsValue) {
                            ref
                                .read(selectedNoteTagProvider.notifier)
                                .update(null);
                            return;
                          }
                          ref
                              .read(selectedNoteTagProvider.notifier)
                              .update(value);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem<String>(
                            value: _allTagsValue,
                            child: Text('All tags'),
                          ),
                          ...availableTags.map(
                            (tag) => CheckedPopupMenuItem<String>(
                              value: tag,
                              checked:
                                  selectedTag != null &&
                                  selectedTag.toLowerCase() ==
                                      tag.toLowerCase(),
                              child: Text('#$tag'),
                            ),
                          ),
                        ],
                        child: IgnorePointer(
                          child: FilterChip(
                            label: Text(
                              selectedTag == null ? 'Tag' : '#$selectedTag',
                            ),
                            avatar: const Icon(Icons.sell_outlined, size: 18),
                            selected: selectedTag != null,
                            showCheckmark: false,
                            side: BorderSide.none,
                            backgroundColor: colorScheme.surfaceContainerHigh,
                            selectedColor: colorScheme.primaryContainer,
                            labelStyle: TextStyle(
                              color: selectedTag != null
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurfaceVariant,
                              fontWeight: selectedTag != null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            iconTheme: IconThemeData(
                              color: selectedTag != null
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurfaceVariant,
                            ),
                            onSelected: (_) {},
                          ),
                        ),
                      ),
                    ],
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
                segments: viewModeSegments,
                selected: {effectiveViewMode},
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
