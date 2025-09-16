import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Utility class for creating markdown stylesheets with smart blockquote colors
/// 
/// This utility automatically adjusts blockquote text color based on background
/// brightness to ensure optimal readability in your notes app across all themes.
/// 
/// Usage in your notes app:
/// ```dart
/// MarkdownBody(
///   data: note.content,
///   styleSheet: SmartMarkdownHelper.createStyleSheet(context),
/// )
/// ```
class SmartMarkdownHelper {
  /// Create a complete MarkdownStyleSheet with smart blockquote colors
  /// 
  /// This method builds a stylesheet that:
  /// - Uses theme colors for consistent design
  /// - Automatically adjusts blockquote text for contrast
  /// - Provides beautiful, readable formatting
  static MarkdownStyleSheet createStyleSheet(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Choose background color for blockquotes (you can customize this)
    final blockquoteBackground = _getBlockquoteBackgroundColor(context);
    final smartTextColor = _getContrastingTextColor(blockquoteBackground);
    
    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      // Smart blockquote styling
      blockquote: TextStyle(
        color: smartTextColor,
        fontStyle: FontStyle.italic,
        fontSize: theme.textTheme.bodyMedium?.fontSize ?? 14,
        height: 1.4,
        fontWeight: FontWeight.w400,
      ),
      
      blockquoteDecoration: BoxDecoration(
        color: blockquoteBackground,
        border: Border(
          left: BorderSide(
            color: smartTextColor.withOpacity(0.6),
            width: 3,
          ),
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
        // Subtle shadow for depth
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            offset: const Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      
      // Enhanced styling for other markdown elements
      h1: TextStyle(
        color: colorScheme.primary,
        fontSize: theme.textTheme.headlineSmall?.fontSize ?? 20,
        fontWeight: FontWeight.bold,
        height: 1.2,
      ),
      
      h2: TextStyle(
        color: colorScheme.primary,
        fontSize: theme.textTheme.titleLarge?.fontSize ?? 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      
      h3: TextStyle(
        color: colorScheme.onSurface,
        fontSize: theme.textTheme.titleMedium?.fontSize ?? 16,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      
      p: TextStyle(
        color: colorScheme.onSurface,
        fontSize: theme.textTheme.bodyMedium?.fontSize ?? 14,
        height: 1.5,
      ),
      
      code: TextStyle(
        backgroundColor: colorScheme.surfaceContainerHighest,
        color: colorScheme.onSurfaceVariant,
        fontFamily: 'monospace',
        fontSize: (theme.textTheme.bodySmall?.fontSize ?? 12) + 1,
        fontWeight: FontWeight.w500,
      ),
      
      // Style for code blocks
      codeblockDecoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      
      codeblockPadding: const EdgeInsets.all(16),
      
      // Links
      a: TextStyle(
        color: colorScheme.primary,
        decoration: TextDecoration.underline,
      ),
      
      // Lists
      listBullet: TextStyle(
        color: colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  /// Create a minimal stylesheet optimized for preview cards (like in your notes list)
  /// 
  /// This version is more compact and suitable for limited space contexts
  static MarkdownStyleSheet createCompactStyleSheet(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final blockquoteBackground = _getBlockquoteBackgroundColor(context);
    final smartTextColor = _getContrastingTextColor(blockquoteBackground);
    
    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      // Compact blockquote styling
      blockquote: TextStyle(
        color: smartTextColor,
        fontStyle: FontStyle.italic,
        fontSize: (theme.textTheme.bodySmall?.fontSize ?? 12) + 1,
        height: 1.3,
      ),
      
      blockquoteDecoration: BoxDecoration(
        color: blockquoteBackground,
        border: Border(
          left: BorderSide(
            color: smartTextColor.withOpacity(0.5),
            width: 2,
          ),
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
      ),
      
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      
      // Compact headers
      h1: TextStyle(
        color: colorScheme.primary,
        fontSize: theme.textTheme.titleMedium?.fontSize ?? 16,
        fontWeight: FontWeight.bold,
        height: 1.2,
      ),
      
      h2: TextStyle(
        color: colorScheme.primary,
        fontSize: theme.textTheme.titleSmall?.fontSize ?? 14,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      
      p: TextStyle(
        color: colorScheme.onSurface,
        fontSize: theme.textTheme.bodySmall?.fontSize ?? 12,
        height: 1.4,
      ),
      
      code: TextStyle(
        backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.7),
        color: colorScheme.onSurfaceVariant,
        fontFamily: 'monospace',
        fontSize: theme.textTheme.bodySmall?.fontSize ?? 12,
      ),
    );
  }

  /// Get the background color for blockquotes based on current theme
  /// 
  /// You can customize this method to use different colors:
  /// - Primary color variants
  /// - Surface variants  
  /// - Custom brand colors
  static Color _getBlockquoteBackgroundColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Option 1: Use primary color with opacity (current implementation)
    return colorScheme.primary.withOpacity(0.1);
    
    // Option 2: Use surface variant (uncomment to try)
    // return colorScheme.surfaceVariant;
    
    // Option 3: Use secondary color (uncomment to try)
    // return colorScheme.secondary.withOpacity(0.15);
    
    // Option 4: Custom color based on brightness
    // return colorScheme.brightness == Brightness.light
    //     ? Colors.blue.shade50
    //     : Colors.blue.shade900.withOpacity(0.3);
  }

  /// Calculate the perceived brightness (luminosity) of a color
  /// 
  /// Uses the standard luminosity formula weighted for human perception:
  /// - Green: 58.7% weight (appears brightest)
  /// - Red: 29.9% weight (medium brightness)  
  /// - Blue: 11.4% weight (appears darkest)
  static double _calculateLuminosity(Color color) {
    final r = color.red / 255.0;
    final g = color.green / 255.0;
    final b = color.blue / 255.0;
    
    return (0.299 * r) + (0.587 * g) + (0.114 * b);
  }

  /// Get contrasting text color for optimal readability
  /// 
  /// Returns:
  /// - Colors.black87 for light backgrounds
  /// - Colors.white for dark backgrounds
  static Color _getContrastingTextColor(Color backgroundColor) {
    final luminosity = _calculateLuminosity(backgroundColor);
    return luminosity > 0.5 ? Colors.black87 : Colors.white;
  }

  /// Check if a color combination meets accessibility standards
  /// 
  /// Returns contrast ratio - should be at least 4.5:1 for WCAG AA compliance
  static double calculateContrastRatio(Color background, Color text) {
    final bgLuminosity = _calculateLuminosity(background);
    final textLuminosity = _calculateLuminosity(text);
    
    final lighter = bgLuminosity > textLuminosity ? bgLuminosity : textLuminosity;
    final darker = bgLuminosity > textLuminosity ? textLuminosity : bgLuminosity;
    
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Get accessibility information for debugging
  static AccessibilityInfo getAccessibilityInfo(BuildContext context) {
    final blockquoteBackground = _getBlockquoteBackgroundColor(context);
    final textColor = _getContrastingTextColor(blockquoteBackground);
    final contrastRatio = calculateContrastRatio(blockquoteBackground, textColor);
    
    return AccessibilityInfo(
      backgroundColor: blockquoteBackground,
      textColor: textColor,
      contrastRatio: contrastRatio,
      meetsWCAGAA: contrastRatio >= 4.5,
      meetsWCAGAAA: contrastRatio >= 7.0,
    );
  }
}

/// Information about accessibility compliance for colors
class AccessibilityInfo {
  final Color backgroundColor;
  final Color textColor;
  final double contrastRatio;
  final bool meetsWCAGAA;
  final bool meetsWCAGAAA;

  const AccessibilityInfo({
    required this.backgroundColor,
    required this.textColor,
    required this.contrastRatio,
    required this.meetsWCAGAA,
    required this.meetsWCAGAAA,
  });

  @override
  String toString() {
    return 'AccessibilityInfo('
        'contrastRatio: ${contrastRatio.toStringAsFixed(2)}, '
        'WCAG AA: $meetsWCAGAA, '
        'WCAG AAA: $meetsWCAGAAA)';
  }
}
