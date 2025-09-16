import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import '../providers/filter_providers.dart';
import '../controllers/task_controller.dart';
import '../controllers/notes_controller.dart';
import '../providers/app_providers.dart';
import '../services/default_tab_service.dart';
import '../services/folder_provider.dart';
import '../screens/task_editor_screen.dart';
import '../widgets/todo_list_tab.dart';
import 'settings_screen.dart';
import 'notes_screen.dart';
import 'note_editor_screen.dart';

// Provider for tracking search mode state
final searchModeProvider = StateProvider<bool>((ref) => false);

// Provider for current tab index with default tab initialization
final currentTabProvider = StateNotifierProvider<CurrentTabNotifier, int>((ref) {
  return CurrentTabNotifier();
});

/// Notifier for managing current tab state with default tab support
class CurrentTabNotifier extends StateNotifier<int> {
  CurrentTabNotifier() : super(0) {
    _initializeDefaultTab();
  }

  /// Initialize with user's preferred default tab
  Future<void> _initializeDefaultTab() async {
    try {
      final defaultIndex = await DefaultTabService.getDefaultTabIndex();
      state = defaultIndex;
    } catch (e) {
      // If loading fails, stay with tasks (index 0)
      state = 0;
    }
  }

  /// Update current tab
  void setTab(int index) {
    state = index;
  }

  /// Reset to default tab
  Future<void> resetToDefault() async {
    final defaultIndex = await DefaultTabService.getDefaultTabIndex();
    state = defaultIndex;
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
  final currentTab = ref.watch(currentTabProvider);
  
  // Removed ambiguous loading heuristic that prevented legitimate empty state UI.
    
    // Define tabs
    final tabs = [
      const TodoListTab(),
      const NotesScreen(),
    ];
  return Scaffold(
      appBar: _buildAppBar(context),
      body: IndexedStack(
        index: currentTab,
        children: tabs,
      ),
      bottomNavigationBar: BottomAppBar(
          elevation: 0,
    color: Theme.of(context).scaffoldBackgroundColor,
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
              // Tasks tab
              Expanded(
                child: InkWell(
                  onTap: () => _onTabSelected(0),
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        currentTab == 0 
                          ? PhosphorIcons.listChecks(PhosphorIconsStyle.fill)
                          : PhosphorIcons.listChecks(),
                        color: currentTab == 0 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tasks',
                        style: TextStyle(
                          fontSize: 12,
                          color: currentTab == 0 
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: currentTab == 0 ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Space for FAB
              const SizedBox(width: 80),
              // Notes tab
              Expanded(
                child: InkWell(
                  onTap: () => _onTabSelected(1),
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        currentTab == 1 
                          ? PhosphorIcons.noteBlank(PhosphorIconsStyle.fill)
                          : PhosphorIcons.noteBlank(),
                        color: currentTab == 1 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Notes',
                        style: TextStyle(
                          fontSize: 12,
                          color: currentTab == 1 
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: currentTab == 1 ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: FloatingActionButton(
          heroTag: "main_fab", // Unique hero tag
          onPressed: () => _onFabPressed(currentTab),
          backgroundColor: _getFabColor(currentTab, Theme.of(context).colorScheme),
          elevation: 6.0,
          highlightElevation: 12.0,
          tooltip: _getFabTooltip(currentTab),
          child: _buildFabIcon(currentTab),
        ),
      ),
    );
  }

  void _onTabSelected(int index) {
    final previousTab = ref.read(currentTabProvider);
    ref.read(currentTabProvider.notifier).setTab(index);
    // Exit search mode when switching tabs
    final isSearchMode = ref.read(searchModeProvider);
    if (isSearchMode) {
      ref.read(searchModeProvider.notifier).state = false;
      _searchController.clear();
      if (previousTab == 0) {
        ref.read(searchQueryProvider.notifier).state = '';
      } else if (previousTab == 1) {
        ref.read(notesSearchQueryProvider.notifier).state = '';
      }
    }
  }

  void _onFabPressed(int currentTab) {
    switch (currentTab) {
      case 0: // Tasks tab
        _showAddTaskDialog();
        break;
      case 1: // Notes tab
        _createNewNote();
        break;
    }
  }

  void _showAddTaskDialog() {
    final viewType = ref.read(taskViewTypeProvider);
    final selectedDate = ref.read(selectedCalendarDateProvider);

    // Use selected calendar date as a preset only when in calendar view
    final DateTime? preset = (viewType == TaskViewType.calendar && selectedDate != null) ? selectedDate : null;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TaskEditorScreen(
          presetDueDate: preset,
          onSave: (todo) {
            ref.read(taskControllerProvider.notifier).add(todo);
          },
        ),
      ),
    );
  }

  void _createNewNote() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const NoteEditorScreen(),
      ),
    );
  }

  /// Builds the context-aware FAB icon with smooth transitions
  Widget _buildFabIcon(int currentTab) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400), // Slightly longer for more graceful feel
      transitionBuilder: (child, animation) {
        // Physics-based spring animation
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.elasticOut, // Spring physics feel
        );
        
        return RotationTransition(
          turns: Tween<double>(
            begin: 0.0,
            end: 0.125, // 45 degrees rotation during transition
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic, // Smoother rotation curve
          )),
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.6, // Start smaller for more dramatic effect
              end: 1.0,
            ).animate(curvedAnimation),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          ),
        );
      },
      child: Icon(
        _getIconForTab(currentTab),
        key: ValueKey(currentTab), // Important for AnimatedSwitcher to detect changes
        size: 24,
      ),
    );
  }

  /// Returns the appropriate icon for the current tab
  IconData _getIconForTab(int currentTab) {
    switch (currentTab) {
      case 0: // Tasks tab
        final viewType = ref.watch(taskViewTypeProvider);
        final selectedDate = ref.watch(selectedCalendarDateProvider);
        
        // Show calendar-specific icon when in calendar view with selected date
        if (viewType == TaskViewType.calendar && selectedDate != null) {
          return PhosphorIcons.calendarPlus(PhosphorIconsStyle.bold);
        }
        return PhosphorIcons.listPlus(PhosphorIconsStyle.bold);
      case 1: // Notes tab
        return PhosphorIcons.notePencil(PhosphorIconsStyle.bold);
      default:
        return PhosphorIcons.plus(PhosphorIconsStyle.bold);
    }
  }

  /// Returns the appropriate tooltip for the current tab and context
  String _getFabTooltip(int currentTab) {
    switch (currentTab) {
      case 0: // Tasks tab
        final viewType = ref.watch(taskViewTypeProvider);
        final selectedDate = ref.watch(selectedCalendarDateProvider);
        
        if (viewType == TaskViewType.calendar && selectedDate != null) {
          final dateStr = DateFormat('MMM d').format(selectedDate);
          return 'Add task for $dateStr';
        }
        return 'Add task';
      case 1: // Notes tab
        return 'Create note';
      default:
        return 'Add';
    }
  }

  /// Returns context-aware color for the FAB
  Color? _getFabColor(int currentTab, ColorScheme colorScheme) {
    // Use theme-aware colors that work in both light and dark mode
    switch (currentTab) {
      case 0: // Tasks tab - Action-oriented with subtle green tint
        return Color.lerp(
          colorScheme.primary,
          colorScheme.tertiary, // Often green in Material 3
          0.15, // More subtle blend
        );
      case 1: // Notes tab - Creative-oriented with warmer tone
        return Color.lerp(
          colorScheme.primary,
          colorScheme.secondary,
          0.2, // Slightly more pronounced for creativity
        );
      default:
        return colorScheme.primary;
    }
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final isSearchMode = ref.watch(searchModeProvider);
    final currentTab = ref.watch(currentTabProvider);
    
    if (isSearchMode && (currentTab == 0 || currentTab == 1)) {
      return AppBar(
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft()),
          onPressed: () {
            ref.read(searchModeProvider.notifier).state = false;
            _searchController.clear();
            if (currentTab == 0) {
              ref.read(searchQueryProvider.notifier).state = '';
            } else if (currentTab == 1) {
              ref.read(notesSearchQueryProvider.notifier).state = '';
            }
          },
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: currentTab == 0 ? 'Search tasks...' : 'Search notes...',
            border: InputBorder.none,
          ),
          onChanged: (value) {
            if (currentTab == 0) {
              ref.read(searchQueryProvider.notifier).state = value;
            } else if (currentTab == 1) {
              ref.read(notesSearchQueryProvider.notifier).state = value;
            }
          },
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(PhosphorIcons.x()),
              onPressed: () {
                _searchController.clear();
                if (currentTab == 0) {
                  ref.read(searchQueryProvider.notifier).state = '';
                } else if (currentTab == 1) {
                  ref.read(notesSearchQueryProvider.notifier).state = '';
                }
              },
            ),
        ],
      );
    }

    final multiMode = ref.watch(multiSelectModeProvider);
    final selectedIds = ref.watch(selectedTodoIdsProvider);
    // Build a custom AppBar using PreferredSize + Stack so the centered folder
    // selector doesn't compete for space with left/right widgets and avoids
    // RenderFlex overflow.
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: SafeArea(
        child: Container(
          height: kToolbarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Left area: close button (multi-select) or app name
              Align(
                alignment: Alignment.centerLeft,
                child: multiMode
                    ? IconButton(
                        icon: Icon(PhosphorIcons.x()),
                        onPressed: () {
                          ref.read(multiSelectModeProvider.notifier).state = false;
                          ref.read(selectedTodoIdsProvider.notifier).clear();
                        },
                      )
                    : Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(
                          'trudido',
                          style: TextStyle(
                            // Slightly larger app name for improved presence
                            fontSize: 20,
                            // Slightly bolder for better visual weight
                            fontWeight: FontWeight.w700,
                            // Small letter spacing for a refined look
                            letterSpacing: 0.3,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
              ),
              // Center area: folder selector (or selected count when multiMode)
              Align(
                alignment: Alignment.center,
                child: multiMode && currentTab == 0
                    ? Text('${selectedIds.length} selected')
                    : (currentTab == 0 ? _buildFolderDropdown(isLeading: false, asTitle: true) : _buildAppBarTitle(currentTab)),
              ),
              // Positioned view toggle: placed between center and right area
              if (currentTab == 0 && !multiMode)
                Align(
                  // Move slightly left compared to previous 0.9 placement
                  alignment: const Alignment(0.8, 0),
                  child: _buildViewToggle(),
                ),

              // Right area: actions (multi-select icons, overflow)
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (currentTab == 0 && multiMode) ...[
                      IconButton(
                        icon: Icon(PhosphorIcons.checkCircle()),
                        tooltip: 'Mark complete',
                        onPressed: selectedIds.isEmpty
                            ? null
                            : () async {
                                final controller = ref.read(taskControllerProvider.notifier);
                                final current = ref.read(tasksProvider);
                                for (final id in selectedIds) {
                                  final t = current.firstWhere((e) => e.id == id);
                                  if (!t.isCompleted) await controller.toggleComplete(id);
                                }
                                ref.read(selectedTodoIdsProvider.notifier).clear();
                              },
                      ),
                      IconButton(
                        icon: Icon(PhosphorIcons.circleDashed()),
                        tooltip: 'Mark incomplete',
                        onPressed: selectedIds.isEmpty
                            ? null
                            : () async {
                                final controller = ref.read(taskControllerProvider.notifier);
                                final current = ref.read(tasksProvider);
                                for (final id in selectedIds) {
                                  final t = current.firstWhere((e) => e.id == id);
                                  if (t.isCompleted) await controller.toggleComplete(id);
                                }
                                ref.read(selectedTodoIdsProvider.notifier).clear();
                              },
                      ),
                      IconButton(
                        icon: Icon(PhosphorIcons.trash()),
                        tooltip: 'Delete',
                        onPressed: selectedIds.isEmpty
                            ? null
                            : () async {
                                final controller = ref.read(taskControllerProvider.notifier);
                                await controller.bulkDelete(selectedIds);
                                ref.read(selectedTodoIdsProvider.notifier).clear();
                                ref.read(multiSelectModeProvider.notifier).state = false;
                              },
                      ),
                    ],
                    // Quick Filters icon (keeps chips below AppBar but provides fast access)
                    
                    // Global overflow menu
                    PopupMenuButton<String>(
                      icon: Icon(PhosphorIcons.dotsThreeVertical()),
                      tooltip: 'More options',
                      onSelected: (value) {
                        switch (value) {
                          case 'search':
                            ref.read(searchModeProvider.notifier).state = true;
                            break;
                            case 'filters':
                              // Open the draggable filters sheet from the overflow menu
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                ),
                                builder: (sheetContext) {
                                  return DraggableScrollableSheet(
                                    expand: true,
                                    initialChildSize: 0.95,
                                    minChildSize: 0.25,
                                    maxChildSize: 0.95,
                                    builder: (context, controller) {
                                      return Consumer(
                                        builder: (ctx, innerRef, _) {
                                          final p = innerRef.watch(selectedPriorityProvider);
                                          final s = innerRef.watch(showCompletedProvider);
                                          final sort = innerRef.watch(sortByProvider);

                                          return Padding(
                                            padding: EdgeInsets.only(
                                              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                                              left: 16,
                                              right: 16,
                                              top: 12,
                                            ),
                                            child: Column(
                                              children: [
                                                Container(
                                                  width: 40,
                                                  height: 4,
                                                  margin: const EdgeInsets.only(bottom: 12),
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context).dividerColor,
                                                    borderRadius: BorderRadius.circular(2),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: ListView(
                                                    controller: controller,
                                                    children: [
                                                      const Padding(
                                                        padding: EdgeInsets.symmetric(vertical: 8.0),
                                                        child: Text('Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                                                      ),
                                                      const Divider(),

                                                      const Padding(
                                                        padding: EdgeInsets.only(top: 8.0, bottom: 4.0),
                                                        child: Text('Priority', style: TextStyle(fontWeight: FontWeight.w600)),
                                                      ),
                                                      RadioListTile<String>(
                                                        title: const Text('All Priorities'),
                                                        value: 'all',
                                                        groupValue: p,
                                                        onChanged: (v) => innerRef.read(selectedPriorityProvider.notifier).state = v ?? 'all',
                                                      ),
                                                      RadioListTile<String>(
                                                        title: const Text('High Priority'),
                                                        value: 'high',
                                                        groupValue: p,
                                                        onChanged: (v) => innerRef.read(selectedPriorityProvider.notifier).state = v ?? 'high',
                                                      ),
                                                      RadioListTile<String>(
                                                        title: const Text('Medium Priority'),
                                                        value: 'medium',
                                                        groupValue: p,
                                                        onChanged: (v) => innerRef.read(selectedPriorityProvider.notifier).state = v ?? 'medium',
                                                      ),
                                                      RadioListTile<String>(
                                                        title: const Text('Low Priority'),
                                                        value: 'low',
                                                        groupValue: p,
                                                        onChanged: (v) => innerRef.read(selectedPriorityProvider.notifier).state = v ?? 'low',
                                                      ),

                                                      const SizedBox(height: 8),

                                                      SwitchListTile(
                                                        title: const Text('Show Completed'),
                                                        value: s,
                                                        onChanged: (value) => innerRef.read(showCompletedProvider.notifier).state = value,
                                                      ),

                                                      const SizedBox(height: 8),

                                                      const Padding(
                                                        padding: EdgeInsets.only(top: 8.0, bottom: 4.0),
                                                        child: Text('Sort by', style: TextStyle(fontWeight: FontWeight.w600)),
                                                      ),
                                                      RadioListTile<String>(
                                                        title: const Text('Default'),
                                                        value: 'default',
                                                        groupValue: sort,
                                                        onChanged: (v) => innerRef.read(sortByProvider.notifier).state = v ?? 'default',
                                                      ),
                                                      RadioListTile<String>(
                                                        title: const Text('Manual'),
                                                        value: 'manual',
                                                        groupValue: sort,
                                                        onChanged: (v) => innerRef.read(sortByProvider.notifier).state = v ?? 'manual',
                                                      ),
                                                      RadioListTile<String>(
                                                        title: const Text('Date Created'),
                                                        value: 'date_created',
                                                        groupValue: sort,
                                                        onChanged: (v) => innerRef.read(sortByProvider.notifier).state = v ?? 'date_created',
                                                      ),
                                                      RadioListTile<String>(
                                                        title: const Text('Due Date'),
                                                        value: 'date_due',
                                                        groupValue: sort,
                                                        onChanged: (v) => innerRef.read(sortByProvider.notifier).state = v ?? 'date_due',
                                                      ),
                                                      RadioListTile<String>(
                                                        title: const Text('Priority'),
                                                        value: 'priority',
                                                        groupValue: sort,
                                                        onChanged: (v) => innerRef.read(sortByProvider.notifier).state = v ?? 'priority',
                                                      ),
                                                      RadioListTile<String>(
                                                        title: const Text('Alphabetical'),
                                                        value: 'alphabetical',
                                                        groupValue: sort,
                                                        onChanged: (v) => innerRef.read(sortByProvider.notifier).state = v ?? 'alphabetical',
                                                      ),

                                                      const SizedBox(height: 12),
                                                    ],
                                                  ),
                                                ),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.end,
                                                  children: [
                                                    TextButton(
                                                      onPressed: () => Navigator.of(sheetContext).pop(),
                                                      child: const Text('Close'),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    ElevatedButton(
                                                      onPressed: () => Navigator.of(sheetContext).pop(),
                                                      child: const Text('Done'),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                              );
                              break;
                          case 'settings':
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const SettingsScreen(),
                              ),
                            );
                            break;
                          case 'help':
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Help feature coming soon')),
                            );
                            break;
                          case 'about':
                            showAboutDialog(
                              context: context,
                              applicationName: 'Todo App',
                              applicationVersion: '1.2.0',
                              applicationIcon: Icon(PhosphorIcons.listChecks()),
                            );
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        if ((currentTab == 0 || currentTab == 1) && !multiMode)
                          PopupMenuItem(
                            value: 'search',
                            child: ListTile(
                              leading: Icon(PhosphorIcons.magnifyingGlass()),
                              title: const Text('Search'),
                              dense: true,
                            ),
                          ),
                        PopupMenuItem(
                          value: 'filters',
                          child: ListTile(
                            leading: Icon(PhosphorIcons.funnelSimple()),
                            title: const Text('Filters'),
                            dense: true,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'settings',
                          child: ListTile(
                            leading: Icon(PhosphorIcons.gear()),
                            title: const Text('Settings'),
                            dense: true,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'help',
                          child: ListTile(
                            leading: Icon(PhosphorIcons.question()),
                            title: const Text('Help & Feedback'),
                            dense: true,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'about',
                          child: ListTile(
                            leading: Icon(PhosphorIcons.info()),
                            title: const Text('About'),
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the app bar title with proper layout based on current tab
  Widget _buildAppBarTitle(int currentTab) {
    if (currentTab == 0) {
      // Tasks tab: show centered 'Tasks' title only; folder dropdown is moved to leading
      return const Text('Tasks');
    }
    // Other tabs: Just the title
    final tabTitles = ['Tasks', 'Notes'];
    return Text(tabTitles[currentTab]);
  }

  /// Build the folder dropdown for folder selection
  Widget _buildFolderDropdown({bool isLeading = false, bool asTitle = false}) {
    final foldersAsync = ref.watch(folderNotifierProvider);
    final selectedFolderId = ref.watch(selectedFolderProvider);
    
    // Debug print current selection
    debugPrint('[FolderDropdown] Current selectedFolderId: $selectedFolderId');
    
    return foldersAsync.when(
      data: (folders) {
        // Find the selected folder or use null for "All folders"
        final selectedFolder = selectedFolderId != null 
          ? folders.where((folder) => folder.id == selectedFolderId).firstOrNull
          : null;
        
        // compute responsive max width when used as AppBar title
        final screenWidth = MediaQuery.of(context).size.width;
  // reserve estimated space for center/right controls (toggle + overflow)
  // reduce reserved to allow more room for folder name
  final reserved = 180.0;
  // allow a larger clamp max so names can display more characters
  final computedMax = ((screenWidth / 2) - reserved).clamp(140.0, 420.0);

        return PopupMenuButton<String>(
          child: Container(
            // Slightly larger padding for better tap target and presence
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // When used as leading, apply a moderate left margin; otherwise keep right margin.
      // When used as the AppBar title, don't add extra right margin.
      margin: isLeading
        ? const EdgeInsets.only(left: 16)
        : (asTitle ? const EdgeInsets.symmetric(horizontal: 0) : const EdgeInsets.only(right: 8)),
            decoration: BoxDecoration(
              color: asTitle ? Colors.transparent : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            // Show compact UI when used as leading: icon + caret only
            child: isLeading
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        selectedFolder != null
                            ? _getIconData(selectedFolder.icon)
                            : PhosphorIcons.folders(),
                        size: 18,
                        color: selectedFolder != null
                            ? Color(selectedFolder.color)
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        PhosphorIcons.caretDown(),
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ],
                  )
        : ConstrainedBox(
          // When used as title, constrain the width based on screen size so
          // long folder names ellipsize before hitting the view-toggle/menu.
          constraints: asTitle ? BoxConstraints(maxWidth: computedMax) : const BoxConstraints(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          selectedFolder != null
                              ? _getIconData(selectedFolder.icon)
                              : PhosphorIcons.folders(),
                          // larger icon for the centered title state
                          size: 20,
                          color: selectedFolder != null
                              ? Color(selectedFolder.color)
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(width: 6),
                        // Allow folder name to shrink with ellipsis when space is tight
                        Flexible(
                          child: Text(
                            selectedFolder?.name ?? 'All',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              // Slightly larger text to match the bigger control
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          PhosphorIcons.caretDown(),
                          // slightly larger caret
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ],
                    ),
                  ),
          ),
          itemBuilder: (context) {
            return [
              // "All folders" option
              PopupMenuItem<String>(
                value: '_ALL_FOLDERS_',
                child: Row(
                  children: [
                    Icon(
                      PhosphorIcons.folders(),
                      size: 18,
                      color: selectedFolderId == null 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'All folders',
                      style: TextStyle(
                        color: selectedFolderId == null 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                        fontWeight: selectedFolderId == null 
                          ? FontWeight.w600 
                          : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              // Individual folders
              ...folders.map((folder) => PopupMenuItem<String>(
                value: folder.id,
                child: Row(
                  children: [
                    Icon(
                      _getIconData(folder.icon),
                      size: 18,
                      color: selectedFolderId == folder.id 
                        ? Theme.of(context).colorScheme.primary
                        : Color(folder.color),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      folder.name,
                      style: TextStyle(
                        color: selectedFolderId == folder.id 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                        fontWeight: selectedFolderId == folder.id 
                          ? FontWeight.w600 
                          : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ];
          },
          onSelected: (String folderId) {
            debugPrint('[FolderDropdown] Selected folder: ${folderId == '_ALL_FOLDERS_' ? 'All folders' : folderId}');
            ref.read(selectedFolderProvider.notifier).state = 
                folderId == '_ALL_FOLDERS_' ? null : folderId;
          },
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: isLeading ? const EdgeInsets.only(left: 8) : const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: asTitle ? Colors.transparent : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
    // Show compact loading UI when leading
    child: isLeading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                    SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    PhosphorIcons.caretDown(),
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ],
              )
      : ConstrainedBox(
        constraints: asTitle ? const BoxConstraints(maxWidth: 220) : const BoxConstraints(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Loading...',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
      error: (error, stackTrace) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: isLeading ? const EdgeInsets.only(left: 8) : const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: asTitle ? Colors.transparent : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
    child: isLeading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    PhosphorIcons.folder(),
                    size: 18,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    PhosphorIcons.caretDown(),
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ],
              )
      : ConstrainedBox(
        constraints: asTitle ? const BoxConstraints(maxWidth: 220) : const BoxConstraints(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PhosphorIcons.folder(),
                      size: 20,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Error',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  /// Build the view toggle for switching between list and calendar views
  Widget _buildViewToggle() {
    final viewType = ref.watch(taskViewTypeProvider);
    
    return Container(
  // Move the toggle slightly to the left to reduce distance from center.
  // Reduce right margin to 8 for a more compact placement.
  margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ViewToggleButton(
            icon: PhosphorIcons.list(),
            isSelected: viewType == TaskViewType.list,
            onTap: () {
              ref.read(taskViewTypeProvider.notifier).state = TaskViewType.list;
            },
            tooltip: 'List View',
          ),
          _ViewToggleButton(
            icon: PhosphorIcons.calendar(),
            isSelected: viewType == TaskViewType.calendar,
            onTap: () {
              ref.read(taskViewTypeProvider.notifier).state = TaskViewType.calendar;
            },
            tooltip: 'Calendar View',
          ),
        ],
      ),
    );
  }

  /// Helper method to get icon data from icon name
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

/// Custom view toggle button for list/calendar switching
class _ViewToggleButton extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final String tooltip;

  const _ViewToggleButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          // Reduced padding to make the control more compact
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            // Slightly smaller corner radius for a tighter look
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            // Slightly smaller icon so the control isn't overly prominent
            size: 18,
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

// Multi-select providers
final multiSelectModeProvider = StateProvider<bool>((ref) => false);
final selectedTodoIdsProvider = StateNotifierProvider<SelectedTodoIdsNotifier, Set<String>>((ref) => SelectedTodoIdsNotifier());

class SelectedTodoIdsNotifier extends StateNotifier<Set<String>> {
  SelectedTodoIdsNotifier() : super(<String>{});
  void toggle(String id) {
    if (state.contains(id)) {
      state = {...state}..remove(id);
    } else {
      state = {...state, id};
    }
  }
  void clear() => state = <String>{};
}

// Provider & notifier for FAB position
// FAB position now from unified preferences.
final fabPositionProvider = Provider<String>((ref) => ref.watch(preferencesStateProvider).fabPosition);
