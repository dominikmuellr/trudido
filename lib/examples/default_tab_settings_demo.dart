import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Complete Flutter app demonstrating default starting tab setting
/// 
/// This solution allows users to select their preferred starting tab
/// and persists the choice using SharedPreferences for future app launches.
/// 
/// Key Features:
/// - Settings screen with tab selection
/// - SharedPreferences for persistence
/// - Dynamic startup logic
/// - Material Design 3 UI
/// - Android best practices compliance
void main() {
  runApp(const DefaultTabSettingsApp());
}

class DefaultTabSettingsApp extends StatelessWidget {
  const DefaultTabSettingsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Default Tab Settings Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const MainScreen(),
    );
  }
}

/// Main screen with BottomNavigationBar and dynamic startup logic
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const String _defaultTabKey = 'default_starting_tab';
  int _currentIndex = 0;
  bool _isLoading = true;

  // Tab configuration - matches your app structure
  final List<TabConfig> _tabs = [
    TabConfig('tasks', 'Tasks', PhosphorIcons.listChecks(), PhosphorIcons.listChecks(PhosphorIconsStyle.fill)),
    TabConfig('calendar', 'Calendar', PhosphorIcons.calendar(), PhosphorIcons.calendar(PhosphorIconsStyle.fill)),
    TabConfig('notes', 'Notes', PhosphorIcons.noteBlank(), PhosphorIcons.noteBlank(PhosphorIconsStyle.fill)),
    TabConfig('progress', 'Progress', PhosphorIcons.chartBar(), PhosphorIcons.chartBar(PhosphorIconsStyle.fill)),
  ];

  @override
  void initState() {
    super.initState();
    _loadDefaultTab();
  }

  /// Load the user's preferred default starting tab from SharedPreferences
  Future<void> _loadDefaultTab() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTab = prefs.getString(_defaultTabKey);
      
      int startingIndex = 0; // Default to Tasks tab
      
      if (savedTab != null) {
        // Find the index of the saved tab
        final tabIndex = _tabs.indexWhere((tab) => tab.id == savedTab);
        if (tabIndex != -1) {
          startingIndex = tabIndex;
        }
      }
      
      setState(() {
        _currentIndex = startingIndex;
        _isLoading = false;
      });
    } catch (e) {
      // If loading fails, use default (Tasks tab)
      setState(() {
        _currentIndex = 0;
        _isLoading = false;
      });
    }
  }

  /// Save the user's selected default tab
  Future<void> _saveDefaultTab(String tabId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_defaultTabKey, tabId);
    } catch (e) {
      // Handle error silently in production
      debugPrint('Failed to save default tab: $e');
    }
  }

  /// Navigate to settings screen
  Future<void> _openSettings() async {
    final currentDefault = _tabs[_currentIndex].id;
    
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          tabs: _tabs,
          currentDefault: currentDefault,
        ),
      ),
    );
    
    if (result != null) {
      await _saveDefaultTab(result);
      
      // Show confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Default starting tab set to ${_tabs.firstWhere((t) => t.id == result).label}'),
            action: SnackBarAction(
              label: 'Test',
              onPressed: () {
                // Simulate app restart by reloading the default
                _loadDefaultTab();
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while determining starting tab
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_tabs[_currentIndex].label),
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.gear()),
            onPressed: _openSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const TasksTab(),
          const CalendarTab(),
          const NotesTab(),
          const ProgressTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: _tabs.map((tab) => NavigationDestination(
          icon: Icon(tab.icon),
          selectedIcon: Icon(tab.selectedIcon),
          label: tab.label,
        )).toList(),
      ),
    );
  }
}

/// Settings screen for selecting default starting tab
class SettingsScreen extends StatefulWidget {
  final List<TabConfig> tabs;
  final String currentDefault;

  const SettingsScreen({
    super.key,
    required this.tabs,
    required this.currentDefault,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.currentDefault;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton(
            onPressed: _selectedTab != widget.currentDefault
                ? () => Navigator.of(context).pop(_selectedTab)
                : null,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        PhosphorIcons.houseLine(),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Default Starting Tab',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose which tab opens when you start the app',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Radio button list for tab selection
                  ...widget.tabs.map((tab) => RadioListTile<String>(
                    value: tab.id,
                    groupValue: _selectedTab,
                    onChanged: (value) {
                      setState(() {
                        _selectedTab = value!;
                      });
                    },
                    title: Row(
                      children: [
                        Icon(
                          tab.icon,
                          size: 20,
                          color: _selectedTab == tab.id
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Text(tab.label),
                      ],
                    ),
                    subtitle: Text(_getTabDescription(tab.id)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  )),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Additional settings section (example)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        PhosphorIcons.info(),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'About Default Tab',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your selected default tab will be shown every time you open the app. '
                    'You can change this setting at any time.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTabDescription(String tabId) {
    switch (tabId) {
      case 'tasks':
        return 'Manage your to-do items and tasks';
      case 'calendar':
        return 'View your schedule and appointments';
      case 'notes':
        return 'Write and organize your notes';
      case 'progress':
        return 'Track your productivity and stats';
      default:
        return '';
    }
  }
}

/// Tab configuration data class
class TabConfig {
  final String id;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  TabConfig(this.id, this.label, this.icon, this.selectedIcon);
}

/// Placeholder tab widgets for demonstration
class TasksTab extends StatelessWidget {
  const TasksTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.listChecks(), size: 64, color: Colors.blue),
          const SizedBox(height: 16),
          const Text(
            'Tasks',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Manage your to-do items here',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class CalendarTab extends StatelessWidget {
  const CalendarTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.calendar(), size: 64, color: Colors.green),
          const SizedBox(height: 16),
          const Text(
            'Calendar',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'View your schedule and events',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class NotesTab extends StatelessWidget {
  const NotesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.noteBlank(), size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          const Text(
            'Notes',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Write and organize your thoughts',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class ProgressTab extends StatelessWidget {
  const ProgressTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.chartBar(), size: 64, color: Colors.purple),
          const SizedBox(height: 16),
          const Text(
            'Progress',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Track your productivity stats',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
