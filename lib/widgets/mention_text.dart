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

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../utils/mention_parser.dart';

/// A [TextEditingController] that only shows display text (`@Title`) to the
/// user, never the raw `@[Title](type:id)` format.
///
/// Mentions are **atomic**: the cursor cannot be placed inside one, tapping
/// a mention navigates instead, and deletion removes the whole mention at
/// once. Mention metadata is stored in a side-map so that [toStorageText]
/// can reconstruct the raw format for persistence.
///
/// Call [notifyPointerUp] from a `Listener(onPointerUp:)` wrapping the
/// text field so the controller can detect real taps and invoke
/// [onMentionTap] when a mention is tapped.
class MentionTextEditingController extends TextEditingController {
  /// Maps a display key (`@Title`) to its mention data.
  final Map<String, MentionLink> _mentionMap = {};

  /// Read-only view of the mention map for use by preview renderers.
  Map<String, MentionLink> get mentionMap => Map.unmodifiable(_mentionMap);

  /// Called when the user taps on a mention. Set by the owning widget.
  void Function(MentionLink mention)? onMentionTap;

  /// Set to `true` by [notifyPointerUp]; consumed by [_guardMentions].
  bool _pointerUpPending = false;

  /// Prevents recursive guard invocations.
  bool _guardActive = false;

  /// Set to `true` by [insertMention] and [setFromStorageText] so that
  /// programmatic edits skip the guard logic.
  bool _suppressGuard = false;

  MentionTextEditingController({String? text}) : super(text: '') {
    if (text != null && text.isNotEmpty) {
      setFromStorageText(text);
    }
  }

  /// Call this from `Listener(onPointerUp: (_) => ctrl.notifyPointerUp())`
  /// so the controller knows a real screen tap happened.
  void notifyPointerUp() {
    _pointerUpPending = true;
  }

  // ── value override ────────────────────────────────────────────────

  @override
  set value(TextEditingValue newValue) {
    if (_suppressGuard || _guardActive) {
      super.value = newValue;
      return;
    }
    _guardActive = true;
    try {
      super.value = _guardMentions(value, newValue);
    } finally {
      _guardActive = false;
    }
  }

  /// Ensures that mentions behave as atomic, non-editable units.
  TextEditingValue _guardMentions(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldText = oldValue.text;
    final newText = newValue.text;

    // ── 1) Pure cursor / selection change ──
    if (newText == oldText) {
      if (!newValue.selection.isCollapsed) return newValue;
      final cursor = newValue.selection.baseOffset;
      if (cursor < 0 || cursor > newText.length) return newValue;

      final hits = findMentionHits(newText, _mentionMap);
      for (final hit in hits) {
        // Strictly inside (not at boundaries)
        if (cursor > hit.start && cursor < hit.end) {
          // If this was a real tap, schedule navigation callback
          if (_pointerUpPending && onMentionTap != null) {
            _pointerUpPending = false;
            // Schedule after value setter completes so listeners
            // are not disrupted.
            final mention = hit.mention;
            Future.microtask(() => onMentionTap?.call(mention));
          }

          final snapTo = (cursor - hit.start) <= (hit.end - cursor)
              ? hit.start
              : hit.end;
          return newValue.copyWith(
            selection: TextSelection.collapsed(offset: snapTo),
          );
        }
      }
      // Cursor wasn't inside a mention, consume the flag
      _pointerUpPending = false;
      return newValue;
    }

    // Not a pure cursor move → consume pointer flag
    _pointerUpPending = false;

    // ── 2) Text shortened → possible mention damage ──
    if (newText.length < oldText.length) {
      final oldHits = findMentionHits(oldText, _mentionMap);
      for (final hit in oldHits) {
        if (!newText.contains(hit.key)) {
          // Mention was damaged → delete it entirely from the *old* text.
          final resultText =
              oldText.substring(0, hit.start) + oldText.substring(hit.end);
          _mentionMap.remove(hit.key);
          final cursor = hit.start.clamp(0, resultText.length);
          // Recurse in case multiple mentions were damaged at once.
          return _guardMentions(
            oldValue,
            TextEditingValue(
              text: resultText,
              selection: TextSelection.collapsed(offset: cursor),
            ),
          );
        }
      }
    }

    // ── 3) Clean up map for mentions that vanished (paste over, etc.) ──
    _mentionMap.removeWhere((key, _) => !newText.contains(key));

    return newValue;
  }

  // ── Storage helpers ───────────────────────────────────────────────

  /// Sets text from raw storage format, stripping mentions to display
  /// format and populating the mention map.
  void setFromStorageText(String rawText) {
    _suppressGuard = true;
    try {
      final parsed = _stripToDisplay(rawText, _mentionMap);
      if (parsed != null) {
        _mentionMap.addAll(parsed.$2);
        text = parsed.$1;
      } else {
        text = rawText;
      }
    } finally {
      _suppressGuard = false;
    }
  }

  /// Parses raw storage text and returns (displayText, mentionMap).
  /// Returns null if no mentions found.
  static (String, Map<String, MentionLink>)? _stripToDisplay(
    String raw,
    Map<String, MentionLink>? existingMap,
  ) {
    final mentions = MentionParser.extractMentions(raw);
    if (mentions.isEmpty) return null;
    final map = <String, MentionLink>{};
    if (existingMap != null) map.addAll(existingMap);
    String display = raw;
    // Replace from end to start so indices stay valid
    for (final m in mentions.reversed) {
      final displayKey = '@${m.title}';
      map[displayKey] = m;
      display =
          display.substring(0, m.start) + displayKey + display.substring(m.end);
    }
    return (display, map);
  }

  /// Inserts a mention at the current cursor position, replacing the
  /// `@query` trigger text.
  void insertMention(MentionLink mention, int triggerStart, int triggerEnd) {
    _suppressGuard = true;
    try {
      final displayKey = '@${mention.title}';
      _mentionMap[displayKey] = mention;
      final before = text.substring(0, triggerStart);
      final after = text.substring(triggerEnd);
      final newText = '$before$displayKey $after';
      value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: triggerStart + displayKey.length + 1,
        ),
      );
    } finally {
      _suppressGuard = false;
    }
  }

  /// Returns the [MentionLink] at the given cursor [offset], or null.
  /// Matches at boundaries (start and end inclusive) so that popup
  /// suppression works when cursor sits right at the edge.
  MentionLink? mentionAtCursor(int offset) {
    if (_mentionMap.isEmpty || offset < 0 || offset > text.length) return null;
    for (final entry in _mentionMap.entries) {
      final key = entry.key;
      int searchFrom = 0;
      while (true) {
        final idx = text.indexOf(key, searchFrom);
        if (idx == -1) break;
        if (offset >= idx && offset <= idx + key.length) {
          return entry.value;
        }
        searchFrom = idx + 1;
      }
    }
    return null;
  }

  /// Finds all mention key occurrences in [source], sorted by position.
  /// Used by [buildTextSpan] and external preview renderers.
  static List<({int start, int end, String key, MentionLink mention})>
  findMentionHits(String source, Map<String, MentionLink> map) {
    final hits = <({int start, int end, String key, MentionLink mention})>[];
    // Search longest keys first to avoid partial overlaps
    final keys = map.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final used = List<bool>.filled(source.length, false);
    for (final key in keys) {
      int searchFrom = 0;
      while (true) {
        final idx = source.indexOf(key, searchFrom);
        if (idx == -1) break;
        // Check no overlap with already-found hit
        bool overlap = false;
        for (int i = idx; i < idx + key.length; i++) {
          if (used[i]) {
            overlap = true;
            break;
          }
        }
        if (!overlap) {
          hits.add((
            start: idx,
            end: idx + key.length,
            key: key,
            mention: map[key]!,
          ));
          for (int i = idx; i < idx + key.length; i++) {
            used[i] = true;
          }
        }
        searchFrom = idx + 1;
      }
    }
    hits.sort((a, b) => a.start.compareTo(b.start));
    return hits;
  }

  /// Converts the current display text back to storage format with full
  /// mention links embedded.
  String toStorageText() {
    String result = text;
    // Replace display mentions with raw format, longest match first
    // to avoid partial-match issues.
    final keys = _mentionMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final key in keys) {
      final mention = _mentionMap[key]!;
      result = result.replaceAll(key, mention.raw);
    }
    return result;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (_mentionMap.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final hits = findMentionHits(text, _mentionMap);
    if (hits.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final hit in hits) {
      if (hit.start > lastEnd) {
        spans.add(
          TextSpan(text: text.substring(lastEnd, hit.start), style: style),
        );
      }

      spans.add(
        TextSpan(
          text: hit.key,
          style: style?.copyWith(
            color: hit.mention.isTask
                ? colorScheme.primary
                : colorScheme.tertiary,
            fontWeight: FontWeight.w600,
            backgroundColor:
                (hit.mention.isTask
                        ? colorScheme.primaryContainer
                        : colorScheme.tertiaryContainer)
                    .withValues(alpha: 0.4),
          ),
        ),
      );

      lastEnd = hit.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: style));
    }

    return TextSpan(children: spans, style: style);
  }
}

/// Builds a [TextSpan] tree from text that may contain mention links.
///
/// Mention links (format: `@[Title](type:id)`) are rendered as styled
/// clickable inline text, while non-mention text is rendered normally.
class MentionTextBuilder {
  /// Builds a [TextSpan] with mention links styled and clickable.
  ///
  /// [text] - The raw text that may contain mention links
  /// [baseStyle] - The default text style for non-mention text
  /// [onMentionTap] - Callback when a mention is tapped (receives MentionLink)
  /// [mentionTaskStyle] - Style override for task mentions
  /// [mentionNoteStyle] - Style override for note mentions
  static TextSpan buildMentionSpans({
    required String text,
    TextStyle? baseStyle,
    void Function(MentionLink mention)? onMentionTap,
    TextStyle? mentionTaskStyle,
    TextStyle? mentionNoteStyle,
  }) {
    final mentions = MentionParser.extractMentions(text);

    if (mentions.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final mention in mentions) {
      // Add plain text before this mention
      if (mention.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, mention.start),
            style: baseStyle,
          ),
        );
      }

      // Add the styled mention
      final isTapEnabled = onMentionTap != null;
      final defaultMentionStyle = (baseStyle ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
        decorationStyle: TextDecorationStyle.dotted,
      );

      final style = mention.isTask
          ? (mentionTaskStyle ?? defaultMentionStyle)
          : (mentionNoteStyle ?? defaultMentionStyle);

      spans.add(
        TextSpan(
          text: '@${mention.title}',
          style: style,
          recognizer: isTapEnabled
              ? (TapGestureRecognizer()..onTap = () => onMentionTap(mention))
              : null,
        ),
      );

      lastEnd = mention.end;
    }

    // Add remaining text after last mention
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
    }

    return TextSpan(children: spans);
  }

  /// Returns the display version of text with mentions rendered as @Title
  /// instead of the raw @[Title](type:id) format.
  static String toDisplayText(String text) {
    return text.replaceAllMapped(
      MentionParser.mentionPattern,
      (match) => '@${match.group(1)}',
    );
  }

  /// A convenience widget that renders text with clickable mentions.
  static Widget buildRichText({
    required String text,
    TextStyle? baseStyle,
    void Function(MentionLink mention)? onMentionTap,
    int? maxLines,
    TextOverflow? overflow,
    TextStyle? mentionTaskStyle,
    TextStyle? mentionNoteStyle,
  }) {
    return RichText(
      text: buildMentionSpans(
        text: text,
        baseStyle: baseStyle,
        onMentionTap: onMentionTap,
        mentionTaskStyle: mentionTaskStyle,
        mentionNoteStyle: mentionNoteStyle,
      ),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
}

/// A widget that renders text with styled, clickable mention links.
///
/// Usage:
/// ```dart
/// MentionText(
///   text: 'Check @[Buy groceries](task:abc123) for the recipe in @[Meal Plan](note:def456)',
///   onMentionTap: (mention) {
///     // Navigate to task or note
///   },
/// )
/// ```
class MentionText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final void Function(MentionLink mention)? onMentionTap;
  final int? maxLines;
  final TextOverflow? overflow;

  const MentionText({
    super.key,
    required this.text,
    this.style,
    this.onMentionTap,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MentionTextBuilder.buildRichText(
      text: text,
      baseStyle: style ?? theme.textTheme.bodyMedium,
      onMentionTap: onMentionTap,
      mentionTaskStyle: (style ?? theme.textTheme.bodyMedium)?.copyWith(
        color: colorScheme.primary,
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
        decorationStyle: TextDecorationStyle.dotted,
        decorationColor: colorScheme.primary.withValues(alpha: 0.5),
      ),
      mentionNoteStyle: (style ?? theme.textTheme.bodyMedium)?.copyWith(
        color: colorScheme.tertiary,
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
        decorationStyle: TextDecorationStyle.dotted,
        decorationColor: colorScheme.tertiary.withValues(alpha: 0.5),
      ),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
