import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/home_screen.dart';
import '../controllers/notes_controller.dart';
import '../repositories/note_folder_repository.dart';

// Provider to track FAB menu expanded state
final fabMenuExpandedProvider = StateProvider<bool>((ref) => false);

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
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isExpanded = false;

  // Expose the expanded state
  bool get isExpanded => _isExpanded;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 175),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubicEmphasized,
      reverseCurve: Curves.easeInOutCubicEmphasized,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isExpanded = !_isExpanded;
      // Update the provider
      ref.read(fabMenuExpandedProvider.notifier).state = _isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
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
      final folders = foldersAsync.valueOrNull ?? [];
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

    // Watch the provider to sync with external close events (like backdrop tap)
    ref.listen<bool>(fabMenuExpandedProvider, (previous, next) {
      if (next != _isExpanded) {
        setState(() {
          _isExpanded = next;
          if (_isExpanded) {
            _animationController.forward();
          } else {
            _animationController.reverse();
          }
        });
      }
    });

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Menu Items - animated one after another from bottom to top
        if (_isExpanded) ...[
          ...menuItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            // Stagger animation: items appear sequentially with delay
            final delay = index * 0.05; // 50ms delay between each item
            final staggeredAnimation = CurvedAnimation(
              parent: _animation,
              curve: Interval(
                delay,
                delay + 0.5,
                curve: Curves.easeOutBack, // Bouncy pop-up effect
              ),
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.5), // Start slightly below
                  end: Offset.zero,
                ).animate(staggeredAnimation),
                child: ScaleTransition(
                  scale: staggeredAnimation,
                  child: FadeTransition(
                    opacity: staggeredAnimation,
                    child: _FabMenuItem(
                      label: item.label,
                      icon: item.icon,
                      onTap: () {
                        _toggleMenu();
                        // Add a small delay to allow the animation to start
                        Future.delayed(const Duration(milliseconds: 50), () {
                          item.onTap();
                        });
                      },
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ],
        // Main FAB
        FloatingActionButton(
          onPressed: _toggleMenu,
          shape: const CircleBorder(),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
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
    return FloatingActionButton.extended(
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
            child: GestureDetector(
              onTap: () {
                ref.read(fabMenuExpandedProvider.notifier).state = false;
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
      child: GestureDetector(
        onTap: () {
          ref.read(fabMenuExpandedProvider.notifier).state = false;
        },
        child: Container(color: Colors.black.withOpacity(0.5)),
      ),
    );
  }
}
