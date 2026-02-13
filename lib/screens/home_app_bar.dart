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
import '../services/storage_service.dart';
import '../services/greeting_service.dart';
import '../services/folder_provider.dart';
import '../repositories/note_folder_repository.dart';
import '../widgets/user_avatar_widget.dart';
import 'home_screen_notifiers.dart';
import 'notes_screen.dart';
import '../widgets/common/common.dart';

/// AppBar widget for the home screen
/// Handles search mode, multi-select mode, and regular greeting display
class HomeAppBar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  final TextEditingController searchController;
  final Animation<double>? searchBarScaleAnimation;
  final Animation<double>? greetingFadeAnimation;
  final bool showSearchBar;
  final VoidCallback onOpenPersonalization;

  const HomeAppBar({
    super.key,
    required this.searchController,
    this.searchBarScaleAnimation,
    this.greetingFadeAnimation,
    required this.showSearchBar,
    required this.onOpenPersonalization,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  ConsumerState<HomeAppBar> createState() => _HomeAppBarState();
}

class _HomeAppBarState extends ConsumerState<HomeAppBar> {
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSearchMode = ref.watch(searchModeProvider);
    final currentTab = ref.watch(currentTabProvider);
    final preferences = ref.watch(preferencesStateProvider);

    // Check if AMOLED black theme is enabled
    final isAmoledBlack =
        preferences.useBlackTheme &&
        Theme.of(context).brightness == Brightness.dark;

    if (isSearchMode && (currentTab == 0 || currentTab == 1)) {
      return _buildSearchAppBar(context, isAmoledBlack);
    }

    return _buildRegularAppBar(context, isAmoledBlack, currentTab);
  }

  /// Builds the search mode AppBar
  AppBar _buildSearchAppBar(BuildContext context, bool isAmoledBlack) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppBar(
      backgroundColor: isAmoledBlack ? Colors.black : colorScheme.surface,
      surfaceTintColor: isAmoledBlack
          ? Colors.transparent
          : colorScheme.surfaceTint,
      leading: ExpressiveIconButton(
        icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
        onPressed: () {
          ref.read(searchModeProvider.notifier).update(false);
          widget.searchController.clear();
          // Clear all search queries for universal search
          ref.read(searchQueryProvider.notifier).update('');
          ref.read(notesSearchQueryProvider.notifier).update('');
          ref.read(settingsSearchQueryProvider.notifier).update('');
          ref.read(folderSearchQueryProvider.notifier).update('');
          ref.read(noteFolderSearchQueryProvider.notifier).update('');
        },
      ),
      title: TextField(
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
          filled: false,
          contentPadding: EdgeInsets.zero,
        ),
        // Use debounced search for better performance
        onChanged: _onSearchChanged,
      ),
      actions: [
        if (widget.searchController.text.isNotEmpty)
          ExpressiveIconButton(
            icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
            tooltip: 'Clear search',
            onPressed: () {
              widget.searchController.clear();
              // Clear all search queries for universal search
              ref.read(searchQueryProvider.notifier).update('');
              ref.read(notesSearchQueryProvider.notifier).update('');
              ref.read(settingsSearchQueryProvider.notifier).update('');
              ref.read(folderSearchQueryProvider.notifier).update('');
              ref.read(noteFolderSearchQueryProvider.notifier).update('');
            },
          ),
      ],
    );
  }

  /// Builds the regular (non-search) AppBar
  AppBar _buildRegularAppBar(
    BuildContext context,
    bool isAmoledBlack,
    int currentTab,
  ) {
    final multiMode = ref.watch(multiSelectModeProvider);
    final selectedIds = ref.watch(selectedTodoIdsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final preferences = ref.watch(preferencesStateProvider);

    return AppBar(
      backgroundColor: isAmoledBlack ? Colors.black : colorScheme.surface,
      surfaceTintColor: isAmoledBlack
          ? Colors.transparent
          : colorScheme.surfaceTint,
      // Leading: Menu button to open drawer (or close button in multi-select mode)
      leading: multiMode
          ? ExpressiveIconButton(
              icon: ScaledIcon(Icons.close),
              onPressed: () {
                ref.read(multiSelectModeProvider.notifier).update(false);
                ref.read(selectedTodoIdsProvider.notifier).clear();
              },
            )
          : Builder(
              builder: (context) => ExpressiveIconButton(
                icon: ScaledIcon(Icons.menu, color: colorScheme.primary),
                tooltip: 'Open menu',
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              ),
            ),
      // Title: App name or selection count
      title: multiMode && currentTab == 0
          ? Text(
              '${selectedIds.length} selected',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            )
          : preferences.showSearchBar && widget.showSearchBar
          ? _buildAnimatedSearchBar(context, currentTab)
          : !preferences.showSearchBar || widget.greetingFadeAnimation == null
          ? _buildGreeting(context, currentTab)
          : AnimatedBuilder(
              animation: widget.greetingFadeAnimation!,
              builder: (context, child) {
                return Opacity(
                  opacity: widget.greetingFadeAnimation!.value,
                  child: _buildGreeting(context, currentTab),
                );
              },
            ),
      // Actions: avatar button and delete button in multi-select mode
      actions: [
        // Delete button in multi-select mode
        if (currentTab == 0 && multiMode)
          ExpressiveIconButton(
            icon: Icon(
              Icons.delete_outline,
              color: selectedIds.isEmpty
                  ? colorScheme.onSurface.withAlpha(100)
                  : colorScheme.error,
            ),
            tooltip: 'Delete',
            onPressed: selectedIds.isEmpty
                ? null
                : () => _showDeleteConfirmation(
                    context,
                    ref,
                    selectedIds,
                    colorScheme,
                  ),
          ),
        // Profile avatar button (always visible when not in multi-select mode)
        if (!multiMode)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: UserAvatarWidget(
              radius: 18,
              onTap: widget.onOpenPersonalization,
            ),
          ),
      ],
    );
  }

  /// Shows the delete confirmation dialog for multi-select mode
  Future<void> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    Set<String> selectedIds,
    ColorScheme colorScheme,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Bin'),
        content: Text(
          'Move ${selectedIds.length} selected ${selectedIds.length == 1 ? 'task' : 'tasks'} to bin? You can restore them later from the Bin.',
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
      await controller.bulkDelete(selectedIds);
      ref.read(selectedTodoIdsProvider.notifier).clear();
      ref.read(multiSelectModeProvider.notifier).update(false);
    }
  }

  /// Builds the animated search bar for the AppBar title
  Widget _buildAnimatedSearchBar(BuildContext context, int currentTab) {
    if (widget.searchBarScaleAnimation == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: widget.searchBarScaleAnimation!,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.searchBarScaleAnimation!.value,
          child: Opacity(
            opacity: widget.searchBarScaleAnimation!.value,
            child: ExpressiveGestureDetector(
              onTap: () {
                // Activate full search mode when tapped
                ref.read(searchModeProvider.notifier).update(true);
              },
              child: Container(
                height: 48,
                margin: const EdgeInsets.only(
                  left: 4,
                  right: 8,
                  top: 4,
                  bottom: 4,
                ),
                padding: const EdgeInsets.only(left: 12, right: 12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.05),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Search Trudido',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // View toggle for Notes tab
                    if (currentTab == 1)
                      Consumer(
                        builder: (context, ref, _) {
                          final viewMode = ref.watch(notesViewModeProvider);
                          return Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: ExpressiveIconButton(
                              icon: Icon(
                                viewMode == 'grid'
                                    ? Icons.view_list
                                    : Icons.grid_view,
                                color: colorScheme.onSurfaceVariant,
                                size: 24,
                              ),
                              tooltip: viewMode == 'grid'
                                  ? 'List view'
                                  : 'Grid view',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                ref
                                    .read(notesViewModeProvider.notifier)
                                    .update(
                                      viewMode == 'grid' ? 'list' : 'grid',
                                    );
                              },
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds greeting widget for AppBar based on current tab
  Widget _buildGreeting(BuildContext context, int currentTab) {
    if (currentTab == 0) {
      return _buildTasksGreeting(context);
    } else {
      return _buildNotesGreeting(context);
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
