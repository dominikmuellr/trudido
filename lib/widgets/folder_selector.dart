import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/folder_provider.dart';
import '../screens/folder_selection_screen.dart';
import '../services/theme_service.dart';

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
  final appOpts = theme.extension<AppOptions>() ?? const AppOptions(compact: false, highContrast: false);
  final cardHeight = appOpts.compact ? 64.0 : 80.0;
  final iconBox = appOpts.compact ? 40.0 : 48.0;
  final outerMarginV = appOpts.compact ? 4.0 : 8.0;
  final outerMarginH = 16.0;
  final horizPad = appOpts.compact ? 12.0 : 16.0;
  final vertPad = appOpts.compact ? 8.0 : 12.0;
  final titleSize = appOpts.compact ? 15.0 : 16.0;
  final descSize = appOpts.compact ? 11.0 : 12.0;

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
            margin: EdgeInsets.symmetric(horizontal: outerMarginH, vertical: outerMarginV),
            child: Container(
              height: cardHeight,
              padding: EdgeInsets.symmetric(horizontal: horizPad, vertical: vertPad),
              child: allOptions.isEmpty
                  ? Row(
                      children: [
                        Container(
                          width: iconBox,
                          height: iconBox,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withAlpha(51),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            PhosphorIcons.folders(),
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: appOpts.compact ? 12 : 16),
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
                          Icons.more_horiz,
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
                              ref.read(selectedFolderProvider.notifier).state = folder?.id;
                            },
                            itemCount: allOptions.length,
                            itemBuilder: (context, index) {
                              final folder = allOptions[index];
                              final isAllFolders = folder == null;
                              
                              return Row(
                                children: [
                                  // Folder icon
                                  Container(
                                    width: iconBox,
                                    height: iconBox,
                                    decoration: BoxDecoration(
                                      color: isAllFolders
                                          ? theme.colorScheme.primary.withAlpha(51)
                                          : Color(folder.color).withAlpha(51),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isAllFolders
                                          ? PhosphorIcons.folders()
                                          : _getIconData(folder.icon),
                                      color: isAllFolders
                                          ? theme.colorScheme.primary
                                          : Color(folder.color),
                                      size: 24,
                                    ),
                                  ),
                                  
                                  SizedBox(width: appOpts.compact ? 12 : 16),
                                  
                                  // Folder info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          isAllFolders ? 'All Folders' : folder.name,
                                          style: TextStyle(
                                            fontSize: titleSize,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: appOpts.compact ? 1 : 2),
                                        Text(
                                          isAllFolders 
                                              ? 'View all your todos'
                                              : (folder.description?.isNotEmpty == true
                                                  ? folder.description!
                                                  : 'Folder todos'),
                                          style: TextStyle(
                                            fontSize: descSize,
                                            color: theme.colorScheme.onSurface.withAlpha(153),
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
                                    margin: const EdgeInsets.symmetric(horizontal: 2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: index == _currentIndex
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface.withAlpha(77),
                                    ),
                                  ),
                                ),
                              ),
          SizedBox(height: appOpts.compact ? 2 : 4),
                            ],
                            
                            // Tap to select icon
                            Icon(
                              Icons.more_horiz,
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
    margin: EdgeInsets.symmetric(horizontal: outerMarginH, vertical: outerMarginV),
        child: Container(
      height: cardHeight,
      padding: EdgeInsets.symmetric(horizontal: horizPad, vertical: vertPad),
          child: Row(
            children: [
              Container(
        width: iconBox,
        height: iconBox,
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
              SizedBox(width: appOpts.compact ? 12 : 16),
              const Text(
                'Loading folders...',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
      error: (error, stack) => Card(
        margin: EdgeInsets.symmetric(horizontal: outerMarginH, vertical: outerMarginV),
        child: Container(
          height: cardHeight,
          padding: EdgeInsets.symmetric(horizontal: horizPad, vertical: vertPad),
          child: Row(
            children: [
              Icon(
                PhosphorIcons.warning(),
                color: theme.colorScheme.error,
                size: 24,
              ),
              SizedBox(width: appOpts.compact ? 12 : 16),
              const Expanded(
                child: Text(
                  'Error loading folders',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              TextButton(
                onPressed: () => ref.read(folderNotifierProvider.notifier).loadFolders(),
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
