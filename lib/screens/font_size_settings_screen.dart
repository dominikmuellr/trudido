import 'package:flutter/material.dart';
import '../services/text_scale_service.dart';
import '../utils/responsive_size.dart';

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
        padding: const EdgeInsets.all(16.0),
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
          const SizedBox(height: 24),

          // Font size slider
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App font size',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _ignoreSystem
                        ? 'Custom size: ${(_value * 100).round()}%'
                        : 'Using system font size',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
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
          const SizedBox(height: 24),

          // Preview card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preview',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Task Title', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'This is how your tasks and notes will look with the current font size setting.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
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
          const SizedBox(height: 16),

          // Info card
          Card(
            color: colorScheme.primaryContainer.withOpacity(0.5),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScaledIcon(
                    Icons.info_outline,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
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
