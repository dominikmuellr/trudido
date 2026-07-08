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

part 'folder.g.dart';

@collection
class Folder {
  Id get isarId => fastHash(id);

  @Index(unique: true, replace: true)
  String id;

  String name;

  String? description;

  int color; // Color value as int

  String? icon; // Icon name as string

  DateTime? createdAt;

  DateTime? updatedAt;

  int sortOrder; // For custom ordering

  bool isDefault; // Mark system default folders

  String? parentId; // For nested folders (optional feature)

  bool isVault; // Mark as encrypted vault folder

  Folder({
    String id = '',
    required this.name,
    this.description,
    required this.color,
    this.icon,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.sortOrder = 0,
    this.isDefault = false,
    this.parentId,
    this.isVault = false,
  }) : id = id.isEmpty ? const Uuid().v4() : id,
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Folder copyWith({
    String? id,
    String? name,
    String? description,
    int? color,
    String? icon,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? sortOrder,
    bool? isDefault,
    String? parentId,
    bool? isVault,
  }) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sortOrder: sortOrder ?? this.sortOrder,
      isDefault: isDefault ?? this.isDefault,
      parentId: parentId ?? this.parentId,
      isVault: isVault ?? this.isVault,
    );
  }

  @override
  String toString() {
    return 'Folder(id: $id, name: $name, description: $description, color: $color, '
        'icon: $icon, createdAt: $createdAt, updatedAt: $updatedAt, '
        'sortOrder: $sortOrder, isDefault: $isDefault, parentId: $parentId, isVault: $isVault)';
  }

  /// Convert to JSON for export
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color': color,
      'icon': icon,
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
      'sortOrder': sortOrder,
      'isDefault': isDefault,
      'parentId': parentId,
      'isVault': isVault,
    };
  }

  /// Create from JSON for import
  static Folder fromJson(Map<String, dynamic> json) {
    return Folder(
      id: json['id'] ?? '',
      name: json['name'],
      description: json['description'],
      color: json['color'],
      icon: json['icon'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      sortOrder: json['sortOrder'] ?? 0,
      isDefault: json['isDefault'] ?? false,
      parentId: json['parentId'],
      isVault: json['isVault'] ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Folder &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.color == color &&
        other.icon == icon &&
            other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.sortOrder == sortOrder &&
        other.isDefault == isDefault &&
        other.parentId == parentId &&
        other.isVault == isVault;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      description,
      color,
      icon,
      createdAt,
      updatedAt,
      sortOrder,
      isDefault,
      parentId,
      isVault,
    );
  }
}
