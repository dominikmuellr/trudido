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

part 'note_folder.g.dart';

/// Folder model specifically for organizing notes (separate from todo folders)
@collection
class NoteFolder {
  Id get isarId => fastHash(id);

  @Index(unique: true, replace: true)
  String id;

  String name;

  String? description;

  DateTime? createdAt;

  DateTime? updatedAt;

  bool isVault; // Encrypted vault folder flag

  int sortOrder; // For custom ordering

  bool hasPassword; // Whether vault has a password/PIN set

  bool useBiometric; // Whether to use biometric shortcut (if available)

  String noteFormat; // 'markdown' or 'todotxt' - format for all notes in this folder

  int color; // Color value used for folder tinting in notes UI

  NoteFolder({
    String id = '',
    required this.name,
    this.description,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isVault = false,
    this.sortOrder = 0,
    this.hasPassword = false,
    this.useBiometric = true,
    this.noteFormat = 'markdown',
    this.color = 0xFF2196F3,
  }) : id = id.isEmpty ? const Uuid().v4() : id,
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  NoteFolder copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isVault,
    int? sortOrder,
    bool? hasPassword,
    bool? useBiometric,
    String? noteFormat,
    int? color,
  }) {
    return NoteFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isVault: isVault ?? this.isVault,
      sortOrder: sortOrder ?? this.sortOrder,
      hasPassword: hasPassword ?? this.hasPassword,
      useBiometric: useBiometric ?? this.useBiometric,
      noteFormat: noteFormat ?? this.noteFormat,
      color: color ?? this.color,
    );
  }

  @override
  String toString() {
    return 'NoteFolder(id: $id, name: $name, isVault: $isVault, color: $color)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NoteFolder && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
      'isVault': isVault,
      'sortOrder': sortOrder,
      'hasPassword': hasPassword,
      'useBiometric': useBiometric,
      'noteFormat': noteFormat,
      'color': color,
    };
  }

  factory NoteFolder.fromJson(Map<String, dynamic> json) {
    return NoteFolder(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isVault: json['isVault'] as bool? ?? false,
      sortOrder: json['sortOrder'] as int? ?? 0,
      hasPassword: json['hasPassword'] as bool? ?? false,
      useBiometric: json['useBiometric'] as bool? ?? true,
      noteFormat: json['noteFormat'] as String? ?? 'markdown',
      color: json['color'] as int? ?? 0xFF2196F3,
    );
  }
}
