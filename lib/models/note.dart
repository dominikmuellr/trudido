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
import '../utils/isar_id.dart';

part 'note.g.dart';

@collection
class Note {
  Id get isarId => fastHash(id);

  @Index(unique: true, replace: true)
  String id;

  String title;

  String content;

  DateTime? createdAt;

  DateTime? updatedAt;

  bool isPinned;

  String? folderId; // Reference to folder (including vault folders)

  String? todoTxtContent; // Optional todo.txt format representation

  bool isDeleted;

  double lineHeightMultiplier;

  double paragraphSpacing;

  bool lastReadMode;

  DateTime? deletedAt;

  int? colorValue; // ARGB color value for card background, null = default theme color

  List<String> tags;

  Note({
    String id = '',
    required this.title,
    required this.content,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isPinned = false,
    this.folderId,
    this.todoTxtContent,
    this.isDeleted = false,
    this.lineHeightMultiplier = 1.5,
    this.paragraphSpacing = 8.0,
    this.lastReadMode = false,
    this.deletedAt,
    this.colorValue,
    this.tags = const [],
  }) : id = id.isEmpty ? const Uuid().v4() : id,
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Note copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPinned,
    String? folderId,
    String? todoTxtContent,
    bool? isDeleted,
    double? lineHeightMultiplier,
    double? paragraphSpacing,
    bool? lastReadMode,
    DateTime? deletedAt,
    Object? colorValue = _sentinel,
    List<String>? tags,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      folderId: folderId ?? this.folderId,
      todoTxtContent: todoTxtContent ?? this.todoTxtContent,
      isDeleted: isDeleted ?? this.isDeleted,
      lineHeightMultiplier: lineHeightMultiplier ?? this.lineHeightMultiplier,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      lastReadMode: lastReadMode ?? this.lastReadMode,
      deletedAt: deletedAt ?? this.deletedAt,
      colorValue: colorValue == _sentinel
          ? this.colorValue
          : colorValue as int?,
      tags: tags ?? this.tags,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Note && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Note(id: $id, title: $title, isPinned: $isPinned, folderId: $folderId, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  /// Converts the note to a JSON map for export/import
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
      'isPinned': isPinned,
      'folderId': folderId,
      'todoTxtContent': todoTxtContent,
      'isDeleted': isDeleted,
      'lineHeightMultiplier': lineHeightMultiplier,
      'paragraphSpacing': paragraphSpacing,
      'lastReadMode': lastReadMode,
      if (colorValue != null) 'colorValue': colorValue,
      'tags': tags,
    };
  }

  /// Creates a Note from a JSON map
  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isPinned: json['isPinned'] as bool? ?? false,
      folderId: json['folderId'] as String?,
      todoTxtContent: json['todoTxtContent'] as String?,
      isDeleted: json['isDeleted'] as bool? ?? false,
      lineHeightMultiplier:
          (json['lineHeightMultiplier'] as num?)?.toDouble() ?? 1.5,
      paragraphSpacing: (json['paragraphSpacing'] as num?)?.toDouble() ?? 8.0,
      lastReadMode: json['lastReadMode'] as bool? ?? false,
      colorValue: json['colorValue'] as int?,
      tags: List<String>.from(json['tags'] ?? const <String>[]),
    );
  }
}

// Sentinel object used by copyWith to distinguish null from "not provided"
const Object _sentinel = Object();
