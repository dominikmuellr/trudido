import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/folder_template.dart';
import '../services/template_provider.dart';
import '../widgets/template_editor_dialog.dart';
import '../widgets/template_item.dart';

class TemplateManagementScreen extends ConsumerStatefulWidget {
  const TemplateManagementScreen({super.key});

  @override
  ConsumerState<TemplateManagementScreen> createState() => _TemplateManagementScreenState();
}

class _TemplateManagementScreenState extends ConsumerState<TemplateManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Template Management'),
        elevation: 0,
        // Ensure proper spacing for back button
        leadingWidth: 56, // Standard leading width
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112), // Increased for better spacing
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0), // Add bottom padding
            child: Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 12.0), // Better spacing
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search templates...',
                      prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),
              // Tab bar
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'All Templates'),
                  Tab(text: 'Built-in'),
                  Tab(text: 'Custom'),
                ],
              ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTemplateList(_getAllTemplates()),
          _buildTemplateList(_getBuiltInTemplates()),
          _buildTemplateList(_getCustomTemplates()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNewTemplate(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTemplateList(AsyncValue<List<FolderTemplate>> templatesAsync) {
    return templatesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error loading templates: $error'),
      ),
      data: (templates) {
        final filteredTemplates = _filterTemplates(templates);

        if (filteredTemplates.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredTemplates.length,
          itemBuilder: (context, index) {
            final template = filteredTemplates[index];
            return TemplateItem(
              template: template,
              onTap: () => _editTemplate(template),
              onUse: () => _useTemplate(template),
              onDuplicate: () => _duplicateTemplate(template),
              onDelete: template.isBuiltIn ? null : () => _deleteTemplate(template),
              onReset: (template.isBuiltIn && template.isCustomized) 
                  ? () => _resetTemplate(template) 
                  : null,
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_copy_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'No templates found'
                : 'No templates match your search',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          if (_searchQuery.isEmpty) ...[
            Text(
              'Create your first custom template',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _createNewTemplate,
              icon: const Icon(Icons.add),
              label: const Text('Create Template'),
            ),
          ],
        ],
      ),
    );
  }

  List<FolderTemplate> _filterTemplates(List<FolderTemplate> templates) {
    if (_searchQuery.isEmpty) return templates;
    
    return templates.where((template) {
      final query = _searchQuery.toLowerCase();
      return template.name.toLowerCase().contains(query) ||
             template.description?.toLowerCase().contains(query) == true ||
             template.keywords.any((keyword) => keyword.toLowerCase().contains(query));
    }).toList();
  }

  AsyncValue<List<FolderTemplate>> _getAllTemplates() {
    return ref.watch(templateNotifierProvider);
  }

  AsyncValue<List<FolderTemplate>> _getBuiltInTemplates() {
    final templatesAsync = ref.watch(templateNotifierProvider);
    return templatesAsync.when(
      loading: () => const AsyncValue.loading(),
      error: (error, stack) => AsyncValue.error(error, stack),
      data: (templates) {
        final builtInTemplates = templates.where((t) => t.isBuiltIn).toList();
        return AsyncValue.data(builtInTemplates);
      },
    );
  }

  AsyncValue<List<FolderTemplate>> _getCustomTemplates() {
    final templatesAsync = ref.watch(templateNotifierProvider);
    return templatesAsync.when(
      loading: () => const AsyncValue.loading(),
      error: (error, stack) => AsyncValue.error(error, stack),
      data: (templates) {
        final customTemplates = templates.where((t) => !t.isBuiltIn).toList();
        return AsyncValue.data(customTemplates);
      },
    );
  }

  void _createNewTemplate() {
    showDialog(
      context: context,
      builder: (context) => TemplateEditorDialog(
        onSave: (template) {
          ref.read(templateNotifierProvider.notifier).createTemplate(template);
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Template "${template.name}" created')),
          );
        },
      ),
    );
  }

  void _editTemplate(FolderTemplate template) {
    showDialog(
      context: context,
      builder: (context) => TemplateEditorDialog(
        template: template,
        onSave: (updatedTemplate) {
          ref.read(templateNotifierProvider.notifier).updateTemplate(updatedTemplate);
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Template "${updatedTemplate.name}" updated')),
          );
        },
      ),
    );
  }

  void _useTemplate(FolderTemplate template) {
    // This would trigger the template usage (create folder with tasks)
    ref.read(templateNotifierProvider.notifier).incrementUsage(template.id);
    Navigator.of(context).pop(template); // Return template to caller
  }

  void _duplicateTemplate(FolderTemplate template) {
    final duplicatedTemplate = FolderTemplate(
      name: '${template.name} (Copy)',
      description: template.description,
      keywords: template.keywords,
      taskTemplates: template.taskTemplates,
      category: template.category,
      isBuiltIn: false, // Duplicates are always custom
    );
    
    ref.read(templateNotifierProvider.notifier).createTemplate(duplicatedTemplate);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Template "${duplicatedTemplate.name}" created')),
    );
  }

  void _deleteTemplate(FolderTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Are you sure you want to delete "${template.name}"?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(templateNotifierProvider.notifier).deleteTemplate(template.id);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Template "${template.name}" deleted')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _resetTemplate(FolderTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Template'),
        content: Text('Reset "${template.name}" to its original built-in version?\n\nYour customizations will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(templateNotifierProvider.notifier).resetTemplate(template.id);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Template "${template.name}" reset to original')),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
