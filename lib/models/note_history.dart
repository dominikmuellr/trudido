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

import 'package:isar_community/isar.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../utils/isar_id.dart';

part 'note_history.g.dart';

/// Represents a single edit history entry for a note's content field.
/// Used for undo/redo functionality and browsing full edit history.
@collection
class NoteHistoryEntry {
  Id get isarId => fastHash(id);

  @Index(unique: true, replace: true)
  String id;

  @Index()
  String noteId;

  String? contentBefore;

  String? contentAfter;

  DateTime? timestamp;

  NoteHistoryEntry({
    String id = '',
    required this.noteId,
    this.contentBefore,
    this.contentAfter,
    DateTime? timestamp,
  }) : id = id.isEmpty ? const Uuid().v4() : id,
       timestamp = timestamp ?? DateTime.now();

  /// Creates a copy with optional field overrides.
  NoteHistoryEntry copyWith({
    String? id,
    String? noteId,
    String? contentBefore,
    String? contentAfter,
    DateTime? timestamp,
  }) {
    return NoteHistoryEntry(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      contentBefore: contentBefore ?? this.contentBefore,
      contentAfter: contentAfter ?? this.contentAfter,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Formats the timestamp as DD.MM.YYYY HH:mm (European 24h format).
  @ignore
  String get formattedTimestamp => formatTimestamp();

  /// Formats the timestamp, respecting the user's 12h/24h preference.
  String formatTimestamp({bool use24Hour = true}) {
    final d = timestamp ?? DateTime.now();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    if (use24Hour) {
      final hour = d.hour.toString().padLeft(2, '0');
      final minute = d.minute.toString().padLeft(2, '0');
      return '$day.$month.$year $hour:$minute';
    } else {
      final period = d.hour >= 12 ? 'PM' : 'AM';
      final displayHour = d.hour == 0
          ? 12
          : (d.hour > 12 ? d.hour - 12 : d.hour);
      final minute = d.minute.toString().padLeft(2, '0');
      return '$day.$month.$year $displayHour:$minute $period';
    }
  }

  /// Returns a brief human-readable summary of the change.
  @ignore
  String get changeSummary {
    if (contentBefore == null && contentAfter != null) {
      return 'Content added';
    } else if (contentBefore != null && contentAfter == null) {
      return 'Content cleared';
    } else if (contentBefore != null && contentAfter != null) {
      final beforeText = _extractPlainText(contentBefore!);
      final afterText = _extractPlainText(contentAfter!);
      final beforeLen = beforeText.length;
      final afterLen = afterText.length;
      if (afterLen > beforeLen) {
        return 'Content expanded (+${afterLen - beforeLen} chars)';
      } else if (afterLen < beforeLen) {
        return 'Content shortened (-${beforeLen - afterLen} chars)';
      } else {
        return 'Content edited';
      }
    }
    return 'No change';
  }

  /// Extracts plain text from content (handles both JSON and plain text).
  String _extractPlainText(String content) {
    try {
      // Check if it's JSON (Quill Delta format)
      if (content.trim().startsWith('[')) {
        final json = jsonDecode(content);
        if (json is List) {
          final buffer = StringBuffer();
          for (final op in json) {
            if (op is Map && op['insert'] is String) {
              buffer.write(op['insert']);
            }
          }
          return buffer.toString().trim();
        }
      }
    } catch (_) {
      // Not JSON, return as-is
    }
    return content.trim();
  }

  /// Returns a preview of the content before this change.
  @ignore
  String get contentBeforePreview {
    if (contentBefore == null) return '(empty)';
    final text = _extractPlainText(contentBefore!);
    if (text.isEmpty) return '(empty)';
    if (text.length <= 100) return text;
    return '${text.substring(0, 100)}...';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'noteId': noteId,
      'contentBefore': contentBefore,
      'contentAfter': contentAfter,
      'timestamp': (timestamp ?? DateTime.now()).toIso8601String(),
    };
  }

  static NoteHistoryEntry fromJson(Map<String, dynamic> json) {
    return NoteHistoryEntry(
      id: json['id'] ?? '',
      noteId: json['noteId'],
      contentBefore: json['contentBefore'],
      contentAfter: json['contentAfter'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  @override
  String toString() {
    return 'NoteHistoryEntry(id: $id, noteId: $noteId, timestamp: $formattedTimestamp)';
  }
}
