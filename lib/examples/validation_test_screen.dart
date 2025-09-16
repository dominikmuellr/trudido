import 'package:flutter/material.dart';
import '../screens/task_editor_screen.dart';
import '../models/todo.dart';

/// Test screen to demonstrate the optional field validation in AddTodoDialog
class ValidationTestScreen extends StatefulWidget {
  const ValidationTestScreen({super.key});

  @override
  State<ValidationTestScreen> createState() => _ValidationTestScreenState();
}

class _ValidationTestScreenState extends State<ValidationTestScreen> {
  final List<Todo> _todos = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Validation Test'),
      ),
      body: Column(
        children: [
          // Info card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✅ Validation Test Cases',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Task with only title (no date/time) - Should save ✅\n' 
                    '• Task with date only (no time) - Should save ✅\n' 
                    '• Task with date and future time - Should save ✅\n' 
                    '• Task with date and past time - Should show error ❌\n' 
                    '• Task without title - Save button disabled ❌',
                  ),
                ],
              ),
            ),
          ),
          
          // Test buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openAddDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Test Add Todo Dialog'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _clearTodos(),
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear Test Results'),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Results list
          Expanded(
            child: _todos.isEmpty
                ? const Center(
                    child: Text(
                      'No todos created yet.\nTap "Test Add Todo Dialog" to start testing.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _todos.length,
                    itemBuilder: (context, index) {
                      final todo = _todos[index];
                      return Card(
                        child: ListTile(
                          title: Text(todo.text),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (todo.notes?.isNotEmpty == true)
                                Text('Notes: ${todo.notes}'),
                              if (todo.dueDate != null)
                                Text(
                                  'Due: ${_formatDateTime(todo.dueDate!)}',
                                  style: TextStyle(
                                    color: todo.dueDate!.isBefore(DateTime.now())
                                        ? Colors.red
                                        : Colors.green,
                                  ),
                                )
                              else
                                const Text(
                                  'No due date',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              Text('Priority: ${todo.priority}'),
                            ],
                          ),
                          leading: CircleAvatar(
                            backgroundColor: todo.dueDate != null
                                ? (todo.dueDate!.isBefore(DateTime.now())
                                    ? Colors.red
                                    : Colors.green)
                                : Colors.grey,
                            child: Text('${index + 1}'),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteTodo(index),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _openAddDialog() {
    showDialog(
      context: context,
      builder: (context) => TaskEditorScreen(
        onSave: (todo) {
          setState(() {
            _todos.add(todo);
          });
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Todo "${todo.text}" created successfully!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  void _clearTodos() {
    setState(() {
      _todos.clear();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🗑️ All test todos cleared'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _deleteTodo(int index) {
    final todo = _todos[index];
    setState(() {
      _todos.removeAt(index);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${todo.text}"'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            setState(() {
              _todos.insert(index, todo);
            });
          },
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final date = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    final time = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    
    // Check if it's just a date (time is 00:00)
    if (dateTime.hour == 0 && dateTime.minute == 0) {
      return date;
    }
    
    return '$date at $time';
  }
}