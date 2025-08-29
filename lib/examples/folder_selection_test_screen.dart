import 'package:flutter/material.dart';
import '../widgets/add_todo_dialog.dart';
import '../models/todo.dart';
import '../services/storage_service.dart';

/// Test screen to demonstrate mandatory folder selection with default values
class FolderSelectionTestScreen extends StatefulWidget {
  const FolderSelectionTestScreen({super.key});

  @override
  State<FolderSelectionTestScreen> createState() => _FolderSelectionTestScreenState();
}

class _FolderSelectionTestScreenState extends State<FolderSelectionTestScreen> {
  final List<Todo> _testTodos = [];
  String? _currentDefaultFolder;

  @override
  void initState() {
    super.initState();
    _loadCurrentDefaultFolder();
  }

  Future<void> _loadCurrentDefaultFolder() async {
    try {
      final defaultFolderId = await StorageService.getDefaultFolderId();
      setState(() {
        _currentDefaultFolder = defaultFolderId;
      });
    } catch (e) {
      setState(() {
        _currentDefaultFolder = 'Error loading default folder';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Folder Selection Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCurrentDefaultFolder,
            tooltip: 'Refresh default folder info',
          ),
        ],
      ),
      body: Column(
        children: [
          // Info card showing current default folder behavior
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📁 Mandatory Folder Selection Test',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '✅ Test Cases:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Folder field is always required (never null)\n'
                    '• Pre-populated with last selected folder\n' 
                    '• Falls back to "Personal" folder if first time\n'
                    '• Save button enabled when task title is entered\n'
                    '• Last selection is remembered for next time',
                  ),
                  const SizedBox(height: 12),
                  if (_currentDefaultFolder != null) ...[
                    const Text(
                      'Current Default Folder:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _currentDefaultFolder!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
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
                    icon: const Icon(Icons.add_task),
                    label: const Text('Test: Create New Todo'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _resetDefaultFolder(),
                    icon: const Icon(Icons.restore),
                    label: const Text('Reset: Clear Last Selected Folder'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _clearTestData(),
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear: Test Results'),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Results list
          Expanded(
            child: _testTodos.isEmpty
                ? const Center(
                    child: Text(
                      'No test todos created yet.\n\n'
                      '1. Tap "Test: Create New Todo"\n'
                      '2. Notice folder is pre-selected\n'
                      '3. Try different folders\n'
                      '4. Create multiple todos\n'
                      '5. See how last selection is remembered',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _testTodos.length,
                    itemBuilder: (context, index) {
                      final todo = _testTodos[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                          title: Text(todo.text),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (todo.notes?.isNotEmpty == true)
                                Text('Notes: ${todo.notes}'),
                              Row(
                                children: [
                                  Icon(
                                    Icons.folder,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Folder: ${todo.folderId ?? "No folder"}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: todo.folderId != null 
                                          ? Theme.of(context).colorScheme.primary
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              if (todo.dueDate != null)
                                Text('Due: ${_formatDate(todo.dueDate!)}'),
                              Text('Priority: ${todo.priority} | Category: ${todo.category}'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (todo.folderId != null)
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20,
                                )
                              else
                                Icon(
                                  Icons.error,
                                  color: Colors.red,
                                  size: 20,
                                ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20),
                                onPressed: () => _deleteTodo(index),
                              ),
                            ],
                          ),
                          isThreeLine: true,
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
      builder: (context) => AddTodoDialog(
        onAdd: (todo) {
          setState(() {
            _testTodos.add(todo);
          });
          
          // Refresh default folder info to show the update
          _loadCurrentDefaultFolder();
          
          // Show success message with folder info
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Todo "${todo.text}" created${todo.folderId != null ? ' in folder ${todo.folderId}' : ' without folder'}!',
              ),
              backgroundColor: todo.folderId != null ? Colors.green : Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        },
      ),
    );
  }

  Future<void> _resetDefaultFolder() async {
    // Clear the last selected folder preference
    await StorageService.setLastSelectedFolder('');
    
    // Reload the default folder info
    _loadCurrentDefaultFolder();
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔄 Last selected folder cleared. Next dialog will use "Personal" folder.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _clearTestData() {
    setState(() {
      _testTodos.clear();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🗑️ All test todos cleared'),
        duration: Duration(seconds: 1),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
