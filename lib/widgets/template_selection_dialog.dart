import 'package:flutter/material.dart';
import '../models/folder_template.dart';

class TemplateSelectionDialog extends StatelessWidget {
  final List<FolderTemplate> suggestedTemplates;
  final String folderName;
  final VoidCallback onSkip;
  final Function(FolderTemplate) onSelectTemplate;

  const TemplateSelectionDialog({
    super.key,
    required this.suggestedTemplates,
    required this.folderName,
    required this.onSkip,
    required this.onSelectTemplate,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Template Suggestion',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'I noticed your folder "$folderName" looks like a project! Would you like to use a template to get started?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Available Templates:',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...suggestedTemplates.map(
              (template) => _buildTemplateOption(context, template),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: onSkip, child: const Text('Skip'))],
    );
  }

  Widget _buildTemplateOption(BuildContext context, FolderTemplate template) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onSelectTemplate(template),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.folder_copy_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      template.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${template.taskTemplates.length} tasks',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              if (template.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  template.description!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withOpacity(0.9),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Tasks: ${template.taskTemplates.take(3).map((t) => t.text).join(', ')}${template.taskTemplates.length > 3 ? '...' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withOpacity(0.85),
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
