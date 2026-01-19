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
import 'package:trudido/utils/responsive_size.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import 'dart:async';
import '../providers/filter_providers.dart';
import '../providers/clock.dart';
import '../controllers/task_controller.dart';
import '../controllers/notes_controller.dart';
import '../providers/app_providers.dart';
import '../services/default_tab_service.dart';
import '../services/folder_provider.dart';
import '../services/vault_auth_service.dart';
import '../services/vault_password_service.dart';
import '../services/biometric_auth_service.dart';
import '../services/storage_service.dart';
import '../services/greeting_service.dart';
import '../services/widget_service.dart';
// import '../services/markdown_export_service.dart'; // Commented out - for future import feature
import '../repositories/note_folder_repository.dart';
import '../models/note_folder.dart';
import '../models/todo.dart';
import '../screens/task_editor_screen.dart';
import '../screens/template_management_screen.dart';
import '../widgets/todo_list_tab.dart';
import '../widgets/fab_menu.dart';
import '../widgets/quick_input_bar.dart';
import '../widgets/create_folder_dialog.dart';
import '../utils/animated_navigation.dart';
import '../utils/week_start_utils.dart';
import '../main.dart'
    show widgetTaskCreationRequestProvider, widgetTaskCreationDateProvider;
import 'settings_screen.dart';
import 'notes_screen.dart';
import 'bin_screen.dart';
import 'vault_bin_screen.dart';
import 'quill_note_editor_screen.dart';
import 'folder_management_screen.dart';
import 'notes_folder_management_screen.dart';
import 'personalization_screen.dart';
import '../widgets/user_avatar_widget.dart';
import '../theme/spacing_tokens.dart';

// --- Moved from end of file ---
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
          padding: SpacingEdgeInsets.insets16,
          children: [
            Text(
              'Create a password/PIN to protect this vault folder',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SpacingGap.gapV24,
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
            SpacingGap.gapV16,
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
              SpacingGap.gapV16,
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
            SpacingGap.gapV24,
            ElevatedButton(
              onPressed: _submit,
              child: const Padding(
                padding: SpacingEdgeInsets.insets16,
                child: Text('Setup Vault'),
              ),
            ),
          ],
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
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isCalendarExpanded = false;
  // _isFilterExpanded removed - filters are now in the always-visible chip row

  @override
  void initState() {
    super.initState();
    // Register lifecycle observer to detect app state changes
    WidgetsBinding.instance.addObserver(this);
    // Update widget data on startup
    _updateWidgetOnStartup();
  }

  Future<void> _updateWidgetOnStartup() async {
    // Delay slightly to ensure tasks are loaded
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final tasks = ref.read(tasksProvider);
    final incomplete = tasks.where((t) => !t.isCompleted).toList();
    await WidgetService.instance.updateWidgetData(incomplete);
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
    final isSearchMode = ref.watch(searchModeProvider);
    final selectedNoteFolderId = ref.watch(selectedNoteFolderProvider);
    final fabMenuExpanded = ref.watch(fabMenuExpandedProvider);
    final preferences = ref.watch(preferencesStateProvider);
    final hideBottomNav = preferences.hideBottomNavigation;
    final useQuickInputBar = preferences.useQuickInputBar;

    // Listen for widget task creation requests
    ref.listen<int>(widgetTaskCreationRequestProvider, (previous, next) {
      if (previous != null && next > previous) {
        // Widget triggered task creation - navigate to tasks tab and open editor
        ref.read(currentTabProvider.notifier).setTab(0);
        final date = ref.read(widgetTaskCreationDateProvider);
        _showAddTaskDialog(initialDate: date);
      }
    });

    // Define tabs
    final tabs = [const TodoListTab(), const NotesScreen()];

    // Check if we should use NavigationRail for wider screens
    final screenWidth = MediaQuery.of(context).size.width;
    final useNavigationRail = screenWidth >= 600; // Material 3 breakpoint

    // Handle back navigation: close search, vault, or FAB menu before exiting app
    return PopScope(
      canPop: !isSearchMode && selectedNoteFolderId == null && !fabMenuExpanded,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Priority 1: Close FAB menu if open
        if (fabMenuExpanded) {
          ref.read(fabMenuExpandedProvider.notifier).state = false;
          return;
        }

        // Priority 2: Exit search mode if active
        if (isSearchMode) {
          ref.read(searchModeProvider.notifier).state = false;
          _searchController.clear();
          if (currentTab == 0) {
            ref.read(searchQueryProvider.notifier).state = '';
          } else if (currentTab == 1) {
            ref.read(notesSearchQueryProvider.notifier).state = '';
          }
          return;
        }

        // Priority 3: Exit vault view if in a vault
        if (selectedNoteFolderId != null) {
          final foldersAsync = ref.read(noteFoldersProvider);
          final folders = foldersAsync.valueOrNull ?? [];
          final folder = folders
              .where((f) => f.id == selectedNoteFolderId)
              .firstOrNull;

          if (folder != null && folder.isVault) {
            ref.read(selectedNoteFolderProvider.notifier).state = null;
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

    if (useNavigationRail && !hideBottomNav) {
      return Stack(
        children: [
          Scaffold(
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
                    body: IndexedStack(index: currentTab, children: tabs),
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
              onAddTask: _showAddTaskDialog,
              onAddNote: _createNewNote,
              onAddFromTemplate: _showTemplateSelection,
              onCreateVaultNote: _createVaultNote,
              onLockVault: _lockVault,
              onSearch: _triggerSearch,
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        Scaffold(
          key: _scaffoldKey,
          drawer: _buildNavigationDrawer(context, currentTab),
          drawerEdgeDragWidth:
              40.0, // Allow swipe from left edge to open drawer
          appBar: _buildAppBar(context),
          // Wrap body in GestureDetector to unfocus quick input bar when tapping elsewhere
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: Stack(
              children: [
                IndexedStack(index: currentTab, children: tabs),
                // Quick Input Bar (experimental mode) - inside Scaffold so it goes behind drawer
                if (useQuickInputBar)
                  _buildQuickInputBottomArea(
                    context,
                    currentTab,
                    hideBottomNav,
                  ),
              ],
            ),
          ),
          // NavigationBar
          bottomNavigationBar: !hideBottomNav
              ? _buildNavigationBar(context, currentTab)
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
                      onAddTask: _showAddTaskDialog,
                      onAddNote: _createNewNote,
                      onAddFromTemplate: _showTemplateSelection,
                      onCreateVaultNote: _createVaultNote,
                      onLockVault: _lockVault,
                      onSearch: _triggerSearch,
                    ),
                  ),
                  if (currentTab == 0 && !fabMenuExpanded)
                    Positioned(
                      right:
                          20, // Offset to center-align with FAB (FAB is larger)
                      bottom: viewToggleBottom,
                      child: FloatingActionButton.small(
                        heroTag: 'view_toggle',
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .secondaryContainer
                            .withOpacity(
                              0.7,
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
                              .state = current == TaskViewType.list
                              ? TaskViewType.calendar
                              : TaskViewType.list;
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

  /// Build the combined Quick Input Bar + NavigationBar bottom area as Positioned widget
  /// Stays at bottom of body, Scaffold handles keyboard resizing
  Widget _buildQuickInputBottomArea(
    BuildContext context,
    int currentTab,
    bool hideBottomNav,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine if we're in vault notes context
    final selectedFolderId = ref.watch(selectedNoteFolderProvider);
    final foldersAsync = ref.watch(noteFoldersProvider);
    final folders = foldersAsync.valueOrNull ?? [];
    final folder = selectedFolderId != null
        ? folders.where((f) => f.id == selectedFolderId).firstOrNull
        : null;
    final isVaultContext = folder != null && folder.isVault;
    final isNotesTab = currentTab == 1;

    // Background color that matches NavigationBar
    final bgColor = theme.brightness == Brightness.dark
        ? colorScheme.surface
        : colorScheme.surfaceContainerLow;

    // Calculate bottom position: always at bottom of body (which is above NavigationBar)
    // The Scaffold automatically handles keyboard by resizing the body
    const bottomPosition = 0.0;

    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomPosition,
      child: Container(
        color: bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Quick Input Bar (takes most of the space)
            Expanded(
              child: QuickInputBar(
                onAddTask: (text) => _showAddTaskDialog(presetTitle: text),
                onAddNote: (text) => _createNewNoteWithTitle(presetTitle: text),
                onQuickSaveNote: _quickSaveNote,
                onAddVaultNote: (text) =>
                    _createVaultNoteWithTitle(presetTitle: text),
                onQuickSaveVaultNote: _quickSaveNote,
              ),
            ),
            const SizedBox(width: 8),
            // Side button: Calendar switcher for Tasks, Create Note FAB for Notes
            if (currentTab == 0)
              // Tasks tab: Calendar/List switcher
              FloatingActionButton.small(
                heroTag: 'view_toggle_quick',
                backgroundColor: colorScheme.secondaryContainer,
                foregroundColor: colorScheme.onSecondaryContainer,
                elevation: 1,
                shape: const CircleBorder(),
                onPressed: () {
                  final current = ref.read(taskViewTypeProvider);
                  ref
                      .read(taskViewTypeProvider.notifier)
                      .state = current == TaskViewType.list
                      ? TaskViewType.calendar
                      : TaskViewType.list;
                },
                child: Icon(
                  ref.watch(taskViewTypeProvider) == TaskViewType.list
                      ? Icons.calendar_month
                      : Icons.list,
                ),
              )
            else if (isNotesTab)
              // Notes tab: Create full note button (pencil icon, no circle)
              IconButton(
                onPressed: isVaultContext ? _createVaultNote : _createNewNote,
                icon: Icon(Icons.edit_outlined, color: colorScheme.primary),
                tooltip: 'Open note editor',
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }

  /// Build the NavigationBar widget (extracted for reuse)
  Widget _buildNavigationBar(BuildContext context, int currentTab) {
    return NavigationBar(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? null // Use default in dark mode
          : Theme.of(context).colorScheme.surfaceContainerLow,
      selectedIndex: currentTab,
      onDestinationSelected: (index) {
        final previousTab = ref.read(currentTabProvider);

        // If tapping the same tab, open the drawer
        if (previousTab == index) {
          _scaffoldKey.currentState?.openDrawer();
          return;
        }

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
    );
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

  void _showAddTaskDialog({DateTime? initialDate, String? presetTitle}) {
    final viewType = ref.read(taskViewTypeProvider);
    final selectedDate = ref.read(selectedCalendarDateProvider);

    // Use selected calendar date as a preset only when in calendar view
    // OR if initialDate is provided (from widget)
    final DateTime? preset =
        initialDate ??
        ((viewType == TaskViewType.calendar && selectedDate != null)
            ? selectedDate
            : null);

    AnimatedNavigation.pushContainerTransform(
      context,
      TaskEditorScreen(
        presetDueDate: preset,
        presetTitle: presetTitle,
        onSave: (todo) {
          ref.read(taskControllerProvider.notifier).add(todo);
        },
      ),
    );
  }

  /// Create note with optional preset title (from quick input bar)
  void _createNewNoteWithTitle({String? presetTitle}) {
    // Get the currently selected folder to create note in
    final selectedFolderId = ref.read(selectedNoteFolderProvider);

    // Create note with WYSIWYG Quill editor
    AnimatedNavigation.pushContainerTransform(
      context,
      QuillNoteEditorScreen(
        initialFolderId: selectedFolderId,
        initialTitle: presetTitle,
      ),
    );
  }

  /// Quick save note directly without opening editor
  void _quickSaveNote(String text) async {
    if (text.isEmpty) return;

    final selectedFolderId = ref.read(selectedNoteFolderProvider);
    final controller = ref.read(notesControllerProvider.notifier);

    // Create note with "Quick Note" as title and text as content
    await controller.createNote(
      title: 'Quick Note',
      content: text,
      folderId: selectedFolderId,
    );

    // Show confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quick note saved'),
          duration: Duration(milliseconds: 1500),
        ),
      );
    }
  }

  /// Create vault note with optional preset title (from quick input bar)
  /// For simplicity, this opens the vault note flow without preset title
  /// The user can type the title in the editor after authentication
  void _createVaultNoteWithTitle({String? presetTitle}) {
    // For vault notes, we need to go through the full authentication flow
    // The preset title will be lost, but this is acceptable for the experimental feature
    // Future improvement: pass title through authentication flow
    _createVaultNote();
  }

  void _createNewNote() {
    // Get the currently selected folder to create note in
    final selectedFolderId = ref.read(selectedNoteFolderProvider);
    print('DEBUG: Creating new note with selectedFolderId: $selectedFolderId');

    // Create note with WYSIWYG Quill editor
    AnimatedNavigation.pushContainerTransform(
      context,
      QuillNoteEditorScreen(initialFolderId: selectedFolderId),
    );
  }

  Future<void> _createVaultNote() async {
    debugPrint('[Home Screen] _createVaultNote called');

    // Get all folders
    final foldersAsync = ref.read(noteFoldersProvider);
    debugPrint(
      '[Home Screen] Folders async state: ${foldersAsync.runtimeType}',
    );

    final folders = foldersAsync.valueOrNull ?? [];
    debugPrint('[Home Screen] Total folders: ${folders.length}');

    // Get vault folders
    final vaultFolders = folders.where((f) => f.isVault).toList();
    debugPrint('[Home Screen] Vault folders found: ${vaultFolders.length}');

    if (vaultFolders.isEmpty) {
      // No vaults exist - navigate to folder management to create one
      debugPrint(
        '[Home Screen] No vaults exist, navigating to folder management',
      );
      if (!mounted) {
        debugPrint('[Home Screen] Widget not mounted, aborting');
        return;
      }

      debugPrint('[Home Screen] Pushing NotesFolderManagementScreen');
      await AnimatedNavigation.pushContainerTransform(
        context,
        const NotesFolderManagementScreen(),
      );
      debugPrint('[Home Screen] Returned from NotesFolderManagementScreen');

      return;
    }

    debugPrint('[Home Screen] Using vault: ${vaultFolders.first.name}');

    // Try to use the last accessed vault, otherwise use the first one
    final lastVaultId = ref.read(lastAccessedVaultProvider);
    final defaultVault = lastVaultId != null
        ? vaultFolders.firstWhere(
            (v) => v.id == lastVaultId,
            orElse: () => vaultFolders.first,
          )
        : vaultFolders.first;

    debugPrint(
      '[Home Screen] Vault details - ID: ${defaultVault.id}, Name: ${defaultVault.name}, useBiometric: ${defaultVault.useBiometric}, hasPassword: ${defaultVault.hasPassword}',
    );

    // Check if vault needs initial setup (no password set yet)
    if (!defaultVault.hasPassword) {
      debugPrint('[Home Screen] Vault has no password, showing setup dialog');
      if (!mounted) return;

      final setupSuccess = await _showVaultSetupDialog(context, defaultVault);
      debugPrint('[Home Screen] Vault setup result: $setupSuccess');

      if (!setupSuccess) {
        debugPrint('[Home Screen] Vault setup cancelled or failed');
        return;
      }

      // Refresh folders to get updated vault with password flag
      ref.invalidate(noteFoldersProvider);
      await Future.delayed(
        const Duration(milliseconds: 100),
      ); // Give time for provider to refresh
    }

    // Authenticate vault access
    debugPrint('[Home Screen] Calling VaultAuthService.authenticate...');
    final authenticated = await VaultAuthService.authenticate(
      context: context,
      folderId: defaultVault.id,
      folderName: defaultVault.name,
      useBiometric: defaultVault.useBiometric,
      hasPassword: defaultVault.hasPassword,
    );

    debugPrint('[Home Screen] Authentication result: $authenticated');

    if (!authenticated) {
      // User cancelled or authentication failed
      debugPrint('[Home Screen] Authentication failed or cancelled');
      return;
    }

    // Authentication successful - save this vault as last accessed
    ref.read(lastAccessedVaultProvider.notifier).state = defaultVault.id;
    debugPrint('[Home Screen] Saved vault ${defaultVault.id} as last accessed');

    // Create note in vault
    debugPrint('[Home Screen] Authentication successful, creating note');
    if (!mounted) {
      debugPrint('[Home Screen] Widget not mounted, aborting');
      return;
    }

    debugPrint(
      '[Home Screen] Pushing QuillNoteEditorScreen with folder ID: ${defaultVault.id}',
    );
    AnimatedNavigation.pushContainerTransform(
      context,
      QuillNoteEditorScreen(initialFolderId: defaultVault.id),
    );
    debugPrint('[Home Screen] Note editor pushed');
  }

  void _showTemplateSelection() {
    AnimatedNavigation.pushContainerTransform(
      context,
      const TemplateManagementScreen(),
    );
  }

  void _lockVault() {
    // Clear the selected folder to exit vault view
    ref.read(selectedNoteFolderProvider.notifier).state = null;

    // Close FAB menu
    ref.read(fabMenuExpandedProvider.notifier).state = false;

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vault locked'),
        duration: Duration(milliseconds: 1500),
      ),
    );
  }

  void _triggerSearch() {
    // Activate search mode
    // Note: Search behavior depends on context:
    // - In a vault: Search is scoped to that specific vault only
    // - Global (not in vault): Search excludes all vault content for security
    // This is handled automatically via filteredNotesProvider and filteredTasksProvider
    ref.read(searchModeProvider.notifier).state = true;

    // Close FAB menu
    ref.read(fabMenuExpandedProvider.notifier).state = false;
  }

  // Commented out - kept for potential future use
  // Future<void> _importNotes() async {
  //   try {
  //     final result = await MarkdownExportService.importNotesFromFiles();

  //     if (!mounted) return;

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(result.message),
  //         backgroundColor: result.success ? Colors.green : Colors.red,
  //         behavior: SnackBarBehavior.floating,
  //       ),
  //     );
  //   } catch (e) {
  //     if (!mounted) return;
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Import failed: $e'),
  //         backgroundColor: Colors.red,
  //         behavior: SnackBarBehavior.floating,
  //       ),
  //     );
  //   }
  // }

  /// Shows note folder creation dialog
  Future<void> _showCreateNoteFolderDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isVault = false;
    String noteFormat = 'markdown'; // Default to markdown

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Note Folder'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Folder Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a folder name';
                      }
                      return null;
                    },
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                  ),
                  SpacingGap.gapV16,
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  SpacingGap.gapV16,
                  SpacingGap.gapV16,
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Encrypted Vault Folder'),
                    subtitle: const Text(
                      'Notes will be encrypted with AES-256',
                      style: TextStyle(fontSize: 12),
                    ),
                    secondary: Icon(
                      isVault ? Icons.lock : Icons.lock_open,
                      color: isVault ? Colors.amber : null,
                    ),
                    value: isVault,
                    onChanged: (value) {
                      setDialogState(() {
                        isVault = value ?? false;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final name = nameController.text.trim();
                  final description = descriptionController.text.trim();

                  // If vault, setup password and biometric preferences
                  String? vaultPassword;
                  bool useBiometric = true;

                  if (isVault) {
                    // Show password setup dialog
                    final passwordResult =
                        await _showPasswordSetupDialogForFolder(context, name);

                    if (passwordResult == null) {
                      return; // User cancelled
                    }

                    vaultPassword = passwordResult['password'] as String;
                    useBiometric = passwordResult['useBiometric'] as bool;
                  }

                  // Create the folder first
                  final result = await ref
                      .read(noteFoldersProvider.notifier)
                      .createFolder(
                        name: name,
                        description: description.isEmpty ? null : description,
                        isVault: isVault,
                        hasPassword: isVault && vaultPassword != null,
                        useBiometric: useBiometric,
                        noteFormat: noteFormat,
                      );

                  if (mounted) {
                    if (result != null) {
                      // Store the password if vault
                      if (isVault && vaultPassword != null) {
                        await VaultPasswordService.setVaultPassword(
                          result.id,
                          vaultPassword,
                        );
                      }

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Folder "$name" created successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Failed to create folder. Name may already exist.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows password setup dialog for vault folders
  Future<Map<String, dynamic>?> _showPasswordSetupDialogForFolder(
    BuildContext context,
    String folderName,
  ) async {
    final formKey = GlobalKey<FormState>();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscurePassword = true;
    bool obscureConfirm = true;
    bool useBiometric = true;

    // Check if biometric is available
    final biometricAvailable =
        await BiometricAuthService.isBiometricsAvailable();

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Setup Password for $folderName'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create a password/PIN to protect this vault folder',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  SpacingGap.gapV16,
                  TextFormField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password/PIN',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
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
                  SpacingGap.gapV16,
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            obscureConfirm = !obscureConfirm;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value != passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  if (biometricAvailable) ...[
                    SpacingGap.gapV16,
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Use Biometric Shortcut'),
                      subtitle: const Text(
                        'Skip password with fingerprint/face recognition',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: useBiometric,
                      onChanged: (value) {
                        setState(() {
                          useBiometric = value ?? true;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, {
                    'password': passwordController.text,
                    'useBiometric': useBiometric,
                  });
                }
              },
              child: const Text('Setup'),
            ),
          ],
        ),
      ),
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
        backgroundColor: Theme.of(context).colorScheme.primary,
        textColor: Theme.of(context).colorScheme.onPrimary,
        child: iconWidget,
      );
    }

    return iconWidget;
  }

  /// Builds a cycling theme mode icon button for the drawer header
  Widget _buildThemeCycleIcon({
    required String currentMode,
    required ColorScheme colorScheme,
  }) {
    // Determine current icon and next mode
    IconData icon;
    String tooltip;
    String nextMode;

    switch (currentMode) {
      case 'light':
        icon = Icons.wb_sunny;
        tooltip = 'Light mode (tap for Dark)';
        nextMode = 'dark';
        break;
      case 'dark':
        icon = Icons.nightlight_round;
        tooltip = 'Dark mode (tap for Auto)';
        nextMode = 'system';
        break;
      case 'system':
      default:
        icon = Icons.brightness_auto;
        tooltip = 'Auto mode (tap for Light)';
        nextMode = 'light';
        break;
    }

    return IconButton(
      icon: Icon(icon),
      iconSize: 20,
      color: colorScheme.primary,
      tooltip: tooltip,
      onPressed: () async {
        // Cycle to next theme mode
        final prefsService = ref.read(preferencesServiceProvider);
        final updated = await prefsService.update(themeMode: nextMode);
        ref.read(preferencesStateProvider.notifier).state = updated;
      },
    );
  }

  /// Builds the navigation drawer with contextual folders and common actions
  Widget _buildNavigationDrawer(BuildContext context, int currentTab) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final preferences = ref.watch(preferencesStateProvider);

    // Check if current theme is dark-only (Hack or Dracula)
    final isDarkOnlyTheme =
        !preferences.useDynamicColor &&
        (preferences.accentColorSeed == 0xFF00FF00 || // Hack theme
            preferences.accentColorSeed == 0xFFBD93F9); // Dracula theme

    // Check if AMOLED black theme is enabled
    final isAmoledBlack =
        preferences.useBlackTheme &&
        Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isAmoledBlack ? Colors.black : colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer header with theme switcher
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
              child: Row(
                children: [
                  // App name
                  Text(
                    'Trudido',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  // Theme mode cycling icon (hidden for dark-only themes)
                  if (!isDarkOnlyTheme)
                    _buildThemeCycleIcon(
                      currentMode: preferences.themeMode,
                      colorScheme: colorScheme,
                    ),
                ],
              ),
            ),

            // Folders section
            Expanded(
              child: currentTab == 0
                  ? _buildTaskFoldersList(context)
                  : _buildNoteFoldersList(context),
            ),

            // Common actions section
            _buildDrawerActions(context),
          ],
        ),
      ),
    );
  }

  /// Builds the task folders list for the drawer
  Widget _buildTaskFoldersList(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foldersAsync = ref.watch(folderNotifierProvider);
    final selectedFolderId = ref.watch(selectedFolderProvider);

    return foldersAsync.when(
      data: (folders) {
        return ListView(
          padding: SpacingEdgeInsets.insetsV8,
          children: [
            // "All Tasks" option
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: Icon(
                Icons.folder_outlined,
                size: 20,
                color: selectedFolderId == null
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              title: Text(
                'All Tasks',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: selectedFolderId == null
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                  fontWeight: selectedFolderId == null
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              selected: selectedFolderId == null,
              selectedTileColor: colorScheme.secondaryContainer.withOpacity(
                0.3,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: SpacingBorderRadius.md,
              ),
              onTap: () {
                ref.read(selectedFolderProvider.notifier).state = null;
                Navigator.of(context).pop(); // Close drawer
              },
            ),
            // Individual folders
            ...folders.map((folder) {
              final isSelected = selectedFolderId == folder.id;
              return ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: Icon(
                  _getIconData(folder.icon),
                  size: 20,
                  color: isSelected ? colorScheme.primary : Color(folder.color),
                ),
                title: Text(
                  folder.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                selected: isSelected,
                selectedTileColor: colorScheme.secondaryContainer.withOpacity(
                  0.3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: SpacingBorderRadius.md,
                ),
                onTap: () {
                  ref.read(selectedFolderProvider.notifier).state = folder.id;
                  Navigator.of(context).pop(); // Close drawer
                },
              );
            }),
            // Create new folder option at the bottom
            SpacingGap.gapV8,
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: Icon(Icons.add, size: 20, color: colorScheme.primary),
              title: Text(
                'Create Folder',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop(); // Close drawer
                // Show create folder dialog directly
                showDialog(
                  context: context,
                  builder: (context) => const CreateFolderDialog(),
                );
              },
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Padding(
          padding: SpacingEdgeInsets.insets16,
          child: Text(
            'Error loading folders',
            style: TextStyle(color: colorScheme.error),
          ),
        ),
      ),
    );
  }

  /// Builds the note folders list for the drawer
  Widget _buildNoteFoldersList(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foldersAsync = ref.watch(noteFoldersProvider);
    final selectedFolderId = ref.watch(selectedNoteFolderProvider);

    return foldersAsync.when(
      data: (folders) {
        return ListView(
          padding: SpacingEdgeInsets.insetsV8,
          children: [
            // "All Notes" option
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: Icon(
                Icons.folder_outlined,
                size: 20,
                color: selectedFolderId == null
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              title: Text(
                'All Notes',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: selectedFolderId == null
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                  fontWeight: selectedFolderId == null
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              selected: selectedFolderId == null,
              selectedTileColor: colorScheme.secondaryContainer.withOpacity(
                0.3,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: SpacingBorderRadius.md,
              ),
              onTap: () {
                ref.read(selectedNoteFolderProvider.notifier).state = null;
                Navigator.of(context).pop(); // Close drawer
              },
            ),
            // Individual folders
            ...folders.map((folder) {
              final isSelected = selectedFolderId == folder.id;
              final isVault = folder.isVault;
              return ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: Icon(
                  isVault
                      ? (isSelected ? Icons.lock_open : Icons.lock)
                      : Icons.folder_outlined,
                  size: 20,
                  color: isSelected
                      ? colorScheme.primary
                      : (isVault ? Colors.amber : colorScheme.onSurfaceVariant),
                ),
                title: Text(
                  folder.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                selected: isSelected,
                selectedTileColor: colorScheme.secondaryContainer.withOpacity(
                  0.3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: SpacingBorderRadius.md,
                ),
                onTap: () async {
                  // Handle vault authentication
                  if (isVault && !folder.hasPassword) {
                    // First-time setup
                    final success = await _showVaultSetupDialog(
                      context,
                      folder,
                    );
                    if (!success) {
                      return;
                    }
                  } else if (isVault && folder.hasPassword) {
                    // Require authentication for vault folders with password
                    final authenticated = await VaultAuthService.authenticate(
                      context: context,
                      folderId: folder.id,
                      folderName: folder.name,
                      useBiometric: folder.useBiometric,
                      hasPassword: folder.hasPassword,
                    );

                    if (!authenticated) {
                      if (context.mounted) {
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

                    // Track last accessed vault
                    ref.read(lastAccessedVaultProvider.notifier).state =
                        folder.id;
                  }

                  ref.read(selectedNoteFolderProvider.notifier).state =
                      folder.id;
                  if (context.mounted) {
                    Navigator.of(context).pop(); // Close drawer
                  }
                },
              );
            }),
            // Create new folder option at the bottom
            SpacingGap.gapV8,
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: Icon(Icons.add, size: 20, color: colorScheme.primary),
              title: Text(
                'Create Folder',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop(); // Close drawer
                // Show create note folder dialog directly
                _showCreateNoteFolderDialog();
              },
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Padding(
          padding: SpacingEdgeInsets.insets16,
          child: Text(
            'Error loading folders',
            style: TextStyle(color: colorScheme.error),
          ),
        ),
      ),
    );
  }

  /// Builds the common actions section of the drawer
  Widget _buildDrawerActions(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentTab = ref.watch(currentTabProvider);

    return Column(
      children: [
        // Calendar section (only for Tasks tab)
        if (currentTab == 0) _buildCompactCalendar(context),

        // Filter section removed - filters are now in the always-visible chip row on the Tasks tab

        // Manage Folders action
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: Icon(
            Icons.folder_special_outlined,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          title: Text('Manage Folders', style: theme.textTheme.bodyMedium),
          onTap: () {
            Navigator.of(context).pop(); // Close drawer
            _clearVaultSelectionIfNeeded();
            if (currentTab == 0) {
              // Tasks folders
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const FolderManagementScreen(),
                ),
              );
            } else {
              // Notes folders
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const NotesFolderManagementScreen(),
                ),
              );
            }
          },
        ),

        // Bin
        Consumer(
          builder: (context, ref, child) {
            final selectedFolderId = ref.watch(selectedNoteFolderProvider);
            final folders = ref.watch(noteFoldersProvider).valueOrNull ?? [];
            final folder = folders
                .where((f) => f.id == selectedFolderId)
                .firstOrNull;
            final isVault = folder?.isVault == true;

            return ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: Icon(
                Icons.delete_outline,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
              title: Text(
                isVault
                    ? 'Vault Bin'
                    : (currentTab == 0 ? 'Tasks Bin' : 'Notes Bin'),
                style: theme.textTheme.bodyMedium,
              ),
              onTap: () {
                Navigator.of(context).pop(); // Close drawer

                if (isVault) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VaultBinScreen(),
                    ),
                  );
                } else {
                  _clearVaultSelectionIfNeeded();
                  // Navigate to appropriate bin based on current tab
                  if (currentTab == 0) {
                    // Tasks Bin
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BinScreen(initialTab: 0),
                      ),
                    );
                  } else {
                    // Notes Bin
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BinScreen(initialTab: 1),
                      ),
                    );
                  }
                }
              },
            );
          },
        ),

        // Settings
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: Icon(
            Icons.settings_outlined,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          title: Text('Settings', style: theme.textTheme.bodyMedium),
          onTap: () {
            Navigator.of(context).pop(); // Close drawer
            _clearVaultSelectionIfNeeded();
            AnimatedNavigation.push(context, const SettingsScreen());
          },
        ),
      ],
    );
  }

  /// Builds a compact collapsible calendar for the drawer
  Widget _buildCompactCalendar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedDate = ref.watch(selectedCalendarDateProvider);
    final tasks = ref.watch(filteredTasksProvider);

    return Column(
      children: [
        // Calendar header with expand/collapse
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: Icon(
            Icons.calendar_month,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          title: Text('Calendar', style: theme.textTheme.bodyMedium),
          trailing: Icon(
            _isCalendarExpanded ? Icons.expand_less : Icons.expand_more,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          onTap: () {
            setState(() {
              _isCalendarExpanded = !_isCalendarExpanded;
            });
          },
        ),

        // Expandable calendar
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(
              8,
              0,
              8,
              8,
            ), // Custom asymmetric padding
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: SpacingBorderRadius.md,
              ),
              child: TableCalendar<Todo>(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: selectedDate ?? DateTime.now(),
                selectedDayPredicate: (day) => isSameDay(selectedDate, day),
                calendarFormat: CalendarFormat.month,
                startingDayOfWeek: WeekStartUtils.toTableCalendarDay(
                  ref.watch(preferencesStateProvider).firstDayOfWeek,
                ),

                // Event loader - get tasks for each day
                eventLoader: (day) {
                  return tasks.where((task) {
                    if (task.dueDate == null) return false;
                    final taskDate = DateTime(
                      task.dueDate!.year,
                      task.dueDate!.month,
                      task.dueDate!.day,
                    );
                    final checkDate = DateTime(day.year, day.month, day.day);
                    return taskDate.isAtSameMomentAs(checkDate);
                  }).toList();
                },

                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  leftChevronIcon: Icon(
                    Icons.chevron_left,
                    size: 20,
                    color: colorScheme.onSurface,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: colorScheme.onSurface,
                  ),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  weekendStyle: TextStyle(
                    fontSize: 11,
                    color: colorScheme.error.withOpacity(0.7),
                  ),
                ),
                calendarStyle: CalendarStyle(
                  cellMargin: const EdgeInsets.all(2),
                  cellPadding: const EdgeInsets.all(0),
                  // Make today decoration transparent so custom builder can handle it
                  todayDecoration: const BoxDecoration(),
                  todayTextStyle: TextStyle(
                    fontSize: 12,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  // No special styling for selected day in compact calendar
                  selectedDecoration: const BoxDecoration(),
                  selectedTextStyle: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface,
                  ),
                  defaultTextStyle: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface,
                  ),
                  weekendTextStyle: TextStyle(
                    fontSize: 12,
                    color: colorScheme.error,
                  ),
                  outsideTextStyle: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withOpacity(0.3),
                  ),
                ),

                // Custom marker builder - show task indicators (left bars) and today indicator
                calendarBuilders: CalendarBuilders<Todo>(
                  // Custom today builder with underline (only for today)
                  todayBuilder: (context, day, focusedDay) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          height: 1.5,
                          width: 14,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(0.75),
                          ),
                        ),
                      ],
                    );
                  },

                  // Selected day builder - show underline only if it's today
                  selectedBuilder: (context, day, focusedDay) {
                    // Check if selected day is today
                    final now = DateTime.now();
                    final isToday =
                        day.year == now.year &&
                        day.month == now.month &&
                        day.day == now.day;

                    if (isToday) {
                      // Show same indicator as today
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            height: 1.5,
                            width: 14,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(0.75),
                            ),
                          ),
                        ],
                      );
                    }

                    // For other selected days, show normal text (no indicator)
                    return null;
                  },

                  markerBuilder: (context, day, events) {
                    if (events.isEmpty) return const SizedBox.shrink();

                    // Sort events: tasks with calendar colors first, then by priority
                    final sortedEvents = events.toList()
                      ..sort((a, b) {
                        // First sort by whether they have a calendar color
                        final aHasColor = a.sourceCalendarColor != null;
                        final bHasColor = b.sourceCalendarColor != null;
                        if (aHasColor != bHasColor) {
                          return aHasColor ? -1 : 1;
                        }
                        // Then by priority
                        const priorityOrder = {
                          'high': 0,
                          'medium': 1,
                          'low': 2,
                          'none': 3,
                        };
                        final aPriority =
                            priorityOrder[a.priority.toLowerCase()] ?? 4;
                        final bPriority =
                            priorityOrder[b.priority.toLowerCase()] ?? 4;
                        return aPriority.compareTo(bPriority);
                      });

                    const maxBars = 2;
                    final bars = sortedEvents.take(maxBars).toList();
                    final extra = sortedEvents.length - bars.length;

                    return Positioned(
                      top: 2,
                      bottom: 2,
                      left: 2,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var event in bars)
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 0.5),
                              width: 3,
                              height: 6,
                              decoration: BoxDecoration(
                                // Use calendar color if available, otherwise priority color
                                color: event.sourceCalendarColor != null
                                    ? Color(event.sourceCalendarColor!)
                                    : _getColorForPriority(
                                        event.priority,
                                        colorScheme,
                                      ),
                                borderRadius: BorderRadius.circular(1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          if (extra > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Text(
                                '+$extra',
                                style: TextStyle(
                                  fontSize: 6,
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),

                onDaySelected: (selectedDay, focusedDay) {
                  // Set the selected date to the tapped day
                  ref
                      .read(selectedCalendarDateProvider.notifier)
                      .state = DateTime(
                    selectedDay.year,
                    selectedDay.month,
                    selectedDay.day,
                  );
                  // Switch to calendar view
                  ref.read(taskViewTypeProvider.notifier).state =
                      TaskViewType.calendar;
                  // Close drawer
                  Navigator.of(context).pop();
                },

                // Handle page changes to update focused day
                onPageChanged: (focusedDay) {
                  // Update focused day when user navigates months
                  ref
                      .read(selectedCalendarDateProvider.notifier)
                      .state = DateTime(
                    focusedDay.year,
                    focusedDay.month,
                    focusedDay.day,
                  );
                },
              ),
            ),
          ),
          crossFadeState: _isCalendarExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  /// Helper method to get color for task priority
  Color _getColorForPriority(String priority, ColorScheme colorScheme) {
    switch (priority.toLowerCase()) {
      case 'high':
        return colorScheme.error;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.blue;
      default:
        return colorScheme.tertiary;
    }
  }

  /// Builds greeting widget for AppBar based on current tab
  Widget _buildGreeting(int currentTab) {
    if (currentTab == 0) {
      // Tasks tab - show greeting with statistics
      return _buildTasksGreeting();
    } else {
      // Notes tab - show creative greeting
      return _buildNotesGreeting();
    }
  }

  /// Builds tasks greeting with time-based subtitle
  Widget _buildTasksGreeting() {
    final userName = StorageService.getUserName();
    final hour = ref.read(clockProvider).now().hour;
    final theme = Theme.of(context);
    final preferences = ref.watch(preferencesStateProvider);
    final languageIndex = preferences.greetingLanguage;

    final greeting = GreetingService.getGreeting(
      hour: hour,
      languageIndex: languageIndex,
      userName: userName,
    );
    final subtitle = GreetingService.getTasksSubtitle(
      hour: hour,
      languageIndex: languageIndex,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          greeting,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700, // Bold for prominence
            color: theme.colorScheme.primary,
            fontSize: 17,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500, // Medium for better readability
            color: theme.colorScheme.secondary.withOpacity(0.8),
            fontSize: 13,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Builds notes greeting
  Widget _buildNotesGreeting() {
    final userName = StorageService.getUserName();
    final hour = ref.read(clockProvider).now().hour;
    final theme = Theme.of(context);
    final preferences = ref.watch(preferencesStateProvider);
    final languageIndex = preferences.greetingLanguage;

    final greeting = GreetingService.getGreeting(
      hour: hour,
      languageIndex: languageIndex,
      userName: userName,
    );
    final subtitle = GreetingService.getNotesSubtitle(
      hour: hour,
      languageIndex: languageIndex,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          greeting,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700, // Bold for prominence
            color: theme.colorScheme.primary,
            fontSize: 17,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500, // Medium for better readability
            color: theme.colorScheme.secondary.withOpacity(0.8),
            fontSize: 13,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Navigate to personalization screen
  void _openPersonalizationScreen() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => const PersonalizationScreen(),
          ),
        )
        .then((_) {
          // Refresh the greeting when returning from personalization
          setState(() {});
        });
  }

  // _buildCompactFilter removed - filters are now in the always-visible chip row on the Tasks tab

  /// Returns the appropriate tooltip for the current tab and context
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final isSearchMode = ref.watch(searchModeProvider);
    final currentTab = ref.watch(currentTabProvider);
    final preferences = ref.watch(preferencesStateProvider);

    // Check if AMOLED black theme is enabled
    final isAmoledBlack =
        preferences.useBlackTheme &&
        Theme.of(context).brightness == Brightness.dark;

    if (isSearchMode && (currentTab == 0 || currentTab == 1)) {
      // Material 3 compliant search AppBar
      final theme = Theme.of(context);
      final colorScheme = theme.colorScheme;

      return AppBar(
        backgroundColor: isAmoledBlack ? Colors.black : colorScheme.surface,
        surfaceTintColor: isAmoledBlack
            ? Colors.transparent
            : colorScheme.surfaceTint,
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
    final colorScheme = Theme.of(context).colorScheme;

    // Simplified AppBar with menu button, title, and actions
    return AppBar(
      backgroundColor: isAmoledBlack ? Colors.black : colorScheme.surface,
      surfaceTintColor: isAmoledBlack
          ? Colors.transparent
          : colorScheme.surfaceTint,
      // Leading: Menu button to open drawer (or close button in multi-select mode)
      leading: multiMode
          ? IconButton(
              icon: ScaledIcon(Icons.close),
              onPressed: () {
                ref.read(multiSelectModeProvider.notifier).state = false;
                ref.read(selectedTodoIdsProvider.notifier).clear();
              },
            )
          : Builder(
              builder: (context) => IconButton(
                icon: ScaledIcon(Icons.menu, color: colorScheme.primary),
                tooltip: 'Open menu',
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              ),
            ),
      // Title: App name or selection count
      title: multiMode && currentTab == 0
          ? Text(
              '${selectedIds.length} selected',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            )
          : _buildGreeting(currentTab),
      // Actions: avatar button and delete button in multi-select mode
      actions: [
        // View toggle button for Notes tab
        if (currentTab == 1 && !multiMode)
          Consumer(
            builder: (context, ref, _) {
              final viewMode = ref.watch(notesViewModeProvider);
              return IconButton(
                icon: Icon(
                  viewMode == 'grid'
                      ? Icons.view_list_outlined
                      : Icons.dashboard_outlined,
                  color: colorScheme.primary,
                ),
                tooltip: viewMode == 'grid' ? 'List view' : 'Grid view',
                onPressed: () {
                  ref.read(notesViewModeProvider.notifier).state =
                      viewMode == 'grid' ? 'list' : 'grid';
                },
              );
            },
          ),
        // Delete button in multi-select mode
        if (currentTab == 0 && multiMode)
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: selectedIds.isEmpty
                  ? colorScheme.onSurface.withAlpha(100)
                  : colorScheme.error,
            ),
            tooltip: 'Delete',
            onPressed: selectedIds.isEmpty
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Move to Bin'),
                        content: Text(
                          'Move ${selectedIds.length} selected ${selectedIds.length == 1 ? 'task' : 'tasks'} to bin? You can restore them later from the Bin.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(
                              'Move to Bin',
                              style: TextStyle(color: colorScheme.error),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      final controller = ref.read(
                        taskControllerProvider.notifier,
                      );
                      await controller.bulkDelete(selectedIds);
                      ref.read(selectedTodoIdsProvider.notifier).clear();
                      ref.read(multiSelectModeProvider.notifier).state = false;
                    }
                  },
          ),
        // Profile avatar button (always visible when not in multi-select mode)
        if (!multiMode)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: UserAvatarWidget(
              radius: 18,
              onTap: _openPersonalizationScreen,
            ),
          ),
      ],
    );
  }

  // Individual folders

  /// Build the view toggle for switching between list and calendar views
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
        return Icons.folder_outlined;
    }
  }
}
