import 'package:flutter/material.dart';
import '../screens/task_editor_screen.dart';
import '../models/todo.dart';

/// Test screen to demonstrate the fixed Save button validation
class SaveButtonValidationTestScreen extends StatefulWidget {
  const SaveButtonValidationTestScreen({super.key});

  @override
  State<SaveButtonValidationTestScreen> createState() => _SaveButtonValidationTestScreenState();
}

class _SaveButtonValidationTestScreenState extends State<SaveButtonValidationTestScreen> {
  final List<Todo> _testTodos = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Save Button Validation Test'),
      ),
      body: Column(
        children: [
          // Info card
          Card(
            margin: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🔧 Save Button Validation Test',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Test the following scenarios:',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '✅ Empty task name → Save button DISABLED\n' 
                    '✅ Enter text → Save button ENABLED immediately\n' 
                    '✅ Clear text → Save button DISABLED again\n' 
                    '✅ Spaces only → Save button DISABLED\n' 
                    '✅ Valid task name → Save button ENABLED',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Test button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openAddDialog(),
                    icon: const Icon(Icons.add_task),
                    label: const Text('Open Task Creation Dialog'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _testTodos.isNotEmpty ? () => _clearTestTodos() : null,
                    icon: const Icon(Icons.clear_all),
                    label: Text('Clear Test Results (${_testTodos.length})'),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Instructions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📝 Test Instructions',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Tap "Open Task Creation Dialog"\n' 
                      '2. Notice Save button is initially DISABLED\n' 
                      '3. Start typing in the task name field\n' 
                      '4. Save button should become ENABLED immediately\n' 
                      '5. Clear the text → Save button should be DISABLED\n' 
                      '6. Type only spaces → Save button should stay DISABLED\n' 
                      '7. Type actual text → Save button should be ENABLED',
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Results
          Expanded(
            child: _testTodos.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.task_alt,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No test todos created yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Use the dialog above to test the Save button validation',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(
                              'Test Results',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_testTodos.length} todo${_testTodos.length == 1 ? '' : 's'} created',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _testTodos.length,
                          itemBuilder: (context, index) {
                            final todo = _testTodos[index];
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  child: Text('${index + 1}'),
                                ),
                                title: Text(
                                  todo.text,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (todo.notes?.isNotEmpty == true)
                                      Text('Notes: ${todo.notes}'),
                                    Text('Priority: ${todo.priority}'),
                                    if (todo.folderId != null)
                                      Text('Folder: ${todo.folderId}'),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _deleteTodo(index),
                                  tooltip: 'Delete todo',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
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
            _testTodos.add(todo);
          });
          
          // Show success message with validation confirmation
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Todo "${todo.text}" created! Save button validation working correctly.'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'DETAILS',
                textColor: Colors.white,
                onPressed: () {
                  _showTodoDetails(todo);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _showTodoDetails(Todo todo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Todo Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Title: ${todo.text}'),
            if (todo.notes?.isNotEmpty == true)
              Text('Notes: ${todo.notes}'),
            Text('Priority: ${todo.priority}'),
            if (todo.folderId != null)
              Text('Folder: ${todo.folderId}'),
            if (todo.dueDate != null)
              Text('Due: ${todo.dueDate.toString()}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _clearTestTodos() {
    final count = _testTodos.length;
    setState(() {
      _testTodos.clear();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🗑️ Cleared $count test todo${count == 1 ? '' : 's'}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _deleteTodo(int index) {
    final todo = _testTodos[index];
    setState(() {
      _testTodos.removeAt(index);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${todo.text}"'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            setState(() {
              _testTodos.insert(index, todo);
            });
          },
        ),
      ),
    );
  }
}