// Trudido - A privacy-focused todo and notes app
// Copyright (C) 2025 Dominik Müller
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
import '../models/folder.dart';
import '../services/folder_provider.dart';
import '../screens/folder_management_screen.dart';
import '../theme/spacing_tokens.dart';
import '../widgets/common/common.dart';

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
          ExpressiveIconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FolderManagementScreen(),
                ),
              );
            },
            icon: Icon(Icons.settings),
            tooltip: 'Manage folders',
          ),
        ],
      ),
      body: foldersAsync.when(
        data: (folders) => ListView(
          padding: SpacingEdgeInsets.insets16,
          children: [
            // All folders option
            _FolderTile(
              folder: null,
              isSelected: selectedFolderId == null,
              onTap: () {
                ref.read(selectedFolderProvider.notifier).update(null);
                Navigator.pop(context);
              },
            ),
            SpacingGap.gapV8,

            // Individual folders
            ...folders.map(
              (folder) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _FolderTile(
                  folder: folder,
                  isSelected: selectedFolderId == folder.id,
                  onTap: () {
                    ref.read(selectedFolderProvider.notifier).update(folder.id);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),

            const SizedBox(height: 32),

            ExpressiveOutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FolderManagementScreen(),
                  ),
                );
              },
              icon: Icon(Icons.add),
              label: const Text('Create New Folder'),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning, color: theme.colorScheme.error, size: 48),
              SpacingGap.gapV16,
              Text('Error loading folders', style: theme.textTheme.titleMedium),
              SpacingGap.gapV8,
              ExpressiveElevatedButton(
                onPressed: () =>
                    ref.read(folderNotifierProvider.notifier).loadFolders(),
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
      borderRadius: SpacingBorderRadius.md,
      child: ExpressiveInkWell(
        borderRadius: SpacingBorderRadius.md,
        onTap: onTap,
        child: Container(
          padding: SpacingEdgeInsets.insets16,
          decoration: BoxDecoration(
            borderRadius: SpacingBorderRadius.md,
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withAlpha(51),
              width: isSelected ? 2 : 1,
            ),
            color: isSelected ? theme.colorScheme.primary.withAlpha(13) : null,
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
                  isAllFolders ? Icons.folder : _getIconData(folder!.icon),
                  color: isAllFolders
                      ? theme.colorScheme.primary
                      : Color(folder!.color),
                  size: 20,
                ),
              ),

              SpacingGap.gapH16,

              // Folder info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAllFolders ? 'All Folders' : folder!.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isSelected ? theme.colorScheme.primary : null,
                      ),
                    ),
                    if (!isAllFolders &&
                        folder!.description?.isNotEmpty == true) ...[
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
                Icon(Icons.done, color: theme.colorScheme.primary, size: 20),
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
