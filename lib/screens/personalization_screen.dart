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

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/flavor_config.dart';
import '../services/avatar_service.dart';
import '../services/storage_service.dart';
import '../providers/app_providers.dart';
import '../controllers/preferences_controller.dart';
import 'font_size_settings_screen.dart';
import 'defaults_settings_screen.dart';
import '../theme/spacing_tokens.dart';

class PersonalizationScreen extends ConsumerStatefulWidget {
  const PersonalizationScreen({super.key});

  @override
  ConsumerState<PersonalizationScreen> createState() =>
      _PersonalizationScreenState();
}

class _PersonalizationScreenState extends ConsumerState<PersonalizationScreen> {
  late TextEditingController _nameController;
  File? _avatarFile;
  bool _hasNameChanges = false;

  @override
  void initState() {
    super.initState();
    final currentName = StorageService.getUserName();
    _nameController = TextEditingController(
      text: (currentName == '_SKIP_NAME_' || currentName == '_CLEARED_NAME_')
          ? ''
          : currentName,
    );
    _avatarFile = AvatarService.getAvatarFile();
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    setState(() {
      _hasNameChanges = true;
    });
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      await StorageService.setUserName('_CLEARED_NAME_');
    } else {
      await StorageService.setUserName(name);
    }
    setState(() {
      _hasNameChanges = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name saved'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showAvatarOptions() async {
    final colorScheme = Theme.of(context).colorScheme;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library, color: colorScheme.primary),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                await _pickFromGallery();
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: colorScheme.primary),
              title: const Text('Take a Photo'),
              onTap: () async {
                Navigator.pop(context);
                await _takePhoto();
              },
            ),
            if (_avatarFile != null)
              ListTile(
                leading: Icon(Icons.delete, color: colorScheme.error),
                title: Text(
                  'Remove Photo',
                  style: TextStyle(color: colorScheme.error),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _removeAvatar();
                },
              ),
            SpacingGap.gapV8,
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    final path = await AvatarService.pickAndSaveAvatar();
    if (path != null) {
      setState(() {
        _avatarFile = File(path);
      });
    }
  }

  Future<void> _takePhoto() async {
    final path = await AvatarService.takeAndSaveAvatar();
    if (path != null) {
      setState(() {
        _avatarFile = File(path);
      });
    }
  }

  Future<void> _removeAvatar() async {
    await AvatarService.deleteAvatar();
    setState(() {
      _avatarFile = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final userName = _nameController.text.trim();
    final hasName = userName.isNotEmpty;

    final initials = hasName ? AvatarService.getInitials(userName) : null;
    final backgroundColor = hasName
        ? AvatarService.getColorFromName(userName, colorScheme)
        : colorScheme.primaryContainer;
    final foregroundColor = AvatarService.getForegroundColor(
      backgroundColor,
      colorScheme,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalization'),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
      ),
      body: ListView(
        children: [
          // Profile Section
          _buildSectionHeader(context, 'Profile'),
          SpacingGap.gapV8,

          // Avatar and Name Column (centered)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Avatar (centered)
                GestureDetector(
                  onTap: _showAvatarOptions,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: _avatarFile != null
                            ? null
                            : backgroundColor,
                        backgroundImage: _avatarFile != null
                            ? FileImage(_avatarFile!)
                            : null,
                        child: _avatarFile != null
                            ? null
                            : initials != null
                            ? Text(
                                initials,
                                style: TextStyle(
                                  color: foregroundColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 32,
                                ),
                              )
                            : Icon(
                                Icons.person,
                                size: 50,
                                color: foregroundColor,
                              ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SpacingGap.gapV32,

                // Name Field
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Your Name',
                    hintText: 'Enter your name',
                    border: const OutlineInputBorder(),
                    suffixIcon: _hasNameChanges
                        ? IconButton(
                            icon: Icon(Icons.check, color: colorScheme.primary),
                            onPressed: _saveName,
                          )
                        : null,
                  ),
                  textCapitalization: TextCapitalization.words,
                  textAlign: TextAlign.center,
                  onSubmitted: (_) => _saveName(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Your name will appear in the greeting on the home screen.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          // Layout Section
          _buildSectionHeader(context, 'Layout'),
          const _ThemeModeSelector(),
          Consumer(
            builder: (context, ref, _) {
              final enabled = ref
                  .watch(preferencesStateProvider)
                  .useDynamicColor;
              final controller = ref.read(preferencesControllerProvider);
              return SwitchListTile(
                secondary: const Icon(Icons.auto_awesome_outlined),
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
              return const _AccentColorSelector();
            },
          ),
          // Contrast Level Selector (Material 3 January 2026)
          const _ContrastLevelSelector(),
          _buildFontSizeLink(),
          Consumer(
            builder: (context, ref, _) {
              final enabled = ref.watch(preferencesStateProvider).showSearchBar;
              final controller = ref.read(preferencesControllerProvider);
              return SwitchListTile(
                secondary: const Icon(Icons.search),
                title: const Text('Show Search Bar'),
                subtitle: const Text(
                  'Display search bar in header. Search is still available via the menu button',
                ),
                value: enabled,
                onChanged: (v) => controller.toggleShowSearchBar(),
              );
            },
          ),

          // Defaults Section
          _buildSectionHeader(context, 'Defaults'),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Default Settings'),
            subtitle: const Text(
              'Starting tab, task view, week start, greeting',
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const DefaultsSettingsScreen(),
                ),
              );
            },
          ),

          // Support Section (FDroid only - hidden on PlayStore)
          if (FlavorConfig.showDonations) ...[
            _buildSectionHeader(context, 'Support'),
            _buildSupportButtons(),
          ],

          const SizedBox(height: 32),
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

  Widget _buildFontSizeLink() {
    return ListTile(
      leading: const Icon(Icons.text_fields),
      title: const Text('Font Size'),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const FontSizeSettingsScreen(),
          ),
        );
      },
    );
  }

  Widget _buildSupportButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'If you enjoy using Trudido, consider supporting its development!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          SpacingGap.gapV12,
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildDonationButton(
                label: 'Ko-fi',
                icon: Icons.coffee_outlined,
                url: 'https://ko-fi.com/dominikmuellr',
                color: const Color(0xFFFF5E5B),
              ),
              _buildDonationButton(
                label: 'Liberapay',
                icon: Icons.favorite_outline,
                url: 'https://liberapay.com/dominikmuellr/donate',
                color: const Color(0xFFF6C915),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDonationButton({
    required String label,
    required IconData icon,
    required String url,
    required Color color,
  }) {
    return OutlinedButton.icon(
      onPressed: () async {
        final uri = Uri.parse(url);
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (e) {
          // URL couldn't be launched
        }
      },
      icon: Icon(icon, color: color, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
      ),
    );
  }
}

// ============================================================================
// Theme Mode Selector
// ============================================================================

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
      leading: const Icon(Icons.palette_outlined),
      title: const Text('Theme Mode'),
      subtitle: Text(
        current == ThemeMode.system
            ? 'Auto (follows device)'
            : current == ThemeMode.dark
            ? 'Dark'
            : 'Light',
      ),
      trailing: const Icon(Icons.arrow_drop_down),
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

    // Check if Hack, Dracula, or Solarized theme is selected and dynamic colors are disabled
    final isHackTheme = accentColorSeed == 0xFF00FF00 && !useDynamicColor;
    final isDraculaTheme = accentColorSeed == 0xFFBD93F9 && !useDynamicColor;
    final isSolarizedTheme = accentColorSeed == 0xFF268BD2 && !useDynamicColor;
    final isDarkOnlyTheme = isHackTheme || isDraculaTheme;
    final isBlackIncompatibleTheme = isDarkOnlyTheme || isSolarizedTheme;

    Widget buildOption(
      ThemeMode mode,
      String label,
      String desc,
      IconData icon,
    ) {
      final selected = current == mode;
      // Disable light mode and auto mode for dark-only themes
      final isEnabled =
          !(isDarkOnlyTheme &&
              (mode == ThemeMode.light || mode == ThemeMode.system));
      final effectiveColor = !isEnabled
          ? cs.onSurfaceVariant.withOpacity(0.4)
          : selected
          ? cs.primary
          : cs.onSurfaceVariant;

      String getUnavailableMessage() {
        if (isHackTheme) return 'Not available for Hack theme';
        if (isDraculaTheme) return 'Not available for Dracula theme';
        if (isSolarizedTheme) return 'Not available for Solarized theme';
        return desc;
      }

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
          isDarkOnlyTheme &&
                  (mode == ThemeMode.light || mode == ThemeMode.system)
              ? getUnavailableMessage()
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
            enabled: !isBlackIncompatibleTheme && current != ThemeMode.light,
            leading: Icon(
              Icons.contrast,
              color: (isBlackIncompatibleTheme || current == ThemeMode.light)
                  ? cs.onSurfaceVariant.withOpacity(0.4)
                  : cs.onSurfaceVariant,
            ),
            title: Text(
              'Black (AMOLED)',
              style: TextStyle(
                color: (isBlackIncompatibleTheme || current == ThemeMode.light)
                    ? cs.onSurfaceVariant.withOpacity(0.4)
                    : null,
              ),
            ),
            subtitle: isBlackIncompatibleTheme
                ? Text(
                    isSolarizedTheme
                        ? 'Not compatible with Solarized theme'
                        : 'Not compatible with this theme',
                    style: TextStyle(
                      color: cs.onSurfaceVariant.withOpacity(0.4),
                    ),
                  )
                : null,
            trailing: Switch(
              value: useBlackTheme,
              onChanged:
                  (current == ThemeMode.light || isBlackIncompatibleTheme)
                  ? null
                  : (v) {
                      controller.toggleBlackTheme();
                    },
            ),
            onTap: (current == ThemeMode.light || isBlackIncompatibleTheme)
                ? null
                : () {
                    controller.toggleBlackTheme();
                  },
          ),
          SpacingGap.gapV8,
        ],
      ),
    );
  }
}

// ============================================================================
// Accent Color Selector
// ============================================================================

class _AccentColorSelector extends ConsumerWidget {
  const _AccentColorSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesStateProvider);
    final currentColorSeed = prefs.accentColorSeed;
    final currentColorName = _getAccentColorName(currentColorSeed);

    return ListTile(
      leading: const Icon(Icons.palette_outlined),
      title: const Text('Accent Color'),
      subtitle: Text(currentColorName),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildColorPreview(currentColorSeed, context),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
      onTap: () async {
        final choice = await showModalBottomSheet<int>(
          context: context,
          isScrollControlled: true,
          builder: (ctx) {
            return DraggableScrollableSheet(
              initialChildSize: 0.5,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return _AccentColorSheet(
                  current: currentColorSeed,
                  scrollController: scrollController,
                );
              },
            );
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
    } else if (colorValue == 0xFFBD93F9) {
      // Special Dracula-style icon for Dracula theme
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: const Color(0xFF282A36), // Dracula background
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFBD93F9), width: 2),
        ),
        child: const Icon(
          Icons.nights_stay,
          color: Color(0xFFBD93F9),
          size: 12,
        ),
      );
    } else if (colorValue == 0xFF268BD2) {
      // Special Solarized icon showing light/dark split
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
              Expanded(
                child: Container(color: const Color(0xFFFDF6E3)),
              ), // Solarized light
              Expanded(
                child: Container(color: const Color(0xFF002B36)),
              ), // Solarized dark
            ],
          ),
        ),
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
      case 0xFFBD93F9:
        return 'Dracula';
      case 0xFF268BD2:
        return 'Solarized';
      case 0xFF607D8B:
        return 'Blue Grey';
      default:
        return 'Custom';
    }
  }
}

class _AccentColorSheet extends StatelessWidget {
  final int current;
  final ScrollController scrollController;

  const _AccentColorSheet({
    required this.current,
    required this.scrollController,
  });

  static const List<int> accentColorSeeds = [
    // Standard Material 3 seed colors
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
    0xFF607D8B, // Blue Grey
    // Custom theme colors with special behavior
    0xFF9E9E9E, // Monochrome (black/white accents)
    0xFF757575, // Grey (grey accents)
    0xFF00FF00, // Hack (Matrix green, dark mode only)
    0xFFBD93F9, // Dracula (authentic Dracula colors, dark mode only)
    0xFF268BD2, // Solarized (authentic Solarized colors with proper light/dark modes)
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

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withOpacity(0.4),
              borderRadius: SpacingBorderRadius.full,
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              'Choose Accent Color',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),

          // Scrollable content
          Expanded(
            child: ListView(
              controller: scrollController,
              children: [
                // Standard Material 3 colors section
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    'Standard Colors',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ...accentColorSeeds.take(14).map((colorValue) {
                  return buildOption(colorValue, _getColorName(colorValue));
                }),

                // Custom themes section
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Special Themes',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ...accentColorSeeds.skip(14).map((colorValue) {
                  return buildOption(colorValue, _getColorName(colorValue));
                }),

                SpacingGap.gapV16,
              ],
            ),
          ),
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
    } else if (colorValue == 0xFFBD93F9) {
      // Special Dracula-style icon for Dracula theme
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF282A36), // Dracula background
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? cs.primary : const Color(0xFFBD93F9),
            width: selected ? 2 : 1,
          ),
        ),
        child: const Icon(
          Icons.nights_stay,
          color: Color(0xFFBD93F9),
          size: 16,
        ),
      );
    } else if (colorValue == 0xFF268BD2) {
      // Special Solarized icon showing light/dark split
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
              Expanded(
                child: Container(color: const Color(0xFFFDF6E3)),
              ), // Solarized light
              Expanded(
                child: Container(color: const Color(0xFF002B36)),
              ), // Solarized dark
            ],
          ),
        ),
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
      case 0xFFBD93F9:
        return 'Dracula';
      case 0xFF268BD2:
        return 'Solarized';
      case 0xFF607D8B:
        return 'Blue Grey';
      default:
        return 'Custom';
    }
  }
}

// ============================================================================
// Contrast Level Selector (Material 3 January 2026)
// ============================================================================

class _ContrastLevelSelector extends ConsumerWidget {
  const _ContrastLevelSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesStateProvider);
    final currentLevel = prefs.contrastLevel;

    String getDisplayName(String level) {
      switch (level) {
        case 'medium':
          return 'Medium';
        case 'high':
          return 'High';
        case 'standard':
        default:
          return 'Standard';
      }
    }

    return ListTile(
      leading: const Icon(Icons.contrast),
      title: const Text('Contrast Level'),
      subtitle: Text(getDisplayName(currentLevel)),
      trailing: const Icon(Icons.arrow_drop_down),
      onTap: () async {
        final choice = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (ctx) {
            return _ContrastLevelSheet(current: currentLevel);
          },
        );
        if (choice != null) {
          final controller = ref.read(preferencesControllerProvider);
          await controller.setContrastLevel(choice);
        }
      },
    );
  }
}

class _ContrastLevelSheet extends StatelessWidget {
  final String current;
  const _ContrastLevelSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget buildOption(String level, String label, String desc, IconData icon) {
      final selected = current == level;
      return ListTile(
        leading: Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant),
        title: Text(
          label,
          style: TextStyle(fontWeight: selected ? FontWeight.w600 : null),
        ),
        subtitle: Text(desc),
        trailing: selected ? Icon(Icons.check, color: cs.primary) : null,
        onTap: () => Navigator.of(context).pop(level),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contrast Level',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Adjust color contrast for better visibility',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          buildOption(
            'standard',
            'Standard',
            'Default contrast for most users',
            Icons.contrast,
          ),
          buildOption(
            'medium',
            'Medium',
            'Enhanced contrast for improved readability',
            Icons.contrast_outlined,
          ),
          buildOption(
            'high',
            'High',
            'Maximum contrast for accessibility needs',
            Icons.accessibility_new,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
