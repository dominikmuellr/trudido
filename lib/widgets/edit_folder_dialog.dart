import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/folder.dart';
import '../services/folder_provider.dart';
import '../use_cases/folder_use_cases.dart';

class EditFolderDialog extends ConsumerStatefulWidget {
  final Folder folder;

  const EditFolderDialog({super.key, required this.folder});

  @override
  ConsumerState<EditFolderDialog> createState() => _EditFolderDialogState();
}

class _EditFolderDialogState extends ConsumerState<EditFolderDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  late String _selectedIcon;
  late int _selectedColor;
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
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.folder.name);
    _descriptionController = TextEditingController(
      text: widget.folder.description ?? '',
    );
    _selectedIcon = widget.folder.icon ?? 'folder';
    _selectedColor = widget.folder.color;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Edit Folder'),
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
                                ? Color(_selectedColor).withAlpha(51)
                                : theme.colorScheme.surface,
                            border: Border.all(
                              color: isSelected
                                  ? Color(_selectedColor)
                                  : theme.colorScheme.outline.withAlpha(77),
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            iconData['icon'],
                            color: isSelected
                                ? Color(_selectedColor)
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
          onPressed: _isLoading ? null : _updateFolder,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _updateFolder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ref
          .read(folderNotifierProvider.notifier)
          .updateFolder(
            folderId: widget.folder.id,
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            color: _selectedColor,
            icon: _selectedIcon,
            isVault: false, // Todo folders don't support vault encryption
          );

      if (mounted) {
        if (result is FolderUpdateSuccess) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Folder "${result.folder.name}" updated successfully',
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        } else if (result is FolderUpdateFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
