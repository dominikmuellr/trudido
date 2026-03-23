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

import 'package:highlight/highlight.dart' as hi;

/// Heuristic-based language detector that uses the highlight.js engine
/// for auto-detection, with fast pre-filters for common patterns.
class LanguageDetector {
  LanguageDetector._();

  /// Detect the most likely language from a code snippet.
  ///
  /// Returns a language identifier string (e.g. 'dart', 'python', 'javascript')
  /// compatible with the highlight package's language names.
  /// Returns 'plaintext' if no confident match is found.
  static String detectLanguage(String code) {
    if (code.trim().isEmpty) return 'plaintext';

    // Phase 1: Fast shebang / header detection
    final shebangResult = _detectFromShebang(code);
    if (shebangResult != null) return shebangResult;

    // Phase 2: Strong keyword patterns (fast, high-confidence)
    final patternResult = _detectFromPatterns(code);
    if (patternResult != null) return patternResult;

    // Phase 3: highlight.js auto-detection (slower but comprehensive)
    try {
      final result = hi.highlight.parse(code, autoDetection: true);
      if (result.language != null && (result.relevance ?? 0) >= 5) {
        return result.language!;
      }
    } catch (_) {
      // Highlight auto-detection can fail on unusual input; fall through.
    }

    return 'plaintext';
  }

  /// Check for shebang lines and common file headers.
  static String? _detectFromShebang(String code) {
    final firstLine = code.split('\n').first.trim();

    if (firstLine.startsWith('#!')) {
      if (firstLine.contains('python')) return 'python';
      if (firstLine.contains('node')) return 'javascript';
      if (firstLine.contains('bash') || firstLine.contains('/sh')) {
        return 'bash';
      }
      if (firstLine.contains('ruby')) return 'ruby';
      if (firstLine.contains('perl')) return 'perl';
      if (firstLine.contains('php')) return 'php';
    }

    if (firstLine.startsWith('<?php')) return 'php';
    if (firstLine.startsWith('<?xml')) return 'xml';
    if (firstLine.startsWith('<!DOCTYPE') || firstLine.startsWith('<html')) {
      return 'xml';
    }

    return null;
  }

  /// Common language-specific patterns with high confidence.
  static String? _detectFromPatterns(String code) {
    final trimmed = code.trim();

    // Dart: import 'package:', void main(), late final, required this.
    if (_hasDartPatterns(trimmed)) return 'dart';

    // Python: def, import, from ... import, if __name__
    if (_hasPythonPatterns(trimmed)) return 'python';

    // Rust: fn main(), let mut, impl, use std::
    if (_hasRustPatterns(trimmed)) return 'rust';

    // Go: func main(), package main, import "fmt"
    if (_hasGoPatterns(trimmed)) return 'go';

    // Kotlin: fun main(), val, var, companion object
    if (_hasKotlinPatterns(trimmed)) return 'kotlin';

    // Swift: func , let , var , import Foundation
    if (_hasSwiftPatterns(trimmed)) return 'swift';

    // TypeScript: interface, type alias, as const, : string
    if (_hasTypeScriptPatterns(trimmed)) return 'typescript';

    // JavaScript: const, let, =>, require(, function
    if (_hasJavaScriptPatterns(trimmed)) return 'javascript';

    // Java: public class, System.out, import java.
    if (_hasJavaPatterns(trimmed)) return 'java';

    // C/C++: #include, int main(, printf
    if (_hasCPatterns(trimmed)) return 'cpp';

    // SQL: SELECT, INSERT, CREATE TABLE
    if (_hasSqlPatterns(trimmed)) return 'sql';

    // CSS: selectors with { }, color:, display:
    if (_hasCssPatterns(trimmed)) return 'css';

    // YAML: key: value patterns at line start
    if (_hasYamlPatterns(trimmed)) return 'yaml';

    // JSON: starts with { or [, contains "key":
    if (_hasJsonPatterns(trimmed)) return 'json';

    // Shell: common shell commands
    if (_hasShellPatterns(trimmed)) return 'bash';

    return null;
  }

  static bool _hasDartPatterns(String code) {
    return _matchMultiple(code, [
      RegExp(r"import\s+'package:"),
      RegExp(r'\bvoid\s+main\s*\('),
      RegExp(r'\blate\s+final\b'),
      RegExp(r'\brequired\s+this\.'),
      RegExp(r'\bWidget\s+build\s*\('),
      RegExp(r'\bStatelessWidget\b|\bStatefulWidget\b'),
      RegExp(r'\bFuture<'),
      RegExp(r'\bStream<'),
    ], threshold: 1);
  }

  static bool _hasPythonPatterns(String code) {
    return _matchMultiple(code, [
      RegExp(r'^def\s+\w+\s*\(', multiLine: true),
      RegExp(r'^from\s+\w+\s+import\b', multiLine: true),
      RegExp(r'^import\s+\w+', multiLine: true),
      RegExp(r"if\s+__name__\s*==\s*['" '"' r"]__main__['" '"' r"]"),
      RegExp(r'\bself\.\w+'),
      RegExp(r'^\s*class\s+\w+.*:', multiLine: true),
      RegExp(r'\bprint\s*\('),
    ], threshold: 2);
  }

  static bool _hasRustPatterns(String code) {
    return _matchMultiple(code, [
      RegExp(r'\bfn\s+main\s*\('),
      RegExp(r'\blet\s+mut\b'),
      RegExp(r'\bimpl\b.*\{'),
      RegExp(r'\buse\s+std::'),
      RegExp(r'\bpub\s+fn\b'),
      RegExp(r'->.*\{'),
      RegExp(r'\bprintln!\s*\('),
    ], threshold: 2);
  }

  static bool _hasGoPatterns(String code) {
    return _matchMultiple(code, [
      RegExp(r'^package\s+\w+', multiLine: true),
      RegExp(r'\bfunc\s+main\s*\('),
      RegExp(r'\bfunc\s+\(\w+\s+\*?\w+\)'),
      RegExp(r'import\s+\('),
      RegExp(r'\bfmt\.Print'),
      RegExp(r':='),
    ], threshold: 2);
  }

  static bool _hasKotlinPatterns(String code) {
    return _matchMultiple(code, [
      RegExp(r'\bfun\s+main\s*\('),
      RegExp(r'\bfun\s+\w+\s*\('),
      RegExp(r'\bval\s+\w+\s*[:=]'),
      RegExp(r'\bcompanion\s+object\b'),
      RegExp(r'\bdata\s+class\b'),
      RegExp(r'\bprintln\s*\('),
    ], threshold: 2);
  }

  static bool _hasSwiftPatterns(String code) {
    return _matchMultiple(code, [
      RegExp(r'\bimport\s+Foundation\b'),
      RegExp(r'\bimport\s+UIKit\b'),
      RegExp(r'\bfunc\s+\w+\s*\(.*\)\s*->'),
      RegExp(r'\bguard\s+let\b'),
      RegExp(r'\bif\s+let\b'),
      RegExp(r'\bstruct\s+\w+.*\{'),
    ], threshold: 2);
  }

  static bool _hasTypeScriptPatterns(String code) {
    return _matchMultiple(code, [
      RegExp(r'\binterface\s+\w+\s*\{'),
      RegExp(r'\btype\s+\w+\s*='),
      RegExp(r':\s*(string|number|boolean|void)\b'),
      RegExp(r'\bas\s+const\b'),
      RegExp(r'<\w+>\s*\('),
      RegExp(r'\bexport\s+(interface|type)\b'),
    ], threshold: 2);
  }

  static bool _hasJavaScriptPatterns(String code) {
    return _matchMultiple(code, [
      RegExp(r'\bconst\s+\w+\s*='),
      RegExp(r'\blet\s+\w+\s*='),
      RegExp(r'=>\s*\{?'),
      RegExp(r'\brequire\s*\('),
      RegExp(r'\bfunction\s+\w+\s*\('),
      RegExp(r'\bconsole\.log\s*\('),
      RegExp(r'\bexport\s+(default|const|function)\b'),
      RegExp(r'\bclass\s+\w+\s+extends\b'),
    ], threshold: 2);
  }

  static bool _hasJavaPatterns(String code) {
    return _matchMultiple(code, [
      RegExp(r'\bpublic\s+class\b'),
      RegExp(r'\bSystem\.out\.print'),
      RegExp(r'\bimport\s+java\.'),
      RegExp(r'\bpublic\s+static\s+void\s+main\b'),
      RegExp(r'\bprivate\s+(final\s+)?\w+\s+\w+'),
      RegExp(r'@Override\b'),
    ], threshold: 2);
  }

  static bool _hasCPatterns(String code) {
    return _matchMultiple(code, [
      RegExp(r'^#include\s*[<"]', multiLine: true),
      RegExp(r'\bint\s+main\s*\('),
      RegExp(r'\bprintf\s*\('),
      RegExp(r'\bstd::\w+'),
      RegExp(r'\busing\s+namespace\b'),
      RegExp(r'\bcout\s*<<'),
    ], threshold: 1);
  }

  static bool _hasSqlPatterns(String code) {
    final upper = code.toUpperCase();
    return _matchMultiple(upper, [
      RegExp(r'\bSELECT\b.*\bFROM\b'),
      RegExp(r'\bCREATE\s+TABLE\b'),
      RegExp(r'\bINSERT\s+INTO\b'),
      RegExp(r'\bALTER\s+TABLE\b'),
      RegExp(r'\bUPDATE\s+\w+\s+SET\b'),
      RegExp(r'\bDROP\s+TABLE\b'),
    ], threshold: 1);
  }

  static bool _hasCssPatterns(String code) {
    return _matchMultiple(code, [
      RegExp(r'[\w.#]\s*\{[^}]*\}', dotAll: true),
      RegExp(r'\b(color|display|margin|padding|font-size)\s*:'),
      RegExp(r'@media\s*\('),
      RegExp(r'\bbackground-color\s*:'),
    ], threshold: 2);
  }

  static bool _hasYamlPatterns(String code) {
    return _matchMultiple(code, [
      RegExp(r'^\w[\w-]*:\s', multiLine: true),
      RegExp(r'^\s+-\s+\w', multiLine: true),
      RegExp(r'^\s+\w[\w-]*:\s', multiLine: true),
    ], threshold: 2);
  }

  static bool _hasJsonPatterns(String code) {
    final trimmed = code.trim();
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return false;
    return RegExp(r'"[\w-]+"\s*:').hasMatch(trimmed);
  }

  static bool _hasShellPatterns(String code) {
    return _matchMultiple(code, [
      RegExp(r'^\s*(echo|cd|ls|mkdir|rm|cp|mv|cat|grep)\s', multiLine: true),
      RegExp(r'^\s*export\s+\w+=', multiLine: true),
      RegExp(r'\$\{\w+\}'),
      RegExp(r'\|\s*(grep|awk|sed|sort|head|tail)\b'),
      RegExp(r'^\s*if\s+\[\[', multiLine: true),
    ], threshold: 2);
  }

  /// Returns true if at least [threshold] patterns match.
  static bool _matchMultiple(
    String code,
    List<RegExp> patterns, {
    int threshold = 2,
  }) {
    var matches = 0;
    for (final pattern in patterns) {
      if (pattern.hasMatch(code)) {
        matches++;
        if (matches >= threshold) return true;
      }
    }
    return false;
  }

  /// All supported language identifiers, sorted alphabetically.
  /// Subset of the most commonly used languages from the highlight package.
  static const List<String> commonLanguages = [
    'bash',
    'c',
    'cpp',
    'csharp',
    'css',
    'dart',
    'diff',
    'dockerfile',
    'elixir',
    'erlang',
    'go',
    'graphql',
    'groovy',
    'haskell',
    'html',
    'java',
    'javascript',
    'json',
    'julia',
    'kotlin',
    'latex',
    'lua',
    'makefile',
    'markdown',
    'matlab',
    'nginx',
    'objectivec',
    'ocaml',
    'perl',
    'php',
    'plaintext',
    'powershell',
    'properties',
    'protobuf',
    'python',
    'r',
    'ruby',
    'rust',
    'scala',
    'scss',
    'shell',
    'sql',
    'swift',
    'toml',
    'typescript',
    'vbnet',
    'xml',
    'yaml',
    'zig',
  ];
}
