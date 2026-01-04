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
    final sortBy = ref.watch(notesSortByProvider);

    return Semantics(
      container: true,
      label: 'Note filters',
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                        child: FilterChip(
                          label: Text(_getSortLabel(sortBy)),
                          avatar: const Icon(Icons.sort, size: 18),
                          selected: sortBy != 'date_modified',
                          showCheckmark: false,
                          onSelected: (_) {}, // Handled by PopupMenuButton
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _getSortLabel(String key) {
    return _sortOptions[key] ?? 'Sort';
  }
}
