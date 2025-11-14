import 'package:flutter/material.dart';
import '../models/folder_template.dart';

class TemplateEditorDialog extends StatefulWidget {
  final FolderTemplate? template;
  final Function(FolderTemplate) onSave;

  const TemplateEditorDialog({super.key, this.template, required this.onSave});

  @override
  State<TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<TemplateEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  List<String> _keywords = [];
  List<TaskTemplateData> _tasks = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.template?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.template?.description ?? '',
    );
    _keywords = List.from(widget.template?.keywords ?? []);

    _tasks =
        widget.template?.taskTemplates
            .map(
              (t) => TaskTemplateData(
                text: t.text,
                priority: t.priority,
                notes: t.notes ?? '',
              ),
            )
            .toList() ??
        [];

    if (_tasks.isEmpty) {
      _tasks.add(TaskTemplateData());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  widget.template == null ? 'Create Template' : 'Edit Template',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Template Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a template name';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),

                      const SizedBox(height: 24),

                      Text(
                        'Keywords (for auto-suggestions)',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      _buildKeywordsSection(),

                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Text(
                            'Tasks',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _tasks.add(TaskTemplateData());
                              });
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Task'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildTasksSection(),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: _isLoading ? null : _saveTemplate,
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Template'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeywordsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._keywords.map(
              (keyword) => Chip(
                label: Text(keyword),
                onDeleted: () {
                  setState(() {
                    _keywords.remove(keyword);
                  });
                },
              ),
            ),
            ActionChip(
              label: const Text('+ Add Keyword'),
              onPressed: () => _addKeywordDialog(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Keywords help the app suggest this template when users create folders with similar names',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildTasksSection() {
    return Column(
      children: _tasks.asMap().entries.map((entry) {
        final index = entry.key;
        final task = entry.value;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Task ${index + 1}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (_tasks.length > 1)
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _tasks.removeAt(index);
                          });
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: task.text,
                  decoration: const InputDecoration(
                    labelText: 'Task Description',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => task.text = value,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a task description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: task.priority,
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                          border: OutlineInputBorder(),
                        ),
                        items: ['low', 'medium', 'high']
                            .map(
                              (priority) => DropdownMenuItem(
                                value: priority,
                                child: Text(priority.toUpperCase()),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => task.priority = value ?? 'medium',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: task.notes,
                        decoration: const InputDecoration(
                          labelText: 'Notes (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => task.notes = value,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _addKeywordDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Keyword'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter keyword (e.g., "project", "shopping")',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final keyword = controller.text.trim().toLowerCase();
              if (keyword.isNotEmpty && !_keywords.contains(keyword)) {
                setState(() {
                  _keywords.add(keyword);
                });
              }
              Navigator.of(context).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _saveTemplate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tasks.where((t) => t.text.trim().isNotEmpty).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one task')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final validTasks = _tasks.where((t) => t.text.trim().isNotEmpty).toList();

      final template = FolderTemplate(
        id: widget.template?.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        keywords: _keywords,
        taskTemplates: validTasks.asMap().entries.map((entry) {
          final task = entry.value;
          return TaskTemplate(
            text: task.text.trim(),
            priority: task.priority,
            notes: task.notes.isEmpty ? null : task.notes,
            sortOrder: entry.key,
          );
        }).toList(),
        isBuiltIn: widget.template?.isBuiltIn ?? false,
        useCount: widget.template?.useCount ?? 0,
      );

      widget.onSave(template);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class TaskTemplateData {
  String text;
  String priority;
  String notes;

  TaskTemplateData({this.text = '', this.priority = 'medium', this.notes = ''});
}
