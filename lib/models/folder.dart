import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'folder.g.dart';

@HiveType(typeId: 2)
class Folder extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? description;

  @HiveField(3)
  int color; // Color value as int

  @HiveField(4)
  String? icon; // Icon name as string

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  DateTime updatedAt;

  @HiveField(7)
  int sortOrder; // For custom ordering

  @HiveField(8)
  bool isDefault; // Mark system default folders

  @HiveField(9)
  String? parentId; // For nested folders (optional feature)

  @HiveField(10, defaultValue: false)
  bool isVault; // Mark as encrypted vault folder

  Folder({
    String? id,
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
  }) : id = id ?? const Uuid().v4(),
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
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'sortOrder': sortOrder,
      'isDefault': isDefault,
      'parentId': parentId,
      'isVault': isVault,
    };
  }

  /// Create from JSON for import
  static Folder fromJson(Map<String, dynamic> json) {
    return Folder(
      id: json['id'],
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
