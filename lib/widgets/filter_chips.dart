import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/todo_provider.dart';

class FilterChips extends ConsumerWidget {
  const FilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final selectedPriority = ref.watch(selectedPriorityProvider);
    final showCompleted = ref.watch(showCompletedProvider);
    final sortBy = ref.watch(sortByProvider);
    final categories = ref.watch(categoriesProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
        // Category filter
        PopupMenuButton<String>(
          initialValue: selectedCategory,
          onSelected: (value) {
            ref.read(selectedCategoryProvider.notifier).state = value;
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'all', child: Text('All Categories')),
            ...categories.map((category) => PopupMenuItem(
              value: category.id,
              child: Text(category.name),
            )),
          ],
          child: Chip(
            label: Text(selectedCategory == 'all' 
                ? 'All Categories' 
                : categories.where((c) => c.id == selectedCategory).firstOrNull?.name ?? 'Category'),
            avatar: const Icon(Icons.folder_outlined, size: 16),
          ),
        ),

        const SizedBox(width: 8),

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
    ),
    );
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
