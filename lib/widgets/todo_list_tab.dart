import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/todo_provider.dart';
import '../widgets/todo_item.dart';
import '../widgets/filter_chips.dart';
import '../widgets/quick_progress_card.dart';
import '../widgets/greeting_header.dart';
import '../widgets/folder_selector.dart';
import '../screens/edit_task_screen.dart';
import '../models/todo.dart';

class TodoListTab extends ConsumerWidget {
  const TodoListTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredTodos = ref.watch(filteredTodosProvider);
    final statistics = ref.watch(statisticsProvider);
    final sortBy = ref.watch(sortByProvider);

    return Column(
      children: [
        // Greeting header
        const GreetingHeader(),
        
        // Folder selector
        const FolderSelector(),
        
        // Filter chips
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: FilterChips(),
        ),
        
        // Quick progress card
        if (statistics.totalTasks > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: QuickProgressCard(statistics: statistics),
          ),
        
        const SizedBox(height: 8),
        
        // Todo list
        Expanded(
          child: filteredTodos.isEmpty
              ? _buildEmptyState(context, ref.watch(searchQueryProvider).isNotEmpty)
              : sortBy == 'manual'
                  ? ReorderableListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredTodos.length,
                      onReorder: (oldIndex, newIndex) {
                        ref.read(todosProvider.notifier).reorderTodos(oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) {
                        final todo = filteredTodos[index];
                        return TodoItem(
                          key: ValueKey(todo.id),
                          todo: todo,
                          onToggle: () => ref.read(todosProvider.notifier).toggleTodo(todo.id),
                          onEdit: () => _showEditDialog(context, ref, todo),
                          onDelete: () => _deleteTodoWithConfirmation(context, ref, todo),
                          showDragHandle: true,
                        );
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredTodos.length,
                      itemBuilder: (context, index) {
                        final todo = filteredTodos[index];
                        return TodoItem(
                          todo: todo,
                          onToggle: () => ref.read(todosProvider.notifier).toggleTodo(todo.id),
                          onEdit: () => _showEditDialog(context, ref, todo),
                          onDelete: () => _deleteTodoWithConfirmation(context, ref, todo),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isSearching) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? PhosphorIcons.magnifyingGlass() : PhosphorIcons.listChecks(),
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            isSearching ? 'No todos found' : 'No todos yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSearching 
                ? 'Try adjusting your search or filters'
                : 'Tap the + button to add your first todo',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Todo todo) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => EditTaskScreen(task: todo),
      ),
    );
    
    // Show SnackBar based on result
    if (result != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Operation completed'),
          backgroundColor: result['success'] == true ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _deleteTodoWithConfirmation(BuildContext context, WidgetRef ref, Todo todo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Todo'),
        content: Text('Are you sure you want to delete "${todo.text}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(todosProvider.notifier).deleteTodo(todo.id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
