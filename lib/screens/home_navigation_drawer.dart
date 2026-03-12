// Trudido - A privacy-focused todo and notes app
// Copyright (C) 2026 Dominik Müller
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
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/todo.dart';
import '../models/note_folder.dart';
import '../models/event.dart' as app_event;
import '../providers/app_providers.dart';
import '../providers/filter_providers.dart';
import '../controllers/notes_controller.dart';
import '../controllers/preferences_controller.dart';
import '../services/folder_provider.dart';
import '../services/vault_auth_service.dart';
import '../repositories/note_folder_repository.dart';
import '../utils/week_start_utils.dart';
import '../widgets/create_folder_dialog.dart';
import '../theme/spacing_tokens.dart';
import 'settings_screen.dart';
import 'folder_management_screen.dart';
import 'notes_folder_management_screen.dart';
import 'bin_screen.dart';
import 'vault_bin_screen.dart';
import '../utils/animated_navigation.dart';
import '../widgets/common/common.dart';

/// Helper to get icon data from icon name string.
IconData getIconDataFromName(String? iconName) {
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

/// Helper method to get color for task priority.
Color getColorForPriority(String priority, ColorScheme colorScheme) {
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

/// Main navigation drawer widget for the home screen.
class HomeNavigationDrawer extends ConsumerStatefulWidget {
  final int currentTab;
  final bool isCalendarExpanded;
  final VoidCallback onCalendarToggle;
  final Future<bool> Function(BuildContext, NoteFolder) onVaultSetup;
  final VoidCallback onCreateNoteFolder;
  final VoidCallback onClearVaultSelection;

  const HomeNavigationDrawer({
    super.key,
    required this.currentTab,
    required this.isCalendarExpanded,
    required this.onCalendarToggle,
    required this.onVaultSetup,
    required this.onCreateNoteFolder,
    required this.onClearVaultSelection,
  });

  @override
  ConsumerState<HomeNavigationDrawer> createState() =>
      _HomeNavigationDrawerState();
}

class _HomeNavigationDrawerState extends ConsumerState<HomeNavigationDrawer> {
  @override
  Widget build(BuildContext context) {
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
                    _ThemeCycleIcon(
                      currentMode: preferences.themeMode,
                      colorScheme: colorScheme,
                    ),
                ],
              ),
            ),

            // Folders section
            Expanded(
              child: widget.currentTab == 1
                  ? _TaskFoldersList(
                      onClearVaultSelection: widget.onClearVaultSelection,
                    )
                  : widget.currentTab == 2
                  ? _NoteFoldersList(
                      onVaultSetup: widget.onVaultSetup,
                      onCreateNoteFolder: widget.onCreateNoteFolder,
                    )
                  : const _OverviewModules(),
            ),

            // Common actions section
            _DrawerActions(
              currentTab: widget.currentTab,
              isCalendarExpanded: widget.isCalendarExpanded,
              onCalendarToggle: widget.onCalendarToggle,
              onClearVaultSelection: widget.onClearVaultSelection,
            ),
          ],
        ),
      ),
    );
  }
}

/// Theme mode cycling icon button.
class _ThemeCycleIcon extends ConsumerWidget {
  final String currentMode;
  final ColorScheme colorScheme;

  const _ThemeCycleIcon({required this.currentMode, required this.colorScheme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return ExpressiveIconButton(
      icon: Icon(icon),
      iconSize: 20,
      color: colorScheme.primary,
      tooltip: tooltip,
      onPressed: () async {
        final prefsService = ref.read(preferencesServiceProvider);
        final updated = await prefsService.update(themeMode: nextMode);
        ref.read(preferencesStateProvider.notifier).update(updated);
      },
    );
  }
}

/// Task folders list widget.
class _TaskFoldersList extends ConsumerWidget {
  final VoidCallback onClearVaultSelection;

  const _TaskFoldersList({required this.onClearVaultSelection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foldersAsync = ref.watch(folderNotifierProvider);
    final selectedFolderId = ref.watch(selectedFolderProvider);

    return foldersAsync.when(
      data: (folders) {
        // Use ListView.builder for better performance with many folders
        return ListView.builder(
          padding: SpacingEdgeInsets.insetsV8,
          itemCount: folders.length + 2, // +1 "All Tasks", +1 "Create Folder"
          itemBuilder: (context, index) {
            final i = index;
            // "All Tasks" option
            if (i == 0) {
              return RepaintBoundary(
                child: ListTile(
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
                  selectedTileColor: colorScheme.secondaryContainer.withValues(
                    alpha: 0.3,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: SpacingBorderRadius.md,
                  ),
                  onTap: () {
                    ref.read(selectedFolderProvider.notifier).update(null);
                    Navigator.of(context).pop();
                  },
                ),
              );
            }

            // "Create Folder" option
            if (i == folders.length + 1) {
              return Column(
                children: [
                  SpacingGap.gapV8,
                  ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: Icon(
                      Icons.add,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    title: Text(
                      'Create Folder',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      showDialog(
                        context: context,
                        builder: (context) => const CreateFolderDialog(),
                      );
                    },
                  ),
                ],
              );
            }

            // Individual folders
            final folder = folders[i - 1];
            final isSelected = selectedFolderId == folder.id;
            return RepaintBoundary(
              child: ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: Icon(
                  getIconDataFromName(folder.icon),
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
                selectedTileColor: colorScheme.secondaryContainer.withValues(
                  alpha: 0.3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: SpacingBorderRadius.md,
                ),
                onTap: () {
                  ref.read(selectedFolderProvider.notifier).update(folder.id);
                  Navigator.of(context).pop();
                },
              ),
            );
          },
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
}

/// Note folders list widget.
class _NoteFoldersList extends ConsumerWidget {
  final Future<bool> Function(BuildContext, NoteFolder) onVaultSetup;
  final VoidCallback onCreateNoteFolder;

  const _NoteFoldersList({
    required this.onVaultSetup,
    required this.onCreateNoteFolder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foldersAsync = ref.watch(noteFoldersProvider);
    final selectedFolderId = ref.watch(selectedNoteFolderProvider);
    final defaultFolderId = ref
        .watch(preferencesStateProvider)
        .defaultNotesFolderId;

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
              trailing: defaultFolderId == null
                  ? Icon(Icons.push_pin, size: 16, color: colorScheme.primary)
                  : null,
              selected: selectedFolderId == null,
              selectedTileColor: colorScheme.secondaryContainer.withValues(
                alpha: 0.3,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: SpacingBorderRadius.md,
              ),
              onTap: () {
                ref.read(selectedNoteFolderProvider.notifier).update(null);
                Navigator.of(context).pop();
              },
              onLongPress: () => _showSetDefaultDialog(
                context,
                ref,
                null,
                'All Notes',
                defaultFolderId,
              ),
            ),
            // "Unfiled Notes" option
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: Icon(
                Icons.folder_open,
                size: 20,
                color: selectedFolderId == 'UNFILED'
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              title: Text(
                'Unfiled Notes',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: selectedFolderId == 'UNFILED'
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                  fontWeight: selectedFolderId == 'UNFILED'
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              trailing: defaultFolderId == 'UNFILED'
                  ? Icon(Icons.push_pin, size: 16, color: colorScheme.primary)
                  : null,
              selected: selectedFolderId == 'UNFILED',
              selectedTileColor: colorScheme.secondaryContainer.withValues(
                alpha: 0.3,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: SpacingBorderRadius.md,
              ),
              onTap: () {
                ref.read(selectedNoteFolderProvider.notifier).update('UNFILED');
                Navigator.of(context).pop();
              },
              onLongPress: () => _showSetDefaultDialog(
                context,
                ref,
                'UNFILED',
                'Unfiled Notes',
                defaultFolderId,
              ),
            ),
            // Individual folders
            ...folders.map((folder) {
              final isSelected = selectedFolderId == folder.id;
              final isVault = folder.isVault;
              final isDefault = defaultFolderId == folder.id;
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
                trailing: isDefault
                    ? Icon(Icons.push_pin, size: 16, color: colorScheme.primary)
                    : null,
                selected: isSelected,
                selectedTileColor: colorScheme.secondaryContainer.withValues(
                  alpha: 0.3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: SpacingBorderRadius.md,
                ),
                onLongPress: isVault
                    ? null
                    : () => _showSetDefaultDialog(
                        context,
                        ref,
                        folder.id,
                        folder.name,
                        defaultFolderId,
                      ),
                onTap: () async {
                  if (isVault && !folder.hasPassword) {
                    final success = await onVaultSetup(context, folder);
                    if (!success) return;
                  } else if (isVault && folder.hasPassword) {
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

                    ref
                        .read(lastAccessedVaultProvider.notifier)
                        .update(folder.id);
                  }

                  ref
                      .read(selectedNoteFolderProvider.notifier)
                      .update(folder.id);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              );
            }),
            // Create new folder option
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
                Navigator.of(context).pop();
                onCreateNoteFolder();
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

  /// Show dialog to set or unset default folder
  void _showSetDefaultDialog(
    BuildContext context,
    WidgetRef ref,
    String? folderId,
    String folderName,
    String? currentDefault,
  ) {
    final isCurrentlyDefault = currentDefault == folderId;
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  isCurrentlyDefault ? Icons.push_pin_outlined : Icons.push_pin,
                  color: colorScheme.primary,
                ),
                title: Text(
                  isCurrentlyDefault
                      ? 'Remove as default view'
                      : 'Set as default view',
                ),
                subtitle: Text(
                  isCurrentlyDefault
                      ? 'Stop opening "$folderName" when switching to Notes tab'
                      : 'Always open "$folderName" when switching to Notes tab',
                ),
                onTap: () async {
                  final controller = ref.read(preferencesControllerProvider);
                  await controller.setDefaultNotesFolder(
                    isCurrentlyDefault ? null : folderId,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isCurrentlyDefault
                              ? 'Default view removed'
                              : '"$folderName" set as default',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Configurable module slots for the Overview tab drawer.
class _OverviewModules extends ConsumerWidget {
  const _OverviewModules();

  static const _moduleLabels = {
    'calendar': 'Calendar',
    'daily_agenda': 'Daily Agenda',
    'today_date': 'Today\'s Date',
    'hidden': 'Empty',
  };

  static const _moduleIcons = {
    'calendar': Icons.calendar_month,
    'daily_agenda': Icons.today,
    'today_date': Icons.event_note,
    'hidden': Icons.visibility_off_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(overviewDrawerModulesProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (int i = 0; i < modules.length; i++)
          if (modules[i] == 'none')
            _buildEmptySlot(context, ref, i, theme, colorScheme)
          else if (modules[i] == 'hidden')
            _buildHiddenSlot(context, ref, i, colorScheme)
          else
            _buildModuleSlot(context, ref, i, modules[i], theme, colorScheme),
      ],
    );
  }

  Widget _buildModuleSlot(
    BuildContext context,
    WidgetRef ref,
    int index,
    String moduleType,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Module header — tap to change, × to remove
        InkWell(
          onTap: () => _showModulePicker(context, ref, index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(
                  _moduleIcons[moduleType] ?? Icons.widgets,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  _moduleLabels[moduleType] ?? moduleType,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    ref
                        .read(overviewDrawerModulesProvider.notifier)
                        .setModule(index, 'none');
                  },
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Module content
        _buildModuleContent(context, ref, moduleType),
      ],
    );
  }

  Widget _buildModuleContent(
    BuildContext context,
    WidgetRef ref,
    String moduleType,
  ) {
    switch (moduleType) {
      case 'calendar':
        return const _InlineCalendar();
      case 'daily_agenda':
        return const _DailyAgenda();
      case 'today_date':
        return const _TodayDate();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildEmptySlot(
    BuildContext context,
    WidgetRef ref,
    int index,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return InkWell(
      onTap: () => _showModulePicker(context, ref, index),
      child: Container(
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Icon(
            Icons.add,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildHiddenSlot(
    BuildContext context,
    WidgetRef ref,
    int index,
    ColorScheme colorScheme,
  ) {
    return Align(
      alignment: Alignment.centerRight,
      child: IconButton(
        icon: Icon(
          Icons.add,
          size: 14,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
        ),
        padding: const EdgeInsets.fromLTRB(0, 2, 16, 2),
        constraints: const BoxConstraints(),
        visualDensity: VisualDensity.compact,
        onPressed: () => _showModulePicker(context, ref, index),
      ),
    );
  }

  void _showModulePicker(BuildContext context, WidgetRef ref, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Choose Module',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final entry in _moduleLabels.entries)
              ListTile(
                leading: Icon(
                  _moduleIcons[entry.key],
                  color: colorScheme.onSurfaceVariant,
                ),
                title: Text(entry.value),
                onTap: () {
                  ref
                      .read(overviewDrawerModulesProvider.notifier)
                      .setModule(index, entry.key);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Drawer actions section (calendar, manage folders, bin, settings).
class _DrawerActions extends ConsumerWidget {
  final int currentTab;
  final bool isCalendarExpanded;
  final VoidCallback onCalendarToggle;
  final VoidCallback onClearVaultSelection;

  const _DrawerActions({
    required this.currentTab,
    required this.isCalendarExpanded,
    required this.onCalendarToggle,
    required this.onClearVaultSelection,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final preferences = ref.watch(preferencesStateProvider);
    final tasksDrawerModule = ref.watch(tasksDrawerModuleProvider);

    return Column(
      children: [
        // Calendar section (only for Tasks tab, hidden when calendar module is active)
        if (currentTab == 1 && tasksDrawerModule != 'calendar')
          _CompactCalendar(
            isExpanded: isCalendarExpanded,
            onToggle: onCalendarToggle,
          ),

        // Manage Folders action (only for tabs that have folders)
        if (currentTab == 1 || currentTab == 2)
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
              Navigator.of(context).pop();
              onClearVaultSelection();
              if (currentTab == 1) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const FolderManagementScreen(),
                  ),
                );
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const NotesFolderManagementScreen(),
                  ),
                );
              }
            },
          ),

        // Bin (hidden when enableBin is false)
        if (preferences.enableBin)
          _BinListTile(
            currentTab: currentTab,
            onClearVaultSelection: onClearVaultSelection,
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
            Navigator.of(context).pop();
            onClearVaultSelection();
            AnimatedNavigation.push(context, const SettingsScreen());
          },
        ),
      ],
    );
  }
}

/// Bin list tile with context-aware label.
class _BinListTile extends ConsumerWidget {
  final int currentTab;
  final VoidCallback onClearVaultSelection;

  const _BinListTile({
    required this.currentTab,
    required this.onClearVaultSelection,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedFolderId = ref.watch(selectedNoteFolderProvider);
    final folders = ref.watch(noteFoldersProvider).value ?? [];
    final folder = folders.where((f) => f.id == selectedFolderId).firstOrNull;
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
            : (currentTab == 1
                  ? 'Tasks Bin'
                  : currentTab == 2
                  ? 'Notes Bin'
                  : 'Bin'),
        style: theme.textTheme.bodyMedium,
      ),
      onTap: () {
        Navigator.of(context).pop();

        if (isVault) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const VaultBinScreen()),
          );
        } else {
          onClearVaultSelection();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BinScreen(initialTab: currentTab),
            ),
          );
        }
      },
    );
  }
}

/// Always-visible calendar module for the overview drawer.
/// Each instance manages its own focused month independently.
class _InlineCalendar extends ConsumerStatefulWidget {
  const _InlineCalendar();

  @override
  ConsumerState<_InlineCalendar> createState() => _InlineCalendarState();
}

class _InlineCalendarState extends ConsumerState<_InlineCalendar> {
  late DateTime _focusedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
  }

  Color _eventColor(app_event.Event event, ColorScheme colorScheme) {
    if (event.folderId != null) {
      final folder = ref.watch(folderByIdProvider(event.folderId!));
      if (folder != null) return Color(folder.color);
    }
    if (event.color != null) return Color(event.color!);
    return colorScheme.tertiary;
  }

  Map<DateTime, List<Object>> _buildItemMap(
    List<Todo> tasks,
    List<app_event.Event> events,
  ) {
    final Map<DateTime, List<Object>> itemMap = {};

    for (final task in tasks) {
      if (task.dueDate == null) continue;
      final date = DateTime(
        task.dueDate!.year,
        task.dueDate!.month,
        task.dueDate!.day,
      );
      itemMap[date] = itemMap[date] ?? [];
      itemMap[date]!.add(task);
    }

    for (final event in events) {
      if (event.isDeleted) continue;
      final start = DateTime(
        event.startDateTime.year,
        event.startDateTime.month,
        event.startDateTime.day,
      );
      final end = DateTime(
        event.endDateTime.year,
        event.endDateTime.month,
        event.endDateTime.day,
      );
      for (
        DateTime d = start;
        !d.isAfter(end);
        d = d.add(const Duration(days: 1))
      ) {
        itemMap[d] = itemMap[d] ?? [];
        itemMap[d]!.add(event);
      }
    }

    return itemMap;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedDate = ref.watch(selectedCalendarDateProvider);
    final tasks = ref.watch(filteredTasksProvider);
    final events = ref.watch(filteredEventsProvider);
    final preferences = ref.watch(preferencesStateProvider);
    final itemMap = _buildItemMap(tasks, events);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: SpacingBorderRadius.md,
        ),
        child: TableCalendar<Object>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(selectedDate, day),
          calendarFormat: CalendarFormat.month,
          startingDayOfWeek: WeekStartUtils.toTableCalendarDay(
            preferences.firstDayOfWeek,
          ),
          eventLoader: (day) =>
              itemMap[DateTime(day.year, day.month, day.day)] ?? [],
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
              color: colorScheme.error.withValues(alpha: 0.7),
            ),
          ),
          calendarStyle: CalendarStyle(
            cellMargin: const EdgeInsets.all(2),
            cellPadding: const EdgeInsets.all(0),
            todayDecoration: const BoxDecoration(),
            todayTextStyle: TextStyle(
              fontSize: 12,
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
            selectedDecoration: const BoxDecoration(),
            selectedTextStyle: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface,
            ),
            defaultTextStyle: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface,
            ),
            weekendTextStyle: TextStyle(fontSize: 12, color: colorScheme.error),
            outsideTextStyle: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
          calendarBuilders: CalendarBuilders<Object>(
            todayBuilder: (context, day, focusedDay) {
              final isSelected = isSameDay(selectedDate, day);
              return Container(
                margin: const EdgeInsets.all(4),
                decoration: isSelected
                    ? BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      )
                    : null,
                child: Column(
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
                ),
              );
            },
            selectedBuilder: (context, day, focusedDay) {
              final now = DateTime.now();
              final isToday =
                  day.year == now.year &&
                  day.month == now.month &&
                  day.day == now.day;
              // Today is handled by todayBuilder; only handle non-today selected
              if (isToday) return null;
              return Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            },
            markerBuilder: (context, day, items) {
              if (items.isEmpty) return const SizedBox.shrink();

              // Sort: todos first by priority, events after
              final sorted = items.toList()
                ..sort((a, b) {
                  if (a is app_event.Event && b is! app_event.Event) return 1;
                  if (a is! app_event.Event && b is app_event.Event) return -1;
                  if (a is Todo && b is Todo) {
                    const order = {'high': 0, 'medium': 1, 'low': 2, 'none': 3};
                    return (order[a.priority.toLowerCase()] ?? 4).compareTo(
                      order[b.priority.toLowerCase()] ?? 4,
                    );
                  }
                  return 0;
                });

              const maxBars = 3;
              final bars = sorted.take(maxBars).toList();
              final extra = sorted.length - bars.length;

              return Positioned(
                top: 2,
                bottom: 2,
                left: 2,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final item in bars)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 0.5),
                        width: 3,
                        height: item is app_event.Event ? 5 : 7,
                        decoration: BoxDecoration(
                          color: item is app_event.Event
                              ? _eventColor(item, colorScheme)
                              : item is Todo
                              ? (item.sourceCalendarColor != null
                                    ? Color(item.sourceCalendarColor!)
                                    : getColorForPriority(
                                        item.priority,
                                        colorScheme,
                                      ))
                              : colorScheme.outline,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    if (extra > 0)
                      Text(
                        '+$extra',
                        style: TextStyle(
                          fontSize: 6,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() => _focusedDay = focusedDay);
            ref
                .read(selectedCalendarDateProvider.notifier)
                .update(
                  DateTime(
                    selectedDay.year,
                    selectedDay.month,
                    selectedDay.day,
                  ),
                );
          },
          onPageChanged: (focusedDay) {
            setState(() => _focusedDay = focusedDay);
          },
        ),
      ),
    );
  }
}

/// Today's date module: displays the current date in European format.
class _TodayDate extends StatelessWidget {
  const _TodayDate();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: SpacingBorderRadius.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEEE').format(now),
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('dd.MM.yyyy').format(now),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Daily agenda module: shows today's tasks and events in a compact list.
class _DailyAgenda extends ConsumerWidget {
  const _DailyAgenda();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tasks = ref.watch(filteredTasksProvider);
    final events = ref.watch(filteredEventsProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final timeFormat = DateFormat('HH:mm');

    // Today's tasks: due today or overdue
    final todayTasks = tasks.where((t) {
      if (t.dueDate == null) return false;
      final d = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      return !d.isAfter(today) && !t.isCompleted;
    }).toList();

    // Today's events: occurring today
    final todayEvents =
        events.where((e) {
          if (e.isDeleted) return false;
          return e.occursOn(today);
        }).toList()..sort((a, b) {
          if (a.isAllDay && !b.isAllDay) return -1;
          if (!a.isAllDay && b.isAllDay) return 1;
          return a.startDateTime.compareTo(b.startDateTime);
        });

    final hasItems = todayTasks.isNotEmpty || todayEvents.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: SpacingBorderRadius.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Text(
                DateFormat('EEEE, MMM d').format(today),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!hasItems)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Text(
                  'Nothing scheduled',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            // Events
            for (final event in todayEvents)
              _buildEventRow(
                context,
                event,
                theme,
                colorScheme,
                ref,
                timeFormat,
              ),
            // Tasks
            for (final task in todayTasks)
              _buildTaskRow(context, task, theme, colorScheme),
            if (hasItems) const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildEventRow(
    BuildContext context,
    app_event.Event event,
    ThemeData theme,
    ColorScheme colorScheme,
    WidgetRef ref,
    DateFormat timeFormat,
  ) {
    Color eventColor = colorScheme.tertiary;
    if (event.folderId != null) {
      final folder = ref.watch(folderByIdProvider(event.folderId!));
      if (folder != null) eventColor = Color(folder.color);
    } else if (event.color != null) {
      eventColor = Color(event.color!);
    }
    final timeText = event.isAllDay
        ? 'All day'
        : timeFormat.format(event.startDateTime);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: eventColor,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeText,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              event.text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskRow(
    BuildContext context,
    Todo task,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final isOverdue =
        task.dueDate != null &&
        DateTime(
          task.dueDate!.year,
          task.dueDate!.month,
          task.dueDate!.day,
        ).isBefore(
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          Icon(
            Icons.circle_outlined,
            size: 14,
            color: getColorForPriority(task.priority, colorScheme),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              task.text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isOverdue ? colorScheme.error : colorScheme.onSurface,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isOverdue)
            Text(
              'Overdue',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.error,
                fontSize: 9,
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact collapsible calendar for the drawer.
class _CompactCalendar extends ConsumerWidget {
  final bool isExpanded;
  final VoidCallback onToggle;

  const _CompactCalendar({required this.isExpanded, required this.onToggle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedDate = ref.watch(selectedCalendarDateProvider);
    final tasks = ref.watch(filteredTasksProvider);
    final events = ref.watch(filteredEventsProvider);
    final preferences = ref.watch(preferencesStateProvider);
    final allFolders = ref.watch(folderNotifierProvider).value ?? [];
    final folderColorMap = {for (final f in allFolders) f.id: Color(f.color)};

    // Build combined item map for todos and events
    final Map<DateTime, List<Object>> itemMap = {};
    for (final task in tasks) {
      if (task.dueDate == null) continue;
      final date = DateTime(
        task.dueDate!.year,
        task.dueDate!.month,
        task.dueDate!.day,
      );
      itemMap[date] = itemMap[date] ?? [];
      itemMap[date]!.add(task);
    }
    for (final event in events) {
      if (event.isDeleted) continue;
      final start = DateTime(
        event.startDateTime.year,
        event.startDateTime.month,
        event.startDateTime.day,
      );
      final end = DateTime(
        event.endDateTime.year,
        event.endDateTime.month,
        event.endDateTime.day,
      );
      for (
        DateTime d = start;
        !d.isAfter(end);
        d = d.add(const Duration(days: 1))
      ) {
        itemMap[d] = itemMap[d] ?? [];
        itemMap[d]!.add(event);
      }
    }

    Color eventColor(app_event.Event event) {
      if (event.folderId != null) {
        return folderColorMap[event.folderId!] ?? colorScheme.tertiary;
      }
      if (event.color != null) return Color(event.color!);
      return colorScheme.tertiary;
    }

    return Column(
      children: [
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
            isExpanded ? Icons.expand_less : Icons.expand_more,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          onTap: onToggle,
        ),

        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Container(
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: SpacingBorderRadius.md,
              ),
              child: TableCalendar<Object>(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: selectedDate ?? DateTime.now(),
                selectedDayPredicate: (day) => isSameDay(selectedDate, day),
                calendarFormat: CalendarFormat.month,
                startingDayOfWeek: WeekStartUtils.toTableCalendarDay(
                  preferences.firstDayOfWeek,
                ),
                eventLoader: (day) =>
                    itemMap[DateTime(day.year, day.month, day.day)] ?? [],
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
                    color: colorScheme.error.withValues(alpha: 0.7),
                  ),
                ),
                calendarStyle: CalendarStyle(
                  cellMargin: const EdgeInsets.all(2),
                  cellPadding: const EdgeInsets.all(0),
                  todayDecoration: const BoxDecoration(),
                  todayTextStyle: TextStyle(
                    fontSize: 12,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
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
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
                calendarBuilders: CalendarBuilders<Object>(
                  todayBuilder: (context, day, focusedDay) {
                    final isSelected = isSameDay(selectedDate, day);
                    return Container(
                      margin: const EdgeInsets.all(4),
                      decoration: isSelected
                          ? BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            )
                          : null,
                      child: Column(
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
                      ),
                    );
                  },
                  selectedBuilder: (context, day, focusedDay) {
                    final now = DateTime.now();
                    final isToday =
                        day.year == now.year &&
                        day.month == now.month &&
                        day.day == now.day;
                    if (isToday) return null;
                    return Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                  markerBuilder: (context, day, items) {
                    if (items.isEmpty) return const SizedBox.shrink();

                    final sorted = items.toList()
                      ..sort((a, b) {
                        if (a is app_event.Event && b is! app_event.Event) {
                          return 1;
                        }
                        if (a is! app_event.Event && b is app_event.Event) {
                          return -1;
                        }
                        if (a is Todo && b is Todo) {
                          const order = {
                            'high': 0,
                            'medium': 1,
                            'low': 2,
                            'none': 3,
                          };
                          return (order[a.priority.toLowerCase()] ?? 4)
                              .compareTo(order[b.priority.toLowerCase()] ?? 4);
                        }
                        return 0;
                      });

                    const maxBars = 3;
                    final bars = sorted.take(maxBars).toList();
                    final extra = sorted.length - bars.length;

                    return Positioned(
                      top: 2,
                      bottom: 2,
                      left: 2,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final item in bars)
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 0.5),
                              width: 3,
                              height: item is app_event.Event ? 5 : 7,
                              decoration: BoxDecoration(
                                color: item is app_event.Event
                                    ? eventColor(item)
                                    : item is Todo
                                    ? (item.sourceCalendarColor != null
                                          ? Color(item.sourceCalendarColor!)
                                          : getColorForPriority(
                                              item.priority,
                                              colorScheme,
                                            ))
                                    : colorScheme.outline,
                                borderRadius: BorderRadius.circular(1.5),
                              ),
                            ),
                          if (extra > 0)
                            Text(
                              '+$extra',
                              style: TextStyle(
                                fontSize: 6,
                                color: theme.textTheme.bodySmall?.color,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  ref
                      .read(selectedCalendarDateProvider.notifier)
                      .update(
                        DateTime(
                          selectedDay.year,
                          selectedDay.month,
                          selectedDay.day,
                        ),
                      );
                  ref
                      .read(taskViewTypeProvider.notifier)
                      .update(TaskViewType.calendar);
                  Navigator.of(context).pop();
                },
                onPageChanged: (focusedDay) {
                  ref
                      .read(selectedCalendarDateProvider.notifier)
                      .update(
                        DateTime(
                          focusedDay.year,
                          focusedDay.month,
                          focusedDay.day,
                        ),
                      );
                },
              ),
            ),
          ),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}
