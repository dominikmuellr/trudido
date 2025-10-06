# Typography System Documentation

## Overview

This document describes the enhanced typography system implemented in Trudido using Montserrat and Inter fonts via Google Fonts.

## Font Pairing Strategy

### Primary Goals

- **Enhanced Visual Identity**: Modern, clean, and professional appearance
- **Improved Readability**: Optimized fonts for different text types
- **Clear Hierarchy**: Distinct visual hierarchy using font pairing
- **Accessibility**: High readability across different screen sizes

## Typography Hierarchy

### Headlines & Titles (Montserrat)

Montserrat is used for all headlines, titles, and navigation elements:

- `displayLarge`, `displayMedium`, `displaySmall`
- `headlineLarge`, `headlineMedium`, `headlineSmall`
- `titleLarge`, `titleMedium`, `titleSmall`
- `labelLarge`, `labelMedium`, `labelSmall`

**Why Montserrat?**

- Modern geometric design
- Strong visual impact for headers
- Clean, sophisticated appearance
- Excellent for establishing visual hierarchy

### Body Text (Inter)

Inter is used for all body text and longer content:

- `bodyLarge`, `bodyMedium`, `bodySmall`

**Why Inter?**

- Specifically designed for user interfaces
- Exceptional readability at small sizes
- Optimized letter spacing for screens
- Reduces eye strain during extended reading

### Code Text (JetBrains Mono)

JetBrains Mono is available for code blocks and monospace text:

- Accessible via `AppTheme.getCodeTextStyle(context)`
- Used in markdown code blocks
- Monospace formatting for technical content

## Implementation Details

### Font Weights

- **Light**: 300 (Display styles)
- **Regular**: 400 (Body text, default)
- **Medium**: 500 (Titles, labels)
- **SemiBold**: 600 (Headlines)
- **Bold**: 700+ (Emphasis, available on demand)

### Letter Spacing

Carefully tuned letter spacing for optimal readability:

- **Tight**: -1.5 to -0.5 (Large displays)
- **Normal**: 0.1 to 0.25 (Titles and headers)
- **Open**: 0.4 to 0.5 (Body text and labels)

## Usage Guidelines

### Do

- Use theme text styles: `Theme.of(context).textTheme.titleLarge`
- Leverage the built-in hierarchy for consistency
- Use `AppTheme.getCodeTextStyle()` for code snippets
- Test readability across different screen sizes

### Don't

- Hardcode font families in individual widgets
- Override the text theme unless absolutely necessary
- Mix typography styles inconsistently
- Use too many different font weights in a single view

## Code Examples

### Basic Usage

```dart
// Headlines (Montserrat)
Text('Welcome to Trudido', style: Theme.of(context).textTheme.headlineLarge)

// Body text (Inter)
Text('Your task description here...', style: Theme.of(context).textTheme.bodyMedium)

// Code text (JetBrains Mono)
Text('function() {}', style: AppTheme.getCodeTextStyle(context))
```

### Custom Styling

```dart
// Extend existing styles
Text(
  'Custom Title',
  style: Theme.of(context).textTheme.titleLarge?.copyWith(
    color: Theme.of(context).colorScheme.primary,
    fontWeight: FontWeight.w700,
  ),
)
```

## Theme Integration

The typography system is fully integrated with:

- **Material 3 Design System**
- **Dynamic Color Theming** (Android 12+)
- **Dark/Light Mode** support
- **High Contrast** accessibility mode
- **Compact Density** layout option

## File Structure

### Modified Files

- `pubspec.yaml` - Added Google Fonts dependency
- `lib/services/theme_service.dart` - Typography implementation
- `lib/utils/typography_demo.dart` - Demo/reference screen

### Key Functions

- `AppTheme._buildTextTheme()` - Core typography definition
- `AppTheme.getCodeTextStyle()` - Code text styling helper

## Accessibility Features

- **High Contrast Support**: Automatically adjusts for accessibility preferences
- **Scalable Text**: Respects system font size settings
- **Screen Reader Friendly**: Semantic font hierarchy
- **Color Contrast**: Optimized for WCAG guidelines

## Performance Notes

- **Google Fonts**: Fonts are cached automatically
- **Lazy Loading**: Fonts load on first use
- **Fallback Support**: System fonts used if network unavailable
- **Bundle Size**: Minimal impact due to selective font loading

## Future Enhancements

Potential improvements for future versions:

- Custom font weights for specific use cases
- Additional language/script support
- Enhanced markdown typography
- Custom icon font integration

---

For questions or suggestions about the typography system, refer to the `AppTheme` class in `lib/services/theme_service.dart`.
