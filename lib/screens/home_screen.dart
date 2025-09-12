import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../providers/filter_providers.dart';
import '../controllers/task_controller.dart';
import '../controllers/notes_controller.dart';
import '../providers/app_providers.dart';
import '../services/default_tab_service.dart';
import '../widgets/add_todo_dialog.dart';
import '../widgets/todo_list_tab.dart';
import 'calendar_screen.dart';
import 'progress_screen.dart';
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
  final isSearchMode = ref.watch(searchModeProvider);
  // Removed ambiguous loading heuristic that prevented legitimate empty state UI.
    
    // Define tabs
    final tabs = [
      const TodoListTab(),
      const CalendarScreen(),
      const NotesScreen(),
      const ProgressScreen(),
    ];

  final fabPosition = ref.watch(fabPositionProvider);
  final fabLocation = fabPosition == 'center'
    ? FloatingActionButtonLocation.centerFloat
    : fabPosition == 'left'
      ? FloatingActionButtonLocation.startFloat
      : FloatingActionButtonLocation.endFloat;
  return Scaffold(
      appBar: _buildAppBar(context),
      body: IndexedStack(
        index: currentTab,
        children: tabs,
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        selectedIndex: currentTab,
        onDestinationSelected: (index) {
          final previousTab = ref.read(currentTabProvider);
          ref.read(currentTabProvider.notifier).setTab(index);
          // Exit search mode when switching tabs
          if (isSearchMode) {
            ref.read(searchModeProvider.notifier).state = false;
            _searchController.clear();
            if (previousTab == 0) {
              ref.read(searchQueryProvider.notifier).state = '';
            } else if (previousTab == 2) {
              ref.read(notesSearchQueryProvider.notifier).state = '';
            }
          }
        },
        destinations: [
          NavigationDestination(
            icon: Icon(PhosphorIcons.listChecks()),
            selectedIcon: Icon(PhosphorIcons.listChecks(PhosphorIconsStyle.fill)),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(PhosphorIcons.calendar()),
            selectedIcon: Icon(PhosphorIcons.calendar(PhosphorIconsStyle.fill)),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(PhosphorIcons.noteBlank()),
            selectedIcon: Icon(PhosphorIcons.noteBlank(PhosphorIconsStyle.fill)),
            label: 'Notes',
          ),
          NavigationDestination(
            icon: Icon(PhosphorIcons.chartBar()),
            selectedIcon: Icon(PhosphorIcons.chartBar(PhosphorIconsStyle.fill)),
            label: 'Progress',
          ),
        ],
      ),
      floatingActionButtonLocation: fabLocation,
      floatingActionButton: _buildFloatingActionButton(currentTab),
    );
  }

  Widget? _buildFloatingActionButton(int currentTab) {
    switch (currentTab) {
      case 0: // Tasks
        return FloatingActionButton(
          onPressed: () => _showAddDialog(context),
          child: Icon(PhosphorIcons.plus()),
        );
      case 2: // Notes
        return FloatingActionButton(
          onPressed: _createNewNote,
          child: Icon(PhosphorIcons.plus()),
        );
      default:
        return null;
    }
  }

  void _createNewNote() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const NoteEditorScreen(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final isSearchMode = ref.watch(searchModeProvider);
    final currentTab = ref.watch(currentTabProvider);
    
    // Define tab titles
    final tabTitles = ['Tasks', 'Calendar', 'Notes', 'Progress'];
    
    if (isSearchMode && (currentTab == 0 || currentTab == 2)) {
      return AppBar(
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft()),
          onPressed: () {
            ref.read(searchModeProvider.notifier).state = false;
            _searchController.clear();
            if (currentTab == 0) {
              ref.read(searchQueryProvider.notifier).state = '';
            } else if (currentTab == 2) {
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
            } else if (currentTab == 2) {
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
                } else if (currentTab == 2) {
                  ref.read(notesSearchQueryProvider.notifier).state = '';
                }
              },
            ),
        ],
      );
    }

    final multiMode = ref.watch(multiSelectModeProvider);
    final selectedIds = ref.watch(selectedTodoIdsProvider);
    return AppBar(
      leading: multiMode
          ? IconButton(
              icon: Icon(PhosphorIcons.x()),
              onPressed: () {
                ref.read(multiSelectModeProvider.notifier).state = false;
                ref.read(selectedTodoIdsProvider.notifier).clear();
              },
            )
          : null,
      title: multiMode && currentTab == 0
          ? Text('${selectedIds.length} selected')
          : Text(tabTitles[currentTab]),
      actions: [
        // Search - Primary action for Tasks and Notes
        if ((currentTab == 0 || currentTab == 2) && !multiMode)
          IconButton(
            icon: Icon(PhosphorIcons.magnifyingGlass()),
            onPressed: () {
              ref.read(searchModeProvider.notifier).state = true;
            },
            tooltip: 'Search',
          ),
          
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
        
        // Single consistent overflow menu (global actions)
        PopupMenuButton<String>(
          icon: Icon(PhosphorIcons.dotsThreeVertical()),
          tooltip: 'More options',
          onSelected: (value) {
            switch (value) {
              case 'settings':
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
                break;
              case 'help':
                // TODO: Add help screen or link
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Help feature coming soon')),
                );
                break;
              case 'about':
                // TODO: Add about dialog
                showAboutDialog(
                  context: context,
                  applicationName: 'Todo App',
                  applicationVersion: '1.0.0',
                  applicationIcon: Icon(PhosphorIcons.listChecks()),
                );
                break;
            }
          },
          itemBuilder: (context) => [
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
    );
  }

  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddTodoDialog(
        onAdd: (todo) {
          ref.read(taskControllerProvider.notifier).add(todo);
        },
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
