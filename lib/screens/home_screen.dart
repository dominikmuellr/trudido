import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/filter_providers.dart';
import '../controllers/task_controller.dart';
import '../controllers/notes_controller.dart';
import '../providers/app_providers.dart';
import '../services/default_tab_service.dart';
import '../services/folder_provider.dart';
import '../screens/task_editor_screen.dart';
import '../widgets/todo_list_tab.dart';
import '../widgets/create_folder_dialog.dart';
import 'settings_screen.dart';
import 'notes_screen.dart';
import 'note_editor_screen.dart';
import '../widgets/filters_sheet.dart';

// Provider for tracking search mode state
final searchModeProvider = StateProvider<bool>((ref) => false);

// Provider for current tab index with default tab initialization
final currentTabProvider = StateNotifierProvider<CurrentTabNotifier, int>((
  ref,
) {
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

    // Define tabs
    final tabs = [const TodoListTab(), const NotesScreen()];

    // Use standard Material FAB position
    const fabLocation = FloatingActionButtonLocation.endFloat;

    // Check if we should use NavigationRail for wider screens
    final screenWidth = MediaQuery.of(context).size.width;
    final useNavigationRail = screenWidth >= 600; // Material 3 breakpoint

    if (useNavigationRail) {
      return Scaffold(
        body: Row(
          children: [
            // Material 3 NavigationRail
            NavigationRail(
              selectedIndex: currentTab,
              onDestinationSelected: (index) {
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
              },
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.checklist_outlined),
                  selectedIcon: Icon(Icons.checklist),
                  label: Text('Tasks'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.note_outlined),
                  selectedIcon: Icon(Icons.note),
                  label: Text('Notes'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            // Main content
            Expanded(
              child: Scaffold(
                appBar: _buildAppBar(context),
                body: IndexedStack(index: currentTab, children: tabs),
                floatingActionButtonLocation: fabLocation,
                floatingActionButton: AnimatedContainer(
                  duration: const Duration(
                    milliseconds: 300,
                  ), // Material 3 standard
                  child: FloatingActionButton(
                    heroTag: "main_fab", // Unique hero tag
                    onPressed: () => _onFabPressed(currentTab),
                    backgroundColor: _getFabColor(
                      currentTab,
                      Theme.of(context).colorScheme,
                    ),
                    elevation: 3.0, // Material 3 standard elevation
                    highlightElevation: 6.0, // Subtle interaction feedback
                    shape: const CircleBorder(), // Explicit Material 3 shape
                    tooltip: _getFabTooltip(currentTab),
                    child: _buildFabIcon(currentTab),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(context),
      body: IndexedStack(index: currentTab, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentTab,
        onTap: (index) {
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
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.checklist),
            activeIcon: Icon(Icons.checklist),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.note),
            activeIcon: Icon(Icons.note),
            label: 'Notes',
          ),
        ],
      ),
      floatingActionButtonLocation: fabLocation,
      floatingActionButton: AnimatedContainer(
        duration: const Duration(milliseconds: 300), // Material 3 standard
        child: FloatingActionButton(
          heroTag: "main_fab", // Unique hero tag
          onPressed: () => _onFabPressed(currentTab),
          backgroundColor: _getFabColor(
            currentTab,
            Theme.of(context).colorScheme,
          ),
          elevation: 3.0, // Material 3 standard elevation
          highlightElevation: 6.0, // Subtle interaction feedback
          shape: const CircleBorder(), // Explicit Material 3 shape
          tooltip: _getFabTooltip(currentTab),
          child: _buildFabIcon(currentTab),
        ),
      ),
    );
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
    final DateTime? preset =
        (viewType == TaskViewType.calendar && selectedDate != null)
        ? selectedDate
        : null;

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
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const NoteEditorScreen()));
  }

  /// Builds the consistent FAB icon (plus)
  Widget _buildFabIcon(int currentTab) {
    return const Icon(
      Icons.add, // Consistent plus icon
      size: 24,
    );
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
          icon: Icon(Icons.arrow_back),
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
              icon: Icon(Icons.close),
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
                        icon: Icon(Icons.close),
                        onPressed: () {
                          ref.read(multiSelectModeProvider.notifier).state =
                              false;
                          ref.read(selectedTodoIdsProvider.notifier).clear();
                        },
                      )
                    : Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(
                          'trudido',
                          style: GoogleFonts.montserrat(
                            // Slightly larger app name for improved presence
                            fontSize: 18,
                            // Lighter weight for subtle brand presence
                            fontWeight: FontWeight.w500,
                            // Small letter spacing for a refined look
                            letterSpacing: 0.4,
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
                    : (currentTab == 0
                          ? _buildFolderDropdown(
                              isLeading: false,
                              asTitle: true,
                            )
                          : _buildAppBarTitle(currentTab)),
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
                        icon: Icon(Icons.check_circle),
                        tooltip: 'Mark complete',
                        onPressed: selectedIds.isEmpty
                            ? null
                            : () async {
                                final controller = ref.read(
                                  taskControllerProvider.notifier,
                                );
                                final current = ref.read(tasksProvider);
                                for (final id in selectedIds) {
                                  final t = current.firstWhere(
                                    (e) => e.id == id,
                                  );
                                  if (!t.isCompleted)
                                    await controller.toggleComplete(id);
                                }
                                ref
                                    .read(selectedTodoIdsProvider.notifier)
                                    .clear();
                              },
                      ),
                      IconButton(
                        icon: Icon(Icons.radio_button_unchecked),
                        tooltip: 'Mark incomplete',
                        onPressed: selectedIds.isEmpty
                            ? null
                            : () async {
                                final controller = ref.read(
                                  taskControllerProvider.notifier,
                                );
                                final current = ref.read(tasksProvider);
                                for (final id in selectedIds) {
                                  final t = current.firstWhere(
                                    (e) => e.id == id,
                                  );
                                  if (t.isCompleted)
                                    await controller.toggleComplete(id);
                                }
                                ref
                                    .read(selectedTodoIdsProvider.notifier)
                                    .clear();
                              },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        tooltip: 'Delete',
                        onPressed: selectedIds.isEmpty
                            ? null
                            : () async {
                                final controller = ref.read(
                                  taskControllerProvider.notifier,
                                );
                                await controller.bulkDelete(selectedIds);
                                ref
                                    .read(selectedTodoIdsProvider.notifier)
                                    .clear();
                                ref
                                        .read(multiSelectModeProvider.notifier)
                                        .state =
                                    false;
                              },
                      ),
                    ],
                    // Quick Filters icon (keeps chips below AppBar but provides fast access)

                    // Global overflow menu
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert),
                      tooltip: 'More options',
                      onSelected: (value) {
                        switch (value) {
                          case 'search':
                            ref.read(searchModeProvider.notifier).state = true;
                            break;
                          case 'filters':
                            showFiltersSheet(context);
                            break;
                          case 'settings':
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const SettingsScreen(),
                              ),
                            );
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        if ((currentTab == 0 || currentTab == 1) && !multiMode)
                          PopupMenuItem(
                            value: 'search',
                            child: ListTile(
                              leading: Icon(Icons.search),
                              title: const Text('Search'),
                              dense: true,
                            ),
                          ),
                        PopupMenuItem(
                          value: 'filters',
                          child: ListTile(
                            leading: Icon(Icons.filter_alt),
                            title: const Text('Filters'),
                            dense: true,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'settings',
                          child: ListTile(
                            leading: Icon(Icons.settings),
                            title: const Text('Settings'),
                            dense: true,
                          ),
                        ),
                        // Help & About entries removed: About and Help moved to Settings -> About & Licenses
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
            ? folders
                  .where((folder) => folder.id == selectedFolderId)
                  .firstOrNull
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
                : (asTitle
                      ? const EdgeInsets.symmetric(horizontal: 0)
                      : const EdgeInsets.only(right: 8)),
            decoration: BoxDecoration(
              color: asTitle
                  ? Colors.transparent
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
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
                            : Icons.folder,
                        size: 18,
                        color: selectedFolder != null
                            ? Color(selectedFolder.color)
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.expand_more,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ],
                  )
                : ConstrainedBox(
                    // When used as title, constrain the width based on screen size so
                    // long folder names ellipsize before hitting the view-toggle/menu.
                    constraints: asTitle
                        ? BoxConstraints(maxWidth: computedMax)
                        : const BoxConstraints(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          selectedFolder != null
                              ? _getIconData(selectedFolder.icon)
                              : Icons.folder,
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
                          Icons.expand_more,
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
                      Icons.folder,
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
              ...folders
                  .map(
                    (folder) => PopupMenuItem<String>(
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
                    ),
                  )
                  .toList(),
              // Divider + create new folder option
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: '_CREATE_FOLDER_',
                child: Row(
                  children: [
                    Icon(
                      Icons.create_new_folder,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    const Text('Create folder'),
                  ],
                ),
              ),
            ];
          },
          onSelected: (String folderId) {
            debugPrint(
              '[FolderDropdown] Selected folder: ${folderId == '_ALL_FOLDERS_' ? 'All folders' : folderId}',
            );
            if (folderId == '_CREATE_FOLDER_') {
              // Open the create folder dialog
              showDialog(
                context: context,
                builder: (ctx) => const CreateFolderDialog(),
              );
              return;
            }

            ref.read(selectedFolderProvider.notifier).state =
                folderId == '_ALL_FOLDERS_' ? null : folderId;
          },
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: isLeading
            ? const EdgeInsets.only(left: 8)
            : const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: asTitle
              ? Colors.transparent
              : Theme.of(context).colorScheme.surfaceContainerHighest,
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
                    Icons.expand_more,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ],
              )
            : ConstrainedBox(
                constraints: asTitle
                    ? const BoxConstraints(maxWidth: 220)
                    : const BoxConstraints(),
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
        margin: isLeading
            ? const EdgeInsets.only(left: 8)
            : const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: asTitle
              ? Colors.transparent
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: isLeading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder,
                    size: 18,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.expand_more,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ],
              )
            : ConstrainedBox(
                constraints: asTitle
                    ? const BoxConstraints(maxWidth: 220)
                    : const BoxConstraints(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.folder,
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
            icon: Icons.list,
            isSelected: viewType == TaskViewType.list,
            onTap: () {
              ref.read(taskViewTypeProvider.notifier).state = TaskViewType.list;
            },
            tooltip: 'List View',
          ),
          _ViewToggleButton(
            icon: Icons.calendar_month,
            isSelected: viewType == TaskViewType.calendar,
            onTap: () {
              ref.read(taskViewTypeProvider.notifier).state =
                  TaskViewType.calendar;
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
final selectedTodoIdsProvider =
    StateNotifierProvider<SelectedTodoIdsNotifier, Set<String>>(
      (ref) => SelectedTodoIdsNotifier(),
    );

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
