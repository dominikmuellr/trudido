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

import '../controllers/task_controller.dart';
import '../providers/app_providers.dart';
import '../providers/filter_providers.dart';
import '../providers/settings_search_provider.dart';
import '../controllers/notes_controller.dart';
import '../services/folder_provider.dart';
import '../repositories/note_folder_repository.dart';
import '../widgets/quick_input_bar.dart';
import 'home_screen_notifiers.dart';
import '../widgets/common/common.dart';
import '../theme/expressive_motion.dart';

/// Bottom navigation bar for the home screen
/// Handles tab switching and search mode exit
class HomeNavigationBar extends ConsumerWidget {
  final int currentTab;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final TextEditingController searchController;
  final VoidCallback onClearVaultSelection;

  const HomeNavigationBar({
    super.key,
    required this.currentTab,
    required this.scaffoldKey,
    required this.searchController,
    required this.onClearVaultSelection,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hapticsEnabled = ref.watch(preferencesStateProvider).hapticsEnabled;
    return NavigationBar(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? null // Use default in dark mode
          : Theme.of(context).colorScheme.surfaceContainerLow,
      selectedIndex: currentTab,
      onDestinationSelected: (index) {
        // Trigger haptic feedback on tab change
        ExpressiveHaptics.lightTap(enabled: hapticsEnabled);

        final previousTab = ref.read(currentTabProvider);

        // If tapping the same tab, open the drawer
        if (previousTab == index) {
          scaffoldKey.currentState?.openDrawer();
          return;
        }

        // Security: Clear vault folder selection when leaving Notes tab
        if (previousTab == 1 && index != 1) {
          onClearVaultSelection();
        }

        ref.read(currentTabProvider.notifier).setTab(index);
        // Exit search mode when switching tabs
        final isSearchMode = ref.read(searchModeProvider);
        if (isSearchMode) {
          ref.read(searchModeProvider.notifier).state = false;
          searchController.clear();
          ref.read(searchQueryProvider.notifier).state = '';
          ref.read(notesSearchQueryProvider.notifier).state = '';
          ref.read(settingsSearchQueryProvider.notifier).state = '';
          ref.read(folderSearchQueryProvider.notifier).state = '';
          ref.read(noteFolderSearchQueryProvider.notifier).state = '';
        }
      },
      destinations: [
        NavigationDestination(
          icon: _NavigationIcon(icon: Icons.checklist_outlined, tabIndex: 0),
          selectedIcon: _NavigationIcon(icon: Icons.checklist, tabIndex: 0),
          label: 'Tasks',
        ),
        NavigationDestination(
          icon: _NavigationIcon(icon: Icons.note_outlined, tabIndex: 1),
          selectedIcon: _NavigationIcon(icon: Icons.note, tabIndex: 1),
          label: 'Notes',
        ),
      ],
    );
  }
}

/// Navigation icon with optional badge for notification counts
class _NavigationIcon extends ConsumerWidget {
  final IconData icon;
  final int tabIndex;

  const _NavigationIcon({required this.icon, required this.tabIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get counts for badges
    int? badgeCount;

    if (tabIndex == 0) {
      // Tasks tab - show overdue count
      final taskStats = ref.watch(taskStatisticsProvider);
      if (taskStats.overdue > 0) {
        badgeCount = taskStats.overdue;
      }
    } else if (tabIndex == 1) {
      // Notes tab - could show unread count (if implemented)
      badgeCount = null;
    }

    final iconWidget = Icon(icon);

    if (badgeCount != null && badgeCount > 0) {
      return Badge(
        label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        textColor: Theme.of(context).colorScheme.onPrimary,
        child: iconWidget,
      );
    }

    return iconWidget;
  }
}

/// Quick input bottom area with input bar and action buttons
class QuickInputBottomArea extends ConsumerWidget {
  final int currentTab;
  final void Function({DateTime? initialDate, String? presetTitle}) onAddTask;
  final void Function({String? presetTitle}) onAddNote;
  final void Function(String text) onQuickSaveNote;
  final VoidCallback onCreateVaultNote;
  final VoidCallback onCreateNote;

  const QuickInputBottomArea({
    super.key,
    required this.currentTab,
    required this.onAddTask,
    required this.onAddNote,
    required this.onQuickSaveNote,
    required this.onCreateVaultNote,
    required this.onCreateNote,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine if we're in vault notes context
    final selectedFolderId = ref.watch(selectedNoteFolderProvider);
    final foldersAsync = ref.watch(noteFoldersProvider);
    final folders = foldersAsync.valueOrNull ?? [];
    final folder = selectedFolderId != null
        ? folders.where((f) => f.id == selectedFolderId).firstOrNull
        : null;
    final isVaultContext = folder != null && folder.isVault;
    final isNotesTab = currentTab == 1;

    // Background color that matches NavigationBar
    final bgColor = theme.brightness == Brightness.dark
        ? colorScheme.surface
        : colorScheme.surfaceContainerLow;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0.0,
      child: Container(
        color: bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Quick Input Bar (takes most of the space)
            Expanded(
              child: QuickInputBar(
                onAddTask: (text) => onAddTask(presetTitle: text),
                onAddNote: (text) => onAddNote(presetTitle: text),
                onQuickSaveNote: onQuickSaveNote,
                onAddVaultNote: (text) => onAddNote(presetTitle: text),
                onQuickSaveVaultNote: onQuickSaveNote,
              ),
            ),
            const SizedBox(width: 8),
            // Side button: Calendar switcher for Tasks, Create Note FAB for Notes
            if (currentTab == 0)
              // Tasks tab: Calendar/List switcher
              ExpressiveFloatingActionButton.small(
                heroTag: 'view_toggle_quick',
                backgroundColor: colorScheme.secondaryContainer,
                foregroundColor: colorScheme.onSecondaryContainer,
                elevation: 1,
                shape: const CircleBorder(),
                onPressed: () {
                  final current = ref.read(taskViewTypeProvider);
                  ref
                      .read(taskViewTypeProvider.notifier)
                      .state = current == TaskViewType.list
                      ? TaskViewType.calendar
                      : TaskViewType.list;
                },
                child: Icon(
                  ref.watch(taskViewTypeProvider) == TaskViewType.list
                      ? Icons.calendar_month
                      : Icons.list,
                ),
              )
            else if (isNotesTab)
              // Notes tab: Create full note button (pencil icon, no circle)
              ExpressiveIconButton(
                onPressed: isVaultContext ? onCreateVaultNote : onCreateNote,
                icon: Icon(Icons.edit_outlined, color: colorScheme.primary),
                tooltip: 'Open note editor',
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}

/// Navigation rail icon with optional badge (for tablet/desktop layouts)
class NavigationRailIcon extends ConsumerWidget {
  final IconData icon;
  final int tabIndex;

  const NavigationRailIcon({
    super.key,
    required this.icon,
    required this.tabIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    int? badgeCount;

    if (tabIndex == 0) {
      final taskStats = ref.watch(taskStatisticsProvider);
      if (taskStats.overdue > 0) {
        badgeCount = taskStats.overdue;
      }
    }

    final iconWidget = Icon(icon);

    if (badgeCount != null && badgeCount > 0) {
      return Badge(
        label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        textColor: Theme.of(context).colorScheme.onPrimary,
        child: iconWidget,
      );
    }

    return iconWidget;
  }
}
