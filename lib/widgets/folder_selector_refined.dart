import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/folder_provider.dart';
import '../screens/folder_selection_screen.dart';

class FolderSelector extends ConsumerStatefulWidget {
  const FolderSelector({super.key});

  @override
  ConsumerState<FolderSelector> createState() => _FolderSelectorState();
}

class _FolderSelectorState extends ConsumerState<FolderSelector> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foldersAsync = ref.watch(folderNotifierProvider);
    final selectedFolderId = ref.watch(selectedFolderProvider);
    final theme = Theme.of(context);

    return foldersAsync.when(
      data: (folders) {
        // Create list with "All folders" option at the beginning
        final allOptions = [null, ...folders];

        // Find current index based on selected folder
        final selectedIndex = selectedFolderId == null
            ? 0
            : allOptions.indexWhere((folder) => folder?.id == selectedFolderId);

        // Update page controller if selection changed externally
        if (selectedIndex != -1 && selectedIndex != _currentIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients) {
              _currentIndex = selectedIndex;
              _pageController.animateToPage(
                selectedIndex,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          });
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FolderSelectionScreen(),
              ),
            );
          },
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: allOptions.isEmpty
                  ? Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withAlpha(51),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.folder,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'No folders available',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: theme.colorScheme.onSurface.withAlpha(128),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        // Swipeable folder display
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: (index) {
                              setState(() {
                                _currentIndex = index;
                              });

                              // Update selected folder
                              final folder = allOptions[index];
                              ref.read(selectedFolderProvider.notifier).state =
                                  folder?.id;
                            },
                            itemCount: allOptions.length,
                            itemBuilder: (context, index) {
                              final folder = allOptions[index];
                              final isAllFolders = folder == null;

                              return Row(
                                children: [
                                  // Folder icon
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isAllFolders
                                          ? theme.colorScheme.primary.withAlpha(
                                              51,
                                            )
                                          : Color(folder.color).withAlpha(51),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isAllFolders
                                          ? Icons.folder
                                          : _getIconData(folder.icon),
                                      color: isAllFolders
                                          ? theme.colorScheme.primary
                                          : Color(folder.color),
                                      size: 24,
                                    ),
                                  ),

                                  const SizedBox(width: 16),

                                  // Folder info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          isAllFolders
                                              ? 'All Folders'
                                              : folder.name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isAllFolders
                                              ? 'View all your todos'
                                              : (folder
                                                            .description
                                                            ?.isNotEmpty ==
                                                        true
                                                    ? folder.description!
                                                    : 'Folder todos'),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.colorScheme.onSurface
                                                .withAlpha(153),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),

                        // Navigation indicator and tap hint
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (allOptions.length > 1) ...[
                              // Page indicator dots
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(
                                  allOptions.length,
                                  (index) => Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: index == _currentIndex
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface
                                                .withAlpha(77),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],

                            // Tap to select icon
                            Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: theme.colorScheme.onSurface.withAlpha(128),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
      loading: () => Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(51),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Text('Loading folders...', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
      error: (error, stack) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.warning, color: theme.colorScheme.error, size: 24),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Error loading folders',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              TextButton(
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
