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
import 'package:file_picker/file_picker.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/custom_theme.dart';
import '../providers/app_providers.dart';
import '../services/storage_service.dart';
import '../services/theme_service.dart';
import '../theme/spacing_tokens.dart';

/// Screen for creating and editing custom themes with full Material 3
/// color role customization. Supports Normal mode (10 essential colors)
/// and Advanced mode (all 48 color roles).
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
  bool _advancedMode = false;
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
    final currentColor = _theme.getResolvedColor(roleKey, _editingBrightness);
    final isCustomized = _theme.isColorCustomized(roleKey, _editingBrightness);
    Color pickedColor = currentColor;

    final result = await showDialog<Color>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final colorScheme = Theme.of(context).colorScheme;
            return AlertDialog(
              title: Text(_getRoleLabel(roleKey)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Color picker wheel + controls
                    ColorPicker(
                      color: pickedColor,
                      onColorChanged: (color) {
                        setDialogState(() => pickedColor = color);
                      },
                      pickersEnabled: const <ColorPickerType, bool>{
                        ColorPickerType.both: false,
                        ColorPickerType.primary: false,
                        ColorPickerType.accent: false,
                        ColorPickerType.bw: false,
                        ColorPickerType.custom: false,
                        ColorPickerType.customSecondary: false,
                        ColorPickerType.wheel: true,
                      },
                      enableShadesSelection: true,
                      enableTonalPalette: true,
                      enableOpacity: false,
                      width: 44,
                      height: 44,
                      borderRadius: 22,
                      wheelDiameter: 230,
                      wheelWidth: 20,
                      wheelHasBorder: true,
                      showColorCode: true,
                      colorCodeHasColor: true,
                      copyPasteBehavior: const ColorPickerCopyPasteBehavior(
                        copyFormat: ColorPickerCopyFormat.hexRRGGBB,
                        pasteButton: true,
                        copyButton: true,
                      ),
                      heading: Text(
                        'Select color',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      subheading: Text(
                        'Shades',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      tonalSubheading: Text(
                        'Tonal palette',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),

                    // Contrast info
                    if (_isContentRole(roleKey)) ...[
                      const Divider(),
                      _buildContrastInfo(pickedColor, roleKey),
                    ],
                  ],
                ),
              ),
              actions: [
                if (isCustomized)
                  TextButton(
                    onPressed: () {
                      // Reset to auto
                      _theme.resetColor(roleKey, _editingBrightness);
                      _markChanged();
                      Navigator.pop(context, null);
                    },
                    child: Text(
                      'Reset to Auto',
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, pickedColor),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _theme.setColor(roleKey, result, _editingBrightness);
        _markChanged();
      });
    } else {
      // May have been reset - refresh UI
      setState(() {});
    }
  }

  /// Build a contrast ratio indicator for "on" colors against their background
  Widget _buildContrastInfo(Color foreground, String roleKey) {
    final bgKey = _getBackgroundKeyForContent(roleKey);
    if (bgKey == null) return const SizedBox.shrink();

    final bgColor = _theme.getResolvedColor(bgKey, _editingBrightness);
    final ratio = CustomTheme.contrastRatio(foreground, bgColor);
    final meetsAA = ratio >= 4.5;
    final meetsAAA = ratio >= 7.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            meetsAA ? Icons.check_circle : Icons.warning,
            color: meetsAA ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Contrast: ${ratio.toStringAsFixed(1)}:1 '
              '${meetsAAA
                  ? "(AAA ✓)"
                  : meetsAA
                  ? "(AA ✓)"
                  : "(Low contrast)"}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // Import / Export (file-based)
  // ============================================================================

  Future<void> _exportTheme() async {
    _theme.name = _nameController.text.trim();
    if (_theme.name.isEmpty) _theme.name = 'Untitled Theme';
    final json = _theme.toJsonString();

    // Write to a temp file and share it
    final dir = await getTemporaryDirectory();
    final safeName = _theme.name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
    final file = File('${dir.path}/${safeName}_theme.json');
    await file.writeAsString(json);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'Trudido Theme: ${_theme.name}',
      ),
    );
  }

  Future<void> _importTheme() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    String jsonString;
    final picked = result.files.single;
    if (picked.bytes != null) {
      jsonString = String.fromCharCodes(picked.bytes!);
    } else if (picked.path != null) {
      jsonString = await File(picked.path!).readAsString();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read the selected file')),
        );
      }
      return;
    }

    final error = CustomTheme.validateJson(jsonString);
    if (error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The selected file is not a valid Trudido theme'),
          ),
        );
      }
      return;
    }

    final imported = CustomTheme.fromJsonString(jsonString);

    // Confirm import
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Import "${imported.name}"?'),
        content: Text(
          'This will replace all colors in the current editor with '
          'the imported theme colors. ${imported.lightColors.length} light '
          'and ${imported.darkColors.length} dark colors will be loaded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _theme.lightColors
          ..clear()
          ..addAll(imported.lightColors);
        _theme.darkColors
          ..clear()
          ..addAll(imported.darkColors);
        _theme.fontFamily = imported.fontFamily;
        _nameController.text = imported.name;
        _markChanged();
      });
    }
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
              icon: const Icon(Icons.file_download_outlined),
              tooltip: 'Import from File',
              onPressed: _importTheme,
            ),
            IconButton(
              icon: const Icon(Icons.file_upload_outlined),
              tooltip: 'Export as File',
              onPressed: _exportTheme,
            ),
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

            // Light/Dark toggle
            _buildBrightnessToggle(colorScheme),
            SpacingGap.gapV12,

            // Preview card
            _buildPreviewCard(),
            SpacingGap.gapV16,

            // Normal/Advanced toggle
            _buildModeToggle(colorScheme),
            SpacingGap.gapV12,

            // Color role list
            if (_advancedMode)
              _buildAdvancedColorList()
            else
              _buildNormalColorList(),

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

  Widget _buildModeToggle(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _advancedMode ? 'Advanced Mode' : 'Normal Mode',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () => setState(() => _advancedMode = !_advancedMode),
          icon: Icon(_advancedMode ? Icons.tune : Icons.settings, size: 18),
          label: Text(_advancedMode ? 'Simple Mode' : 'Advanced'),
        ),
      ],
    );
  }

  Widget _buildPreviewCard() {
    final scheme = _theme.buildColorScheme(_editingBrightness);
    final isDark = _editingBrightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preview',
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This is how your theme looks in ${isDark ? "dark" : "light"} mode.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _previewChip('Primary', scheme.primary, scheme.onPrimary),
                const SizedBox(width: 8),
                _previewChip('Secondary', scheme.secondary, scheme.onSecondary),
                const SizedBox(width: 8),
                _previewChip('Tertiary', scheme.tertiary, scheme.onTertiary),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Container',
                      style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: scheme.outline),
                    ),
                    child: Text(
                      'Surface',
                      style: TextStyle(color: scheme.onSurface, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Error',
                      style: TextStyle(
                        color: scheme.onErrorContainer,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewChip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  // ============================================================================
  // Normal Mode - 10 Essential Colors
  // ============================================================================

  Widget _buildNormalColorList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final role in CustomTheme.essentialRoles) _buildColorTile(role),
      ],
    );
  }

  // ============================================================================
  // Advanced Mode - All 48 Roles in Sections
  // ============================================================================

  Widget _buildAdvancedColorList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in CustomTheme.advancedSections)
          _buildAdvancedSection(section),
      ],
    );
  }

  Widget _buildAdvancedSection(ColorRoleSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
          child: Text(
            section.title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (final role in section.roles) _buildColorTile(role),
        const Divider(),
      ],
    );
  }

  // ============================================================================
  // Individual Color Tile
  // ============================================================================

  Widget _buildColorTile(ColorRoleInfo role) {
    final resolvedColor = _theme.getResolvedColor(role.key, _editingBrightness);
    final isCustomized = _theme.isColorCustomized(role.key, _editingBrightness);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: resolvedColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: isCustomized
            ? null
            : Icon(
                Icons.auto_awesome,
                size: 16,
                color: _contrastIcon(resolvedColor),
              ),
      ),
      title: Text(
        role.label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: isCustomized ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      subtitle: Text(
        isCustomized
            ? '#${resolvedColor.value.toRadixString(16).substring(2).toUpperCase()}'
            : 'Auto-generated',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: isCustomized
          ? IconButton(
              icon: Icon(
                Icons.refresh,
                size: 20,
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
          : const Icon(Icons.chevron_right, size: 20),
      onTap: () => _showColorPicker(role.key),
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
    // Check essential roles first
    for (final role in CustomTheme.essentialRoles) {
      if (role.key == key) return role.label;
    }
    // Then check advanced sections
    for (final section in CustomTheme.advancedSections) {
      for (final role in section.roles) {
        if (role.key == key) return role.label;
      }
    }
    return key;
  }

  /// Whether this role is a "content" color (text on a background)
  bool _isContentRole(String key) {
    return key.startsWith('on') || key == 'inversePrimary';
  }

  /// Get the background key for a content/foreground role
  String? _getBackgroundKeyForContent(String key) {
    switch (key) {
      case 'onPrimary':
        return 'primary';
      case 'onPrimaryContainer':
        return 'primaryContainer';
      case 'onPrimaryFixed':
        return 'primaryFixed';
      case 'onPrimaryFixedVariant':
        return 'primaryFixedDim';
      case 'onSecondary':
        return 'secondary';
      case 'onSecondaryContainer':
        return 'secondaryContainer';
      case 'onSecondaryFixed':
        return 'secondaryFixed';
      case 'onSecondaryFixedVariant':
        return 'secondaryFixedDim';
      case 'onTertiary':
        return 'tertiary';
      case 'onTertiaryContainer':
        return 'tertiaryContainer';
      case 'onTertiaryFixed':
        return 'tertiaryFixed';
      case 'onTertiaryFixedVariant':
        return 'tertiaryFixedDim';
      case 'onError':
        return 'error';
      case 'onErrorContainer':
        return 'errorContainer';
      case 'onSurface':
        return 'surface';
      case 'onSurfaceVariant':
        return 'surface';
      case 'onInverseSurface':
        return 'inverseSurface';
      case 'inversePrimary':
        return 'inverseSurface';
      default:
        return null;
    }
  }
}
