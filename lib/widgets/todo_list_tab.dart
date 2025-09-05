import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../providers/filter_providers.dart';
import '../controllers/task_controller.dart';
import '../widgets/todo_item.dart';
import '../widgets/filter_chips.dart';
import '../widgets/greeting_header.dart';
import '../widgets/folder_selector.dart';
import '../screens/edit_task_screen.dart';
import '../models/todo.dart';
import '../screens/home_screen.dart';
import 'package:flutter/services.dart';
import '../services/theme_service.dart';

class TodoListTab extends ConsumerWidget {
  const TodoListTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
  final filteredTodos = ref.watch(filteredTasksProvider);
    final sortBy = ref.watch(sortByProvider);
  final hideGreeting = ref.watch(hideGreetingProvider);
  final multiMode = ref.watch(multiSelectModeProvider);
  final selectedIds = ref.watch(selectedTodoIdsProvider);

  final appOpts = Theme.of(context).extension<AppOptions>() ?? const AppOptions(compact: false, highContrast: false);
  final outerPad = EdgeInsets.all(appOpts.compact ? 12 : 16);
  final sectionGap = SizedBox(height: appOpts.compact ? 6 : 8);
  return Column(
      children: [
  // Greeting header (optional)
  if (!hideGreeting) const GreetingHeader(),
        
        // Folder selector
        const FolderSelector(),
        
        // Filter chips
        Padding(
          padding: EdgeInsets.symmetric(vertical: appOpts.compact ? 4 : 8),
          child: const FilterChips(),
        ),
        
        sectionGap,
        
        // Todo list
        Expanded(
          child: filteredTodos.isEmpty
              ? _buildEmptyState(context, ref.watch(searchQueryProvider).isNotEmpty)
              : sortBy == 'manual'
                  ? (!multiMode ? ReorderableListView.builder(
                      padding: outerPad,
                      itemCount: filteredTodos.length,
                      onReorder: (oldIndex, newIndex) {
                        ref.read(taskControllerProvider.notifier).reorder(oldIndex, newIndex, filteredTodos);
                      },
                      itemBuilder: (context, index) {
                        final todo = filteredTodos[index];
                        return TodoItem(
                          key: ValueKey(todo.id),
                          todo: todo,
                          onToggle: () => ref.read(taskControllerProvider.notifier).toggleComplete(todo.id),
                          onEdit: () => _showEditDialog(context, ref, todo),
                          onDelete: () => _deleteTodoWithConfirmation(context, ref, todo),
                          showDragHandle: true,
                          selectable: multiMode,
                          selected: selectedIds.contains(todo.id),
                          onSelectToggle: () {
                            // For manual reorder view, only allow selection if already in multi mode to avoid gesture conflict
                            final wasMulti = ref.read(multiSelectModeProvider);
                            if (!wasMulti) return; // user should use toolbar icon in manual mode
                            ref.read(selectedTodoIdsProvider.notifier).toggle(todo.id);
                            HapticFeedback.selectionClick();
                          },
                        );
                      },
                    ) : _buildSelectableList(filteredTodos, ref, true))
                  : ListView.builder(
                      padding: outerPad,
                      itemCount: filteredTodos.length,
                      itemBuilder: (context, index) {
                        final todo = filteredTodos[index];
                        return TodoItem(
                          todo: todo,
                          onToggle: () => ref.read(taskControllerProvider.notifier).toggleComplete(todo.id),
                          onEdit: () => _showEditDialog(context, ref, todo),
                          onDelete: () => _deleteTodoWithConfirmation(context, ref, todo),
                          selectable: multiMode,
                          selected: selectedIds.contains(todo.id),
                          onSelectToggle: () {
                            final wasMulti = ref.read(multiSelectModeProvider);
                            if (!wasMulti) {
                              ref.read(multiSelectModeProvider.notifier).state = true;
                            }
                            ref.read(selectedTodoIdsProvider.notifier).toggle(todo.id);
                            HapticFeedback.selectionClick();
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSelectableList(List<Todo> todos, WidgetRef ref, bool manual) {
  final appOpts = Theme.of(ref.context).extension<AppOptions>() ?? const AppOptions(compact: false, highContrast: false);
  final pad = EdgeInsets.all(appOpts.compact ? 12 : 16);
  return ListView.builder(
	padding: pad,
      itemCount: todos.length,
      itemBuilder: (context, index) {
        final todo = todos[index];
        final selected = ref.watch(selectedTodoIdsProvider).contains(todo.id);
        return TodoItem(
          key: ValueKey(todo.id),
          todo: todo,
          onToggle: () => ref.read(taskControllerProvider.notifier).toggleComplete(todo.id),
          onEdit: () => _showEditDialog(context, ref, todo),
          onDelete: () => _deleteTodoWithConfirmation(context, ref, todo),
          selectable: true,
          selected: selected,
          onSelectToggle: () {
            ref.read(selectedTodoIdsProvider.notifier).toggle(todo.id);
            HapticFeedback.selectionClick();
          },
        );
      },
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
              ref.read(taskControllerProvider.notifier).delete(todo.id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
