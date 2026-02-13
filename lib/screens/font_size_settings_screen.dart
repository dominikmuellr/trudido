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
import '../services/text_scale_service.dart';
import '../utils/responsive_size.dart';
import '../theme/spacing_tokens.dart';

class FontSizeSettingsScreen extends StatefulWidget {
  const FontSizeSettingsScreen({super.key});

  @override
  State<FontSizeSettingsScreen> createState() => _FontSizeSettingsScreenState();
}

class _FontSizeSettingsScreenState extends State<FontSizeSettingsScreen> {
  double _value = 1.0;
  bool _ignoreSystem = false;

  @override
  void initState() {
    super.initState();
    _value = textScaleNotifier.value;
    _ignoreSystem = ignoreSystemNotifier.value;
    textScaleNotifier.addListener(_sync);
    ignoreSystemNotifier.addListener(_syncBool);
  }

  @override
  void dispose() {
    textScaleNotifier.removeListener(_sync);
    ignoreSystemNotifier.removeListener(_syncBool);
    super.dispose();
  }

  void _sync() {
    if (mounted) {
      setState(() => _value = textScaleNotifier.value);
    }
  }

  void _syncBool() {
    if (mounted) {
      setState(() => _ignoreSystem = ignoreSystemNotifier.value);
    }
  }

  void _onScaleChanged(double v) {
    // Clamp to avoid floating-point precision issues
    final clamped = v.clamp(0.9, 1.3);
    setTextScale(clamped);
  }

  void _onIgnoreChanged(bool? v) {
    if (v != null) {
      setIgnoreSystem(v);
      // When turning off "ignore system", reset to 1.0 (default)
      if (!v) {
        setTextScale(1.0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Font Size'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: ListView(
        padding: SpacingEdgeInsets.insets16,
        children: [
          // Ignore system font size switch
          Card(
            child: SwitchListTile(
              title: const Text('Ignore system font size'),
              subtitle: const Text(
                'Use custom font size instead of device settings',
              ),
              value: _ignoreSystem,
              onChanged: _onIgnoreChanged,
            ),
          ),
          SpacingGap.gapV24,

          // Font size slider
          Card(
            child: Padding(
              padding: SpacingEdgeInsets.insets16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App font size',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SpacingGap.gapV8,
                  Text(
                    _ignoreSystem
                        ? 'Custom size: ${(_value * 100).round()}%'
                        : 'Using system font size',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SpacingGap.gapV16,
                  Opacity(
                    opacity: _ignoreSystem ? 1.0 : 0.5,
                    child: Row(
                      children: [
                        Text('A', style: theme.textTheme.bodySmall),
                        Expanded(
                          child: Slider(
                            min: 0.9,
                            max: 1.3,
                            divisions: 8,
                            value: _value.clamp(0.9, 1.3),
                            label: '${(_value * 100).round()}%',
                            onChanged: _ignoreSystem ? _onScaleChanged : null,
                          ),
                        ),
                        Text('A', style: theme.textTheme.headlineMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SpacingGap.gapV24,

          // Preview card
          Card(
            child: Padding(
              padding: SpacingEdgeInsets.insets16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preview',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SpacingGap.gapV16,
                  Text('Task Title', style: theme.textTheme.titleLarge),
                  SpacingGap.gapV8,
                  Text(
                    'This is how your tasks and notes will look with the current font size setting.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  SpacingGap.gapV8,
                  Text(
                    'Small details and timestamps',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SpacingGap.gapV16,

          // Info card
          Card(
            color: colorScheme.primaryContainer.withValues(alpha: 0.5),
            child: Padding(
              padding: SpacingEdgeInsets.insets16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScaledIcon(
                    Icons.info_outline,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  SpacingGap.gapH12,
                  Expanded(
                    child: Text(
                      _ignoreSystem
                          ? 'Custom font size (90% - 130%) overrides your device settings, similar to Reddit\'s font size control.'
                          : 'Turn on "Ignore system font size" to customize the app\'s text size independently from your device settings.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
