import 'package:flutter/material.dart';
import 'package:trudido/utils/responsive_size.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/theme_service.dart';
import 'dart:math';
import 'dart:async';
import '../providers/filter_providers.dart';
import '../controllers/task_controller.dart';
import '../controllers/notes_controller.dart';
import '../providers/app_providers.dart';
import '../services/default_tab_service.dart';
import '../services/folder_provider.dart';
import '../services/vault_auth_service.dart';
import '../services/vault_password_service.dart';
import '../services/biometric_auth_service.dart';
import '../repositories/note_folder_repository.dart';
import '../models/note_folder.dart';
import '../screens/task_editor_screen.dart';
import '../widgets/todo_list_tab.dart';
import '../widgets/create_folder_dialog.dart';
import '../widgets/animated_widgets.dart';
import '../utils/animated_navigation.dart';
import 'settings_screen.dart';
import 'notes_screen.dart';
import 'note_editor_screen.dart';
import 'notes_folder_management_screen.dart';

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

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Register lifecycle observer to detect app state changes
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Unregister lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Security: Clear vault selection when app goes to background
    // Only lock when app is truly backgrounded, not just temporarily inactive
    // (inactive = notification panel, PiP still visible)
    if (state ==
            AppLifecycleState
                .paused || // App in background (home button, app switcher)
        state == AppLifecycleState.hidden) {
      // App completely hidden (iOS)
      _clearVaultSelectionIfNeeded();
    }
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

                // Security: Clear vault folder selection when leaving Notes tab
                if (previousTab == 1 && index != 1) {
                  _clearVaultSelectionIfNeeded();
                }

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
              destinations: [
                NavigationRailDestination(
                  icon: _buildNavigationIcon(Icons.checklist_outlined, 0),
                  selectedIcon: _buildNavigationIcon(Icons.checklist, 0),
                  label: const Text('Tasks'),
                ),
                NavigationRailDestination(
                  icon: _buildNavigationIcon(Icons.note_outlined, 1),
                  selectedIcon: _buildNavigationIcon(Icons.note, 1),
                  label: const Text('Notes'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            // Main content
            Expanded(
              child: Scaffold(
                appBar: _buildAppBar(context),
                body: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeInOut,
                  switchOutCurve: Curves.easeInOut,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: IndexedStack(
                    key: ValueKey<int>(currentTab),
                    index: currentTab,
                    children: tabs,
                  ),
                ),
                floatingActionButtonLocation: fabLocation,
                floatingActionButton: AnimatedFAB(
                  heroTag: "main_fab",
                  visible: true,
                  icon: _buildFabIcon(currentTab),
                  onPressed: () => _onFabPressed(currentTab),
                  backgroundColor: _getFabColor(
                    currentTab,
                    Theme.of(context).colorScheme,
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
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: IndexedStack(
          key: ValueKey<int>(currentTab),
          index: currentTab,
          children: tabs,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentTab,
        onDestinationSelected: (index) {
          final previousTab = ref.read(currentTabProvider);

          // Security: Clear vault folder selection when leaving Notes tab
          if (previousTab == 1 && index != 1) {
            _clearVaultSelectionIfNeeded();
          }

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
        destinations: [
          NavigationDestination(
            icon: _buildNavigationIcon(Icons.checklist_outlined, 0),
            selectedIcon: _buildNavigationIcon(Icons.checklist, 0),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: _buildNavigationIcon(Icons.note_outlined, 1),
            selectedIcon: _buildNavigationIcon(Icons.note, 1),
            label: 'Notes',
          ),
        ],
      ),
      floatingActionButtonLocation: fabLocation,
      floatingActionButton: AnimatedFAB(
        heroTag: "main_fab",
        visible: true,
        icon: _buildFabIcon(currentTab),
        onPressed: () => _onFabPressed(currentTab),
        backgroundColor: _getFabColor(
          currentTab,
          Theme.of(context).colorScheme,
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

  /// Security: Clear vault folder selection if currently viewing a vault
  void _clearVaultSelectionIfNeeded() {
    final selectedFolderId = ref.read(selectedNoteFolderProvider);
    if (selectedFolderId != null) {
      final foldersAsync = ref.read(noteFoldersProvider);
      final folders = foldersAsync.valueOrNull ?? [];
      final folder = folders.where((f) => f.id == selectedFolderId).firstOrNull;

      // Clear selection if it's a vault folder
      if (folder != null && folder.isVault) {
        ref.read(selectedNoteFolderProvider.notifier).state = null;
      }
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

    AnimatedNavigation.pushContainerTransform(
      context,
      TaskEditorScreen(
        presetDueDate: preset,
        onSave: (todo) {
          ref.read(taskControllerProvider.notifier).add(todo);
        },
      ),
    );
  }

  void _createNewNote() {
    // Get the currently selected folder to create note in
    final selectedFolderId = ref.read(selectedNoteFolderProvider);

    AnimatedNavigation.pushContainerTransform(
      context,
      NoteEditorScreen(initialFolderId: selectedFolderId),
    );
  }

  /// Shows vault setup dialog for first-time vault access
  Future<bool> _showVaultSetupDialog(
    BuildContext context,
    NoteFolder folder,
  ) async {
    // Check if biometric is available
    final biometricAvailable =
        await BiometricAuthService.isBiometricsAvailable();

    // Show the dialog using a separate stateful widget
    final result = await Navigator.of(context).push<Map<String, dynamic>?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _VaultSetupScreen(
          folderName: folder.name,
          biometricAvailable: biometricAvailable,
        ),
      ),
    );

    // Process the result outside the dialog
    if (result != null) {
      try {
        // Save the password
        await VaultPasswordService.setVaultPassword(
          folder.id,
          result['password'] as String,
        );

        // Update the folder to mark it has a password
        final updatedFolder = folder.copyWith(
          hasPassword: true,
          useBiometric: result['useBiometric'] as bool,
        );

        await ref
            .read(noteFoldersProvider.notifier)
            .updateFolder(updatedFolder);

        return true;
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to setup vault: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }
    }

    return false;
  }

  /// Builds the consistent FAB icon (plus)
  Widget _buildFabIcon(int currentTab) {
    return const ScaledIcon(
      Icons.add, // Consistent plus icon
      size: 24,
    );
  }

  /// Builds navigation icon with optional badge for notification counts
  Widget _buildNavigationIcon(IconData icon, int tabIndex) {
    // Get counts for badges
    int? badgeCount;

    if (tabIndex == 0) {
      // Tasks tab - show overdue count
      final taskStats = ref.watch(taskStatisticsProvider);
      if (taskStats.overdue > 0) {
        badgeCount = taskStats.overdue;
      }
    } else if (tabIndex == 1) {
      // Notes tab - could show unread count (if implemented)
      // For now, no badge
      badgeCount = null;
    }

    final iconWidget = Icon(icon);

    if (badgeCount != null && badgeCount > 0) {
      return Badge(
        label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
        backgroundColor: Theme.of(context).colorScheme.error,
        textColor: Theme.of(context).colorScheme.onError,
        child: iconWidget,
      );
    }

    return iconWidget;
  }

  /// Returns the appropriate tooltip for the current tab and context
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
      // Material 3 compliant search AppBar
      final theme = Theme.of(context);
      final colorScheme = theme.colorScheme;

      return AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
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
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: currentTab == 0 ? 'Search tasks...' : 'Search notes...',
            hintStyle: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            border: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.zero,
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
              icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
              tooltip: 'Clear search',
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
                        icon: ScaledIcon(Icons.close),
                        onPressed: () {
                          ref.read(multiSelectModeProvider.notifier).state =
                              false;
                          ref.read(selectedTodoIdsProvider.notifier).clear();
                        },
                      )
                    : Consumer(
                        builder: (context, ref, child) {
                          final preferences = ref.watch(
                            preferencesStateProvider,
                          );
                          final isHackTheme =
                              preferences.accentColorSeed == 0xFF00FF00 &&
                              !preferences
                                  .useDynamicColor; // Dynamic colors override hack theme

                          return Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: GestureDetector(
                              onTap: isHackTheme
                                  ? () => _triggerMatrixRain(ref)
                                  : null,
                              child: Text(
                                'trudido',
                                style: AppTheme.safeMontserrat(
                                  context,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.4,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          );
                        },
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
                          : currentTab == 1
                          ? _buildNoteFolderDropdown(
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
                        icon: ScaledIcon(Icons.check_circle_outline),
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
                        icon: ScaledIcon(Icons.radio_button_unchecked),
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
                        icon: ScaledIcon(Icons.delete_outline),
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

                    // Global overflow menu
                    PopupMenuButton<String>(
                      icon: ScaledIcon(
                        Icons.more_vert,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      tooltip: 'More options',
                      onSelected: (value) {
                        switch (value) {
                          case 'search':
                            ref.read(searchModeProvider.notifier).state = true;
                            break;
                          case 'settings':
                            // Security: Clear vault selection before navigating away
                            _clearVaultSelectionIfNeeded();
                            AnimatedNavigation.push(
                              context,
                              const SettingsScreen(),
                            );
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        if ((currentTab == 0 || currentTab == 1) && !multiMode)
                          PopupMenuItem(
                            value: 'search',
                            child: ListTile(
                              leading: const Icon(Icons.search, size: 20),
                              title: const Text('Search'),
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                          ),

                        PopupMenuItem(
                          value: 'settings',
                          child: ListTile(
                            leading: const Icon(
                              Icons.settings_outlined,
                              size: 20,
                            ),
                            title: const Text('Settings'),
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
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
                      ScaledIcon(
                        selectedFolder != null
                            ? _getIconData(selectedFolder.icon)
                            : Icons.folder_outlined,
                        size: 18,
                        color: selectedFolder != null
                            ? Color(selectedFolder.color)
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(width: 6),
                      ScaledIcon(
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
                        ScaledIcon(
                          selectedFolder != null
                              ? _getIconData(selectedFolder.icon)
                              : Icons.folder_outlined,
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
                        ScaledIcon(
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
                    ScaledIcon(
                      Icons.folder_outlined,
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
                          ScaledIcon(
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
              PopupMenuDivider(
                height: 1,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              ),
              PopupMenuItem<String>(
                value: '_CREATE_FOLDER_',
                child: Row(
                  children: [
                    ScaledIcon(
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
                  ScaledIcon(
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
                  ScaledIcon(
                    Icons.folder_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  ScaledIcon(
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
                    ScaledIcon(
                      Icons.folder_outlined,
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

  /// Build the folder dropdown for note folder selection
  Widget _buildNoteFolderDropdown({
    bool isLeading = false,
    bool asTitle = false,
  }) {
    final foldersAsync = ref.watch(noteFoldersProvider);
    final selectedFolderId = ref.watch(selectedNoteFolderProvider);

    final screenWidth = MediaQuery.of(context).size.width;
    final reserved = 180.0;
    final computedMax = ((screenWidth / 2) - reserved).clamp(140.0, 420.0);

    return foldersAsync.when(
      data: (folders) {
        final selectedFolder = selectedFolderId != null
            ? folders
                  .where((folder) => folder.id == selectedFolderId)
                  .firstOrNull
            : null;

        return PopupMenuButton<String>(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            child: isLeading
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaledIcon(
                        selectedFolder != null && selectedFolder.isVault
                            ? Icons.lock_open
                            : Icons.folder,
                        size: 18,
                        color: selectedFolder != null && selectedFolder.isVault
                            ? Colors.amber
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(width: 6),
                      ScaledIcon(
                        Icons.expand_more,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ],
                  )
                : ConstrainedBox(
                    constraints: asTitle
                        ? BoxConstraints(maxWidth: computedMax)
                        : const BoxConstraints(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ScaledIcon(
                          selectedFolder != null && selectedFolder.isVault
                              ? Icons.lock_open
                              : Icons.folder,
                          size: 20,
                          color:
                              selectedFolder != null && selectedFolder.isVault
                              ? Colors.amber
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            selectedFolder?.name ?? 'All Notes',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        ScaledIcon(
                          Icons.expand_more,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ],
                    ),
                  ),
          ),
          itemBuilder: (context) {
            return [
              // "All Notes" option
              PopupMenuItem<String>(
                value: '_ALL_NOTES_',
                child: Row(
                  children: [
                    ScaledIcon(
                      Icons.folder,
                      size: 18,
                      color: selectedFolderId == null
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'All Notes',
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
                          ScaledIcon(
                            folder.isVault
                                ? (selectedFolderId == folder.id
                                      ? Icons.lock_open
                                      : Icons.lock)
                                : Icons.folder,
                            size: 18,
                            color: selectedFolderId == folder.id
                                ? Theme.of(context).colorScheme.primary
                                : (folder.isVault
                                      ? Colors.amber
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurface),
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
              // Divider + manage folders option
              PopupMenuDivider(
                height: 1,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              ),
              PopupMenuItem<String>(
                value: '_MANAGE_FOLDERS_',
                child: Row(
                  children: [
                    ScaledIcon(
                      Icons.settings,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    const Text('Manage folders'),
                  ],
                ),
              ),
            ];
          },
          onSelected: (String folderId) async {
            if (folderId == '_MANAGE_FOLDERS_') {
              // Security: Clear vault selection before navigating away
              _clearVaultSelectionIfNeeded();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const NotesFolderManagementScreen(),
                ),
              );
            } else if (folderId == '_ALL_NOTES_') {
              ref.read(selectedNoteFolderProvider.notifier).state = null;
            } else {
              // Check if this is a vault folder and require authentication
              final foldersAsync = ref.read(noteFoldersProvider);
              final folders = foldersAsync.valueOrNull ?? [];
              final folder = folders.where((f) => f.id == folderId).firstOrNull;

              if (folder != null && folder.isVault) {
                // If vault has no password yet, prompt to set it up
                if (!folder.hasPassword) {
                  final setupResult = await _showVaultSetupDialog(
                    context,
                    folder,
                  );

                  if (!setupResult) {
                    // User cancelled setup
                    return;
                  }
                  // Password is now set, proceed to select folder
                } else {
                  // Require authentication for vault folders with password
                  final authenticated = await VaultAuthService.authenticate(
                    context: context,
                    folderId: folder.id,
                    folderName: folder.name,
                    useBiometric: folder.useBiometric,
                    hasPassword: folder.hasPassword,
                  );

                  if (!authenticated) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Authentication required to access vault folder',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }
                }
              }

              ref.read(selectedNoteFolderProvider.notifier).state = folderId;
            }
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
                  ScaledIcon(
                    Icons.expand_more,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ],
              )
            : Row(
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
                  const Text('Loading...'),
                ],
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaledIcon(
              Icons.folder,
              size: 18,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 6),
            const Text('Error'),
          ],
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

  void _triggerMatrixRain(WidgetRef ref) {
    // Show Matrix rain overlay
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => const MatrixRainOverlay(),
    );
  }
}

// Matrix Rain Overlay Widget
class MatrixRainOverlay extends StatefulWidget {
  const MatrixRainOverlay({super.key});

  @override
  State<MatrixRainOverlay> createState() => _MatrixRainOverlayState();
}

class _MatrixRainOverlayState extends State<MatrixRainOverlay>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  final List<MatrixColumn> _columns = [];
  final Random _random = Random();
  Timer? _animationTimer;
  bool _columnsInitialized = false;

  final List<String> _matrixChars = [
    'ｱ',
    'ｲ',
    'ｳ',
    'ｴ',
    'ｵ',
    'ｶ',
    'ｷ',
    'ｸ',
    'ｹ',
    'ｺ',
    'ｻ',
    'ｼ',
    'ｽ',
    'ｾ',
    'ｿ',
    'ﾀ',
    'ﾁ',
    'ﾂ',
    'ﾃ',
    'ﾄ',
    'ﾅ',
    'ﾆ',
    'ﾇ',
    'ﾈ',
    'ﾉ',
    'ﾊ',
    'ﾋ',
    'ﾌ',
    'ﾍ',
    'ﾎ',
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    'T',
    'R',
    'U',
    'D',
    'I',
    'D',
    'O',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    // Note: _initializeColumns() moved to build method to avoid MediaQuery issues

    // Use a timer for better performance control (30 FPS instead of 60)
    _animationTimer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _updateRain();
    });

    _controller.forward();

    // Auto-close after 1.5 seconds
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _initializeColumns(BuildContext context) {
    // Create optimized columns for better performance on low-end devices
    final screenWidth = MediaQuery.of(context).size.width;
    final columnCount = (screenWidth / 25).floor().clamp(
      20,
      30,
    ); // Adaptive column count

    for (int i = 0; i < columnCount; i++) {
      _columns.add(
        MatrixColumn(
          x: i * (screenWidth / columnCount),
          chars: List.generate(
            8 +
                _random.nextInt(
                  8,
                ), // Shorter columns (8-16 chars) for performance
            (index) => _matrixChars[_random.nextInt(_matrixChars.length)],
          ),
          speed: 0.5 + _random.nextDouble() * 1.5,
          opacity: 0.3 + _random.nextDouble() * 0.7,
        ),
      );
    }
  }

  void _updateRain() {
    if (!mounted) return;
    setState(() {
      for (var column in _columns) {
        column.y +=
            column.speed * 6; // Reduced multiplier for smoother animation
        if (column.y > 800) {
          // Vary the reset position for more natural flow
          column.y = -200 - _random.nextDouble() * 100;
          // Regenerate characters with performance-optimized length
          final newLength =
              8 + _random.nextInt(8); // Keep shorter for performance
          column.chars = List.generate(
            newLength,
            (index) => _matrixChars[_random.nextInt(_matrixChars.length)],
          );
          // Slightly vary speed and opacity on reset
          column.speed = 0.5 + _random.nextDouble() * 1.5;
          column.opacity = 0.3 + _random.nextDouble() * 0.7;
        }
      }
    });
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Initialize columns on first build when MediaQuery is available
    if (!_columnsInitialized) {
      _initializeColumns(context);
      _columnsInitialized = true;
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Matrix rain columns
          ..._columns.map(
            (column) => Positioned(
              left: column.x,
              top: column.y,
              child: Column(
                children: column.chars
                    .map(
                      (char) => Text(
                        char,
                        style: TextStyle(
                          color: const Color(
                            0xFF00FF00,
                          ).withOpacity(column.opacity),
                          fontSize: 16,
                          fontFamily: 'monospace',
                          shadows: [
                            Shadow(
                              color: const Color(0xFF00FF00).withOpacity(0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          // Center "trudido" text
          Center(
            child: Text(
              'trudido',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 48,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.8),
                    blurRadius: 16,
                  ),
                  Shadow(
                    color: const Color(0xFF00FF00).withOpacity(0.4),
                    blurRadius: 32,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MatrixColumn {
  double x;
  double y;
  List<String> chars;
  double speed;
  double opacity;

  MatrixColumn({
    required this.x,
    this.y = -200,
    required this.chars,
    required this.speed,
    required this.opacity,
  });
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
          child: ScaledIcon(
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

/// Separate screen for vault password setup to avoid dialog context issues
class _VaultSetupScreen extends StatefulWidget {
  final String folderName;
  final bool biometricAvailable;

  const _VaultSetupScreen({
    required this.folderName,
    required this.biometricAvailable,
  });

  @override
  State<_VaultSetupScreen> createState() => _VaultSetupScreenState();
}

class _VaultSetupScreenState extends State<_VaultSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _useBiometric = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop({
        'password': _passwordController.text,
        'useBiometric': _useBiometric,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Setup ${widget.folderName}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(null),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Create a password/PIN to protect this vault folder',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password/PIN',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a password';
                }
                if (value.length < 4) {
                  return 'Password must be at least 4 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirm = !_obscureConfirm;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            if (widget.biometricAvailable) ...[
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Use biometric authentication'),
                subtitle: const Text(
                  'Use fingerprint/face ID for quick access',
                ),
                value: _useBiometric,
                onChanged: (value) {
                  setState(() {
                    _useBiometric = value ?? true;
                  });
                },
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submit,
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Setup Vault'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
