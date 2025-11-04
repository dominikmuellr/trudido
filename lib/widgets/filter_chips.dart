import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/filter_providers.dart';

class FilterChips extends ConsumerWidget {
  const FilterChips({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedPriority = ref.watch(selectedPriorityProvider);
    final showCompleted = ref.watch(showCompletedProvider);
    final sortBy = ref.watch(sortByProvider);

    // subtle chip styling (de-emphasized)
    final chipBg = theme.colorScheme.surface.withOpacity(0.02);
    final chipSelectedBg = theme.colorScheme.primary.withOpacity(0.12);
    final chipLabelColor = theme.colorScheme.onSurface.withOpacity(0.9);
    final chipSelectedLabelColor = theme.colorScheme.primary;
    final chipBorder = BorderSide(
      color: theme.colorScheme.onSurface.withOpacity(0.06),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  // Priority → Sort → Show Completed

                  // Priority filter
                  PopupMenuButton<String>(
                    initialValue: selectedPriority,
                    onSelected: (value) =>
                        ref.read(selectedPriorityProvider.notifier).state =
                            value,
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'all',
                        child: Text('All Priorities'),
                      ),
                      PopupMenuItem(
                        value: 'high',
                        child: Text('High Priority'),
                      ),
                      PopupMenuItem(
                        value: 'medium',
                        child: Text('Medium Priority'),
                      ),
                      PopupMenuItem(value: 'low', child: Text('Low Priority')),
                    ],
                    child: Chip(
                      label: Text(
                        selectedPriority == 'all'
                            ? 'All Priorities'
                            : '${selectedPriority[0].toUpperCase()}${selectedPriority.substring(1)} Priority',
                      ),
                      avatar: Icon(
                        Icons.flag_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(
                          0.8,
                        ),
                      ),
                      backgroundColor: chipBg,
                      shape: StadiumBorder(side: chipBorder),
                      labelStyle: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w400,
                        fontSize: 13.0,
                        color: chipLabelColor,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Sort by
                  PopupMenuButton<String>(
                    initialValue: sortBy,
                    onSelected: (value) =>
                        ref.read(sortByProvider.notifier).state = value,
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'default',
                        child: Text('Default Sort'),
                      ),
                      PopupMenuItem(
                        value: 'date_created',
                        child: Text('Date Created'),
                      ),
                      PopupMenuItem(value: 'date_due', child: Text('Due Date')),
                      PopupMenuItem(value: 'priority', child: Text('Priority')),
                      PopupMenuItem(
                        value: 'alphabetical',
                        child: Text('Alphabetical'),
                      ),
                    ],
                    child: Chip(
                      label: Text(_getSortLabel(sortBy)),
                      avatar: Icon(
                        Icons.sort,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(
                          0.8,
                        ),
                      ),
                      backgroundColor: chipBg,
                      shape: StadiumBorder(side: chipBorder),
                      labelStyle: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w400,
                        fontSize: 13.0,
                        color: chipLabelColor,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Show completed toggle
                  FilterChip(
                    label: const Text('Show Completed'),
                    selected: showCompleted,
                    onSelected: (selected) =>
                        ref.read(showCompletedProvider.notifier).state =
                            selected,
                    avatar: Icon(
                      showCompleted ? Icons.visibility : Icons.visibility_off,
                      size: 14,
                      color: showCompleted
                          ? chipSelectedLabelColor
                          : theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                    ),
                    backgroundColor: chipBg,
                    selectedColor: chipSelectedBg,
                    shape: StadiumBorder(side: chipBorder),
                    labelStyle: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w400,
                      fontSize: 13.0,
                      color: showCompleted
                          ? chipSelectedLabelColor
                          : chipLabelColor,
                    ),
                  ),
                ],
              ), // Row
            ), // Padding
          ), // ConstrainedBox
        ); // SingleChildScrollView
      }, // builder
    ); // LayoutBuilder
  }

  String _getSortLabel(String sortBy) {
    switch (sortBy) {
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
