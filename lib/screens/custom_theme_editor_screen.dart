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
import '../models/custom_theme.dart';
import '../providers/app_providers.dart';
import '../services/storage_service.dart';
import '../services/theme_service.dart';
import '../theme/spacing_tokens.dart';

/// Screen for creating and editing custom themes with full Material 3

class CustomThemeEditorScreen extends ConsumerStatefulWidget {
  /// The theme to edit. If null, creates a new theme.
  final CustomTheme? existingTheme;

  const CustomThemeEditorScreen({super.key, this.existingTheme});

  @override
  ConsumerState<CustomThemeEditorScreen> createState() =>
      _CustomThemeEditorScreenState();
}

class _CustomThemeEditorScreenState
    extends ConsumerState<CustomThemeEditorScreen> {
  late CustomTheme _theme;
  late TextEditingController _nameController;
  Brightness _editingBrightness = Brightness.light;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingTheme != null) {
      // Edit existing - deep copy the color maps
      _theme = CustomTheme(
        id: widget.existingTheme!.id,
        name: widget.existingTheme!.name,
        lightColors: Map<String, int>.from(widget.existingTheme!.lightColors),
        darkColors: Map<String, int>.from(widget.existingTheme!.darkColors),
        fontFamily: widget.existingTheme!.fontFamily,
        createdAt: widget.existingTheme!.createdAt,
        modifiedAt: widget.existingTheme!.modifiedAt,
      );
    } else {
      // Create new
      _theme = CustomTheme(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'My Theme',
      );
    }
    _nameController = TextEditingController(text: _theme.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool _didSave = false;

  /// Whether this theme is currently the active app theme.
  bool get _isActiveTheme {
    return ref.read(preferencesStateProvider).activeCustomThemeId == _theme.id;
  }

  /// Bump the revision counter so main.dart reloads the custom theme.
  void _bumpThemeRevision() {
    final current = ref.read(customThemeRevisionProvider);
    ref.read(customThemeRevisionProvider.notifier).update(current + 1);
  }

  Future<void> _save({bool popAfter = false}) async {
    _theme.name = _nameController.text.trim();
    if (_theme.name.isEmpty) _theme.name = 'Untitled Theme';
    _theme.modifiedAt = DateTime.now().toIso8601String();
    await StorageService.saveCustomTheme(_theme.id, _theme.toJsonString());
    _hasChanges = false;
    _didSave = true;
    // If this theme is active, immediately update the app theme
    if (_isActiveTheme) _bumpThemeRevision();
    if (mounted) {
      if (popAfter) {
        Navigator.pop(context, true);
      } else {
        setState(() {}); // refresh save button state
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Theme saved'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('You have unsaved changes. Save before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true), // discard
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false), // cancel
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await _save();
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  Future<void> _showColorPicker(String roleKey) async {
    final currentColor = _theme.getSeedColor(roleKey, _editingBrightness);
    final isCustomized = _theme.isColorCustomized(roleKey, _editingBrightness);
    Color? pickedColor;

    // Use Flutter's native color picker - much simpler!
    pickedColor = await showDialog<Color>(
      context: context,
      builder: (context) {
        Color tempColor = currentColor;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(_getRoleLabel(roleKey)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Simple color picker with common colors
                    _buildSimpleColorPicker(
                      tempColor,
                      (color) => setState(() => tempColor = color),
                    ),
                    const SizedBox(height: 16),
                    // Current color preview
                    Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        color: tempColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '#${tempColor.value.toRadixString(16).substring(2).toUpperCase()}',
                          style: TextStyle(
                            color: tempColor.computeLuminance() > 0.5
                                ? Colors.black
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Material You result preview
                    Builder(
                      builder: (context) {
                        final previewScheme = ColorScheme.fromSeed(
                          seedColor: tempColor,
                          brightness: _editingBrightness,
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Material You result',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: previewScheme.primary,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Button',
                                        style: TextStyle(
                                          color: previewScheme.onPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: previewScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Chip',
                                        style: TextStyle(
                                          color:
                                              previewScheme.onPrimaryContainer,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildColorWarning(tempColor, roleKey),
                  ],
                ),
              ),
              actions: [
                if (isCustomized)
                  TextButton(
                    onPressed: () {
                      _theme.resetColor(roleKey, _editingBrightness);
                      _markChanged();
                      Navigator.pop(context, null);
                    },
                    child: Text(
                      'Reset to Auto',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, tempColor),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (pickedColor != null) {
      setState(() {
        _theme.setColor(roleKey, pickedColor!, _editingBrightness);
        _markChanged();
      });
    } else if (pickedColor == null && !isCustomized) {
      // Was reset - refresh UI
      setState(() {});
    }
  }

  /// Build a simple grid of common colors
  Widget _buildSimpleColorPicker(
    Color currentColor,
    Function(Color) onColorChanged,
  ) {
    // Material You seed colors — muted tone-40 values that produce
    // soft, elegant palettes per Google's Material You guidelines
    final commonColors = [
      const Color(0xFFB4464C), // Red
      const Color(0xFFAD4670), // Rose
      const Color(0xFF9C4589), // Pink
      const Color(0xFF8450A0), // Purple
      const Color(0xFF6058B0), // Deep Purple
      const Color(0xFF4A64B8), // Indigo
      const Color(0xFF3D78B8), // Blue
      const Color(0xFF358CA8), // Steel Blue
      const Color(0xFF2E8E8E), // Teal
      const Color(0xFF38826A), // Seafoam
      const Color(0xFF488258), // Green
      const Color(0xFF618345), // Sage
      const Color(0xFF7B7E35), // Olive
      const Color(0xFF96793A), // Gold
      const Color(0xFFA06D38), // Amber
      const Color(0xFFA66040), // Terracotta
      const Color(0xFF8B6558), // Earth
      const Color(0xFF6B6F7E), // Blue Grey
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: commonColors.map((color) {
        final isSelected = color.value == currentColor.value;
        return InkWell(
          onTap: () => onColorChanged(color),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
                width: isSelected ? 3 : 1,
              ),
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    color: color.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }

  /// Build warning for problematic colors (pure white/black)
  Widget _buildColorWarning(Color color, String roleKey) {
    // Only show warnings for primary/secondary colors
    if (roleKey != 'primary' && roleKey != 'secondary') {
      return const SizedBox.shrink();
    }

    final warning = CustomTheme.getColorWarning(color, _editingBrightness);
    if (warning == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.error),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_rounded, color: colorScheme.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              warning,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // Build UI
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isNew = widget.existingTheme == null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!_hasChanges) {
          if (mounted) Navigator.pop(context, _didSave);
          return;
        }
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) Navigator.pop(context, _didSave);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isNew ? 'New Custom Theme' : 'Edit Theme'),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save',
              onPressed: _hasChanges ? () => _save() : null,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // Theme name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'Theme Name',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => _markChanged(),
            ),
            SpacingGap.gapV16,

            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Pick 2 colors. Essential sets the app. Enhanced '
                          'colors everything else.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: colorScheme.primary.withOpacity(0.7),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Material You generates subtle, professional variations from your colors. '
                          'Hot restart after saving to see changes.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.8),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SpacingGap.gapV16,

            // Light/Dark toggle
            _buildBrightnessToggle(colorScheme),
            SpacingGap.gapV12,

            // Preview card
            _buildPreviewCard(),
            SpacingGap.gapV16,

            // Color role list organized by category
            _buildColorList(),

            SpacingGap.gapV16,

            // Reset section
            _buildResetSection(colorScheme),
            SpacingGap.gapV24,
          ],
        ),
      ),
    );
  }

  Widget _buildBrightnessToggle(ColorScheme colorScheme) {
    return SegmentedButton<Brightness>(
      segments: const [
        ButtonSegment(
          value: Brightness.light,
          label: Text('Light'),
          icon: Icon(Icons.light_mode),
        ),
        ButtonSegment(
          value: Brightness.dark,
          label: Text('Dark'),
          icon: Icon(Icons.dark_mode),
        ),
      ],
      selected: {_editingBrightness},
      onSelectionChanged: (selection) {
        setState(() => _editingBrightness = selection.first);
      },
    );
  }

  // ============================================================================
  // Color List - All Roles Organized by Category
  // ============================================================================

  Widget _buildColorList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < CustomTheme.colorSections.length; i++)
          _buildColorSection(CustomTheme.colorSections[i], i),
      ],
    );
  }

  Widget _buildPreviewCard() {
    final scheme = _theme.buildColorScheme(_editingBrightness);
    final isDark = _editingBrightness == Brightness.dark;

    return Card(
      elevation: 2,
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.preview, color: scheme.primary, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Preview',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'See how your colors work together in ${isDark ? "dark" : "light"} mode',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 20),

            // Warning banner if colors are problematic
            ..._buildPreviewWarnings(scheme),

            // Main color chips
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _previewChip(
                  'Essential',
                  scheme.primary,
                  scheme.onPrimary,
                  Icons.palette,
                ),
                _previewChip(
                  'Enhanced',
                  scheme.secondary,
                  scheme.onSecondary,
                  Icons.bolt,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Example UI elements
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.task_alt,
                          color: scheme.onPrimaryContainer,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Task example',
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Background and text auto-generated',
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Enhanced',
                          style: TextStyle(
                            color: scheme.onSecondaryContainer,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search bar preview
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          size: 18,
                          color: scheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Search example...',
                          style: TextStyle(
                            color: scheme.onSecondaryContainer.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () {},
                          style: FilledButton.styleFrom(
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                          ),
                          child: const Text('Essential'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: () {},
                          style: FilledButton.styleFrom(
                            backgroundColor: scheme.secondaryContainer,
                            foregroundColor: scheme.onSecondaryContainer,
                          ),
                          child: const Text('Enhanced'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            foregroundColor: scheme.primary,
                          ),
                          child: const Text('Outline'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build warning banners for problematic colors in preview
  List<Widget> _buildPreviewWarnings(ColorScheme scheme) {
    final warnings = <Widget>[];
    final colors = _editingBrightness == Brightness.light
        ? _theme.lightColors
        : _theme.darkColors;

    // Check primary color
    if (colors.containsKey('primary')) {
      final primaryColor = Color(colors['primary']!);
      final warning = CustomTheme.getColorWarning(
        primaryColor,
        _editingBrightness,
      );
      if (warning != null) {
        warnings.add(
          _buildWarningBanner('Your Essential color', warning, scheme),
        );
      }
    }

    // Check secondary color
    if (colors.containsKey('secondary')) {
      final secondaryColor = Color(colors['secondary']!);
      final warning = CustomTheme.getColorWarning(
        secondaryColor,
        _editingBrightness,
      );
      if (warning != null) {
        warnings.add(
          _buildWarningBanner('Your Enhanced color', warning, scheme),
        );
      }
    }

    if (warnings.isNotEmpty) {
      return [...warnings, const SizedBox(height: 12)];
    }
    return [];
  }

  Widget _buildWarningBanner(
    String colorName,
    String message,
    ColorScheme scheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.error.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: scheme.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  colorName,
                  style: TextStyle(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  message,
                  style: TextStyle(
                    color: scheme.onErrorContainer,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewChip(String label, Color bg, Color fg, IconData icon) {
    // Check contrast
    final contrast = CustomTheme.contrastRatio(fg, bg);
    final hasGoodContrast = contrast >= 4.5;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: bg.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: fg, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // Contrast warning badge
        if (!hasGoodContrast)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildColorSection(ColorRoleSection section, int index) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    section.roles.first.icon,
                    color: colorScheme.onPrimaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        section.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (final role in section.roles) _buildColorTile(role),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // Individual Color Tile
  // ============================================================================

  Widget _buildColorTile(ColorRoleInfo role) {
    final resolvedColor = _theme.getResolvedColor(role.key, _editingBrightness);
    final isCustomized = _theme.isColorCustomized(role.key, _editingBrightness);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCustomized
              ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
              : Theme.of(context).colorScheme.outlineVariant,
          width: isCustomized ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showColorPicker(role.key),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Color preview circle
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: resolvedColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: resolvedColor.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isCustomized
                    ? null
                    : Icon(
                        Icons.auto_awesome,
                        size: 24,
                        color: _contrastIcon(resolvedColor),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          role.icon,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          role.label,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      role.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (isCustomized) ...[
                      const SizedBox(height: 4),
                      Text(
                        '#${resolvedColor.value.toRadixString(16).substring(2).toUpperCase()}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withOpacity(0.7),
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Action button
              if (isCustomized)
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  tooltip: 'Reset to auto',
                  onPressed: () {
                    setState(() {
                      _theme.resetColor(role.key, _editingBrightness);
                      _markChanged();
                    });
                  },
                )
              else
                Icon(
                  Icons.edit_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _contrastIcon(Color bg) {
    return bg.computeLuminance() > 0.5
        ? Colors.black.withOpacity(0.4)
        : Colors.white.withOpacity(0.4);
  }

  // ============================================================================
  // Reset Section
  // ============================================================================

  Widget _buildResetSection(ColorScheme colorScheme) {
    final brightnessLabel = _editingBrightness == Brightness.light
        ? 'Light'
        : 'Dark';
    final colorsMap = _editingBrightness == Brightness.light
        ? _theme.lightColors
        : _theme.darkColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reset',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: colorScheme.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        SpacingGap.gapV8,
        OutlinedButton.icon(
          onPressed: colorsMap.isEmpty
              ? null
              : () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Reset $brightnessLabel Colors?'),
                      content: Text(
                        'This will remove all custom $brightnessLabel mode '
                        'colors and revert to auto-generated values.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    setState(() {
                      _theme.resetAll(_editingBrightness);
                      _markChanged();
                    });
                  }
                },
          icon: const Icon(Icons.restart_alt),
          label: Text('Reset All $brightnessLabel Colors'),
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.error,
            side: BorderSide(color: colorScheme.error.withOpacity(0.5)),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // Helpers
  // ============================================================================

  String _getRoleLabel(String key) {
    // Check all color sections
    for (final section in CustomTheme.colorSections) {
      for (final role in section.roles) {
        if (role.key == key) return role.label;
      }
    }
    return key;
  }
}
