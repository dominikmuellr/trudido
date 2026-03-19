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

import 'dart:async';
import '../providers/filter_providers.dart';
import '../providers/settings_search_provider.dart';
import '../controllers/notes_controller.dart';
import '../providers/app_providers.dart';
import '../services/folder_provider.dart';
import '../services/default_tab_service.dart';
import '../services/widget_service.dart';
import '../repositories/note_folder_repository.dart';
import '../widgets/todo_list_tab.dart';
import '../widgets/fab_menu.dart';
import 'overview_tab.dart';
import '../main.dart'
    show widgetTaskCreationRequestProvider, widgetTaskCreationDateProvider;
import 'notes_screen.dart';
import 'home_screen_notifiers.dart';
import 'home_navigation_drawer.dart';
import 'unified_search_results.dart';
import 'home_app_bar.dart';
import 'home_bottom_navigation.dart';
import 'home_screen_actions.dart';
import 'note_folder_dialogs.dart';
import '../widgets/common/common.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin, HomeScreenActions {
  @override
  TextEditingController get searchController => _searchController;

  final _searchController = TextEditingController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isCalendarExpanded = false;
  // _isFilterExpanded removed - filters are now in the always-visible chip row

  // Animation state for greeting → search bar transition
  AnimationController? _greetingAnimationController;
  Animation<double>? _greetingFadeAnimation;
  Animation<double>? _searchBarScaleAnimation;
  bool _showSearchBar = false;
  DateTime? _lastPausedTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateWidgetOnStartup();

    _greetingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _greetingFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _greetingAnimationController!,
        curve: Curves.easeOut,
      ),
    );

    _searchBarScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _greetingAnimationController!,
        curve: Curves.easeOut,
      ),
    );

    _triggerGreetingAnimation();
    // Guard: if Overview tab is hidden but current tab is 0 at startup, switch away.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkInitialTab());
  }

  Future<void> _checkInitialTab() async {
    if (!mounted) return;
    final prefs = ref.read(preferencesStateProvider);
    if (!prefs.showOverviewTab && ref.read(currentTabProvider) == 0) {
      final fallback = await DefaultTabService.getDefaultTabIndex();
      final target = fallback == 0 ? 1 : fallback;
      if (mounted) ref.read(currentTabProvider.notifier).setTab(target);
    }
  }

  Future<void> _updateWidgetOnStartup() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final tasks = ref.read(tasksProvider);
    final incomplete = tasks.where((t) => !t.isCompleted).toList();
    await WidgetService.instance.updateWidgetData(incomplete);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _greetingAnimationController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      clearVaultSelectionIfNeeded();
      _lastPausedTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_lastPausedTime != null) {
        final pauseDuration = DateTime.now().difference(_lastPausedTime!);
        if (pauseDuration.inMilliseconds > 500) {
          // Meaningful resume, trigger greeting animation
          _triggerGreetingAnimation();
        }
      }
      _lastPausedTime = null;
    }
  }

  /// Triggers the greeting → search bar animation after a 2-second delay
  void _triggerGreetingAnimation() {
    final showSearchBar = ref.read(preferencesStateProvider).showSearchBar;
    if (!showSearchBar) return; // Don't show search bar if disabled in settings

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted || _greetingAnimationController == null) return;
      setState(() {
        _showSearchBar = true;
      });
      _greetingAnimationController!.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentTab = ref.watch(currentTabProvider);
    final isSearchMode = ref.watch(searchModeProvider);
    final selectedNoteFolderId = ref.watch(selectedNoteFolderProvider);
    final fabMenuExpanded = ref.watch(fabMenuExpandedProvider);
    final notesMultiSelectMode = ref.watch(notesMultiSelectModeProvider);
    final tasksMultiSelectMode = ref.watch(multiSelectModeProvider);
    final preferences = ref.watch(preferencesStateProvider);
    final hideBottomNav = preferences.hideBottomNavigation;
    final useQuickInputBar = preferences.useQuickInputBar;

    // Guard: if Overview tab is hidden and user is on it, switch to default tab.
    ref.listen(preferencesStateProvider, (previous, next) {
      if (previous != null &&
          previous.showOverviewTab &&
          !next.showOverviewTab &&
          ref.read(currentTabProvider) == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final fallback = await DefaultTabService.getDefaultTabIndex();
          final target = fallback == 0 ? 1 : fallback;
          if (mounted) ref.read(currentTabProvider.notifier).setTab(target);
        });
      }
    });

    ref.listen<int>(widgetTaskCreationRequestProvider, (previous, next) {
      if (previous != null && next > previous) {
        ref.read(currentTabProvider.notifier).setTab(1);
        final date = ref.read(widgetTaskCreationDateProvider);
        showAddTaskDialog(initialDate: date);
      }
    });

    // Exit multi-select modes when switching tabs
    ref.listen<int>(currentTabProvider, (previous, next) {
      if (previous == next) return;
      if (ref.read(notesMultiSelectModeProvider)) {
        ref.read(notesMultiSelectModeProvider.notifier).update(false);
        ref.read(selectedNoteIdsProvider.notifier).clear();
      }
      if (ref.read(multiSelectModeProvider)) {
        ref.read(multiSelectModeProvider.notifier).update(false);
        ref.read(selectedTodoIdsProvider.notifier).clear();
        ref.read(selectedEventIdsProvider.notifier).clear();
      }
    });

    final tabs = [
      const OverviewTab(),
      const TodoListTab(),
      const NotesScreen(),
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    final useNavigationRail = screenWidth >= 600;

    return PopScope(
      canPop:
          !isSearchMode &&
          selectedNoteFolderId == null &&
          !fabMenuExpanded &&
          !notesMultiSelectMode &&
          !tasksMultiSelectMode,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (fabMenuExpanded) {
          ref.read(fabMenuExpandedProvider.notifier).update(false);
          return;
        }

        if (notesMultiSelectMode) {
          ref.read(notesMultiSelectModeProvider.notifier).update(false);
          ref.read(selectedNoteIdsProvider.notifier).clear();
          return;
        }

        if (tasksMultiSelectMode) {
          ref.read(multiSelectModeProvider.notifier).update(false);
          ref.read(selectedTodoIdsProvider.notifier).clear();
          ref.read(selectedEventIdsProvider.notifier).clear();
          return;
        }

        if (isSearchMode) {
          ref.read(searchModeProvider.notifier).update(false);
          _searchController.clear();
          ref.read(searchQueryProvider.notifier).update('');
          ref.read(notesSearchQueryProvider.notifier).update('');
          ref.read(settingsSearchQueryProvider.notifier).update('');
          ref.read(folderSearchQueryProvider.notifier).update('');
          ref.read(noteFolderSearchQueryProvider.notifier).update('');
          return;
        }

        if (selectedNoteFolderId != null) {
          final foldersAsync = ref.read(noteFoldersProvider);
          final folders = foldersAsync.value ?? [];
          final folder = folders
              .where((f) => f.id == selectedNoteFolderId)
              .firstOrNull;

          if (folder != null && folder.isVault) {
            ref.read(selectedNoteFolderProvider.notifier).update(null);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Vault locked'),
                  duration: Duration(milliseconds: 1500),
                ),
              );
            }
            return;
          }

          // Clear folder selection for UNFILED or regular folders
          ref.read(selectedNoteFolderProvider.notifier).update(null);
          return;
        }

        // If none of the above, allow default back behavior (exit app)
      },
      child: _buildContent(
        useNavigationRail,
        tabs,
        currentTab,
        hideBottomNav,
        useQuickInputBar,
      ),
    );
  }

  Widget _buildContent(
    bool useNavigationRail,
    List<Widget> tabs,
    int currentTab,
    bool hideBottomNav,
    bool useQuickInputBar,
  ) {
    final fabMenuExpanded = ref.watch(fabMenuExpandedProvider);
    final showOverviewTab = ref.watch(preferencesStateProvider).showOverviewTab;

    if (useNavigationRail && !hideBottomNav) {
      return Stack(
        children: [
          Scaffold(
            body: Row(
              children: [
                // Material 3 NavigationRail
                NavigationRail(
                  selectedIndex: showOverviewTab
                      ? currentTab
                      : (currentTab == 0 ? 0 : currentTab - 1),
                  onDestinationSelected: (displayed) {
                    final index = showOverviewTab ? displayed : displayed + 1;
                    final previousTab = ref.read(currentTabProvider);

                    // Security: Clear vault folder selection when leaving Notes tab
                    if (previousTab == 2 && index != 2) {
                      clearVaultSelectionIfNeeded();
                    }

                    ref.read(currentTabProvider.notifier).setTab(index);
                    // Exit search mode when switching tabs
                    final isSearchMode = ref.read(searchModeProvider);
                    if (isSearchMode) {
                      ref.read(searchModeProvider.notifier).update(false);
                      _searchController.clear();
                      ref.read(searchQueryProvider.notifier).update('');
                      ref.read(notesSearchQueryProvider.notifier).update('');
                      ref.read(settingsSearchQueryProvider.notifier).update('');
                      ref.read(folderSearchQueryProvider.notifier).update('');
                      ref
                          .read(noteFolderSearchQueryProvider.notifier)
                          .update('');
                    }
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    if (showOverviewTab)
                      NavigationRailDestination(
                        icon: NavigationRailIcon(
                          icon: Icons.dashboard_outlined,
                          tabIndex: 0,
                        ),
                        selectedIcon: NavigationRailIcon(
                          icon: Icons.dashboard,
                          tabIndex: 0,
                        ),
                        label: const Text('Overview'),
                      ),
                    NavigationRailDestination(
                      icon: NavigationRailIcon(
                        icon: Icons.checklist_outlined,
                        tabIndex: 1,
                      ),
                      selectedIcon: NavigationRailIcon(
                        icon: Icons.checklist,
                        tabIndex: 1,
                      ),
                      label: const Text('Tasks'),
                    ),
                    NavigationRailDestination(
                      icon: NavigationRailIcon(
                        icon: Icons.note_outlined,
                        tabIndex: 2,
                      ),
                      selectedIcon: NavigationRailIcon(
                        icon: Icons.note,
                        tabIndex: 2,
                      ),
                      label: const Text('Notes'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                // Main content
                Expanded(
                  child: Scaffold(
                    appBar: HomeAppBar(
                      searchController: _searchController,
                      searchBarScaleAnimation: _searchBarScaleAnimation,
                      greetingFadeAnimation: _greetingFadeAnimation,
                      showSearchBar: _showSearchBar,
                      onOpenPersonalization: () =>
                          openPersonalizationScreen(() => setState(() {})),
                    ),
                    body: ref.watch(searchModeProvider)
                        ? UnifiedSearchResults(
                            searchController: _searchController,
                            onAddTask: showAddTaskDialog,
                            onEditTask: showEditTaskDialog,
                            onDeleteTask: deleteTaskWithConfirmation,
                            onEditEvent: showEditEventDialog,
                            onDeleteEvent: deleteEventWithConfirmation,
                            onEditNote: editNoteInSearch,
                            onToggleNotePin: toggleNotePin,
                            onDeleteNote: deleteNoteInSearch,
                            onDeleteNoteConfirmed: deleteNoteConfirmed,
                            onNavigateToSetting: navigateToSetting,
                          )
                        : IndexedStack(index: currentTab, children: tabs),
                  ),
                ),
              ],
            ),
          ),
          // Backdrop overlay
          const FabMenuScreenBackdrop(),
          // FAB on top
          Positioned(
            right: 16,
            bottom: 16,
            child: FabMenu(
              onAddTask: showAddTaskDialog,
              onAddNote: createNewNote,
              onAddEvent: showAddEventDialog,
              onAddFromTemplate: showTemplateSelection,
              onCreateVaultNote: createVaultNote,
              onLockVault: lockVault,
              onSearch: triggerSearch,
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        Scaffold(
          key: _scaffoldKey,
          drawer: HomeNavigationDrawer(
            currentTab: currentTab,
            isCalendarExpanded: _isCalendarExpanded,
            onCalendarToggle: () {
              setState(() {
                _isCalendarExpanded = !_isCalendarExpanded;
              });
            },
            onVaultSetup: (ctx, folder) =>
                showVaultSetupDialogWithPassword(ctx, ref, folder),
            onCreateNoteFolder: () => showCreateNoteFolderDialog(context, ref),
            onClearVaultSelection: clearVaultSelectionIfNeeded,
          ),
          drawerEdgeDragWidth:
              80.0, // Allow swipe from left edge to open drawer (increased for easier triggering)
          appBar: HomeAppBar(
            searchController: _searchController,
            searchBarScaleAnimation: _searchBarScaleAnimation,
            greetingFadeAnimation: _greetingFadeAnimation,
            showSearchBar: _showSearchBar,
            onOpenPersonalization: () =>
                openPersonalizationScreen(() => setState(() {})),
          ),
          // Wrap body in GestureDetector to unfocus quick input bar when tapping elsewhere
          body: ExpressiveGestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            enableHaptics: false,
            child: Stack(
              children: [
                ref.watch(searchModeProvider)
                    ? UnifiedSearchResults(
                        searchController: _searchController,
                        onAddTask: showAddTaskDialog,
                        onEditTask: showEditTaskDialog,
                        onDeleteTask: deleteTaskWithConfirmation,
                        onEditEvent: showEditEventDialog,
                        onDeleteEvent: deleteEventWithConfirmation,
                        onEditNote: editNoteInSearch,
                        onToggleNotePin: toggleNotePin,
                        onDeleteNote: deleteNoteInSearch,
                        onDeleteNoteConfirmed: deleteNoteConfirmed,
                        onNavigateToSetting: navigateToSetting,
                      )
                    : IndexedStack(index: currentTab, children: tabs),
                // Quick Input Bar (experimental mode) - inside Scaffold so it goes behind drawer
                if (useQuickInputBar)
                  QuickInputBottomArea(
                    currentTab: currentTab,
                    onAddTask: showAddTaskDialog,
                    onAddNote: createNewNoteWithTitle,
                    onQuickSaveNote: quickSaveNote,
                    onCreateVaultNote: createVaultNote,
                    onCreateNote: createNewNote,
                  ),
              ],
            ),
          ),
          // NavigationBar
          bottomNavigationBar: !hideBottomNav
              ? HomeNavigationBar(
                  currentTab: currentTab,
                  scaffoldKey: _scaffoldKey,
                  searchController: _searchController,
                  onClearVaultSelection: clearVaultSelectionIfNeeded,
                )
              : null,
        ),
        // Backdrop overlay (only for FAB menu mode)
        if (!useQuickInputBar) const FabMenuScreenBackdrop(),
        // FAB (only for FAB menu mode, not for Quick Input Bar mode)
        if (!useQuickInputBar)
          Builder(
            builder: (context) {
              final safeBottom = MediaQuery.viewPaddingOf(context).bottom;

              // For FAB mode, use original positioning
              final fabBottom = hideBottomNav
                  ? (24.0 + safeBottom)
                  : (130.0 + safeBottom);
              final viewToggleBottom = fabBottom + 64.0;

              // Default: FAB Menu mode
              return Stack(
                children: [
                  Positioned(
                    right: 16,
                    bottom: fabBottom,
                    child: FabMenu(
                      onAddTask: showAddTaskDialog,
                      onAddNote: createNewNote,
                      onAddEvent: showAddEventDialog,
                      onAddFromTemplate: showTemplateSelection,
                      onCreateVaultNote: createVaultNote,
                      onLockVault: lockVault,
                      onSearch: triggerSearch,
                    ),
                  ),
                  if ((currentTab == 1) && !fabMenuExpanded)
                    Positioned(
                      right:
                          20, // Offset to center-align with FAB (FAB is larger)
                      bottom: viewToggleBottom,
                      child: ExpressiveFloatingActionButton.small(
                        heroTag: 'view_toggle',
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .secondaryContainer
                            .withValues(
                              alpha: 0.7,
                            ), // Semi-transparent for subtle effect
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                        elevation: 2,
                        shape: const CircleBorder(), // Explicitly circular
                        onPressed: () {
                          final current = ref.read(taskViewTypeProvider);
                          ref
                              .read(taskViewTypeProvider.notifier)
                              .update(
                                current == TaskViewType.list
                                    ? TaskViewType.calendar
                                    : TaskViewType.list,
                              );
                        },
                        child: Icon(
                          ref.watch(taskViewTypeProvider) == TaskViewType.list
                              ? Icons.calendar_month
                              : Icons.list,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}
