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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/custom_theme.dart';
import '../services/storage_service.dart';
import '../controllers/preferences_controller.dart';
import '../providers/app_providers.dart';
import '../services/theme_service.dart';
import '../theme/spacing_tokens.dart';
import 'custom_theme_editor_screen.dart';

/// Screen that lists all saved custom themes, allowing users to create,
/// activate, edit, duplicate, delete, and import themes.
class CustomThemeListScreen extends ConsumerStatefulWidget {
  const CustomThemeListScreen({super.key});

  @override
  ConsumerState<CustomThemeListScreen> createState() =>
      _CustomThemeListScreenState();
}

class _CustomThemeListScreenState extends ConsumerState<CustomThemeListScreen> {
  List<CustomTheme> _themes = [];
  String? _activeThemeId;

  @override
  void initState() {
    super.initState();
    _loadThemes();
  }

  void _loadThemes() {
    final jsonStrings = StorageService.getAllCustomThemes();
    _themes = jsonStrings
        .map((s) {
          try {
            return CustomTheme.fromJsonString(s);
          } catch (_) {
            return null;
          }
        })
        .whereType<CustomTheme>()
        .toList();
    _themes.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    _activeThemeId = ref.read(preferencesStateProvider).activeCustomThemeId;
  }

  /// Bump the revision counter so main.dart reloads the custom theme from storage.
  void _bumpThemeRevision() {
    final current = ref.read(customThemeRevisionProvider);
    ref.read(customThemeRevisionProvider.notifier).update(current + 1);
  }

  Future<void> _createNewTheme() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CustomThemeEditorScreen()),
    );
    if (result == true) {
      _bumpThemeRevision();
      setState(_loadThemes);
    }
  }

  Future<void> _editTheme(CustomTheme theme) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomThemeEditorScreen(existingTheme: theme),
      ),
    );
    if (result == true) {
      _bumpThemeRevision();
      setState(_loadThemes);
    }
  }

  Future<void> _activateTheme(String id) async {
    final controller = ref.read(preferencesControllerProvider);
    await controller.setActiveCustomTheme(id);
    setState(() => _activeThemeId = id);
  }

  Future<void> _deactivateTheme() async {
    final controller = ref.read(preferencesControllerProvider);
    await controller.clearActiveCustomTheme();
    setState(() => _activeThemeId = null);
  }

  Future<void> _duplicateTheme(CustomTheme theme) async {
    final newTheme = theme.duplicate(
      newId: DateTime.now().millisecondsSinceEpoch.toString(),
      newName: '${theme.name} (Copy)',
    );
    await StorageService.saveCustomTheme(newTheme.id, newTheme.toJsonString());
    setState(_loadThemes);
  }

  Future<void> _deleteTheme(CustomTheme theme) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Theme?'),
        content: Text('Delete "${theme.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      // If deleting the active theme, deactivate first
      if (theme.id == _activeThemeId) {
        await ref.read(preferencesControllerProvider).clearActiveCustomTheme();
      }
      await StorageService.deleteCustomTheme(theme.id);
      setState(_loadThemes);
    }
  }

  Future<void> _importFromFile() async {
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
    // Give it a new id to avoid conflicts
    final newTheme = CustomTheme(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: imported.name,
      lightColors: Map<String, int>.from(imported.lightColors),
      darkColors: Map<String, int>.from(imported.darkColors),
      fontFamily: imported.fontFamily,
    );

    await StorageService.saveCustomTheme(newTheme.id, newTheme.toJsonString());
    setState(_loadThemes);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Imported "${newTheme.name}"')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Themes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Import from File',
            onPressed: _importFromFile,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewTheme,
        icon: const Icon(Icons.add),
        label: const Text('New Theme'),
      ),
      body: _themes.isEmpty
          ? _buildEmptyState(theme, colorScheme)
          : _buildThemeList(theme, colorScheme),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.palette_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            SpacingGap.gapV16,
            Text(
              'No Custom Themes Yet',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            SpacingGap.gapV8,
            Text(
              'Create your own theme with full control over every color, '
              'or import one from a friend.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeList(ThemeData theme, ColorScheme colorScheme) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: _themes.length,
      itemBuilder: (context, index) {
        final customTheme = _themes[index];
        final isActive = customTheme.id == _activeThemeId;
        return _buildThemeCard(customTheme, isActive, theme, colorScheme);
      },
    );
  }

  Widget _buildThemeCard(
    CustomTheme customTheme,
    bool isActive,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    // Build preview color schemes
    final lightScheme = customTheme.buildColorScheme(Brightness.light);
    final darkScheme = customTheme.buildColorScheme(Brightness.dark);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isActive ? colorScheme.primary : colorScheme.outlineVariant,
          width: isActive ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _editTheme(customTheme),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Active',
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      customTheme.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (action) {
                      switch (action) {
                        case 'activate':
                          _activateTheme(customTheme.id);
                          break;
                        case 'deactivate':
                          _deactivateTheme();
                          break;
                        case 'edit':
                          _editTheme(customTheme);
                          break;
                        case 'duplicate':
                          _duplicateTheme(customTheme);
                          break;
                        case 'delete':
                          _deleteTheme(customTheme);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      if (!isActive)
                        const PopupMenuItem(
                          value: 'activate',
                          child: ListTile(
                            leading: Icon(Icons.check_circle),
                            title: Text('Activate'),
                            dense: true,
                          ),
                        )
                      else
                        const PopupMenuItem(
                          value: 'deactivate',
                          child: ListTile(
                            leading: Icon(Icons.cancel_outlined),
                            title: Text('Deactivate'),
                            dense: true,
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('Edit'),
                          dense: true,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: ListTile(
                          leading: Icon(Icons.copy),
                          title: Text('Duplicate'),
                          dense: true,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete, color: colorScheme.error),
                          title: Text(
                            'Delete',
                            style: TextStyle(color: colorScheme.error),
                          ),
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              SpacingGap.gapV8,

              // Color preview swatches (light)
              Row(
                children: [
                  Icon(
                    Icons.light_mode,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  _colorSwatch(lightScheme.primary),
                  _colorSwatch(lightScheme.secondary),
                  _colorSwatch(lightScheme.tertiary),
                  _colorSwatch(lightScheme.surface),
                  _colorSwatch(lightScheme.primaryContainer),
                  _colorSwatch(lightScheme.error),
                  const Spacer(),
                  Text(
                    '${customTheme.lightColors.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              SpacingGap.gapV4,

              // Color preview swatches (dark)
              Row(
                children: [
                  Icon(
                    Icons.dark_mode,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  _colorSwatch(darkScheme.primary),
                  _colorSwatch(darkScheme.secondary),
                  _colorSwatch(darkScheme.tertiary),
                  _colorSwatch(darkScheme.surface),
                  _colorSwatch(darkScheme.primaryContainer),
                  _colorSwatch(darkScheme.error),
                  const Spacer(),
                  Text(
                    '${customTheme.darkColors.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colorSwatch(Color color) {
    return Container(
      width: 24,
      height: 24,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
    );
  }
}
