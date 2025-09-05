import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../providers/app_providers.dart';
import '../controllers/preferences_controller.dart';

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
            final black = ref.watch(preferencesStateProvider).useBlackTheme;
            final controller = ref.read(preferencesControllerProvider);
            return SwitchListTile(
              secondary: Icon(PhosphorIcons.monitor()),
              title: const Text('Pure Black'),
              subtitle: const Text('Deeper blacks for OLED screens'),
              value: black,
              onChanged: (v) => controller.toggleBlackTheme(),
            );
          }),
          Consumer(builder: (context, ref, _) {
            final enabled = ref.watch(preferencesStateProvider).useDynamicColor;
            final controller = ref.read(preferencesControllerProvider);
            return SwitchListTile(
              secondary: Icon(PhosphorIcons.dropHalfBottom()),
              title: const Text('Dynamic system colors'),
              subtitle: const Text('Material You palette (Android 12+)'),
              value: enabled,
              onChanged: (v) => controller.toggleDynamicColor(),
            );
          }),

          const Divider(),

          // Display Section
          _buildSectionHeader(context, 'Display'),
          Consumer(builder: (context, ref, _) {
            final hideGreeting = ref.watch(preferencesStateProvider).hideGreeting;
            final controller = ref.read(preferencesControllerProvider);
            return SwitchListTile(
              secondary: Icon(PhosphorIcons.handWaving()),
              title: const Text('Show Greeting Header'),
              subtitle: const Text('Disable to maximize list space'),
              value: !hideGreeting,
              onChanged: (v) => controller.toggleHideGreeting(),
            );
          }),
          Consumer(builder: (context, ref, _) {
            final compact = ref.watch(preferencesStateProvider).compactDensity;
            final controller = ref.read(preferencesControllerProvider);
            return SwitchListTile(
              secondary: Icon(PhosphorIcons.textAlignCenter()),
              title: const Text('Compact density'),
              subtitle: const Text('Smaller padding & tighter lists'),
              value: compact,
              onChanged: (v) => controller.toggleCompactDensity(),
            );
          }),
          Consumer(builder: (context, ref, _) {
            final hc = ref.watch(preferencesStateProvider).highContrast;
            final controller = ref.read(preferencesControllerProvider);
            return SwitchListTile(
              secondary: Icon(PhosphorIcons.eye()),
              title: const Text('High contrast'),
              subtitle: const Text('Stronger outlines & text clarity'),
              value: hc,
              onChanged: (v) => controller.toggleHighContrast(),
            );
          }),

          const Divider(),

          // Layout Section
          _buildSectionHeader(context, 'Layout'),
          _FabPositionSelector(),

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
      leading: Icon(PhosphorIcons.palette()),
      title: const Text('Theme Mode'),
      subtitle: Text(
        current == ThemeMode.system
            ? 'Auto (follows device)'
            : current == ThemeMode.dark
                ? 'Dark'
                : 'Light',
      ),
      trailing: Icon(PhosphorIcons.caretDown()),
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

class _ThemeModeSheet extends StatelessWidget {
  final ThemeMode current;
  const _ThemeModeSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _FabPositionSelector extends ConsumerWidget {
  const _FabPositionSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesStateProvider);
    final current = prefs.fabPosition;
    
    return ListTile(
      leading: Icon(PhosphorIcons.plusCircle()),
      title: const Text('Add Button Position'),
      subtitle: Text(current[0].toUpperCase() + current.substring(1)),
      trailing: Icon(PhosphorIcons.caretDown()),
      onTap: () async {
        final choice = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (ctx) => _FabPositionSheet(current: current),
        );
        if (choice != null) {
          final controller = ref.read(preferencesControllerProvider);
          await controller.setFabPosition(choice);
        }
      },
    );
  }
}

class _FabPositionSheet extends StatelessWidget {
  final String current;
  const _FabPositionSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget option(String value, String label, IconData icon) {
      final selected = current == value;
      return ListTile(
        leading: Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant),
        title: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w600 : null)),
        trailing: selected ? Icon(Icons.check, color: cs.primary) : null,
        onTap: () => Navigator.pop(context, value),
      );
    }
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          option('left', 'Left', PhosphorIcons.arrowLineLeft()),
          option('center', 'Center', PhosphorIcons.arrowsInLineVertical()),
          option('right', 'Right', PhosphorIcons.arrowLineRight()),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
