import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/filter_providers.dart';

class FilterChips extends ConsumerWidget {
  const FilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPriority = ref.watch(selectedPriorityProvider);
    final showCompleted = ref.watch(showCompletedProvider);
    final sortBy = ref.watch(sortByProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          // match AppBar horizontal padding for consistent alignment
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              // left-align chips so they start at the same horizontal offset as the AppBar
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // (Filters icon removed — Filters available from overflow menu)
                // Priority filter
                PopupMenuButton<String>(
                  initialValue: selectedPriority,
                  onSelected: (value) {
                    ref.read(selectedPriorityProvider.notifier).state = value;
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'all', child: Text('All Priorities')),
                    PopupMenuItem(value: 'high', child: Text('High Priority')),
                    PopupMenuItem(value: 'medium', child: Text('Medium Priority')),
                    PopupMenuItem(value: 'low', child: Text('Low Priority')),
                  ],
                  child: Chip(
                    label: Text(selectedPriority == 'all' 
                        ? 'All Priorities' 
                        : '${selectedPriority[0].toUpperCase()}${selectedPriority.substring(1)} Priority'),
                    avatar: const Icon(Icons.flag_outlined, size: 16),
                  ),
                ),

                const SizedBox(width: 8),

                // Show completed toggle
                FilterChip(
                  label: const Text('Show Completed'),
                  selected: showCompleted,
                  onSelected: (selected) {
                    ref.read(showCompletedProvider.notifier).state = selected;
                  },
                  avatar: Icon(
                    showCompleted ? Icons.visibility : Icons.visibility_off,
                    size: 16,
                  ),
                ),

                const SizedBox(width: 8),

                // Sort by
                PopupMenuButton<String>(
                  initialValue: sortBy,
                  onSelected: (value) {
                    ref.read(sortByProvider.notifier).state = value;
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'default', child: Text('Default Sort')),
                    PopupMenuItem(value: 'manual', child: Text('Manual Order')),
                    PopupMenuItem(value: 'date_created', child: Text('Date Created')),
                    PopupMenuItem(value: 'date_due', child: Text('Due Date')),
                    PopupMenuItem(value: 'priority', child: Text('Priority')),
                    PopupMenuItem(value: 'alphabetical', child: Text('Alphabetical')),
                  ],
                  child: Chip(
                    label: Text(_getSortLabel(sortBy)),
                    avatar: const Icon(Icons.sort, size: 16),
                  ),
                ),
              ],
            ), // Row
          ), // ConstrainedBox
        ); // SingleChildScrollView
      }, // builder
    ); // LayoutBuilder
  }

  String _getSortLabel(String sortBy) {
    switch (sortBy) {
      case 'manual':
        return 'Manual';
      case 'date_created':
        return 'Date Created';
      case 'date_due':
        return 'Due Date';
      case 'priority':
        return 'Priority';
      case 'alphabetical':
        return 'A-Z';
      default:
        return 'Default';
    }
  }
}
