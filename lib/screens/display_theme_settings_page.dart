import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../controllers/preferences_controller.dart';
import '../services/default_tab_service.dart';
import 'default_tab_settings_screen.dart';

class DisplayThemeSettingsPage extends ConsumerWidget {
  const DisplayThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Display & Theme'),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: theme.colorScheme.surfaceTint,
      ),
      body: ListView(
        children: [
          // Theme Section
          _buildSectionHeader(context, 'Theme'),
          _ThemeModeSelector(),
          Consumer(builder: (context, ref, _) {
            final enabled = ref.watch(preferencesStateProvider).useDynamicColor;
            final controller = ref.read(preferencesControllerProvider);
            return SwitchListTile(
              secondary: Icon(Icons.auto_awesome_outlined),
              title: const Text('Dynamic Color'),
              value: enabled,
              onChanged: (v) => controller.toggleDynamicColor(),
            );
          }),

          const Divider(),

          // Display Section
          _buildSectionHeader(context, 'Display'),
          _DefaultTabSelector(),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ThemeModeSelector extends ConsumerWidget {
  const _ThemeModeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesStateProvider);
    final currentModeStr = prefs.themeMode;
    final current = currentModeStr == 'light'
        ? ThemeMode.light
        : currentModeStr == 'dark'
            ? ThemeMode.dark
            : ThemeMode.system;

    return ListTile(
      leading: Icon(Icons.palette_outlined),
      title: const Text('Theme Mode'),
      subtitle: Text(
        current == ThemeMode.system
            ? 'Auto (follows device)'
            : current == ThemeMode.dark
                ? 'Dark'
                : 'Light',
      ),
      trailing: Icon(Icons.arrow_drop_down),
      onTap: () async {
        final choice = await showModalBottomSheet<ThemeMode>(
          context: context,
          showDragHandle: true,
          builder: (ctx) {
            return _ThemeModeSheet(current: current);
          },
        );
        if (choice != null) {
          final controller = ref.read(preferencesControllerProvider);
          switch (choice) {
            case ThemeMode.light:
              await controller.setThemeMode('light');
              break;
            case ThemeMode.dark:
              await controller.setThemeMode('dark');
              break;
            case ThemeMode.system:
              await controller.setThemeMode('system');
              break;
          }
        }
      },
    );
  }
}

class _ThemeModeSheet extends ConsumerWidget {
  final ThemeMode current;
  const _ThemeModeSheet({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final useBlackTheme = ref.watch(preferencesStateProvider).useBlackTheme;
    final controller = ref.read(preferencesControllerProvider);

    Widget buildOption(ThemeMode mode, String label, String desc, IconData icon) {
      final selected = current == mode;
      return ListTile(
        leading: Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant),
        title: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w600 : null)),
        subtitle: Text(desc),
        trailing: selected ? Icon(Icons.check, color: cs.primary) : null,
        onTap: () => Navigator.pop(context, mode),
      );
    }
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          buildOption(ThemeMode.light, 'Light', 'Always use light theme', Icons.light_mode_outlined),
          buildOption(ThemeMode.dark, 'Dark', 'Always use dark theme', Icons.dark_mode_outlined),
          buildOption(ThemeMode.system, 'Auto', 'Follow device setting', Icons.auto_mode_outlined),
          const Divider(),
          ListTile(
            leading: Icon(Icons.contrast, color: cs.onSurfaceVariant),
            title: const Text('Black'),
            trailing: Switch(
              value: useBlackTheme,
              onChanged: (current == ThemeMode.light) ? null : (v) {
                controller.toggleBlackTheme();
              },
            ),
            onTap: (current == ThemeMode.light) ? null : () {
              controller.toggleBlackTheme();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

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
      error: (error, _) => ListTile(
        leading: Icon(Icons.error_outline),
        title: Text('Default Starting Tab'),
        subtitle: Text('Error loading setting'),
      ),
      data: (currentTab) {
        final tabs = DefaultTabService.getAllTabs();
        final currentTabName = tabs[currentTab] ?? 'Unknown';

        return ListTile(
          leading: Icon(Icons.home_outlined),
          title: const Text('Default Starting Tab'),
          subtitle: Text(currentTabName),
          trailing: Icon(Icons.arrow_drop_down),
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
            }
          },
        );
      },
    );
  }
}

class _DefaultTabSheet extends StatelessWidget {
  final String current;
  const _DefaultTabSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tabs = DefaultTabService.getAllTabs();

    Widget buildOption(String tabId, String tabName, IconData icon) {
      final selected = current == tabId;
      return ListTile(
        leading: Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant),
        title: Text(tabName, style: TextStyle(fontWeight: selected ? FontWeight.w600 : null)),
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
          }).toList(),
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
