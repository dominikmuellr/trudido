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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trudido/utils/responsive_size.dart';

import '../providers/filter_providers.dart';
import '../providers/settings_search_provider.dart';
import '../providers/clock.dart';
import '../providers/app_providers.dart';
import '../controllers/task_controller.dart';
import '../controllers/notes_controller.dart';
import '../controllers/event_controller.dart';
import '../controllers/preferences_controller.dart';
import '../services/storage_service.dart';
import '../services/greeting_service.dart';
import '../services/folder_provider.dart';
import '../repositories/note_folder_repository.dart';
import '../widgets/user_avatar_widget.dart';
import 'home_screen_notifiers.dart';
import '../widgets/common/common.dart';

/// AppBar widget for the home screen
/// Handles search mode, multi-select mode, and regular greeting display
class HomeAppBar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  final TextEditingController searchController;
  final VoidCallback onOpenPersonalization;

  const HomeAppBar({
    super.key,
    required this.searchController,
    required this.onOpenPersonalization,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  ConsumerState<HomeAppBar> createState() => _HomeAppBarState();
}

class _HomeAppBarState extends ConsumerState<HomeAppBar>
    with SingleTickerProviderStateMixin {
  Timer? _debounceTimer;
  late AnimationController _searchModeController;
  late Animation<double> _searchFadeAnimation;
  bool _wasSearchMode = false;

  @override
  void initState() {
    super.initState();
    _searchModeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _searchFadeAnimation = CurvedAnimation(
      parent: _searchModeController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchModeController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // Cancel previous timer
    _debounceTimer?.cancel();

    // Debounce: wait 300ms before updating search
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      // Universal search - update tasks, notes, folders, and settings
      ref.read(searchQueryProvider.notifier).update(value);
      ref.read(notesSearchQueryProvider.notifier).update(value);
      ref.read(settingsSearchQueryProvider.notifier).update(value);
      ref.read(folderSearchQueryProvider.notifier).update(value);
      ref.read(noteFolderSearchQueryProvider.notifier).update(value);
      // Persist to search history
      if (value.trim().length >= 3) {
        ref.read(preferencesControllerProvider).addSearchHistory(value.trim());
      }
    });
  }

  void _exitSearch() {
    ref.read(searchModeProvider.notifier).update(false);
    widget.searchController.clear();
    ref.read(searchQueryProvider.notifier).update('');
    ref.read(notesSearchQueryProvider.notifier).update('');
    ref.read(settingsSearchQueryProvider.notifier).update('');
    ref.read(folderSearchQueryProvider.notifier).update('');
    ref.read(noteFolderSearchQueryProvider.notifier).update('');
    ref.read(searchScopeProvider.notifier).update(<String>{});
  }

  void _clearSearch() {
    widget.searchController.clear();
    ref.read(searchQueryProvider.notifier).update('');
    ref.read(notesSearchQueryProvider.notifier).update('');
    ref.read(settingsSearchQueryProvider.notifier).update('');
    ref.read(folderSearchQueryProvider.notifier).update('');
    ref.read(noteFolderSearchQueryProvider.notifier).update('');
    ref.read(searchScopeProvider.notifier).update(<String>{});
  }

  @override
  Widget build(BuildContext context) {
    final isSearchMode = ref.watch(searchModeProvider);
    final currentTab = ref.watch(currentTabProvider);
    final preferences = ref.watch(preferencesStateProvider);
    final isAmoledBlack =
        preferences.useBlackTheme &&
        Theme.of(context).brightness == Brightness.dark;
    final multiMode = ref.watch(multiSelectModeProvider);
    final selectedIds = ref.watch(selectedTodoIdsProvider);
    final selectedEventIds = ref.watch(selectedEventIdsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isActiveSearch = isSearchMode && currentTab <= 2;

    // Drive the search-mode animation controller
    if (isActiveSearch && !_wasSearchMode) {
      _wasSearchMode = true;
      _searchModeController.forward();
    } else if (!isActiveSearch && _wasSearchMode) {
      _wasSearchMode = false;
      _searchModeController.reverse();
    }

    final bgColor = isAmoledBlack ? Colors.black : colorScheme.surface;
    final surfaceTint = isAmoledBlack
        ? Colors.transparent
        : colorScheme.surfaceTint;

    return AppBar(
      backgroundColor: bgColor,
      surfaceTintColor: surfaceTint,
      leading: _buildLeading(
        isActiveSearch: isActiveSearch,
        multiMode: multiMode,
        colorScheme: colorScheme,
      ),
      title: _buildTitle(
        context: context,
        isActiveSearch: isActiveSearch,
        multiMode: multiMode,
        currentTab: currentTab,
        showSearchBar: preferences.showSearchBar,
        selectedCount: selectedIds.length + selectedEventIds.length,
        theme: theme,
        colorScheme: colorScheme,
      ),
      actions: _buildActions(
        context: context,
        isActiveSearch: isActiveSearch,
        multiMode: multiMode,
        currentTab: currentTab,
        selectedIds: selectedIds,
        selectedEventIds: selectedEventIds,
        colorScheme: colorScheme,
      ),
    );
  }

  /// Builds the leading icon with animated transitions
  Widget _buildLeading({
    required bool isActiveSearch,
    required bool multiMode,
    required ColorScheme colorScheme,
  }) {
    Widget child;
    if (isActiveSearch) {
      child = ExpressiveIconButton(
        key: const ValueKey('back'),
        icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
        onPressed: _exitSearch,
      );
    } else if (multiMode) {
      child = ExpressiveIconButton(
        key: const ValueKey('close'),
        icon: ScaledIcon(Icons.close),
        onPressed: () {
          ref.read(multiSelectModeProvider.notifier).update(false);
          ref.read(selectedTodoIdsProvider.notifier).clear();
          ref.read(selectedEventIdsProvider.notifier).clear();
        },
      );
    } else {
      child = Builder(
        key: const ValueKey('menu'),
        builder: (ctx) => ExpressiveIconButton(
          icon: ScaledIcon(Icons.menu, color: colorScheme.primary),
          tooltip: 'Open menu',
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: child,
    );
  }

  /// Builds the title area: active search bar, multi-select count, resting trigger, or greeting
  Widget _buildTitle({
    required BuildContext context,
    required bool isActiveSearch,
    required bool multiMode,
    required int currentTab,
    required bool showSearchBar,
    required int selectedCount,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    // Active search takes priority
    if (isActiveSearch) {
      return _buildM3SearchBar(
        isActive: true,
        theme: theme,
        colorScheme: colorScheme,
      );
    }

    // Multi-select title
    if (multiMode && currentTab == 1) {
      return Text(
        '$selectedCount selected',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
      );
    }

    // Resting search trigger
    if (showSearchBar) {
      return _buildM3SearchBar(
        isActive: false,
        theme: theme,
        colorScheme: colorScheme,
      );
    }

    // Greeting fallback
    return _buildGreeting(context, currentTab);
  }

  /// Builds the action buttons
  List<Widget> _buildActions({
    required BuildContext context,
    required bool isActiveSearch,
    required bool multiMode,
    required int currentTab,
    required Set<String> selectedIds,
    required Set<String> selectedEventIds,
    required ColorScheme colorScheme,
  }) {
    return [
      if (currentTab == 1 && multiMode)
        ExpressiveIconButton(
          icon: Icon(
            Icons.delete_outline,
            color: selectedIds.isEmpty && selectedEventIds.isEmpty
                ? colorScheme.onSurface.withAlpha(100)
                : colorScheme.error,
          ),
          tooltip: 'Delete',
          onPressed: selectedIds.isEmpty && selectedEventIds.isEmpty
              ? null
              : () => _showDeleteConfirmation(
                  context,
                  ref,
                  selectedIds,
                  selectedEventIds,
                  colorScheme,
                ),
        ),
      if (isActiveSearch && widget.searchController.text.isNotEmpty)
        ExpressiveIconButton(
          icon: Icon(
            Icons.close_rounded,
            color: colorScheme.onSurfaceVariant,
            size: 20,
          ),
          tooltip: 'Clear search',
          onPressed: _clearSearch,
        ),
      if (!multiMode && !isActiveSearch)
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: UserAvatarWidget(
            radius: 18,
            onTap: widget.onOpenPersonalization,
          ),
        ),
    ];
  }

  /// Shows the delete confirmation dialog for multi-select mode
  Future<void> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    Set<String> selectedIds,
    Set<String> selectedEventIds,
    ColorScheme colorScheme,
  ) async {
    final totalCount = selectedIds.length + selectedEventIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Bin'),
        content: Text(
          'Move $totalCount selected ${totalCount == 1 ? 'task' : 'tasks'} to bin? You can restore them later from the Bin.',
        ),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ExpressiveTextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Move to Bin',
              style: TextStyle(color: colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final controller = ref.read(taskControllerProvider.notifier);
      if (selectedIds.isNotEmpty) await controller.bulkDelete(selectedIds);
      if (selectedEventIds.isNotEmpty) {
        final eventController = ref.read(eventControllerProvider.notifier);
        await eventController.bulkDelete(selectedEventIds);
      }
      ref.read(selectedTodoIdsProvider.notifier).clear();
      ref.read(selectedEventIdsProvider.notifier).clear();
      ref.read(multiSelectModeProvider.notifier).update(false);
    }
  }

  /// M3-styled search bar that morphs between resting and active states
  Widget _buildM3SearchBar({
    required bool isActive,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final pill = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      height: 48,
      decoration: BoxDecoration(
        color: isActive
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      clipBehavior: Clip.antiAlias,
      child: isActive
          ? FadeTransition(
              opacity: _searchFadeAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextField(
                    controller: widget.searchController,
                    autofocus: true,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search Trudido',
                      hintStyle: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Search Trudido',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );

    if (isActive) return pill;
    return ExpressiveGestureDetector(
      onTap: () => ref.read(searchModeProvider.notifier).update(true),
      child: pill,
    );
  }

  /// Builds greeting widget for AppBar based on current tab
  Widget _buildGreeting(BuildContext context, int currentTab) {
    if (currentTab == 1) {
      return _buildTasksGreeting(context);
    } else if (currentTab == 2) {
      return _buildNotesGreeting(context);
    } else {
      return _buildTasksGreeting(context);
    }
  }

  /// Builds tasks greeting with time-based subtitle
  Widget _buildTasksGreeting(BuildContext context) {
    final userName = StorageService.getUserName();
    final hour = ref.read(clockProvider).now().hour;
    final theme = Theme.of(context);
    final preferences = ref.watch(preferencesStateProvider);
    final languageIndex = preferences.greetingLanguage;

    final greeting = GreetingService.getGreeting(
      hour: hour,
      languageIndex: languageIndex,
      userName: userName,
    );
    final subtitle = GreetingService.getTasksSubtitle(
      hour: hour,
      languageIndex: languageIndex,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          greeting,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.primary,
            fontSize: 17,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.secondary.withValues(alpha: 0.8),
            fontSize: 13,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Builds notes greeting
  Widget _buildNotesGreeting(BuildContext context) {
    final userName = StorageService.getUserName();
    final hour = ref.read(clockProvider).now().hour;
    final theme = Theme.of(context);
    final preferences = ref.watch(preferencesStateProvider);
    final languageIndex = preferences.greetingLanguage;

    final greeting = GreetingService.getGreeting(
      hour: hour,
      languageIndex: languageIndex,
      userName: userName,
    );
    final subtitle = GreetingService.getNotesSubtitle(
      hour: hour,
      languageIndex: languageIndex,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          greeting,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
            fontSize: 17,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.secondary.withValues(alpha: 0.8),
            fontSize: 13,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
