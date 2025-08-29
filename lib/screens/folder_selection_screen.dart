import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/folder.dart';
import '../services/folder_provider.dart';
import '../screens/folder_management_screen.dart';

class FolderSelectionScreen extends ConsumerWidget {
  const FolderSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(folderNotifierProvider);
    final selectedFolderId = ref.watch(selectedFolderProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Folder'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FolderManagementScreen(),
                ),
              );
            },
            icon: Icon(PhosphorIcons.gear()),
            tooltip: 'Manage folders',
          ),
        ],
      ),
      body: foldersAsync.when(
        data: (folders) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // All folders option
            _FolderTile(
              folder: null,
              isSelected: selectedFolderId == null,
              onTap: () {
                ref.read(selectedFolderProvider.notifier).state = null;
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
            
            // Individual folders
            ...folders.map((folder) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _FolderTile(
                folder: folder,
                isSelected: selectedFolderId == folder.id,
                onTap: () {
                  ref.read(selectedFolderProvider.notifier).state = folder.id;
                  Navigator.pop(context);
                },
              ),
            )),
            
            const SizedBox(height: 32),
            
            // Create new folder button
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FolderManagementScreen(),
                  ),
                );
              },
              icon: Icon(PhosphorIcons.plus()),
              label: const Text('Create New Folder'),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PhosphorIcons.warning(),
                color: theme.colorScheme.error,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading folders',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.read(folderNotifierProvider.notifier).loadFolders(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  final Folder? folder;
  final bool isSelected;
  final VoidCallback onTap;

  const _FolderTile({
    required this.folder,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAllFolders = folder == null;
    
    return Material(
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected 
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withAlpha(51),
              width: isSelected ? 2 : 1,
            ),
            color: isSelected 
              ? theme.colorScheme.primary.withAlpha(13)
              : null,
          ),
          child: Row(
            children: [
              // Folder icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isAllFolders
                      ? theme.colorScheme.primary.withAlpha(51)
                      : Color(folder!.color).withAlpha(51),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isAllFolders
                      ? PhosphorIcons.folders()
                      : _getIconData(folder!.icon),
                  color: isAllFolders
                      ? theme.colorScheme.primary
                      : Color(folder!.color),
                  size: 20,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Folder info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAllFolders ? 'All Folders' : folder!.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? theme.colorScheme.primary : null,
                      ),
                    ),
                    if (!isAllFolders && folder!.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        folder!.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(153),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              
              // Selection indicator
              if (isSelected)
                Icon(
                  PhosphorIcons.check(),
                  color: theme.colorScheme.primary,
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
