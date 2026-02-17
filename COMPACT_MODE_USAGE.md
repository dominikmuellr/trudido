# Compact Mode Usage Guide

This guide explains how to use the new Compact Mode feature throughout the app.

## Overview

Compact Mode allows power users to see more content on screen by:

- Reducing spacing and padding by 20% (using an 0.8 multiplier)
- Reducing text size by 10% (using a 0.90 text scale factor)
- Eliminating vertical padding in list tiles
- Making the UI more information-dense

## How Users Enable Compact Mode

Users can toggle Compact Mode in **Settings > Defaults > Compact Mode**.

## For Developers: Using Compact Spacing in Widgets

### 1. Basic Usage with AdaptiveSpacing Provider

The `adaptiveSpacingProvider` automatically adjusts spacing based on the compact mode setting:

```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = ref.watch(adaptiveSpacingProvider);

    return Padding(
      padding: spacing.insets16,  // Automatically adjusts: 16dp normal, 12.8dp compact
      child: Column(
        children: [
          Text('Item 1'),
          spacing.gapV8,  // Vertical gap: 8dp normal, 6.4dp compact
          Text('Item 2'),
        ],
      ),
    );
  }
}
```

### 2. Common Spacing Properties

```dart
final spacing = ref.watch(adaptiveSpacingProvider);

// Base spacing values
spacing.s4    // 4dp normal, 3.2dp compact
spacing.s8    // 8dp normal, 6.4dp compact
spacing.s16   // 16dp normal, 12.8dp compact
spacing.s24   // 24dp normal, 19.2dp compact

// Semantic spacing
spacing.paddingStandard      // 16dp normal, 12.8dp compact
spacing.cardPadding          // 16dp normal, 12.8dp compact
spacing.listTileVertical     // 4dp normal, 0dp compact (!)

// EdgeInsets
spacing.insets16             // All sides: 16dp normal, 12.8dp compact
spacing.insetsH16            // Horizontal: 16dp normal, 12.8dp compact
spacing.insetsV8             // Vertical: 8dp normal, 6.4dp compact
spacing.listTileInsets       // ListTile padding (h:16, v:4 normal; h:12.8, v:0 compact)

// Gaps (SizedBox)
spacing.gapV8                // Vertical: 8dp normal, 6.4dp compact
spacing.gapH16               // Horizontal: 16dp normal, 12.8dp compact
```

### 3. List Tiles (Most Impactful)

List tiles benefit most from compact mode:

```dart
class TaskListTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = ref.watch(adaptiveSpacingProvider);

    return ListTile(
      contentPadding: spacing.listTileInsets,  // Removes vertical padding in compact mode
      title: Text('Task name'),
      subtitle: Text('Details'),
    );
  }
}
```

### 4. Cards

```dart
class InfoCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = ref.watch(adaptiveSpacingProvider);

    return Card(
      child: Padding(
        padding: spacing.cardInsets,  // 16dp normal, 12.8dp compact
        child: Column(
          children: [
            Text('Title'),
            spacing.gapV12,  // 12dp normal, 9.6dp compact
            Text('Content'),
          ],
        ),
      ),
    );
  }
}
```

### 5. Custom Layouts

```dart
class CustomLayout extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = ref.watch(adaptiveSpacingProvider);

    return Container(
      margin: spacing.insetsH16,
      padding: spacing.insetsV8,
      child: Row(
        children: [
          Icon(Icons.info),
          spacing.gapH8,
          Expanded(child: Text('Info text')),
        ],
      ),
    );
  }
}
```

## Text Scaling

Text scaling is applied globally via MediaQuery in [main.dart](lib/main.dart):

```dart
// In MaterialApp builder:
final compactScale = ref.watch(compactTextScaleProvider);
final effective = baseScale * compactScale;  // 0.90 when compact mode is on

return MediaQuery(
  data: mq.copyWith(textScaler: TextScaler.linear(effective)),
  child: child,
);
```

No per-widget changes needed for text scaling - it's automatic!

## Migration Strategy

### Priority 1: List Views (High Impact)

- Task lists
- Note lists
- Settings screens
- Any scrollable lists where users want to see more items

### Priority 2: Cards & Containers (Medium Impact)

- Dashboard cards
- Summary widgets
- Dialog content

### Priority 3: Detail Screens (Lower Impact)

- Task editor
- Note editor
- Full-screen views

## Example Migration

**Before:**

```dart
return Padding(
  padding: SpacingEdgeInsets.insets16,
  child: Column(
    children: [
      Text('Item'),
      SpacingGap.gapV8,
      Text('Item'),
    ],
  ),
);
```

**After (Compact-Aware):**

```dart
final spacing = ref.watch(adaptiveSpacingProvider);

return Padding(
  padding: spacing.insets16,
  child: Column(
    children: [
      Text('Item'),
      spacing.gapV8,
      Text('Item'),
    ],
  ),
);
```

## Technical Details

### Constants in AdaptiveSpacing

- **Spacing multiplier:** 0.8 (20% reduction)
- **Text scale factor:** 0.90 (10% reduction)
- **List tile vertical padding in compact mode:** 0dp (complete removal)

### Providers

- `adaptiveSpacingProvider` - Returns AdaptiveSpacing instance
- `compactTextScaleProvider` - Returns text scale factor (0.90 or 1.0)
- Both are defined in [lib/providers/app_providers.dart](lib/providers/app_providers.dart)

### Settings Storage

- Key: `compact_density` (bool)
- Service: `PreferencesService`
- Controller method: `toggleCompactDensity()`
- UI: Settings > Defaults > Compact Mode

## Notes

- Static spacing (`Spacing.s16`) remains unchanged and should only be used for constants
- Use `spacing.s16` (via provider) for runtime-adjustable spacing
- Text scale is global - no per-widget implementation needed
- Compact mode is OFF by default for new users
