import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../controllers/preferences_controller.dart';
import '../services/default_tab_service.dart';
import '../l10n/app_localizations.dart';
import 'default_tab_settings_screen.dart';

class DisplayThemeSettingsPage extends ConsumerWidget {
  const DisplayThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.displayTheme),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: theme.colorScheme.surfaceTint,
      ),
      body: ListView(
        children: [
          // Theme Section
          _buildSectionHeader(context, l10n.theme),
          _ThemeModeSelector(),
          Consumer(
            builder: (context, ref, _) {
              final enabled = ref
                  .watch(preferencesStateProvider)
                  .useDynamicColor;
              final controller = ref.read(preferencesControllerProvider);
              return SwitchListTile(
                secondary: Icon(Icons.auto_awesome_outlined),
                title: const Text('Dynamic Color'),
                value: enabled,
                onChanged: (v) => controller.toggleDynamicColor(),
              );
            },
          ),

          // Accent Color Selector - only show when dynamic color is disabled
          Consumer(
            builder: (context, ref, _) {
              final useDynamicColor = ref
                  .watch(preferencesStateProvider)
                  .useDynamicColor;
              if (useDynamicColor) return const SizedBox.shrink();

              return _AccentColorSelector();
            },
          ),

          // Display Section
          _buildSectionHeader(context, l10n.display),
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
    final accentColorSeed = ref.watch(preferencesStateProvider).accentColorSeed;
    final useDynamicColor = ref.watch(preferencesStateProvider).useDynamicColor;
    final controller = ref.read(preferencesControllerProvider);

    // Check if Hack theme is selected (Matrix green) and dynamic colors are disabled
    final isHackTheme = accentColorSeed == 0xFF00FF00 && !useDynamicColor;

    Widget buildOption(
      ThemeMode mode,
      String label,
      String desc,
      IconData icon,
    ) {
      final selected = current == mode;
      // Disable light mode and auto mode for Hack theme
      final isEnabled =
          !(isHackTheme &&
              (mode == ThemeMode.light || mode == ThemeMode.system));
      final effectiveColor = !isEnabled
          ? cs.onSurfaceVariant.withOpacity(0.4)
          : selected
          ? cs.primary
          : cs.onSurfaceVariant;

      return ListTile(
        enabled: isEnabled,
        leading: Icon(icon, color: effectiveColor),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w600 : null,
            color: !isEnabled ? cs.onSurfaceVariant.withOpacity(0.4) : null,
          ),
        ),
        subtitle: Text(
          isHackTheme && (mode == ThemeMode.light || mode == ThemeMode.system)
              ? 'Not available for Hack theme'
              : desc,
          style: TextStyle(
            color: !isEnabled ? cs.onSurfaceVariant.withOpacity(0.4) : null,
          ),
        ),
        trailing: selected ? Icon(Icons.check, color: cs.primary) : null,
        onTap: isEnabled ? () => Navigator.pop(context, mode) : null,
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          buildOption(
            ThemeMode.light,
            'Light',
            'Always use light theme',
            Icons.light_mode_outlined,
          ),
          buildOption(
            ThemeMode.dark,
            'Dark',
            'Always use dark theme',
            Icons.dark_mode_outlined,
          ),
          buildOption(
            ThemeMode.system,
            'Auto',
            'Follow device setting',
            Icons.auto_mode_outlined,
          ),
          ListTile(
            leading: Icon(Icons.contrast, color: cs.onSurfaceVariant),
            title: const Text('Black (AMOLED)'),
            trailing: Switch(
              value: useBlackTheme,
              onChanged: (current == ThemeMode.light)
                  ? null
                  : (v) {
                      controller.toggleBlackTheme();
                    },
            ),
            onTap: (current == ThemeMode.light)
                ? null
                : () {
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

class _AccentColorSelector extends ConsumerWidget {
  const _AccentColorSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesStateProvider);
    final currentColorSeed = prefs.accentColorSeed;
    final currentColorName = _getAccentColorName(currentColorSeed);

    return ListTile(
      leading: Icon(Icons.palette_outlined),
      title: const Text('Accent Color'),
      subtitle: Text(currentColorName),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildColorPreview(currentColorSeed, context),
          const SizedBox(width: 8),
          Icon(Icons.arrow_drop_down),
        ],
      ),
      onTap: () async {
        final choice = await showModalBottomSheet<int>(
          context: context,
          showDragHandle: true,
          builder: (ctx) {
            return _AccentColorSheet(current: currentColorSeed);
          },
        );
        if (choice != null) {
          final controller = ref.read(preferencesControllerProvider);
          await controller.setAccentColorSeed(choice);
        }
      },
    );
  }

  Widget _buildColorPreview(int colorValue, BuildContext context) {
    if (colorValue == 0xFF9E9E9E) {
      // Special half black/half white icon for monochrome
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: ClipOval(
          child: Row(
            children: [
              Expanded(child: Container(color: Colors.black)),
              Expanded(child: Container(color: Colors.white)),
            ],
          ),
        ),
      );
    } else if (colorValue == 0xFF00FF00) {
      // Special Matrix-style icon for hack theme
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.black,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF00FF00), width: 2),
        ),
        child: const Icon(Icons.terminal, color: Color(0xFF00FF00), size: 12),
      );
    } else {
      // Regular solid color circle for other colors
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Color(colorValue),
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: 1,
          ),
        ),
      );
    }
  }

  String _getAccentColorName(int colorValue) {
    switch (colorValue) {
      case 0xFF2196F3:
        return 'Blue';
      case 0xFFE91E63:
        return 'Pink';
      case 0xFF9C27B0:
        return 'Purple';
      case 0xFF673AB7:
        return 'Deep Purple';
      case 0xFF3F51B5:
        return 'Indigo';
      case 0xFF009688:
        return 'Teal';
      case 0xFF4CAF50:
        return 'Green';
      case 0xFF8BC34A:
        return 'Light Green';
      case 0xFFCDDC39:
        return 'Lime';
      case 0xFFFFC107:
        return 'Amber';
      case 0xFFFF9800:
        return 'Orange';
      case 0xFFFF5722:
        return 'Deep Orange';
      case 0xFF795548:
        return 'Brown';
      case 0xFF9E9E9E:
        return 'Monochrome';
      case 0xFF757575:
        return 'Grey';
      case 0xFF00FF00:
        return 'Hack';
      case 0xFF607D8B:
        return 'Blue Grey';
      default:
        return 'Custom';
    }
  }
}

class _AccentColorSheet extends StatelessWidget {
  final int current;
  const _AccentColorSheet({required this.current});

  static const List<int> accentColorSeeds = [
    0xFF2196F3, // Blue (default)
    0xFFE91E63, // Pink
    0xFF9C27B0, // Purple
    0xFF673AB7, // Deep Purple
    0xFF3F51B5, // Indigo
    0xFF009688, // Teal
    0xFF4CAF50, // Green
    0xFF8BC34A, // Light Green
    0xFFCDDC39, // Lime
    0xFFFFC107, // Amber
    0xFFFF9800, // Orange
    0xFFFF5722, // Deep Orange
    0xFF795548, // Brown
    0xFF9E9E9E, // Monochrome (black/white accents)
    0xFF757575, // Grey
    0xFF00FF00, // Hack
    0xFF607D8B, // Blue Grey
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget buildOption(int colorValue, String colorName) {
      final selected = current == colorValue;
      return ListTile(
        leading: _buildColorIcon(colorValue, selected, cs),
        title: Text(
          colorName,
          style: TextStyle(fontWeight: selected ? FontWeight.w600 : null),
        ),
        trailing: selected ? Icon(Icons.check, color: cs.primary) : null,
        onTap: () => Navigator.pop(context, colorValue),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Choose Accent Color',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ...accentColorSeeds.map((colorValue) {
                  return buildOption(colorValue, _getColorName(colorValue));
                }).toList(),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildColorIcon(int colorValue, bool selected, ColorScheme cs) {
    if (colorValue == 0xFF9E9E9E) {
      // Special half black/half white icon for monochrome
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? cs.primary : cs.outline.withOpacity(0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: ClipOval(
          child: Row(
            children: [
              Expanded(child: Container(color: Colors.black)),
              Expanded(child: Container(color: Colors.white)),
            ],
          ),
        ),
      );
    } else if (colorValue == 0xFF00FF00) {
      // Special Matrix-style icon for hack theme
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? cs.primary : const Color(0xFF00FF00),
            width: selected ? 2 : 1,
          ),
        ),
        child: const Icon(Icons.terminal, color: Color(0xFF00FF00), size: 16),
      );
    } else {
      // Regular solid color circle for other colors
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Color(colorValue),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? cs.primary : cs.outline.withOpacity(0.3),
            width: selected ? 2 : 1,
          ),
        ),
      );
    }
  }

  String _getColorName(int colorValue) {
    switch (colorValue) {
      case 0xFF2196F3:
        return 'Blue';
      case 0xFFE91E63:
        return 'Pink';
      case 0xFF9C27B0:
        return 'Purple';
      case 0xFF673AB7:
        return 'Deep Purple';
      case 0xFF3F51B5:
        return 'Indigo';
      case 0xFF009688:
        return 'Teal';
      case 0xFF4CAF50:
        return 'Green';
      case 0xFF8BC34A:
        return 'Light Green';
      case 0xFFCDDC39:
        return 'Lime';
      case 0xFFFFC107:
        return 'Amber';
      case 0xFFFF9800:
        return 'Orange';
      case 0xFFFF5722:
        return 'Deep Orange';
      case 0xFF795548:
        return 'Brown';
      case 0xFF9E9E9E:
        return 'Monochrome';
      case 0xFF757575:
        return 'Grey';
      case 0xFF00FF00:
        return 'Hack';
      case 0xFF607D8B:
        return 'Blue Grey';
      default:
        return 'Custom';
    }
  }
}
