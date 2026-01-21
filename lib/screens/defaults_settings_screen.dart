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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/default_tab_service.dart';
import 'home_screen_notifiers.dart';
import '../services/preferences_service.dart';
import '../providers/app_providers.dart';
import '../controllers/preferences_controller.dart';
import '../utils/week_start_utils.dart';
import '../theme/spacing_tokens.dart';

/// Provider for saving default tab changes
final defaultTabNotifierProvider =
    StateNotifierProvider<DefaultTabNotifier, AsyncValue<String>>((ref) {
      return DefaultTabNotifier();
    });

/// State notifier for managing default tab changes
class DefaultTabNotifier extends StateNotifier<AsyncValue<String>> {
  DefaultTabNotifier() : super(const AsyncValue.loading()) {
    _loadCurrentTab();
  }

  Future<void> _loadCurrentTab() async {
    try {
      final tab = await DefaultTabService.getDefaultTab();
      state = AsyncValue.data(tab);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> setDefaultTab(String tabId) async {
    state = const AsyncValue.loading();
    try {
      final success = await DefaultTabService.setDefaultTab(tabId);
      if (success) {
        state = AsyncValue.data(tabId);
      } else {
        throw Exception('Failed to save default tab setting');
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      // Attempt to reload the current setting after error
      _loadCurrentTab();
    }
  }
}

class DefaultsSettingsScreen extends ConsumerWidget {
  const DefaultsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Defaults'),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
      ),
      body: ListView(
        children: [
          SpacingGap.gapV8,
          const _DefaultTabSelector(),
          const _DefaultViewSelector(),
          const _WeekStartSelector(),
          const _GreetingLanguageSelector(),
          const _SwipeActionsSelector(),
          SpacingGap.gapV16,
        ],
      ),
    );
  }
}

// ============================================================================
// Default Tab Selector
// ============================================================================

class _DefaultTabSelector extends ConsumerWidget {
  const _DefaultTabSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaultTabAsync = ref.watch(defaultTabNotifierProvider);

    return defaultTabAsync.when(
      loading: () => const ListTile(
        leading: Icon(Icons.home_outlined),
        title: Text('Default Starting Tab'),
        subtitle: Text('Loading...'),
      ),
      error: (error, _) => const ListTile(
        leading: Icon(Icons.error_outline),
        title: Text('Default Starting Tab'),
        subtitle: Text('Error loading setting'),
      ),
      data: (currentTab) {
        final tabs = DefaultTabService.getAllTabs();
        final currentTabName = tabs[currentTab] ?? 'Unknown';

        return ListTile(
          leading: const Icon(Icons.home_outlined),
          title: const Text('Default Starting Tab'),
          subtitle: Text(currentTabName),
          trailing: const Icon(Icons.arrow_drop_down),
          onTap: () async {
            final choice = await showModalBottomSheet<String>(
              context: context,
              showDragHandle: true,
              builder: (ctx) {
                return _DefaultTabSheet(current: currentTab);
              },
            );
            if (choice != null) {
              final notifier = ref.read(defaultTabNotifierProvider.notifier);
              await notifier.setDefaultTab(choice);
              // Also switch to the selected tab immediately
              final tabIndex = DefaultTabService.tabIndices[choice] ?? 0;
              ref.read(currentTabProvider.notifier).setTab(tabIndex);
            }
          },
        );
      },
    );
  }
}

class _DefaultTabSheet extends ConsumerWidget {
  final String current;
  const _DefaultTabSheet({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tabs = DefaultTabService.getAllTabs();
    final hideBottomNav = ref
        .watch(preferencesStateProvider)
        .hideBottomNavigation;

    Widget buildOption(String tabId, String tabName, IconData icon) {
      final selected = current == tabId;
      return ListTile(
        leading: Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant),
        title: Text(
          tabName,
          style: TextStyle(fontWeight: selected ? FontWeight.w600 : null),
        ),
        trailing: selected ? Icon(Icons.check, color: cs.primary) : null,
        onTap: () => Navigator.pop(context, tabId),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          ...tabs.entries.map((entry) {
            return buildOption(entry.key, entry.value, _getTabIcon(entry.key));
          }),
          const Divider(height: 12),
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            secondary: const Icon(Icons.view_agenda_outlined),
            title: const Text('Show bottom navigation'),
            subtitle: const Text('Hide the bottom tab bar and navigation rail'),
            value: !hideBottomNav,
            onChanged: (value) async {
              final prefsService = PreferencesService();
              final updated = await prefsService.update(
                hideBottomNavigation: !value,
              );
              ref.read(preferencesStateProvider.notifier).state = updated;
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  IconData _getTabIcon(String tabId) {
    switch (tabId) {
      case 'tasks':
        return Icons.check_circle_outline;
      case 'notes':
        return Icons.notes_outlined;
      default:
        return Icons.circle_outlined;
    }
  }
}

// ============================================================================
// Default View Selector
// ============================================================================

class _DefaultViewSelector extends ConsumerWidget {
  const _DefaultViewSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaultView = ref.watch(preferencesStateProvider).defaultTaskView;
    final viewName = defaultView == 'calendar' ? 'Calendar' : 'List';

    return ListTile(
      leading: const Icon(Icons.view_list_outlined),
      title: const Text('Default Task View'),
      subtitle: Text(viewName),
      trailing: const Icon(Icons.arrow_drop_down),
      onTap: () async {
        final choice = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (ctx) {
            return _DefaultViewSheet(current: defaultView);
          },
        );
        if (choice != null) {
          final controller = ref.read(preferencesControllerProvider);
          await controller.setDefaultTaskView(choice);
        }
      },
    );
  }
}

class _DefaultViewSheet extends ConsumerWidget {
  final String current;

  const _DefaultViewSheet({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      shrinkWrap: true,
      children: [
        _buildOption(context, 'list', 'List', Icons.list),
        _buildOption(context, 'calendar', 'Calendar', Icons.calendar_month),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildOption(
    BuildContext context,
    String value,
    String label,
    IconData icon,
  ) {
    final isSelected = value == current;
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: isSelected
          ? Icon(Icons.check, color: theme.colorScheme.primary)
          : null,
      selected: isSelected,
      onTap: () => Navigator.pop(context, value),
    );
  }
}

// ============================================================================
// Week Start Selector
// ============================================================================

class _WeekStartSelector extends ConsumerWidget {
  const _WeekStartSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesStateProvider);
    final controller = ref.read(preferencesControllerProvider);
    final currentDay = prefs.firstDayOfWeek;
    final dayName = WeekStartUtils.getDayName(currentDay);

    return ListTile(
      leading: const Icon(Icons.calendar_view_week_outlined),
      title: const Text('Week Starts On'),
      subtitle: Text(dayName),
      trailing: const Icon(Icons.arrow_drop_down),
      onTap: () async {
        final choice = await showModalBottomSheet<int>(
          context: context,
          showDragHandle: true,
          builder: (ctx) {
            return _WeekStartSheet(current: currentDay);
          },
        );
        if (choice != null) {
          controller.setFirstDayOfWeek(choice);
        }
      },
    );
  }
}

class _WeekStartSheet extends StatelessWidget {
  final int current;
  const _WeekStartSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget buildOption(int dayIndex) {
      final selected = current == dayIndex;
      final dayName = WeekStartUtils.getDayName(dayIndex);
      return ListTile(
        leading: Icon(
          Icons.today,
          color: selected ? cs.primary : cs.onSurfaceVariant,
        ),
        title: Text(
          dayName,
          style: TextStyle(fontWeight: selected ? FontWeight.w600 : null),
        ),
        trailing: selected ? Icon(Icons.check, color: cs.primary) : null,
        onTap: () => Navigator.pop(context, dayIndex),
      );
    }

    final commonDays = [0, 1, 6]; // Sunday, Monday, Saturday
    final otherDays = [2, 3, 4, 5]; // Tue-Fri

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Common',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            ...commonDays.map(buildOption),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Other',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            ...otherDays.map(buildOption),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Greeting Language Selector
// ============================================================================

class _GreetingLanguageSelector extends ConsumerWidget {
  const _GreetingLanguageSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesStateProvider);

    return ListTile(
      leading: const Icon(Icons.translate),
      title: const Text('Greeting Language'),
      subtitle: Text(_getGreetingLanguageName(preferences.greetingLanguage)),
      trailing: const Icon(Icons.arrow_drop_down),
      onTap: () async {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (ctx) {
            return DraggableScrollableSheet(
              initialChildSize: 0.5,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return _GreetingLanguageSheet(
                  scrollController: scrollController,
                );
              },
            );
          },
        );
      },
    );
  }

  String _getGreetingLanguageName(int index) {
    const greetings = [
      'English',
      'Español',
      'Français',
      'Deutsch',
      'Italiano',
      'Nederlands',
      'Português',
      'Svenska',
      'Dansk',
      'Norsk',
      'Suomi',
      'Polski',
      'Čeština',
      'Magyar',
      'Română',
      'Türkçe',
      'Українська',
    ];
    if (index >= 0 && index < greetings.length) {
      return greetings[index];
    }
    return 'English';
  }
}

// ============================================================================
// Greeting Language Sheet
// ============================================================================

class _GreetingLanguageSheet extends ConsumerWidget {
  final ScrollController scrollController;

  const _GreetingLanguageSheet({required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesStateProvider);
    final controller = ref.read(preferencesControllerProvider);

    final languages = [
      'English',
      'Español',
      'Français',
      'Deutsch',
      'Italiano',
      'Nederlands',
      'Português',
      'Svenska',
      'Dansk',
      'Norsk',
      'Suomi',
      'Polski',
      'Čeština',
      'Magyar',
      'Română',
      'Türkçe',
      'Українська',
    ];

    return SafeArea(
      child: ListView.builder(
        controller: scrollController,
        itemCount: languages.length,
        itemBuilder: (context, index) {
          final isSelected = preferences.greetingLanguage == index;
          return ListTile(
            title: Text(languages[index]),
            trailing: isSelected
                ? Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
            onTap: () {
              controller.setGreetingLanguage(index);
              Navigator.of(context).pop();
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// Swipe Actions Selector
// ============================================================================

String _getSwipeActionName(String action) {
  switch (action) {
    case 'delete':
      return 'Delete';
    case 'pin':
      return 'Pin';
    case 'none':
      return 'None';
    default:
      return 'Unknown';
  }
}

class _SwipeActionsSelector extends ConsumerWidget {
  const _SwipeActionsSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesStateProvider);

    return ListTile(
      leading: const Icon(Icons.swipe),
      title: const Text('Swipe Actions'),
      subtitle: Text(
        'Left: ${_getSwipeActionName(preferences.swipeLeftAction)}, Right: ${_getSwipeActionName(preferences.swipeRightAction)}',
      ),
      trailing: const Icon(Icons.arrow_drop_down),
      onTap: () async {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (ctx) => const _SwipeActionSheet(),
        );
      },
    );
  }
}

class _SwipeActionSheet extends ConsumerWidget {
  const _SwipeActionSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesStateProvider);
    final controller = ref.read(preferencesControllerProvider);
    final cs = Theme.of(context).colorScheme;

    Widget buildActionOption(
      String action,
      String label,
      IconData icon,
      bool isSelected,
      VoidCallback onTap,
    ) {
      return ListTile(
        leading: Icon(
          icon,
          color: isSelected ? cs.primary : cs.onSurfaceVariant,
        ),
        title: Text(
          label,
          style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : null),
        ),
        trailing: isSelected ? Icon(Icons.check, color: cs.primary) : null,
        onTap: onTap,
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Configure Swipe Actions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          ListTile(
            title: const Text('Left Swipe Action'),
            subtitle: Text(_getSwipeActionName(preferences.swipeLeftAction)),
          ),
          buildActionOption(
            'delete',
            'Delete',
            Icons.delete_outline,
            preferences.swipeLeftAction == 'delete',
            () {
              controller.setSwipeLeftAction('delete');
            },
          ),
          buildActionOption(
            'pin',
            'Pin',
            Icons.push_pin_outlined,
            preferences.swipeLeftAction == 'pin',
            () {
              controller.setSwipeLeftAction('pin');
            },
          ),
          buildActionOption(
            'none',
            'None',
            Icons.do_not_disturb_alt_outlined,
            preferences.swipeLeftAction == 'none',
            () {
              controller.setSwipeLeftAction('none');
            },
          ),
          ListTile(
            title: const Text('Right Swipe Action'),
            subtitle: Text(_getSwipeActionName(preferences.swipeRightAction)),
          ),
          buildActionOption(
            'delete',
            'Delete',
            Icons.delete_outline,
            preferences.swipeRightAction == 'delete',
            () {
              controller.setSwipeRightAction('delete');
            },
          ),
          buildActionOption(
            'pin',
            'Pin',
            Icons.push_pin_outlined,
            preferences.swipeRightAction == 'pin',
            () {
              controller.setSwipeRightAction('pin');
            },
          ),
          buildActionOption(
            'none',
            'None',
            Icons.do_not_disturb_alt_outlined,
            preferences.swipeRightAction == 'none',
            () {
              controller.setSwipeRightAction('none');
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
