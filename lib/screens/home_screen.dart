import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/todo_provider.dart';
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
  // Simple heuristic: if todos empty and categories empty very early, show lightweight loading
  final todos = ref.watch(todosProvider);
  final categories = ref.watch(categoriesProvider);
  final showLoading = todos.isEmpty && categories.isEmpty;
    
    // Define tabs
    final tabs = [
      const TodoListTab(),
      const CalendarScreen(),
      const ProgressScreen(),
    ];

    return Scaffold(
      appBar: _buildAppBar(context),
      body: showLoading
          ? const Center(child: SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3)))
          : IndexedStack(
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

    return AppBar(
      title: Text(tabTitles[currentTab]),
      actions: [
        if (currentTab == 0) // Only show search on Tasks tab
          IconButton(
            icon: Icon(PhosphorIcons.magnifyingGlass()),
            onPressed: () {
              ref.read(searchModeProvider.notifier).state = true;
            },
          ),
        PopupMenuButton<String>(
          icon: Icon(PhosphorIcons.dotsThreeVertical()),
          onSelected: (value) {
            switch (value) {
              case 'clear_completed':
                if (currentTab == 0) {
                  ref.read(todosProvider.notifier).deleteCompleted();
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
          ref.read(todosProvider.notifier).addTodo(todo);
        },
      ),
    );
  }
}
