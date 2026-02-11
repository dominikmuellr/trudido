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
import 'package:trudido/providers/filter_providers.dart';
import 'package:trudido/services/storage_service.dart';
import '../theme/spacing_tokens.dart';

/// Material 3 compliant filter chips row for the Tasks tab.
/// Always visible, with action-based labels and a Clear chip.
/// Supports multi-sort via a "+" chip next to Sort.
class FilterChips extends ConsumerWidget {
  const FilterChips({super.key});

  // Available sort keys for multi-sort (excludes 'default' and 'manual')
  static const _sortOptions = {
    'date_created': 'Created',
    'date_due': 'Due Date',
    'priority': 'Priority',
    'alphabetical': 'A-Z',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    // Optimize: only rebuild when these specific values change
    final showCompleted = ref.watch(
      showCompletedProvider.select((show) => show),
    );
    final sortBy = ref.watch(sortByProvider.select((sort) => sort));
    final secondarySortKeys = ref.watch(
      secondarySortKeysProvider.select((keys) => keys),
    );
    final dueToday = ref.watch(dueTodayFilterProvider.select((due) => due));

    // Determine if any filter or sort is active (for Clear chip)
    final hasActiveFilters =
        dueToday == true ||
        showCompleted == false ||
        sortBy != 'default' ||
        secondarySortKeys.isNotEmpty;

    // Available secondary sort keys (not already used as primary or secondary)
    final availableSecondaryKeys = _sortOptions.keys
        .where((k) => k != sortBy && !secondarySortKeys.contains(k))
        .toList();

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
                    // Sort by (InputChip with menu)
                    PopupMenuButton<String>(
                      initialValue: sortBy,
                      onSelected: (value) {
                        print('[FilterChips] Sort selected: $value');
                        ref.read(sortByProvider.notifier).update(value);
                        print(
                          '[FilterChips] After update, sortBy is now: ${ref.read(sortByProvider)}',
                        );
                        // Remove from secondary if user selects it as primary
                        final current = ref.read(secondarySortKeysProvider);
                        if (current.contains(value)) {
                          ref
                              .read(secondarySortKeysProvider.notifier)
                              .update(
                                current.where((k) => k != value).toList(),
                              );
                        }
                      },
                      position: PopupMenuPosition.under,
                      popUpAnimationStyle: const AnimationStyle(
                        duration: Duration(milliseconds: 100),
                      ),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'default',
                          child: Text('Default Sort'),
                        ),
                        ..._sortOptions.entries.map(
                          (e) =>
                              PopupMenuItem(value: e.key, child: Text(e.value)),
                        ),
                      ],
                      child: IgnorePointer(
                        child: FilterChip(
                          label: Text(_getSortLabel(sortBy)),
                          avatar: const Icon(Icons.sort, size: 18),
                          selected: sortBy != 'default',
                          showCheckmark: false,
                          side: BorderSide.none,
                          backgroundColor: colorScheme.tertiaryContainer,
                          selectedColor: colorScheme.tertiaryContainer,
                          labelStyle: TextStyle(
                            color: colorScheme.onTertiaryContainer,
                          ),
                          iconTheme: IconThemeData(
                            color: colorScheme.onTertiaryContainer,
                          ),
                          onSelected: (_) {},
                        ),
                      ),
                    ),

                    // "+" chip to add secondary sort (only if primary is not default/manual)
                    if (sortBy != 'default' &&
                        sortBy != 'manual' &&
                        availableSecondaryKeys.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          final current = ref.read(secondarySortKeysProvider);
                          ref.read(secondarySortKeysProvider.notifier).update([
                            ...current,
                            value,
                          ]);
                        },
                        position: PopupMenuPosition.under,
                        popUpAnimationStyle: const AnimationStyle(
                          duration: Duration(milliseconds: 100),
                        ),
                        tooltip: 'Add secondary sort',
                        itemBuilder: (context) => availableSecondaryKeys
                            .map(
                              (k) => PopupMenuItem(
                                value: k,
                                child: Text(_sortOptions[k] ?? k),
                              ),
                            )
                            .toList(),
                        child: IgnorePointer(
                          child: ActionChip(
                            label: const Text('+'),
                            side: BorderSide.none,
                            backgroundColor: colorScheme.tertiaryContainer,
                            labelStyle: TextStyle(
                              color: colorScheme.onTertiaryContainer,
                            ),
                            onPressed: () {},
                          ),
                        ),
                      ),
                    ],

                    // Show active secondary sort keys as removable chips
                    ...secondarySortKeys.map(
                      (key) => Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: InputChip(
                          key: ValueKey(key),
                          label: Text(_sortOptions[key] ?? key),
                          selected: true,
                          showCheckmark: false,
                          side: BorderSide.none,
                          backgroundColor: colorScheme.tertiaryContainer,
                          selectedColor: colorScheme.tertiaryContainer,
                          labelStyle: TextStyle(
                            color: colorScheme.onTertiaryContainer,
                          ),
                          deleteIconColor: colorScheme.onTertiaryContainer,
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () {
                            final current = ref.read(secondarySortKeysProvider);
                            ref
                                .read(secondarySortKeysProvider.notifier)
                                .update(
                                  current.where((k) => k != key).toList(),
                                );
                          },
                          onPressed: () {}, // keep chip visually enabled
                        ),
                      ),
                    ),

                    SpacingGap.gapH8,

                    // Due Today toggle (FilterChip)
                    FilterChip(
                      label: const Text('Due Today'),
                      avatar: const Icon(Icons.calendar_today, size: 18),
                      selected: dueToday,
                      showCheckmark: false,
                      side: BorderSide.none,
                      backgroundColor: colorScheme.tertiaryContainer,
                      selectedColor: colorScheme.tertiaryContainer,
                      labelStyle: TextStyle(
                        color: colorScheme.onTertiaryContainer,
                      ),
                      iconTheme: IconThemeData(
                        color: colorScheme.onTertiaryContainer,
                      ),
                      onSelected: (selected) {
                        print('[FilterChips] Due Today selected: $selected');
                        ref
                            .read(dueTodayFilterProvider.notifier)
                            .update(selected);
                        print(
                          '[FilterChips] After update, dueTodayFilter is now: ${ref.read(dueTodayFilterProvider)}',
                        );
                      },
                    ),

                    SpacingGap.gapH8,

                    // Show/Hide Completed toggle (FilterChip with action-based label)
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
                      selected:
                          !showCompleted, // selected when hiding (filter active)
                      showCheckmark: false,
                      side: BorderSide.none,
                      backgroundColor: colorScheme.tertiaryContainer,
                      selectedColor: colorScheme.tertiaryContainer,
                      labelStyle: TextStyle(
                        color: colorScheme.onTertiaryContainer,
                      ),
                      iconTheme: IconThemeData(
                        color: colorScheme.onTertiaryContainer,
                      ),
                      onSelected: (selected) {
                        // Toggle: if selected (wants to hide), set false); else true
                        final newValue = !selected;
                        print(
                          '[FilterChips] Show Completed toggled to: $newValue',
                        );
                        ref
                            .read(showCompletedProvider.notifier)
                            .update(newValue);
                        print(
                          '[FilterChips] After update, showCompleted is now: ${ref.read(showCompletedProvider)}',
                        );
                        // Persist choice
                        StorageService.setShowCompletedTasks(newValue);
                      },
                    ),

                    SpacingGap.gapH8,

                    // Clear filters AND sort (ActionChip)
                    ActionChip(
                      label: const Text('Clear'),
                      avatar: const Icon(Icons.clear_all, size: 18),
                      side: BorderSide.none,
                      backgroundColor: colorScheme.tertiaryContainer,
                      labelStyle: TextStyle(
                        color: colorScheme.onTertiaryContainer,
                      ),
                      iconTheme: IconThemeData(
                        color: colorScheme.onTertiaryContainer,
                      ),
                      onPressed: hasActiveFilters
                          ? () {
                              // Reset filters
                              ref
                                  .read(dueTodayFilterProvider.notifier)
                                  .update(false);
                              ref
                                  .read(showCompletedProvider.notifier)
                                  .update(true);
                              // Reset sort
                              ref
                                  .read(sortByProvider.notifier)
                                  .update('default');
                              ref
                                  .read(secondarySortKeysProvider.notifier)
                                  .update([]);
                              // Persist reset
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

  String _getSortLabel(String sortBy) {
    switch (sortBy) {
      case 'date_created':
        return 'Created';
      case 'date_due':
        return 'Due Date';
      case 'priority':
        return 'Priority';
      case 'alphabetical':
        return 'A-Z';
      case 'manual':
        return 'Manual';
      default:
        return 'Sort';
    }
  }
}
