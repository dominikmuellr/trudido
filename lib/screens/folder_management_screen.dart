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
import '../services/folder_provider.dart';
import '../widgets/create_folder_dialog.dart';
import '../widgets/edit_folder_dialog.dart';
import '../use_cases/folder_use_cases.dart';
import '../theme/spacing_tokens.dart';
import '../widgets/common/common.dart';

class FolderManagementScreen extends ConsumerStatefulWidget {
  const FolderManagementScreen({super.key});

  @override
  ConsumerState<FolderManagementScreen> createState() =>
      _FolderManagementScreenState();
}

class _FolderManagementScreenState
    extends ConsumerState<FolderManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final foldersAsync = ref.watch(folderNotifierProvider);
    final foldersWithCounts = ref.watch(foldersWithTaskCountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Folders'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: foldersAsync.when(
        data: (folders) {
          if (folders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  SpacingGap.gapV16,
                  Text(
                    'No folders yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  SpacingGap.gapV8,
                  const Text('Create a folder to organize your tasks'),
                  SpacingGap.gapV24,
                  FilledButton.icon(
                    onPressed: () => _showCreateFolderDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Folder'),
                  ),
                ],
              ),
            );
          }

          return foldersWithCounts.when(
            data: (foldersWithTaskCounts) {
              // Create a map for quick lookup of task counts
              final taskCountMap = <String, int>{};
              for (final folderWithCount in foldersWithTaskCounts) {
                taskCountMap[folderWithCount.folder.id] =
                    folderWithCount.taskCount;
              }

              return ListView.builder(
                padding: SpacingEdgeInsets.insets16,
                itemCount: folders.length,
                itemBuilder: (context, index) {
                  final folder = folders[index];
                  final taskCount = taskCountMap[folder.id] ?? 0;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Icon(
                        _getIconData(folder.icon ?? 'folder'),
                        color: Color(folder.color),
                        size: 32,
                      ),
                      title: Text(
                        folder.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (folder.description != null &&
                              folder.description!.isNotEmpty)
                            Text(folder.description!),
                          Text(
                            '$taskCount ${taskCount == 1 ? 'task' : 'tasks'}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _showEditFolderDialog(context, folder),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ExpressiveIconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () =>
                                _showEditFolderDialog(context, folder),
                            tooltip: 'Edit folder',
                          ),
                          ExpressiveIconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteFolder(folder.id),
                            tooltip: 'Delete folder',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) =>
                Center(child: Text('Error loading task counts: $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              SpacingGap.gapV16,
              Text('Error loading folders'),
              SpacingGap.gapV8,
              FilledButton(
                onPressed: () => ref.refresh(folderNotifierProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: ExpressiveFloatingActionButton(
        onPressed: () => _showCreateFolderDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'work':
        return Icons.work;
      case 'home':
        return Icons.home;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'favorite':
        return Icons.favorite;
      case 'school':
        return Icons.school;
      case 'folder':
      default:
        return Icons.folder;
    }
  }

  void _showCreateFolderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateFolderDialog(),
    );
  }

  void _showEditFolderDialog(BuildContext context, folder) {
    showDialog(
      context: context,
      builder: (context) => EditFolderDialog(folder: folder),
    );
  }

  void _deleteFolder(String folderId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: const Text(
          'Are you sure you want to delete this folder? '
          'Tasks in this folder will be moved to the default folder.',
        ),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ExpressiveTextButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await ref
                  .read(folderNotifierProvider.notifier)
                  .deleteFolder(folderId);

              if (result is FolderDeletionFailure && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result.message),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
            style: ExpressiveTextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
