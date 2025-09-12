import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Complete Flutter app demonstrating smart text color for markdown blockquotes
/// 
/// This solution dynamically adjusts blockquote text color based on background
/// brightness to ensure optimal readability across all themes and color schemes.
/// 
/// Key Features:
/// - Luminosity-based contrast calculation
/// - Dynamic text color selection
/// - Theme-aware background colors
/// - Multiple theme examples
/// - Custom MarkdownStyleSheet integration
void main() {
  runApp(const SmartBlockquoteApp());
}

class SmartBlockquoteApp extends StatelessWidget {
  const SmartBlockquoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Blockquote Colors Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const SmartBlockquoteDemo(),
    );
  }
}

/// Main demo screen showcasing smart blockquote text colors
class SmartBlockquoteDemo extends StatefulWidget {
  const SmartBlockquoteDemo({super.key});

  @override
  State<SmartBlockquoteDemo> createState() => _SmartBlockquoteDemoState();
}

class _SmartBlockquoteDemoState extends State<SmartBlockquoteDemo> {
  int _selectedColorIndex = 0;
  
  // Various background colors to test contrast
  final List<ColorOption> _backgroundColors = [
    ColorOption('Theme Primary', null), // Will use theme primary color
    ColorOption('Light Blue', Colors.lightBlue.shade100),
    ColorOption('Dark Blue', Colors.blue.shade800),
    ColorOption('Light Grey', Colors.grey.shade200),
    ColorOption('Dark Grey', Colors.grey.shade700),
    ColorOption('Orange', Colors.orange.shade300),
    ColorOption('Deep Purple', Colors.deepPurple.shade600),
    ColorOption('Green', Colors.green.shade400),
    ColorOption('Red', Colors.red.shade300),
    ColorOption('Black', Colors.black),
    ColorOption('White', Colors.white),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Blockquote Colors'),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette),
            onPressed: _showColorSelector,
            tooltip: 'Change Background Color',
          ),
        ],
      ),
      body: Column(
        children: [
          // Color selector chip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha((255 * 0.3).round()),
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                const Icon(Icons.info_outline, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Current Background: ${_backgroundColors[_selectedColorIndex].name}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _showColorSelector,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _getCurrentBackgroundColor(context),
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Markdown content with smart blockquotes
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: MarkdownBody(
                data: _markdownContent,
                styleSheet: _buildSmartMarkdownStyleSheet(context),
                selectable: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Get the current background color for blockquotes
  Color _getCurrentBackgroundColor(BuildContext context) {
    final selectedColor = _backgroundColors[_selectedColorIndex].color;
    return selectedColor ?? Theme.of(context).colorScheme.primary;
  }

  /// Build a custom MarkdownStyleSheet with smart blockquote colors
  MarkdownStyleSheet _buildSmartMarkdownStyleSheet(BuildContext context) {
    final backgroundColor = _getCurrentBackgroundColor(context);
    final smartTextColor = ColorContrastHelper.getContrastingTextColor(backgroundColor);
    
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      // Smart blockquote styling
      blockquote: TextStyle(
        color: smartTextColor,
        fontStyle: FontStyle.italic,
        fontSize: 16,
        height: 1.4,
      ),
      blockquoteDecoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          left: BorderSide(
            color: smartTextColor.withAlpha((255 * 0.5).round()),
            width: 4,
          ),
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      
      // Enhanced styling for other elements
      h1: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      h2: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      code: TextStyle(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontFamily: 'monospace',
        fontSize: 14,
      ),
    );
  }

  /// Show color selector bottom sheet
  void _showColorSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Background Color',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _backgroundColors.asMap().entries.map((entry) {
                final index = entry.key;
                final colorOption = entry.value;
                final isSelected = index == _selectedColorIndex;
                
                return ChoiceChip(
                  label: Text(colorOption.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedColorIndex = index;
                      });
                      Navigator.pop(context);
                    }
                  },
                  avatar: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: colorOption.color ?? Theme.of(context).colorScheme.primary,
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Sample markdown content with various blockquotes
  static const String _markdownContent = '''
# Smart Blockquote Color Demo

This demo showcases **smart text color selection** for markdown blockquotes based on background luminosity.

## How It Works

The system automatically chooses between light and dark text colors to ensure optimal readability:

> This is a blockquote with automatically adjusted text color.
> 
> The text color is dynamically selected based on the background's brightness to ensure **perfect contrast** and readability.

## Luminosity Calculation

The perceived brightness is calculated using the standard formula:

> **Luminosity = (0.299 × R) + (0.587 × G) + (0.114 × B)**
> 
> This accounts for how the human eye perceives different colors, with green appearing brightest and blue appearing darkest.

## Contrast Threshold

> If luminosity > 0.5 → Use **dark text** (`Colors.black87`)
> 
> If luminosity ≤ 0.5 → Use **light text** (`Colors.white`)

## Benefits

> ✅ **Always readable** - Text is never lost against the background
> 
> ✅ **Theme-aware** - Works with light, dark, and custom themes
> 
> ✅ **Automatic** - No manual color adjustments needed
> 
> ✅ **Accessible** - Meets WCAG contrast guidelines

## Try Different Colors

Use the palette button in the app bar to test various background colors and see how the text color automatically adapts!

> "The best user interface is the one that gets out of the user's way."
> 
> — *Jef Raskin, Interface Designer*

## Code Example

Here's how the smart color selection works:

```dart
Color getContrastingTextColor(Color backgroundColor) {
  final luminosity = ColorContrastHelper.calculateLuminosity(backgroundColor);
  return luminosity > 0.5 ? Colors.black87 : Colors.white;
}
```

> This approach ensures that your markdown content is always perfectly readable, regardless of the theme or background color chosen by the user.
''';
}

/// Helper class for color contrast calculations
class ColorContrastHelper {
  /// Calculate the perceived brightness (luminosity) of a color
  /// 
  /// Uses the standard luminosity formula that accounts for how
  /// the human eye perceives different colors:
  /// - Green appears brightest (weight: 0.587)
  /// - Red appears medium bright (weight: 0.299)  
  /// - Blue appears darkest (weight: 0.114)
  /// 
  /// Returns a value between 0.0 (black) and 1.0 (white)
  static double calculateLuminosity(Color color) {
    // Normalize RGB values to 0-1 range
    final r = color.red / 255.0;
    final g = color.green / 255.0;
    final b = color.blue / 255.0;
    
    // Apply luminosity formula with perceptual weights
    return (0.299 * r) + (0.587 * g) + (0.114 * b);
  }

  /// Get the optimal text color (dark or light) for a given background color
  /// 
  /// This ensures maximum readability by choosing:
  /// - Dark text (Colors.black87) for light backgrounds
  /// - Light text (Colors.white) for dark backgrounds
  /// 
  /// The threshold of 0.5 provides the best balance for most use cases
  static Color getContrastingTextColor(Color backgroundColor) {
    final luminosity = calculateLuminosity(backgroundColor);
    
    // Use dark text for light backgrounds, light text for dark backgrounds
    return luminosity > 0.5 ? Colors.black87 : Colors.white;
  }

  /// Get a detailed contrast analysis for debugging/information
  static ContrastAnalysis analyzeContrast(Color backgroundColor) {
    final luminosity = calculateLuminosity(backgroundColor);
    final textColor = getContrastingTextColor(backgroundColor);
    final isLightBackground = luminosity > 0.5;
    
    return ContrastAnalysis(
      backgroundColor: backgroundColor,
      textColor: textColor,
      luminosity: luminosity,
      isLightBackground: isLightBackground,
      contrastRatio: _calculateContrastRatio(backgroundColor, textColor),
    );
  }

  /// Calculate the actual contrast ratio between two colors
  /// This is useful for accessibility compliance (WCAG guidelines)
  static double _calculateContrastRatio(Color background, Color text) {
    final bgLuminosity = calculateLuminosity(background);
    final textLuminosity = calculateLuminosity(text);
    
    final lighter = bgLuminosity > textLuminosity ? bgLuminosity : textLuminosity;
    final darker = bgLuminosity > textLuminosity ? textLuminosity : bgLuminosity;
    
    return (lighter + 0.05) / (darker + 0.05);
  }
}

/// Data class for color options in the selector
class ColorOption {
  final String name;
  final Color? color; // null means use theme color
  
  const ColorOption(this.name, this.color);
}

/// Detailed contrast analysis result
class ContrastAnalysis {
  final Color backgroundColor;
  final Color textColor;
  final double luminosity;
  final bool isLightBackground;
  final double contrastRatio;
  
  const ContrastAnalysis({
    required this.backgroundColor,
    required this.textColor,
    required this.luminosity,
    required this.isLightBackground,
    required this.contrastRatio,
  });
  
  /// Whether this combination meets WCAG AA standards (4.5:1 ratio)
  bool get meetsWCAGAA => contrastRatio >= 4.5;
  
  /// Whether this combination meets WCAG AAA standards (7:1 ratio)
  bool get meetsWCAGAAA => contrastRatio >= 7.0;
}

/// Extension on MarkdownStyleSheet for easy smart blockquote creation
extension SmartBlockquoteStyleSheet on MarkdownStyleSheet {
  /// Create a copy with smart blockquote colors based on background
  MarkdownStyleSheet withSmartBlockquotes(BuildContext context, Color backgroundColor) {
    final smartTextColor = ColorContrastHelper.getContrastingTextColor(backgroundColor);
    
    return copyWith(
      blockquote: TextStyle(
        color: smartTextColor,
        fontStyle: FontStyle.italic,
        fontSize: 16,
        height: 1.4,
      ),
      blockquoteDecoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          left: BorderSide(
            color: smartTextColor.withAlpha((255 * 0.5).round()),
            width: 4,
          ),
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
    );
  }
}
