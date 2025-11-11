import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'note.g.dart';

/// Represents a markdown note with metadata
@HiveType(typeId: 6)
class Note extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String content;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  DateTime updatedAt;

  @HiveField(5, defaultValue: false)
  bool isPinned;

  @HiveField(6)
  String? folderId; // Reference to folder (including vault folders)

  @HiveField(7)
  String? todoTxtContent; // Optional todo.txt format representation

  Note({
    String? id,
    required this.title,
    required this.content,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isPinned = false,
    this.folderId,
    this.todoTxtContent,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Creates a copy of this note with updated fields
  Note copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPinned,
    String? folderId,
    String? todoTxtContent,
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
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isPinned': isPinned,
      'folderId': folderId,
      'todoTxtContent': todoTxtContent,
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
    );
  }
}
