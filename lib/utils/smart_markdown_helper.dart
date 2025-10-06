import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../services/theme_service.dart';

/// Utility class for creating markdown stylesheets with smart blockquote colors
/// and VS Code-style syntax highlighting
///
/// This utility automatically adjusts colors based on theme and provides:
/// - Smart blockquote backgrounds with proper contrast
/// - VS Code-style code block styling with syntax highlighting colors
/// - GitHub/VS Code inspired color schemes for both light and dark themes
/// - Accessible color combinations meeting WCAG standards
///
/// Note: For full syntax highlighting within code blocks, consider using
/// packages like 'flutter_highlight' or 'syntax_highlight' with a custom
/// code block builder.
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

    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      // Smart blockquote styling
      blockquote: TextStyle(
        color: colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
        fontSize: theme.textTheme.bodyMedium?.fontSize ?? 14,
        height: 1.4,
        fontWeight: FontWeight.w400,
      ),

      blockquoteDecoration: BoxDecoration(
        color: blockquoteBackground,
        border: Border(left: BorderSide(color: colorScheme.primary, width: 4)),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
        // Subtle shadow for depth
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.08),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),

      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),

      // Enhanced styling for other markdown elements
      h1: TextStyle(
        color: _getSyntaxColor(context, 'keyword'), // Use syntax colors
        fontSize: theme.textTheme.headlineSmall?.fontSize ?? 20,
        fontWeight: FontWeight.bold,
        height: 1.2,
      ),

      h2: TextStyle(
        color: _getSyntaxColor(context, 'function'),
        fontSize: theme.textTheme.titleLarge?.fontSize ?? 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),

      h3: TextStyle(
        color: _getSyntaxColor(context, 'variable'),
        fontSize: theme.textTheme.titleMedium?.fontSize ?? 16,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),

      p: TextStyle(
        color: colorScheme.onSurface,
        fontSize: theme.textTheme.bodyMedium?.fontSize ?? 14,
        height: 1.5,
      ),

      code: AppTheme.getCodeTextStyle(context).copyWith(
        backgroundColor: _getCodeBackgroundColor(context),
        color: _getCodeTextColor(context),
      ),

      // Style for code blocks
      codeblockDecoration: BoxDecoration(
        color: _getCodeBlockBackgroundColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.15),
          width: 1,
        ),
        // VS Code-style shadow
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.08),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),

      codeblockPadding: const EdgeInsets.all(20),

      // Links
      a: TextStyle(
        color: _getSyntaxColor(context, 'string'),
        decoration: TextDecoration.underline,
        decorationColor: _getSyntaxColor(context, 'string'),
      ),

      // Lists
      listBullet: TextStyle(
        color: _getSyntaxColor(context, 'keyword'),
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

    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      // Compact blockquote styling
      blockquote: TextStyle(
        color: colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
        fontSize: (theme.textTheme.bodySmall?.fontSize ?? 12) + 1,
        height: 1.3,
      ),

      blockquoteDecoration: BoxDecoration(
        color: blockquoteBackground,
        border: Border(left: BorderSide(color: colorScheme.primary, width: 3)),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
      ),

      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),

      // Compact headers
      h1: TextStyle(
        color: _getSyntaxColor(context, 'keyword'),
        fontSize: theme.textTheme.titleMedium?.fontSize ?? 16,
        fontWeight: FontWeight.bold,
        height: 1.2,
      ),

      h2: TextStyle(
        color: _getSyntaxColor(context, 'function'),
        fontSize: theme.textTheme.titleSmall?.fontSize ?? 14,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),

      p: TextStyle(
        color: colorScheme.onSurface,
        fontSize: theme.textTheme.bodySmall?.fontSize ?? 12,
        height: 1.4,
      ),

      code: AppTheme.getCodeTextStyle(context).copyWith(
        backgroundColor: _getCodeBackgroundColor(context),
        color: _getCodeTextColor(context),
        fontSize: theme.textTheme.bodySmall?.fontSize ?? 12,
      ),
    );
  }

  /// Get the background color for blockquotes based on current theme
  ///
  /// Uses surface variants for better readability and accessibility
  static Color _getBlockquoteBackgroundColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Use surface variants for better readability
    if (brightness == Brightness.light) {
      // Light mode: use a slightly darker surface for better contrast
      return colorScheme.surfaceContainerHigh;
    } else {
      // Dark mode: use a slightly lighter surface for better contrast
      return colorScheme.surfaceContainerHighest;
    }
  }

  /// Get VS Code-style background color for inline code
  static Color _getCodeBackgroundColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    if (brightness == Brightness.light) {
      // Light theme: VS Code light grey
      return const Color(0xFFF6F8FA); // GitHub-style light code background
    } else {
      // Dark theme: VS Code dark grey
      return const Color(0xFF2D3748); // VS Code dark background
    }
  }

  /// Get VS Code-style text color for inline code
  static Color _getCodeTextColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    if (brightness == Brightness.light) {
      // Light theme: darker text for better readability in code blocks
      return const Color(0xFF24292E); // GitHub dark text
    } else {
      // Dark theme: VS Code light text
      return const Color(0xFFD4D4D4); // VS Code light grey
    }
  }

  /// Get VS Code-style background color for code blocks
  static Color _getCodeBlockBackgroundColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    if (brightness == Brightness.light) {
      // Light theme: slightly darker than surface for code blocks
      return const Color(0xFFF8F9FA); // GitHub code block background
    } else {
      // Dark theme: VS Code editor background
      return const Color(0xFF1E1E1E); // VS Code dark editor background
    }
  }

  /// Get VS Code-style syntax highlighting colors
  static Color _getSyntaxColor(BuildContext context, String type) {
    final brightness = Theme.of(context).brightness;

    if (brightness == Brightness.light) {
      switch (type) {
        case 'keyword': // For H1 headers
          return const Color(0xFFD73A49); // GitHub red
        case 'function': // For H2 headers
          return const Color(0xFF6F42C1); // GitHub purple
        case 'variable': // For H3 headers
          return const Color(0xFF005CC5); // GitHub blue
        case 'string':
          return const Color(0xFF032F62); // GitHub dark blue
        case 'comment':
          return const Color(0xFF6A737D); // GitHub grey
        default:
          return const Color(0xFF24292E); // GitHub black
      }
    } else {
      switch (type) {
        case 'keyword': // For H1 headers
          return const Color(0xFFC586C0); // VS Code magenta
        case 'function': // For H2 headers
          return const Color(0xFFDCDCAA); // VS Code yellow
        case 'variable': // For H3 headers
          return const Color(0xFF9CDCFE); // VS Code light blue
        case 'string':
          return const Color(0xFFCE9178); // VS Code orange
        case 'comment':
          return const Color(0xFF6A9955); // VS Code green
        default:
          return const Color(0xFFD4D4D4); // VS Code light grey
      }
    }
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
  /// Uses theme-appropriate colors for better accessibility
  static Color _getContrastingTextColor(Color backgroundColor) {
    final luminosity = _calculateLuminosity(backgroundColor);

    // For very light backgrounds, use a strong dark color
    // For darker backgrounds, use a lighter color
    if (luminosity > 0.7) {
      return const Color(0xFF1C1B1F); // Material 3 neutral variant 10
    } else if (luminosity > 0.3) {
      return const Color(0xFF49454F); // Material 3 neutral variant 30
    } else {
      return const Color(0xFFE6E0E9); // Material 3 neutral variant 90
    }
  }

  /// Check if a color combination meets accessibility standards
  ///
  /// Returns contrast ratio - should be at least 4.5:1 for WCAG AA compliance
  /// and 7:1 for WCAG AAA compliance
  static double calculateContrastRatio(Color background, Color text) {
    final bgLuminosity = _calculateLuminosity(background);
    final textLuminosity = _calculateLuminosity(text);

    final lighter = bgLuminosity > textLuminosity
        ? bgLuminosity
        : textLuminosity;
    final darker = bgLuminosity > textLuminosity
        ? textLuminosity
        : bgLuminosity;

    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Validate accessibility for current theme
  ///
  /// Returns true if all color combinations meet WCAG AA standards
  static bool validateThemeAccessibility(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Test primary text on surface
    final primaryTextRatio = calculateContrastRatio(
      colorScheme.surface,
      colorScheme.onSurface,
    );

    // Test secondary text on surface
    final secondaryTextRatio = calculateContrastRatio(
      colorScheme.surface,
      colorScheme.onSurfaceVariant,
    );

    // Test blockquote accessibility
    final blockquoteBackground = _getBlockquoteBackgroundColor(context);
    final blockquoteText = _getContrastingTextColor(blockquoteBackground);
    final blockquoteRatio = calculateContrastRatio(
      blockquoteBackground,
      blockquoteText,
    );

    return primaryTextRatio >= 4.5 &&
        secondaryTextRatio >= 3.0 && // More lenient for secondary text
        blockquoteRatio >= 4.5;
  }

  /// Create a custom code block widget with better styling
  ///
  /// This can be used with MarkdownBody's builders parameter for enhanced code blocks:
  /// ```dart
  /// MarkdownBody(
  ///   data: note.content,
  ///   styleSheet: SmartMarkdownHelper.createStyleSheet(context),
  ///   builders: {
  ///     'code': SmartMarkdownHelper.createCodeBlockBuilder(context),
  ///   },
  /// )
  /// ```
  static Widget Function(String text, String? language) createCodeBlockBuilder(
    BuildContext context,
  ) {
    return (String text, String? language) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _getCodeBlockBackgroundColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Optional language label
            if (language != null && language.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getSyntaxColor(context, 'comment').withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  language.toUpperCase(),
                  style: AppTheme.getCodeTextStyle(context).copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _getSyntaxColor(context, 'comment'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Code content
            SelectableText(
              text,
              style: AppTheme.getCodeTextStyle(context).copyWith(
                fontSize: 13,
                color: _getCodeTextColor(context),
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    };
  }

  /// Get accessibility information for debugging
  static AccessibilityInfo getAccessibilityInfo(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final blockquoteBackground = _getBlockquoteBackgroundColor(context);
    final textColor = colorScheme.onSurfaceVariant;
    final contrastRatio = calculateContrastRatio(
      blockquoteBackground,
      textColor,
    );

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
