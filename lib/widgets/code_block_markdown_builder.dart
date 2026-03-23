// Trudido - A privacy-focused todo and notes app
// Copyright (C) 2026 Dominik Müller
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
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../utils/language_detector.dart';
import '../utils/syntax_highlighter.dart';

/// A colored badge pill for a programming language.
///
/// Used in code block headers and the language picker dialog.
class LanguageBadge extends StatelessWidget {
  final String language;
  final double fontSize;

  const LanguageBadge({super.key, required this.language, this.fontSize = 10});

  /// Returns a deterministic color for a given language name.
  static Color colorForLanguage(String language) {
    // Well-known language colors (loosely based on GitHub linguist)
    const languageColors = <String, Color>{
      'dart': Color(0xFF00B4AB),
      'python': Color(0xFF3572A5),
      'javascript': Color(0xFFF1E05A),
      'typescript': Color(0xFF3178C6),
      'java': Color(0xFFB07219),
      'kotlin': Color(0xFFA97BFF),
      'swift': Color(0xFFFF6C3E),
      'rust': Color(0xFFDEA584),
      'go': Color(0xFF00ADD8),
      'c': Color(0xFF555555),
      'cpp': Color(0xFFF34B7D),
      'c++': Color(0xFFF34B7D),
      'csharp': Color(0xFF178600),
      'c#': Color(0xFF178600),
      'ruby': Color(0xFF701516),
      'php': Color(0xFF4F5D95),
      'html': Color(0xFFE34C26),
      'css': Color(0xFF563D7C),
      'scss': Color(0xFFC6538C),
      'sql': Color(0xFFE38C00),
      'shell': Color(0xFF89E051),
      'bash': Color(0xFF89E051),
      'yaml': Color(0xFFCB171E),
      'json': Color(0xFF292929),
      'xml': Color(0xFF0060AC),
      'markdown': Color(0xFF083FA1),
      'lua': Color(0xFF000080),
      'r': Color(0xFF198CE7),
      'scala': Color(0xFFDC322F),
      'perl': Color(0xFF0298C3),
      'haskell': Color(0xFF5E5086),
      'elixir': Color(0xFF6E4A7E),
      'erlang': Color(0xFFB83998),
      'clojure': Color(0xFFDB5855),
      'dockerfile': Color(0xFF384D54),
    };

    final key = language.toLowerCase();
    if (languageColors.containsKey(key)) {
      return languageColors[key]!;
    }
    // Deterministic hash-based color fallback
    final hash = key.hashCode.abs();
    return HSLColor.fromAHSL(1.0, (hash % 360).toDouble(), 0.5, 0.45).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final label = language.toUpperCase();
    final color = colorForLanguage(language);
    final brightness = Theme.of(context).brightness;
    final bgAlpha = brightness == Brightness.dark ? 0.25 : 0.15;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.6,
        vertical: fontSize * 0.2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: brightness == Brightness.dark
              ? color.withValues(alpha: 0.9)
              : color,
          height: 1.2,
        ),
      ),
    );
  }
}

/// Custom [MarkdownElementBuilder] for `pre` (code block) elements.
///
/// Extracts the language from the child `<code class="language-xxx">` element,
/// shows a language badge pill, and applies syntax highlighting.
class CodeBlockMarkdownBuilder extends MarkdownElementBuilder {
  String? _language;
  String _codeText = '';

  @override
  bool isBlockElement() => true;

  @override
  void visitElementBefore(md.Element element) {
    _language = null;
    _codeText = '';
    // Extract language from child <code class="language-xxx"> element.
    if (element.children != null) {
      for (final child in element.children!) {
        if (child is md.Element && child.tag == 'code') {
          final cls = child.attributes['class'];
          if (cls != null && cls.startsWith('language-')) {
            _language = cls.substring('language-'.length);
          }
        }
      }
    }
  }

  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) {
    _codeText += text.text;
    return null; // We build everything in visitElementAfterWithContext
  }

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final brightness = Theme.of(context).brightness;
    final language = _language;

    // Auto-detect language if not specified.
    final displayLanguage = (language != null && language.isNotEmpty)
        ? language
        : LanguageDetector.detectLanguage(_codeText);

    // Use the resolved displayLanguage for highlighting so the badge and
    // syntax colours always agree (auto-detected language is applied to both).
    final highlighted = CodeSyntaxHighlighter.highlightToSpans(
      _codeText,
      displayLanguage,
      brightness,
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Language badge
          if (displayLanguage.isNotEmpty && displayLanguage != 'plaintext') ...[
            LanguageBadge(language: displayLanguage),
            const SizedBox(height: 8),
          ],
          // Horizontally scrollable syntax-highlighted code
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText.rich(highlighted),
          ),
        ],
      ),
    );
  }
}
