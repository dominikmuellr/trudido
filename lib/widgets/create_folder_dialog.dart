import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/folder_provider.dart';
import '../services/template_provider.dart';
import '../providers/app_providers.dart';
import '../use_cases/folder_use_cases.dart';
import '../widgets/template_selection_dialog.dart';

class CreateFolderDialog extends ConsumerStatefulWidget {
  const CreateFolderDialog({super.key});

  @override
  ConsumerState<CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends ConsumerState<CreateFolderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedIcon = 'folder';
  int? _selectedColor; // Will initialize from theme primary on first build
  bool _isLoading = false;

  final List<Map<String, dynamic>> _availableIcons = [
    {'name': 'folder', 'icon': Icons.folder, 'label': 'Folder'},
    {'name': 'person', 'icon': Icons.person, 'label': 'Personal'},
    {'name': 'work', 'icon': Icons.work, 'label': 'Work'},
    {'name': 'shopping_cart', 'icon': Icons.shopping_cart, 'label': 'Shopping'},
    {'name': 'home', 'icon': Icons.home, 'label': 'Home'},
    {'name': 'school', 'icon': Icons.school, 'label': 'Education'},
    {'name': 'health', 'icon': Icons.favorite, 'label': 'Health'},
    {'name': 'travel', 'icon': Icons.flight, 'label': 'Travel'},
    {'name': 'finance', 'icon': Icons.savings, 'label': 'Finance'},
    {'name': 'hobby', 'icon': Icons.games, 'label': 'Hobby'},
    {'name': 'fitness', 'icon': Icons.fitness_center, 'label': 'Fitness'},
  ];

  final List<int> _availableColors = [
    0xFF2196F3, // Blue
    0xFF4CAF50, // Green
    0xFFFF9800, // Orange
    0xFFF44336, // Red
    0xFF9C27B0, // Purple
    0xFF00BCD4, // Cyan
    0xFFFFEB3B, // Yellow
    0xFF795548, // Brown
    0xFF607D8B, // Blue Grey
    0xFFE91E63, // Pink
    0xFF3F51B5, // Indigo
    0xFF009688, // Teal
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Use toARGB32() instead of deprecated .value access for color raw int.
    _selectedColor ??= theme.colorScheme.primary.toARGB32();

    return AlertDialog(
      title: const Text('Create Folder'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Folder name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Folder Name',
                    hintText: 'Enter folder name',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a folder name';
                    }
                    if (value.trim().length > 50) {
                      return 'Folder name cannot exceed 50 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Description (optional)
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Enter folder description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),

                const SizedBox(height: 20),

                // Icon selection
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Icon',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
                  child: GridView.builder(
                    scrollDirection: Axis.horizontal,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: _availableIcons.length,
                    itemBuilder: (context, index) {
                      final iconData = _availableIcons[index];
                      final isSelected = _selectedIcon == iconData['name'];

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedIcon = iconData['name'];
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Color(_selectedColor!).withAlpha(51)
                                : theme.colorScheme.surface,
                            border: Border.all(
                              color: isSelected
                                  ? Color(_selectedColor!)
                                  : theme.colorScheme.outline.withAlpha(77),
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            iconData['icon'],
                            color: isSelected
                                ? Color(_selectedColor!)
                                : theme.colorScheme.onSurface.withAlpha(179),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Color selection
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Color',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _availableColors.length,
                    itemBuilder: (context, index) {
                      final color = _availableColors[index];
                      final isSelected = _selectedColor == color;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedColor = color;
                            });
                          },
                          borderRadius: BorderRadius.circular(25),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Color(color),
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(
                                      color: theme.colorScheme.onSurface,
                                      width: 3,
                                    )
                                  : null,
                            ),
                            child: isSelected
                                ? Icon(
                                    Icons.done,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createFolder,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _createFolder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // First check for template suggestions
      final folderName = _nameController.text.trim();
      await _checkForTemplatesSuggestions(folderName);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkForTemplatesSuggestions(String folderName) async {
    try {
      // Get template suggestions based on folder name
      final suggestUseCase = ref.read(suggestTemplatesUseCaseProvider);
      final suggestions = await suggestUseCase(folderName);

      if (mounted && suggestions.isNotEmpty) {
        // Show template suggestion dialog
        await _showTemplateSuggestion(folderName, suggestions);
      } else {
        // No suggestions, create folder normally
        await _createFolderDirectly(folderName);
      }
    } catch (e) {
      // If template suggestion fails, just create folder normally
      await _createFolderDirectly(folderName);
    }
  }

  Future<void> _showTemplateSuggestion(
    String folderName,
    List suggestions,
  ) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TemplateSelectionDialog(
        suggestedTemplates: suggestions.cast(),
        folderName: folderName,
        onSkip: () {
          Navigator.of(context).pop();
          _createFolderDirectly(folderName);
        },
        onSelectTemplate: (template) async {
          Navigator.of(context).pop();
          await _createFolderWithTemplate(folderName, template);
        },
      ),
    );
  }

  Future<void> _createFolderDirectly(String folderName) async {
    final result = await ref
        .read(folderNotifierProvider.notifier)
        .createFolder(
          name: folderName,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          color: _selectedColor!,
          icon: _selectedIcon,
          isVault: false, // Todo folders don't support vault encryption
        );

    if (mounted) {
      if (result is FolderCreationSuccess) {
        // Select the newly created folder so the task list shows its contents
        ref.read(selectedFolderProvider.notifier).state = result.folder.id;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Folder "$folderName" created successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      } else if (result is FolderCreationFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _createFolderWithTemplate(String folderName, template) async {
    // Create folder first
    final result = await ref
        .read(folderNotifierProvider.notifier)
        .createFolder(
          name: folderName,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          color: _selectedColor!,
          icon: _selectedIcon,
          isVault: false, // Todo folders don't support vault encryption
        );

    if (result is FolderCreationSuccess) {
      // Apply template to create tasks
      try {
        final applyUseCase = ref.read(applyTemplateUseCaseProvider);
        final createdTodos = await applyUseCase(template, result.folder.id);

        // Refresh the tasks provider to show new todos
        await ref.read(tasksProvider.notifier).refresh();
        // Select the newly created folder so the UI shows the new tasks
        ref.read(selectedFolderProvider.notifier).state = result.folder.id;

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Folder "$folderName" created with ${createdTodos.length} tasks from "${template.name}" template',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(milliseconds: 2500),
            ),
          );
        }
      } catch (e) {
        // Template application failed, but folder was created
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Folder "$folderName" created, but template application failed',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } else if (result is FolderCreationFailure) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
