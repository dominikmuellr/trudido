import 'package:flutter/material.dart';
import '../models/folder.dart';

class FolderItem extends StatelessWidget {
  final Folder folder;
  final int taskCount;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const FolderItem({
    super.key,
    required this.folder,
    required this.taskCount,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Folder icon with color
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(folder.color).withAlpha(51),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        _getIconData(folder.icon),
                        color: Color(folder.color),
                        size: 24,
                      ),
                    ),
                    if (folder.isVault)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.lock,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Folder details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            folder.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (folder.isVault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withAlpha(51),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock,
                                  size: 12,
                                  color: Colors.amber.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Vault',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.amber.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (folder.isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withAlpha(26),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Default',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    if (folder.description != null &&
                        folder.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        folder.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(179),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Task count and actions
                    Row(
                      children: [
                        Icon(
                          Icons.checklist,
                          size: 16,
                          color: theme.colorScheme.onSurface.withAlpha(153),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$taskCount ${taskCount == 1 ? 'task' : 'tasks'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(153),
                          ),
                        ),
                        const Spacer(),

                        // Action buttons
                        if (onEdit != null) ...[
                          IconButton(
                            onPressed: onEdit,
                            icon: Icon(Icons.edit),
                            iconSize: 18,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            tooltip: 'Edit folder',
                          ),
                        ],

                        if (onDelete != null) ...[
                          IconButton(
                            onPressed: onDelete,
                            icon: Icon(Icons.delete),
                            iconSize: 18,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            style: IconButton.styleFrom(
                              foregroundColor: theme.colorScheme.error,
                            ),
                            tooltip: 'Delete folder',
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Drag handle
              const SizedBox(width: 8),
              Icon(
                Icons.drag_handle,
                color: theme.colorScheme.onSurface.withAlpha(102),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'person':
        return Icons.person;
      case 'work':
        return Icons.work;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'home':
        return Icons.home;
      case 'school':
        return Icons.school;
      case 'health':
        return Icons.favorite;
      case 'travel':
        return Icons.flight;
      case 'finance':
        return Icons.savings;
      case 'hobby':
        return Icons.games;
      case 'fitness':
        return Icons.fitness_center;
      default:
        return Icons.folder;
    }
  }
}
