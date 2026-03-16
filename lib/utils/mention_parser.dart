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

/// Represents a parsed mention link in text content.
///
/// Mentions are stored in the format: `@[Display Title](type:id)`
/// where type is either "task" or "note".
class MentionLink {
  /// The display title shown to the user
  final String title;

  /// The type of the linked item: "task" or "note"
  final String type;

  /// The unique ID of the linked item
  final String id;

  /// Start position in the source text (inclusive)
  final int start;

  /// End position in the source text (exclusive)
  final int end;

  const MentionLink({
    required this.title,
    required this.type,
    required this.id,
    required this.start,
    required this.end,
  });

  bool get isTask => type == 'task';
  bool get isNote => type == 'note';
  bool get isEvent => type == 'event';

  /// The full raw mention string as stored in text
  String get raw => '@[$title]($type:$id)';

  @override
  String toString() => 'MentionLink($type:$id "$title" [$start-$end])';
}

/// Parses and creates mention links in text content.
///
/// Mention format: `@[Display Title](task:uuid)` or `@[Display Title](note:uuid)`
///
/// This format is chosen because:
/// - It's markdown-compatible (similar to `[text](url)`)
/// - It embeds the ID directly, so it survives renames
/// - It's human-readable in raw form
/// - It doesn't conflict with existing markdown patterns
class MentionParser {
  /// Regex to match mention links: @[title](type:id)
  static final RegExp mentionPattern = RegExp(
    r'@\[([^\]]+)\]\((task|note|event):([a-zA-Z0-9\-]+)\)',
  );

  /// Regex to detect the start of a mention being typed: @ followed by text
  /// Used for triggering autocomplete
  static final RegExp mentionTriggerPattern = RegExp(r'@([^\s@\[\]]{0,50})$');

  /// Extracts all mention links from the given text.
  static List<MentionLink> extractMentions(String text) {
    final mentions = <MentionLink>[];
    for (final match in mentionPattern.allMatches(text)) {
      mentions.add(
        MentionLink(
          title: match.group(1)!,
          type: match.group(2)!,
          id: match.group(3)!,
          start: match.start,
          end: match.end,
        ),
      );
    }
    return mentions;
  }

  /// Extracts all unique task IDs mentioned in the text.
  static Set<String> extractTaskIds(String text) {
    return extractMentions(
      text,
    ).where((m) => m.isTask).map((m) => m.id).toSet();
  }

  /// Extracts all unique note IDs mentioned in the text.
  static Set<String> extractNoteIds(String text) {
    return extractMentions(
      text,
    ).where((m) => m.isNote).map((m) => m.id).toSet();
  }

  /// Extracts all unique event IDs mentioned in the text.
  static Set<String> extractEventIds(String text) {
    return extractMentions(
      text,
    ).where((m) => m.isEvent).map((m) => m.id).toSet();
  }

  /// Creates a mention string for a task.
  static String createTaskMention(String id, String title) {
    // Sanitize title: remove brackets that would break the format
    final safeTitle = title.replaceAll('[', '(').replaceAll(']', ')');
    return '@[$safeTitle](task:$id)';
  }

  /// Creates a mention string for a note.
  static String createNoteMention(String id, String title) {
    final safeTitle = title.replaceAll('[', '(').replaceAll(']', ')');
    return '@[$safeTitle](note:$id)';
  }

  /// Creates a mention string for an event.
  static String createEventMention(String id, String title) {
    final safeTitle = title.replaceAll('[', '(').replaceAll(']', ')');
    return '@[$safeTitle](event:$id)';
  }

  /// Detects if the user is currently typing a mention trigger (@).
  ///
  /// Returns the search query after @ (the text being typed to search),
  /// or null if the cursor is not at a mention trigger position.
  static String? detectMentionTrigger(String text, int cursorPosition) {
    if (cursorPosition <= 0 || cursorPosition > text.length) return null;

    final textBeforeCursor = text.substring(0, cursorPosition);
    final match = mentionTriggerPattern.firstMatch(textBeforeCursor);
    if (match == null) return null;

    return match.group(1) ?? '';
  }

  /// Returns the position range where the mention trigger starts,
  /// so it can be replaced when a mention is selected.
  ///
  /// Returns (start, end) tuple or null if no trigger detected.
  static ({int start, int end})? getMentionTriggerRange(
    String text,
    int cursorPosition,
  ) {
    if (cursorPosition <= 0 || cursorPosition > text.length) return null;

    final textBeforeCursor = text.substring(0, cursorPosition);
    final match = mentionTriggerPattern.firstMatch(textBeforeCursor);
    if (match == null) return null;

    return (start: match.start, end: cursorPosition);
  }

  /// Replaces a mention trigger (@query) with a full mention link.
  ///
  /// Returns the new text and the new cursor position after the inserted mention.
  static ({String text, int cursorPosition}) replaceTriggerWithMention({
    required String text,
    required int cursorPosition,
    required String mentionString,
  }) {
    final range = getMentionTriggerRange(text, cursorPosition);
    if (range == null) {
      return (text: text, cursorPosition: cursorPosition);
    }

    final before = text.substring(0, range.start);
    final after = text.substring(range.end);
    final newText = '$before$mentionString $after';
    final newCursor = before.length + mentionString.length + 1;

    return (text: newText, cursorPosition: newCursor);
  }

  /// Returns display text for a mention (strips the raw format to just the title).
  /// Useful for rendering mentions as styled inline text.
  static String getDisplayText(String rawMention) {
    final match = mentionPattern.firstMatch(rawMention);
    if (match == null) return rawMention;
    return '@${match.group(1)}';
  }
}
