import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../providers/filter_providers.dart';
import '../controllers/task_controller.dart';
import '../providers/app_providers.dart';
import '../widgets/add_todo_dialog.dart';
import '../widgets/todo_list_tab.dart';
import 'calendar_screen.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';

// Provider for tracking search mode state
final searchModeProvider = StateProvider<bool>((ref) => false);

// Provider for current tab index
final currentTabProvider = StateProvider<int>((ref) => 0);

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
          ref.read(currentTabProvider.notifier).state = index;
          // Exit search mode when switching tabs
          if (isSearchMode) {
            ref.read(searchModeProvider.notifier).state = false;
            _searchController.clear();
            ref.read(searchQueryProvider.notifier).state = '';
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
            icon: Icon(PhosphorIcons.chartBar()),
            selectedIcon: Icon(PhosphorIcons.chartBar(PhosphorIconsStyle.fill)),
            label: 'Progress',
          ),
        ],
      ),
      floatingActionButtonLocation: fabLocation,
      floatingActionButton: currentTab == 0 ? FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: Icon(PhosphorIcons.plus()),
      ) : null,
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final isSearchMode = ref.watch(searchModeProvider);
    final currentTab = ref.watch(currentTabProvider);
    
    // Define tab titles
    final tabTitles = ['Tasks', 'Calendar', 'Progress'];
    
    if (isSearchMode && currentTab == 0) {
      return AppBar(
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft()),
          onPressed: () {
            ref.read(searchModeProvider.notifier).state = false;
            _searchController.clear();
            ref.read(searchQueryProvider.notifier).state = '';
          },
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search tasks...',
            border: InputBorder.none,
          ),
          onChanged: (value) {
            ref.read(searchQueryProvider.notifier).state = value;
          },
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(PhosphorIcons.x()),
              onPressed: () {
                _searchController.clear();
                ref.read(searchQueryProvider.notifier).state = '';
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
        if (currentTab == 0 && !multiMode)
          IconButton(
            icon: Icon(PhosphorIcons.magnifyingGlass()),
            onPressed: () {
              ref.read(searchModeProvider.notifier).state = true;
            },
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
        PopupMenuButton<String>(
          icon: Icon(PhosphorIcons.dotsThreeVertical()),
          onSelected: (value) {
            switch (value) {
              case 'clear_completed':
                if (currentTab == 0) {
                  ref.read(taskControllerProvider.notifier).clearCompleted();
                }
                break;
              case 'settings':
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
                break;
              // 'reliability' case removed (now accessible via Settings screen)
            }
          },
          itemBuilder: (context) => [
            if (currentTab == 0)
              PopupMenuItem(
                value: 'clear_completed',
                child: Row(
                  children: [
                    Icon(PhosphorIcons.trash()),
                    const SizedBox(width: 8),
                    const Text('Clear completed'),
                  ],
                ),
              ),
            // Notification test item removed (legacy plugin-based screen)
            PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(PhosphorIcons.gear()),
                  const SizedBox(width: 8),
                  const Text('Settings'),
                ],
              ),
            ),
            // Removed duplicate Reminder Reliability entry
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
