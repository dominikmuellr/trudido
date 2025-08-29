import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
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
                child: Icon(
                  _getIconData(folder.icon),
                  color: Color(folder.color),
                  size: 24,
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
                    
                    if (folder.description != null && folder.description!.isNotEmpty) ...[
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
                          PhosphorIcons.listChecks(),
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
                            icon: Icon(PhosphorIcons.pencil()),
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
                            icon: Icon(PhosphorIcons.trash()),
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
                PhosphorIcons.dotsSixVertical(),
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
        return PhosphorIcons.user();
      case 'work':
        return PhosphorIcons.briefcase();
      case 'shopping_cart':
        return PhosphorIcons.shoppingCart();
      case 'home':
        return PhosphorIcons.house();
      case 'school':
        return PhosphorIcons.graduationCap();
      case 'health':
        return PhosphorIcons.heart();
      case 'travel':
        return PhosphorIcons.airplane();
      case 'finance':
        return PhosphorIcons.piggyBank();
      case 'hobby':
        return PhosphorIcons.gameController();
      case 'fitness':
        return PhosphorIcons.barbell();
      default:
        return PhosphorIcons.folder();
    }
  }
}
