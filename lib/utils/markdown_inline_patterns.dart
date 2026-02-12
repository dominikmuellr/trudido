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

class MarkdownInlinePatterns {
  static final Map<RegExp, String> textStyles = <RegExp, String>{
    RegExp(r'\*\*([^*]+)\*\*'): 'bold',
    RegExp(r'__([^_]+)__'): 'bold',
    RegExp(r'(?<!\*)\*(?!\*)([^*]+)\*(?!\*)'): 'italic',
    RegExp(r'(?<!_)_(?!_)([^_]+)_(?!_)'): 'italic',
    RegExp(r'~~([^~]+)~~'): 'strikethrough',
    RegExp(r'==([^=]+)=='): 'highlight',
    RegExp(r'`([^`]+)`'): 'code',
    RegExp(r'<u>([^<]+)</u>'): 'underline',
  };

  static final Map<RegExp, Map<String, dynamic>> quillAttributes =
      <RegExp, Map<String, dynamic>>{
        RegExp(r'\*\*([^*]+)\*\*'): {'bold': true},
        RegExp(r'__([^_]+)__'): {'bold': true},
        RegExp(r'(?<!\*)\*(?!\*)([^*]+)\*(?!\*)'): {'italic': true},
        RegExp(r'(?<!_)_(?!_)([^_]+)_(?!_)'): {'italic': true},
        RegExp(r'~~([^~]+)~~'): {'strike': true},
        RegExp(r'`([^`]+)`'): {'code': true},
        RegExp(r'<u>([^<]+)</u>'): {'underline': true},
        RegExp(r'==([^=]+)=='): {'background': '#ffff00'},
      };

  static List<MapEntry<Match, T>> findNonOverlappingMatches<T>(
    String text,
    Map<RegExp, T> patterns,
  ) {
    final allMatches = <MapEntry<Match, T>>[];
    patterns.forEach((pattern, value) {
      for (final match in pattern.allMatches(text)) {
        allMatches.add(MapEntry(match, value));
      }
    });

    allMatches.sort((a, b) => a.key.start.compareTo(b.key.start));

    final filteredMatches = <MapEntry<Match, T>>[];
    for (final entry in allMatches) {
      final match = entry.key;
      final overlaps = filteredMatches.any(
        (existing) =>
            match.start < existing.key.end && match.end > existing.key.start,
      );
      if (!overlaps) {
        filteredMatches.add(entry);
      }
    }

    return filteredMatches;
  }
}
