import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/filter_providers.dart';
import '../controllers/task_controller.dart';
import '../widgets/hybrid_todo_item.dart';
import '../widgets/calendar_view.dart';
import '../screens/task_editor_screen.dart';
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

    final multiMode = ref.watch(multiSelectModeProvider);
    final selectedIds = ref.watch(selectedTodoIdsProvider);
    final viewType = ref.watch(taskViewTypeProvider);

    final appOpts =
        Theme.of(context).extension<AppOptions>() ??
        const AppOptions(compact: false, highContrast: false);
    final outerPad = EdgeInsets.all(appOpts.compact ? 12 : 16);

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onPanUpdate: (details) {
              if (viewType == TaskViewType.calendar || filteredTodos.isEmpty) {
                if (details.delta.dy > 60) {
                  ref.read(searchModeProvider.notifier).state = true;
                }
              }
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (scrollNotification) {
                if (viewType == TaskViewType.list && filteredTodos.isNotEmpty) {
                  if (scrollNotification is ScrollUpdateNotification) {
                    if (scrollNotification.metrics.extentBefore <= 0) {
                      if (scrollNotification.metrics.pixels <= -120) {
                        ref.read(searchModeProvider.notifier).state = true;
                        return true;
                      }
                    }
                  }

                  if (scrollNotification is OverscrollNotification) {
                    if (scrollNotification.metrics.extentBefore <= 0) {
                      if (scrollNotification.overscroll <= -80) {
                        ref.read(searchModeProvider.notifier).state = true;
                        return true;
                      }
                    }
                  }
                }

                return false;
              },
              child: viewType == TaskViewType.calendar
                  ? CalendarView(
                      key: ValueKey(ref.watch(selectedCalendarDateProvider)),
                      tasks: filteredTodos,
                    )
                  : filteredTodos.isEmpty
                  ? _buildEmptyState(
                      context,
                      ref.watch(searchQueryProvider).isNotEmpty,
                    )
                  : sortBy == 'manual'
                  ? (!multiMode
                        ? ReorderableListView.builder(
                            padding: outerPad,
                            itemCount: filteredTodos.length,
                            physics: const BouncingScrollPhysics(),
                            onReorder: (oldIndex, newIndex) {
                              ref
                                  .read(taskControllerProvider.notifier)
                                  .reorder(oldIndex, newIndex, filteredTodos);
                            },
                            itemBuilder: (context, index) {
                              final todo = filteredTodos[index];
                              return HybridTodoItem(
                                key: ValueKey(todo.id),
                                todo: todo,
                                onToggle: () => ref
                                    .read(taskControllerProvider.notifier)
                                    .toggleComplete(todo.id),
                                onEdit: () =>
                                    _showEditDialog(context, ref, todo),
                                onDelete: () => _deleteTodoWithConfirmation(
                                  context,
                                  ref,
                                  todo,
                                ),
                                showDragHandle: true,
                                selectable: multiMode,
                                selected: selectedIds.contains(todo.id),
                                onSelectToggle: () {
                                  final wasMulti = ref.read(
                                    multiSelectModeProvider,
                                  );
                                  if (!wasMulti) return;
                                  ref
                                      .read(selectedTodoIdsProvider.notifier)
                                      .toggle(todo.id);
                                  HapticFeedback.selectionClick();
                                },
                              );
                            },
                          )
                        : _buildSelectableList(filteredTodos, ref, true))
                  : ListView.builder(
                      padding: outerPad,
                      physics: const BouncingScrollPhysics(),
                      itemCount: filteredTodos.length,
                      itemBuilder: (context, index) {
                        final todo = filteredTodos[index];
                        return HybridTodoItem(
                          todo: todo,
                          onToggle: () => ref
                              .read(taskControllerProvider.notifier)
                              .toggleComplete(todo.id),
                          onEdit: () => _showEditDialog(context, ref, todo),
                          onDelete: () =>
                              _deleteTodoWithConfirmation(context, ref, todo),
                          selectable: multiMode,
                          selected: selectedIds.contains(todo.id),
                          onSelectToggle: () {
                            final wasMulti = ref.read(multiSelectModeProvider);
                            if (!wasMulti) {
                              ref.read(multiSelectModeProvider.notifier).state =
                                  true;
                            }
                            ref
                                .read(selectedTodoIdsProvider.notifier)
                                .toggle(todo.id);
                            HapticFeedback.selectionClick();
                          },
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectableList(List<Todo> todos, WidgetRef ref, bool manual) {
    final appOpts =
        Theme.of(ref.context).extension<AppOptions>() ??
        const AppOptions(compact: false, highContrast: false);
    final pad = EdgeInsets.all(appOpts.compact ? 12 : 16);
    return ListView.builder(
      padding: pad,
      physics: const BouncingScrollPhysics(),
      itemCount: todos.length,
      itemBuilder: (context, index) {
        final todo = todos[index];
        final selected = ref.watch(selectedTodoIdsProvider).contains(todo.id);
        return HybridTodoItem(
          key: ValueKey(todo.id),
          todo: todo,
          onToggle: () =>
              ref.read(taskControllerProvider.notifier).toggleComplete(todo.id),
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
            isSearching ? Icons.search : Icons.check_circle_outline,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            isSearching ? 'No tasks found' : 'No tasks yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSearching
                ? 'Try adjusting your search or filters'
                : 'Tap the + button to add your first task',
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TaskEditorScreen(
          todo: todo,
          onSave: (updatedTodo) {
            ref.read(taskControllerProvider.notifier).update(updatedTodo);
          },
        ),
      ),
    );
  }

  void _deleteTodoWithConfirmation(
    BuildContext context,
    WidgetRef ref,
    Todo todo,
  ) {
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
