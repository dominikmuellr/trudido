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

/// Provides fuzzy date parsing using Levenshtein distance algorithm.
/// Enables matching user input to calendar dates with typo tolerance.
class FuzzySearch {
  /// Calculates the Levenshtein distance between two strings
  /// Returns the minimum number of edits (insertions, deletions, substitutions)
  /// needed to transform s1 into s2
  static int _levenshteinDistance(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;

    final matrix = List.generate(
      len1 + 1,
      (i) => List.generate(len2 + 1, (j) => 0),
    );

    for (var i = 0; i <= len1; i++) {
      matrix[i][0] = i;
    }
    for (var j = 0; j <= len2; j++) {
      matrix[0][j] = j;
    }

    // Fill in the rest of the matrix
    for (var i = 1; i <= len1; i++) {
      for (var j = 1; j <= len2; j++) {
        if (s1[i - 1].toLowerCase() == s2[j - 1].toLowerCase()) {
          matrix[i][j] = matrix[i - 1][j - 1];
        } else {
          matrix[i][j] = [
            matrix[i - 1][j] + 1, // deletion
            matrix[i][j - 1] + 1, // insertion
            matrix[i - 1][j - 1] + 1, // substitution
          ].reduce((a, b) => a < b ? a : b);
        }
      }
    }

    return matrix[len1][len2];
  }

  /// Calculates similarity score between two strings (0.0 to 1.0)
  /// 1.0 means perfect match, 0.0 means completely different
  static double calculateSimilarity(String s1, String s2) {
    if (s1.isEmpty && s2.isEmpty) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final distance = _levenshteinDistance(s1, s2);
    final maxLen = s1.length > s2.length ? s1.length : s2.length;
    return 1.0 - (distance / maxLen);
  }

  /// Filters a list of items based on fuzzy matching
  /// Returns items sorted by relevance score
  static List<T> filter<T>({
    required List<T> items,
    required String query,
    required String Function(T) getText,
    double minSimilarity = 0.5,
  }) {
    if (query.isEmpty) return items;

    final results = <_FuzzyResult<T>>[];
    final queryLower = query.toLowerCase();

    // Adjust minimum similarity based on query length
    // Shorter queries need stricter matching to avoid false positives
    final adjustedMinSimilarity = queryLower.length <= 3
        ? 0.85 // Very strict for short queries (1 typo max for 3-letter words)
        : queryLower.length <= 5
        ? 0.75 // Strict for medium queries
        : minSimilarity; // Use provided threshold for longer queries

    for (final item in items) {
      final text = getText(item).toLowerCase();
      double bestScore = 0.0;

      if (text.contains(queryLower)) {
        bestScore = 1.0;
      } else {
        final words = text.split(RegExp(r'\s+'));
        for (final word in words) {
          // Skip very short words unless query is also very short
          if (word.length < 3 && queryLower.length > 3) continue;

          final wordSimilarity = calculateSimilarity(queryLower, word);
          if (wordSimilarity > bestScore) {
            bestScore = wordSimilarity;
          }
        }

        // For longer words, check if query matches start of word (common typo pattern)
        for (final word in words) {
          if (word.length >= queryLower.length) {
            final wordStart = word.substring(0, queryLower.length);
            final startSimilarity = calculateSimilarity(queryLower, wordStart);
            if (startSimilarity > bestScore) {
              bestScore = startSimilarity;
            }
          }
        }
      }

      if (bestScore >= adjustedMinSimilarity) {
        results.add(_FuzzyResult(item, bestScore));
      }
    }

    // Sort by score (highest first)
    results.sort((a, b) => b.score.compareTo(a.score));
    return results.map((r) => r.item).toList();
  }
}

/// Helper class to store item with its fuzzy match score
class _FuzzyResult<T> {
  final T item;
  final double score;

  _FuzzyResult(this.item, this.score);
}

/// Utility class for parsing date queries in search
class DateSearchParser {
  /// Attempts to parse a search query as a date
  /// Supports multiple formats with fuzzy parsing:
  /// - DD.MM.YYYY or DD/MM/YYYY (European)
  /// - MM/DD/YYYY or MM-DD-YYYY (US)
  /// - YYYY-MM-DD (ISO)
  /// - Accepts 2-digit years (e.g., 24 -> 2024)
  /// - Accepts any separator (., /, -, space)
  /// Returns null if the query is not a valid date format
  static DateTime? parseDate(String query) {
    if (query.trim().isEmpty) return null;

    // Normalize the input: replace any separator with space for easier parsing
    final cleaned = query
        .trim()
        .replaceAll(RegExp(r'[./-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');

    // Split by space to get components
    final parts = cleaned.split(' ');
    if (parts.length != 3) return null;

    try {
      int part1 = int.parse(parts[0]);
      int part2 = int.parse(parts[1]);
      int part3 = int.parse(parts[2]);

      if (part3 < 100) {
        part3 += (part3 < 50 ? 2000 : 1900);
      }
      if (part1 >= 1900 && part1 <= 2100) {
        // First part is a 4-digit year, so this is ISO format
        if (part1 < 100) {
          part1 += (part1 < 50 ? 2000 : 1900);
        }
      }

      // Determine format based on first component
      if (part1 > 31 || part1 >= 1900) {
        // Likely ISO format: YYYY-MM-DD
        final year = part1;
        final month = part2;
        final day = part3;
        if (_isValidDate(year, month, day)) {
          return DateTime(year, month, day);
        }
      } else if (part2 > 12 || part3 < 1900) {
        // Likely European format: DD.MM.YYYY
        final day = part1;
        final month = part2;
        final year = part3;
        if (_isValidDate(year, month, day)) {
          return DateTime(year, month, day);
        }
      } else {
        // Ambiguous - try both US and European formats
        // Try US format first: MM/DD/YYYY
        final month = part1;
        final day = part2;
        final year = part3;
        if (_isValidDate(year, month, day)) {
          return DateTime(year, month, day);
        }

        // Try European format: DD.MM.YYYY
        final dayEu = part1;
        final monthEu = part2;
        final yearEu = part3;
        if (_isValidDate(yearEu, monthEu, dayEu)) {
          return DateTime(yearEu, monthEu, dayEu);
        }
      }
    } catch (e) {
      return null;
    }

    return null;
  }

  /// Validates if the given date components form a valid date
  static bool _isValidDate(int year, int month, int day) {
    if (year < 1900 || year > 2100) return false;
    if (month < 1 || month > 12) return false;
    if (day < 1) return false;

    final daysInMonth = DateTime(year, month + 1, 0).day;
    return day <= daysInMonth;
  }

  /// Checks if two dates are on the same day (ignoring time)
  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
