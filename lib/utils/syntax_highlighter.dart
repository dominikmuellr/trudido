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
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart' as md;
import 'package:highlight/highlight.dart' as hi;

/// Maximum number of lines to highlight in real-time.
/// Blocks larger than this are shown plain and highlighted lazily.
const int _kMaxLinesForRealtimeHighlight = 500;

/// Converts highlight.js parse results into Flutter [TextSpan] trees,
/// themed to match Trudido's light/dark VS-Code-style palette.
class CodeSyntaxHighlighter implements md.SyntaxHighlighter {
  CodeSyntaxHighlighter({required this.brightness});

  final Brightness brightness;

  @override
  TextSpan format(String source) {
    return highlightToSpans(source, null, brightness);
  }

  /// Highlight [source] for [language] (null = auto-detect).
  ///
  /// Returns a single [TextSpan] with children coloured per token type.
  /// Falls back to plain monospace text when parsing fails or the block
  /// exceeds [_kMaxLinesForRealtimeHighlight] lines.
  static TextSpan highlightToSpans(
    String source,
    String? language,
    Brightness brightness,
  ) {
    final baseStyle = const TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      height: 1.4,
    );

    // Performance guard: skip highlighting for very large blocks.
    if ('\n'.allMatches(source).length > _kMaxLinesForRealtimeHighlight) {
      return TextSpan(
        style: baseStyle.copyWith(color: _defaultColor(brightness)),
        text: source,
      );
    }

    hi.Result result;
    try {
      if (language != null &&
          language != 'plaintext' &&
          language.isNotEmpty) {
        result = hi.highlight.parse(source, language: language);
      } else {
        result = hi.highlight.parse(source, autoDetection: true);
      }
    } catch (_) {
      return TextSpan(
        style: baseStyle.copyWith(color: _defaultColor(brightness)),
        text: source,
      );
    }

    final spans = <InlineSpan>[];
    if (result.nodes != null) {
      for (final node in result.nodes!) {
        _buildSpans(node, spans, brightness);
      }
    }

    if (spans.isEmpty) {
      return TextSpan(
        style: baseStyle.copyWith(color: _defaultColor(brightness)),
        text: source,
      );
    }

    return TextSpan(
      style: baseStyle.copyWith(color: _defaultColor(brightness)),
      children: spans,
    );
  }

  /// Recursively convert a highlight [Node] tree into [TextSpan] children.
  static void _buildSpans(
    hi.Node node,
    List<InlineSpan> spans,
    Brightness brightness,
  ) {
    if (node.value != null) {
      final color = node.className != null
          ? _colorForClassName(node.className!, brightness)
          : null;
      spans.add(TextSpan(
        text: node.value,
        style: color != null ? TextStyle(color: color) : null,
      ));
    } else if (node.children != null) {
      final color = node.className != null
          ? _colorForClassName(node.className!, brightness)
          : null;
      final childSpans = <InlineSpan>[];
      for (final child in node.children!) {
        _buildSpans(child, childSpans, brightness);
      }
      if (color != null) {
        spans.add(TextSpan(style: TextStyle(color: color), children: childSpans));
      } else {
        spans.addAll(childSpans);
      }
    }
  }

  // ── Theme colours ────────────────────────────────────────────────────────

  static Color _defaultColor(Brightness b) =>
      b == Brightness.light ? const Color(0xFF24292E) : const Color(0xFFD4D4D4);

  /// Map highlight.js class names to VS-Code / GitHub-style colours.
  static Color _colorForClassName(String className, Brightness b) {
    if (b == Brightness.light) {
      return _lightColors[className] ?? const Color(0xFF24292E);
    }
    return _darkColors[className] ?? const Color(0xFFD4D4D4);
  }

  // GitHub Light colours
  static const _lightColors = <String, Color>{
    // Keywords & built-ins
    'keyword': Color(0xFFD73A49),
    'built_in': Color(0xFF6F42C1),
    'type': Color(0xFF6F42C1),
    'literal': Color(0xFF005CC5),
    'addition': Color(0xFF22863A),
    'deletion': Color(0xFFD73A49),
    // Strings & numbers
    'string': Color(0xFF032F62),
    'number': Color(0xFF005CC5),
    'regexp': Color(0xFF032F62),
    // Functions & titles
    'function': Color(0xFF6F42C1),
    'title': Color(0xFF6F42C1),
    'title.class_': Color(0xFF6F42C1),
    'title.function_': Color(0xFF6F42C1),
    'section': Color(0xFF005CC5),
    // Comments & meta
    'comment': Color(0xFF6A737D),
    'doctag': Color(0xFF6A737D),
    'meta': Color(0xFF6A737D),
    // Variables & params
    'variable': Color(0xFFE36209),
    'params': Color(0xFFE36209),
    'attr': Color(0xFF005CC5),
    'attribute': Color(0xFF005CC5),
    // Misc
    'symbol': Color(0xFF005CC5),
    'selector-tag': Color(0xFF22863A),
    'selector-class': Color(0xFF6F42C1),
    'selector-id': Color(0xFF005CC5),
    'name': Color(0xFF22863A),
    'tag': Color(0xFF22863A),
    'template-variable': Color(0xFF005CC5),
    'template-tag': Color(0xFFD73A49),
    'subst': Color(0xFF24292E),
    'operator': Color(0xFFD73A49),
    'punctuation': Color(0xFF24292E),
    'property': Color(0xFF005CC5),
    'class': Color(0xFF6F42C1),
  };

  // VS Code Dark+ colours
  static const _darkColors = <String, Color>{
    // Keywords & built-ins
    'keyword': Color(0xFFC586C0),
    'built_in': Color(0xFF4EC9B0),
    'type': Color(0xFF4EC9B0),
    'literal': Color(0xFF569CD6),
    'addition': Color(0xFF6A9955),
    'deletion': Color(0xFFCE9178),
    // Strings & numbers
    'string': Color(0xFFCE9178),
    'number': Color(0xFFB5CEA8),
    'regexp': Color(0xFFD16969),
    // Functions & titles
    'function': Color(0xFFDCDCAA),
    'title': Color(0xFFDCDCAA),
    'title.class_': Color(0xFF4EC9B0),
    'title.function_': Color(0xFFDCDCAA),
    'section': Color(0xFF569CD6),
    // Comments & meta
    'comment': Color(0xFF6A9955),
    'doctag': Color(0xFF608B4E),
    'meta': Color(0xFF569CD6),
    // Variables & params
    'variable': Color(0xFF9CDCFE),
    'params': Color(0xFF9CDCFE),
    'attr': Color(0xFF9CDCFE),
    'attribute': Color(0xFF9CDCFE),
    // Misc
    'symbol': Color(0xFF569CD6),
    'selector-tag': Color(0xFFD7BA7D),
    'selector-class': Color(0xFFD7BA7D),
    'selector-id': Color(0xFFD7BA7D),
    'name': Color(0xFF569CD6),
    'tag': Color(0xFF569CD6),
    'template-variable': Color(0xFF9CDCFE),
    'template-tag': Color(0xFFC586C0),
    'subst': Color(0xFFD4D4D4),
    'operator': Color(0xFFD4D4D4),
    'punctuation': Color(0xFFD4D4D4),
    'property': Color(0xFF9CDCFE),
    'class': Color(0xFF4EC9B0),
  };
}
