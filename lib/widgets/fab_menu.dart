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
import '../screens/home_screen_notifiers.dart';
import '../controllers/notes_controller.dart';
import '../repositories/note_folder_repository.dart';
import '../widgets/common/common.dart';
import '../utils/state_notifiers.dart';


// Provider to track FAB menu expanded state
final fabMenuExpandedProvider = stateProvider<bool>(false);

// Data class for menu items
class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  _MenuItem({required this.icon, required this.label, required this.onTap});
}

/// Material 3 Expandable FAB Menu
class FabMenu extends ConsumerStatefulWidget {
  final VoidCallback onAddTask;
  final VoidCallback onAddNote;
  final VoidCallback? onAddFromTemplate;
  final VoidCallback? onCreateVaultNote;
  final VoidCallback? onLockVault;
  final VoidCallback? onSearch;

  const FabMenu({
    super.key,
    required this.onAddTask,
    required this.onAddNote,
    this.onAddFromTemplate,
    this.onCreateVaultNote,
    this.onLockVault,
    this.onSearch,
  });

  @override
  ConsumerState<FabMenu> createState() => _FabMenuState();

  // Static method to get the current state
  static _FabMenuState? of(BuildContext context) {
    return context.findAncestorStateOfType<_FabMenuState>();
  }
}

class _FabMenuState extends ConsumerState<FabMenu>
    with TickerProviderStateMixin {
  final List<AnimationController> _itemControllers = [];
  bool _isExpanded = false;

  // Expose the expanded state
  bool get isExpanded => _isExpanded;

  @override
  void dispose() {
    for (final controller in _itemControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _ensureControllers(int count) {
    // Add controllers if needed
    while (_itemControllers.length < count) {
      _itemControllers.add(
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 200),
        ),
      );
    }
  }

  void _toggleMenu() {
    setState(() {
      _isExpanded = !_isExpanded;
      ref.read(fabMenuExpandedProvider.notifier).update(_isExpanded);
    });
    _animateItems();
  }

  void _animateItems() {
    const staggerDelay = Duration(milliseconds: 50);

    if (_isExpanded) {
      // Open: animate from bottom to top (last item first)
      for (int i = _itemControllers.length - 1; i >= 0; i--) {
        final delay = staggerDelay * (_itemControllers.length - 1 - i);
        Future.delayed(delay, () {
          if (mounted && _isExpanded) {
            _itemControllers[i].forward();
          }
        });
      }
    } else {
      // Close: animate all at once (fast close)
      for (final controller in _itemControllers) {
        controller.reverse();
      }
    }
  }

  List<_MenuItem> _getMenuItems(WidgetRef ref) {
    final currentTab = ref.watch(currentTabProvider);
    if (currentTab == 0) {
      // Tasks Tab - show global search (excludes vaults)
      return [
        _MenuItem(
          icon: Icons.add_task,
          label: 'Add Task',
          onTap: widget.onAddTask,
        ),
        if (widget.onAddFromTemplate != null)
          _MenuItem(
            icon: Icons.dashboard_customize_outlined,
            label: 'From Template',
            onTap: widget.onAddFromTemplate!,
          ),
        if (widget.onSearch != null)
          _MenuItem(
            icon: Icons.search,
            label: 'Search',
            onTap: widget.onSearch!,
          ),
      ];
    } else {
      // Notes Tab - check if we're in a vault
      final selectedFolderId = ref.watch(selectedNoteFolderProvider);
      final foldersAsync = ref.watch(noteFoldersProvider);
      final folders = foldersAsync.value ?? [];
      final selectedFolder = selectedFolderId != null
          ? folders.where((f) => f.id == selectedFolderId).firstOrNull
          : null;

      final isInVault = selectedFolder != null && selectedFolder.isVault;

      if (isInVault) {
        // Inside a vault - show vault-specific menu with vault-scoped search
        return [
          _MenuItem(
            icon: Icons.note_add_outlined,
            label: 'New Vault Note',
            onTap: widget
                .onAddNote, // Use onAddNote since we're already in the vault
          ),
          if (widget.onLockVault != null)
            _MenuItem(
              icon: Icons.lock,
              label: 'Lock Vault',
              onTap: widget.onLockVault!,
            ),
          if (widget.onSearch != null)
            _MenuItem(
              icon: Icons.search,
              label: 'Search',
              onTap: widget.onSearch!,
            ),
        ];
      } else {
        // Not in a vault - show normal menu with global search (excludes vaults)
        return [
          _MenuItem(
            icon: Icons.note_add_outlined,
            label: 'New Note',
            onTap: widget.onAddNote,
          ),
          if (widget.onCreateVaultNote != null)
            _MenuItem(
              icon: Icons.lock_outlined,
              label: 'New Vault Note',
              onTap: widget.onCreateVaultNote!,
            ),
          if (widget.onSearch != null)
            _MenuItem(
              icon: Icons.search,
              label: 'Search',
              onTap: widget.onSearch!,
            ),
        ];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuItems = _getMenuItems(ref).reversed.toList();

    // Ensure we have enough controllers
    _ensureControllers(menuItems.length);

    // Watch the provider to sync with external close events (like backdrop tap)
    ref.listen<bool>(fabMenuExpandedProvider, (previous, next) {
      if (next != _isExpanded) {
        setState(() {
          _isExpanded = next;
        });
        _animateItems();
      }
    });

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Menu Items with staggered animation
        ...menuItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final controller = _itemControllers[index];

          return AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              final value = Curves.easeOutBack.transform(controller.value);
              if (value == 0 && !_isExpanded) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Opacity(
                  opacity: controller.value,
                  child: Transform.scale(
                    scale: value,
                    alignment: Alignment.bottomRight,
                    child: child,
                  ),
                ),
              );
            },
            child: _FabMenuItem(
              label: item.label,
              icon: item.icon,
              onTap: () {
                _toggleMenu();
                Future.delayed(const Duration(milliseconds: 50), () {
                  item.onTap();
                });
              },
            ),
          );
        }),
        // Main FAB
        ExpressiveFloatingActionButton(
          onPressed: _toggleMenu,
          shape: const CircleBorder(),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) {
              return RotationTransition(
                turns: Tween<double>(begin: 0.5, end: 1.0).animate(animation),
                child: ScaleTransition(scale: animation, child: child),
              );
            },
            child: Icon(
              _isExpanded ? Icons.close : Icons.add,
              key: ValueKey<bool>(_isExpanded),
            ),
          ),
        ),
      ],
    );
  }
}

class _FabMenuItem extends StatelessWidget {
  const _FabMenuItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpressiveFloatingActionButton.extended(
      heroTag: null,
      onPressed: () {
        onTap();
      },
      label: Text(label),
      icon: Icon(icon),
      backgroundColor: theme.colorScheme.secondaryContainer,
      foregroundColor: theme.colorScheme.onSecondaryContainer,
    );
  }
}

/// Widget to wrap Scaffold body and add FAB menu backdrop
class FabMenuBackdrop extends ConsumerWidget {
  final Widget child;

  const FabMenuBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFabExpanded = ref.watch(fabMenuExpandedProvider);

    return Stack(
      children: [
        child,
        if (isFabExpanded)
          Positioned.fill(
            child: ExpressiveGestureDetector(
              onTap: () {
                ref.read(fabMenuExpandedProvider.notifier).update(false);
              },
              child: Container(
                color: Colors.black.withOpacity(0.5), // Semi-transparent black
              ),
            ),
          ),
      ],
    );
  }
}

/// Widget to wrap the entire screen (outside Scaffold) for full-screen backdrop
class FabMenuScreenBackdrop extends ConsumerWidget {
  const FabMenuScreenBackdrop({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFabExpanded = ref.watch(fabMenuExpandedProvider);

    if (!isFabExpanded) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: ExpressiveGestureDetector(
        onTap: () {
          ref.read(fabMenuExpandedProvider.notifier).update(false);
        },
        child: Container(color: Colors.black.withOpacity(0.5)),
      ),
    );
  }
}
