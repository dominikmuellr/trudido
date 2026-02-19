// Trudido - A privacy-focused todo and notes app
// Copyright (C) 2026 Dominik Müller
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/folder_template.dart';
import '../services/template_provider.dart';
import '../widgets/template_editor_dialog.dart';
import '../widgets/common/common.dart';

class TemplateManagementScreen extends ConsumerStatefulWidget {
  const TemplateManagementScreen({super.key});

  @override
  ConsumerState<TemplateManagementScreen> createState() =>
      _TemplateManagementScreenState();
}

class _TemplateManagementScreenState
    extends ConsumerState<TemplateManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final templatesAsync = ref.watch(templateNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Folder Templates')),
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text('Error loading templates: $error'),
            ],
          ),
        ),
        data: (allTemplates) {
          final builtInTemplates = allTemplates
              .where((t) => t.isBuiltIn)
              .toList();
          final customTemplates = allTemplates
              .where((t) => !t.isBuiltIn)
              .toList();

          return ListView(
            children: [
              // Header description
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Templates help you quickly create folders with pre-configured tasks.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

              // Built-in templates
              if (builtInTemplates.isNotEmpty) ...[
                _buildSectionHeader(context, 'Built-in Templates'),
                ...builtInTemplates.map(
                  (template) =>
                      _buildTemplateListTile(context, template, colorScheme),
                ),
              ],

              // Custom templates
              if (customTemplates.isNotEmpty) ...[
                _buildSectionHeader(context, 'Custom Templates'),
                ...customTemplates.map(
                  (template) =>
                      _buildTemplateListTile(context, template, colorScheme),
                ),
              ],

              // Empty state for custom templates
              if (customTemplates.isEmpty) ...[
                _buildSectionHeader(context, 'Custom Templates'),
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.folder_copy_outlined,
                          size: 48,
                          color: colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No custom templates yet',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create templates to organize your workflows',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
      floatingActionButton: ExpressiveFloatingActionButton.extended(
        onPressed: _createNewTemplate,
        icon: const Icon(Icons.add),
        label: const Text('New Template'),
      ),
    );
  }

  Widget _buildTemplateListTile(
    BuildContext context,
    FolderTemplate template,
    ColorScheme colorScheme,
  ) {
    final isCustomized = template.isBuiltIn && template.isCustomized;

    return ListTile(
      leading: Icon(
        template.isBuiltIn
            ? Icons.folder_special_outlined
            : Icons.folder_outlined,
        color: template.isBuiltIn ? colorScheme.tertiary : colorScheme.primary,
      ),
      title: Row(
        children: [
          Expanded(child: Text(template.name)),
          if (isCustomized)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Chip(label: const Text('Modified')),
            ),
        ],
      ),
      subtitle: Text(
        template.description ?? '${template.taskTemplates.length} tasks',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) {
          switch (value) {
            case 'edit':
              _editTemplate(template);
              break;
            case 'duplicate':
              _duplicateTemplate(template);
              break;
            case 'reset':
              _resetTemplate(template);
              break;
            case 'delete':
              _deleteTemplate(template);
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 20),
                SizedBox(width: 12),
                Text('Edit'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'duplicate',
            child: Row(
              children: [
                Icon(Icons.content_copy_outlined, size: 20),
                SizedBox(width: 12),
                Text('Duplicate'),
              ],
            ),
          ),
          if (isCustomized)
            const PopupMenuItem(
              value: 'reset',
              child: Row(
                children: [
                  Icon(Icons.restore_outlined, size: 20),
                  SizedBox(width: 12),
                  Text('Reset to Default'),
                ],
              ),
            ),
          if (!template.isBuiltIn)
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 20),
                  SizedBox(width: 12),
                  Text('Delete'),
                ],
              ),
            ),
        ],
      ),
      onTap: () => _editTemplate(template),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
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
          ref
              .read(templateNotifierProvider.notifier)
              .updateTemplate(updatedTemplate);
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Template "${updatedTemplate.name}" updated'),
            ),
          );
        },
      ),
    );
  }

  void _duplicateTemplate(FolderTemplate template) {
    final duplicatedTemplate = FolderTemplate(
      name: '${template.name} (Copy)',
      description: template.description,
      keywords: template.keywords,
      taskTemplates: template.taskTemplates,
      isBuiltIn: false, // Duplicates are always custom
    );

    ref
        .read(templateNotifierProvider.notifier)
        .createTemplate(duplicatedTemplate);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Template "${duplicatedTemplate.name}" created')),
    );
  }

  void _deleteTemplate(FolderTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text(
          'Are you sure you want to delete "${template.name}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(templateNotifierProvider.notifier)
                  .deleteTemplate(template.id);
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
        content: Text(
          'Reset "${template.name}" to its original built-in version?\n\nYour customizations will be lost.',
        ),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(templateNotifierProvider.notifier)
                  .resetTemplate(template.id);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Template "${template.name}" reset to original',
                  ),
                ),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
