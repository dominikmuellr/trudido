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
import 'package:trudido/providers/filter_providers.dart';
import 'package:trudido/services/storage_service.dart';
import '../theme/spacing_tokens.dart';

/// Material 3 compliant filter chips row for the Tasks tab.
/// Filters: item type (All/Todos/Events), Due Today, Show/Hide Completed, Clear.
class FilterChips extends ConsumerWidget {
  const FilterChips({super.key});

  static const String _allTagsValue = '__all_tags__';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    final showCompleted = ref.watch(
      showCompletedProvider.select((show) => show),
    );
    final dueToday = ref.watch(dueTodayFilterProvider.select((due) => due));
    final itemType = ref.watch(
      listItemTypeFilterProvider.select((type) => type),
    );
    final selectedTag = ref.watch(
      selectedTaskEventTagProvider.select((value) => value),
    );
    final availableTags = ref.watch(availableTaskEventTagsProvider);

    final hasActiveFilters =
        dueToday == true ||
        showCompleted == false ||
        itemType != 'all' ||
        selectedTag != null;

    return Semantics(
      container: true,
      label: 'Task filters',
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
                    // Item type filter (segmented-style chips)
                    _buildTypeChip(
                      context,
                      ref,
                      label: 'All',
                      icon: Icons.dashboard_outlined,
                      isSelected: itemType == 'all',
                      colorScheme: colorScheme,
                      onSelected: () => ref
                          .read(listItemTypeFilterProvider.notifier)
                          .update('all'),
                    ),
                    SpacingGap.gapH4,
                    _buildTypeChip(
                      context,
                      ref,
                      label: 'Todos',
                      icon: Icons.check_circle_outline,
                      isSelected: itemType == 'tasks_only',
                      colorScheme: colorScheme,
                      onSelected: () => ref
                          .read(listItemTypeFilterProvider.notifier)
                          .update('tasks_only'),
                    ),
                    SpacingGap.gapH4,
                    _buildTypeChip(
                      context,
                      ref,
                      label: 'Events',
                      icon: Icons.event_outlined,
                      isSelected: itemType == 'events_only',
                      colorScheme: colorScheme,
                      onSelected: () => ref
                          .read(listItemTypeFilterProvider.notifier)
                          .update('events_only'),
                    ),

                    if (availableTags.isNotEmpty || selectedTag != null) ...[
                      SpacingGap.gapH8,
                      PopupMenuButton<String>(
                        position: PopupMenuPosition.under,
                        onSelected: (value) {
                          if (value == _allTagsValue) {
                            ref
                                .read(selectedTaskEventTagProvider.notifier)
                                .update(null);
                            return;
                          }
                          ref
                              .read(selectedTaskEventTagProvider.notifier)
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

                    SpacingGap.gapH8,

                    // Due Today toggle
                    FilterChip(
                      label: const Text('Due Today'),
                      avatar: const Icon(Icons.calendar_today, size: 18),
                      selected: dueToday,
                      showCheckmark: false,
                      side: BorderSide.none,
                      backgroundColor: colorScheme.surfaceContainerHigh,
                      selectedColor: colorScheme.primaryContainer,
                      labelStyle: TextStyle(
                        color: dueToday
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                        fontWeight: dueToday
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      iconTheme: IconThemeData(
                        color: dueToday
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                      ),
                      onSelected: (selected) {
                        ref
                            .read(dueTodayFilterProvider.notifier)
                            .update(selected);
                      },
                    ),

                    SpacingGap.gapH8,

                    // Show/Hide Completed toggle
                    FilterChip(
                      label: Text(
                        showCompleted ? 'Hide completed' : 'Show completed',
                      ),
                      avatar: Icon(
                        showCompleted
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                      ),
                      selected: !showCompleted,
                      showCheckmark: false,
                      side: BorderSide.none,
                      backgroundColor: colorScheme.surfaceContainerHigh,
                      selectedColor: colorScheme.primaryContainer,
                      labelStyle: TextStyle(
                        color: !showCompleted
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                        fontWeight: !showCompleted
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      iconTheme: IconThemeData(
                        color: !showCompleted
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                      ),
                      onSelected: (selected) {
                        final newValue = !selected;
                        ref
                            .read(showCompletedProvider.notifier)
                            .update(newValue);
                        StorageService.setShowCompletedTasks(newValue);
                      },
                    ),

                    SpacingGap.gapH8,

                    // Clear filters
                    ActionChip(
                      label: const Text('Clear'),
                      avatar: const Icon(Icons.clear_all, size: 18),
                      side: BorderSide.none,
                      backgroundColor: colorScheme.surfaceContainerHigh,
                      labelStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      iconTheme: IconThemeData(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      onPressed: hasActiveFilters
                          ? () {
                              ref
                                  .read(dueTodayFilterProvider.notifier)
                                  .update(false);
                              ref
                                  .read(showCompletedProvider.notifier)
                                  .update(true);
                              ref
                                  .read(listItemTypeFilterProvider.notifier)
                                  .update('all');
                              ref
                                  .read(selectedTaskEventTagProvider.notifier)
                                  .update(null);
                              StorageService.setShowCompletedTasks(true);
                            }
                          : null,
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

  Widget _buildTypeChip(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required IconData icon,
    required bool isSelected,
    required ColorScheme colorScheme,
    required VoidCallback onSelected,
  }) {
    return AnimatedScale(
      scale: isSelected ? 1.03 : 1.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: FilterChip(
        label: Text(label),
        avatar: Icon(icon, size: 18),
        selected: isSelected,
        showCheckmark: false,
        side: BorderSide.none,
        backgroundColor: colorScheme.surfaceContainerHigh,
        selectedColor: colorScheme.primaryContainer,
        labelStyle: TextStyle(
          color: isSelected
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
        iconTheme: IconThemeData(
          color: isSelected
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
        ),
        onSelected: (_) => onSelected(),
      ),
    );
  }
}
