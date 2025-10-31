import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/default_tab_service.dart';

/// Provider for the current default tab setting
final defaultTabProvider = FutureProvider<String>((ref) async {
  return await DefaultTabService.getDefaultTab();
});

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
    }
  }

  Future<void> resetToDefault() async {
    state = const AsyncValue.loading();
    try {
      await DefaultTabService.resetToDefault();
      final tab = await DefaultTabService.getDefaultTab();
      state = AsyncValue.data(tab);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

/// Default Tab Settings Screen
///
/// This screen allows users to choose their preferred starting tab.
/// It integrates with your app's Material Design 3 theme
/// and follows Android best practices for settings UI.
class DefaultTabSettingsScreen extends ConsumerWidget {
  const DefaultTabSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaultTabAsync = ref.watch(defaultTabNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Default Starting Tab'),
        centerTitle: false,
      ),
      body: defaultTabAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load settings',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.refresh(defaultTabNotifierProvider),
                icon: Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (currentTab) => _buildSettingsBody(context, ref, currentTab),
      ),
    );
  }

  Widget _buildSettingsBody(
    BuildContext context,
    WidgetRef ref,
    String currentTab,
  ) {
    final tabs = DefaultTabService.getAllTabs();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Main settings card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.home_outlined,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Default Starting Tab',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Choose which tab opens when you start the app',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Tab selection options
                ...tabs.entries.map(
                  (entry) => _buildTabOption(
                    context,
                    ref,
                    entry.key,
                    entry.value,
                    currentTab,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Information card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'About This Setting',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'The selected tab will be displayed every time you open the app. '
                  'This setting is saved locally on your device and can be changed at any time.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Reset button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showResetDialog(context, ref),
            icon: Icon(Icons.undo),
            label: const Text('Reset to Default (Tasks)'),
          ),
        ),
      ],
    );
  }

  Widget _buildTabOption(
    BuildContext context,
    WidgetRef ref,
    String tabId,
    String tabName,
    String currentTab,
  ) {
    final isSelected = currentTab == tabId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _selectTab(context, ref, tabId, tabName),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isSelected
                ? Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withAlpha((255 * 0.3).round())
                : null,
          ),
          child: Row(
            children: [
              Icon(
                _getTabIcon(tabId),
                size: 24,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tabName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    Text(
                      _getTabDescription(tabId),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTabIcon(String tabId) {
    switch (tabId) {
      case 'tasks':
        return Icons.checklist;
      case 'notes':
        return Icons.description;
      default:
        return Icons.circle_outlined;
    }
  }

  String _getTabDescription(String tabId) {
    switch (tabId) {
      case 'tasks':
        return 'Manage your to-do items and tasks';
      case 'notes':
        return 'Write and organize your notes';
      default:
        return '';
    }
  }

  Future<void> _selectTab(
    BuildContext context,
    WidgetRef ref,
    String tabId,
    String tabName,
  ) async {
    final notifier = ref.read(defaultTabNotifierProvider.notifier);
    await notifier.setDefaultTab(tabId);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Default tab set to $tabName'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              // This would need the previous tab value to implement properly
            },
          ),
        ),
      );
    }
  }

  Future<void> _showResetDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Default'),
        content: const Text(
          'This will set your default starting tab back to Tasks. '
          'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final notifier = ref.read(defaultTabNotifierProvider.notifier);
      await notifier.resetToDefault();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Default tab reset to Tasks'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
