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

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

part 'note_history.g.dart';

/// Represents a single edit history entry for a note's content field.
/// Used for undo/redo functionality and browsing full edit history.
/// Supports branching history via parentEntryId - when editing from a past
/// version, a new branch is created while preserving the original timeline.
@HiveType(typeId: 9)
class NoteHistoryEntry extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String noteId;

  @HiveField(2)
  String? contentBefore;

  @HiveField(3)
  String? contentAfter;

  @HiveField(4)
  DateTime timestamp;

  /// ID of the parent history entry. Null for the first entry in a note's history.
  /// When branching from a past version, this points to the restored entry.
  @HiveField(5)
  String? parentEntryId;

  /// Optional label for this branch (e.g., "Main", "Alternative version")
  @HiveField(6)
  String? branchLabel;

  NoteHistoryEntry({
    String? id,
    required this.noteId,
    this.contentBefore,
    this.contentAfter,
    DateTime? timestamp,
    this.parentEntryId,
    this.branchLabel,
  }) : id = id ?? const Uuid().v4(),
       timestamp = timestamp ?? DateTime.now();

  /// Creates a copy with optional field overrides.
  NoteHistoryEntry copyWith({
    String? id,
    String? noteId,
    String? contentBefore,
    String? contentAfter,
    DateTime? timestamp,
    String? parentEntryId,
    String? branchLabel,
  }) {
    return NoteHistoryEntry(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      contentBefore: contentBefore ?? this.contentBefore,
      contentAfter: contentAfter ?? this.contentAfter,
      timestamp: timestamp ?? this.timestamp,
      parentEntryId: parentEntryId ?? this.parentEntryId,
      branchLabel: branchLabel ?? this.branchLabel,
    );
  }

  /// Formats the timestamp as DD.MM.YYYY HH:mm (European 24h format).
  String get formattedTimestamp {
    final d = timestamp;
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  /// Returns a brief human-readable summary of the change.
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
      'timestamp': timestamp.toIso8601String(),
      'parentEntryId': parentEntryId,
      'branchLabel': branchLabel,
    };
  }

  static NoteHistoryEntry fromJson(Map<String, dynamic> json) {
    return NoteHistoryEntry(
      id: json['id'],
      noteId: json['noteId'],
      contentBefore: json['contentBefore'],
      contentAfter: json['contentAfter'],
      timestamp: DateTime.parse(json['timestamp']),
      parentEntryId: json['parentEntryId'],
      branchLabel: json['branchLabel'],
    );
  }

  @override
  String toString() {
    return 'NoteHistoryEntry(id: $id, noteId: $noteId, parentEntryId: $parentEntryId, timestamp: $formattedTimestamp)';
  }
}
