import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'note_folder.g.dart';

/// Folder model specifically for organizing notes (separate from todo folders)
@HiveType(typeId: 7) // Using typeId 7 for note folders
class NoteFolder extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? description;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  DateTime updatedAt;

  @HiveField(5, defaultValue: false)
  bool isVault; // Encrypted vault folder flag

  @HiveField(6)
  int sortOrder; // For custom ordering

  @HiveField(7, defaultValue: false)
  bool hasPassword; // Whether vault has a password/PIN set

  @HiveField(8, defaultValue: true)
  bool useBiometric; // Whether to use biometric shortcut (if available)

  @HiveField(9, defaultValue: 'markdown')
  String noteFormat; // 'markdown' or 'todotxt' - format for all notes in this folder

  NoteFolder({
    String? id,
    required this.name,
    this.description,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isVault = false,
    this.sortOrder = 0,
    this.hasPassword = false,
    this.useBiometric = true,
    this.noteFormat = 'markdown',
  }) : id = id ?? const Uuid().v4(),
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
    );
  }

  @override
  String toString() {
    return 'NoteFolder(id: $id, name: $name, isVault: $isVault)';
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
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isVault': isVault,
      'sortOrder': sortOrder,
      'hasPassword': hasPassword,
      'useBiometric': useBiometric,
      'noteFormat': noteFormat,
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
    );
  }
}
