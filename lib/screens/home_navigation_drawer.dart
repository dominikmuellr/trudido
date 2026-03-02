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
import 'package:table_calendar/table_calendar.dart';

import '../models/todo.dart';
import '../models/note_folder.dart';
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
              child: widget.currentTab == 0
                  ? _TaskFoldersList(
                      onClearVaultSelection: widget.onClearVaultSelection,
                    )
                  : _NoteFoldersList(
                      onVaultSetup: widget.onVaultSetup,
                      onCreateNoteFolder: widget.onCreateNoteFolder,
                    ),
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
          itemCount:
              folders.length + 2, // +1 for "All Tasks", +1 for "Create Folder"
          itemBuilder: (context, index) {
            // "All Tasks" option
            if (index == 0) {
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
            if (index == folders.length + 1) {
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
            final folder = folders[index - 1];
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

    return Column(
      children: [
        // Calendar section (only for Tasks tab)
        if (currentTab == 0)
          _CompactCalendar(
            isExpanded: isCalendarExpanded,
            onToggle: onCalendarToggle,
          ),

        // Manage Folders action
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
            if (currentTab == 0) {
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
        isVault ? 'Vault Bin' : (currentTab == 0 ? 'Tasks Bin' : 'Notes Bin'),
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
    final preferences = ref.watch(preferencesStateProvider);

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
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: SpacingBorderRadius.md,
              ),
              child: TableCalendar<Todo>(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: selectedDate ?? DateTime.now(),
                selectedDayPredicate: (day) => isSameDay(selectedDate, day),
                calendarFormat: CalendarFormat.month,
                startingDayOfWeek: WeekStartUtils.toTableCalendarDay(
                  preferences.firstDayOfWeek,
                ),
                eventLoader: (day) {
                  return tasks.where((task) {
                    if (task.dueDate == null) return false;
                    final taskDate = DateTime(
                      task.dueDate!.year,
                      task.dueDate!.month,
                      task.dueDate!.day,
                    );
                    final checkDate = DateTime(day.year, day.month, day.day);
                    return taskDate.isAtSameMomentAs(checkDate);
                  }).toList();
                },
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
                calendarBuilders: CalendarBuilders<Todo>(
                  todayBuilder: (context, day, focusedDay) {
                    return Column(
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
                    );
                  },
                  selectedBuilder: (context, day, focusedDay) {
                    final now = DateTime.now();
                    final isToday =
                        day.year == now.year &&
                        day.month == now.month &&
                        day.day == now.day;

                    if (isToday) {
                      return Column(
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
                      );
                    }
                    return null;
                  },
                  markerBuilder: (context, day, events) {
                    if (events.isEmpty) return const SizedBox.shrink();

                    final sortedEvents = events.toList()
                      ..sort((a, b) {
                        final aHasColor = a.sourceCalendarColor != null;
                        final bHasColor = b.sourceCalendarColor != null;
                        if (aHasColor != bHasColor) {
                          return aHasColor ? -1 : 1;
                        }
                        const priorityOrder = {
                          'high': 0,
                          'medium': 1,
                          'low': 2,
                          'none': 3,
                        };
                        final aPriority =
                            priorityOrder[a.priority.toLowerCase()] ?? 4;
                        final bPriority =
                            priorityOrder[b.priority.toLowerCase()] ?? 4;
                        return aPriority.compareTo(bPriority);
                      });

                    const maxBars = 2;
                    final bars = sortedEvents.take(maxBars).toList();
                    final extra = sortedEvents.length - bars.length;

                    return Positioned(
                      top: 2,
                      bottom: 2,
                      left: 2,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var event in bars)
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 0.5),
                              width: 3,
                              height: 6,
                              decoration: BoxDecoration(
                                color: event.sourceCalendarColor != null
                                    ? Color(event.sourceCalendarColor!)
                                    : getColorForPriority(
                                        event.priority,
                                        colorScheme,
                                      ),
                                borderRadius: BorderRadius.circular(1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          if (extra > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Text(
                                '+$extra',
                                style: TextStyle(
                                  fontSize: 6,
                                  color: theme.textTheme.bodySmall?.color,
                                ),
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
