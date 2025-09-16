import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'todo.g.dart';

@HiveType(typeId: 0)
class Todo extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String text;

  @HiveField(2)
  bool isCompleted;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  DateTime? dueDate;

  @HiveField(5)
  String priority;

  @HiveField(7)
  List<String> tags;

  @HiveField(8)
  DateTime? completedAt;

  @HiveField(9)
  String? notes;

  @HiveField(10)
  String? folderId; // Reference to folder

  @HiveField(11)
  List<int> reminderOffsetsMinutes; // A list of offsets in minutes

  @HiveField(12)
  DateTime? startDate; // Optional start for multi-day span (end = dueDate)

  Todo({
    String? id,
    required this.text,
    this.isCompleted = false,
    DateTime? createdAt,
    this.dueDate,
  this.startDate,
    this.priority = 'medium',
    List<String>? tags,
    this.completedAt,
    this.notes,
    this.folderId,
    List<int>? reminderOffsetsMinutes,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        tags = tags ?? [],
        reminderOffsetsMinutes = reminderOffsetsMinutes ?? [];

  // Copy with method for immutable updates
  Todo copyWith({
    String? id,
    String? text,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? dueDate,
    DateTime? startDate,
    String? priority,
    List<String>? tags,
    DateTime? completedAt,
    String? notes,
    String? folderId,
    List<int>? reminderOffsetsMinutes,
  }) {
    return Todo(
      id: id ?? this.id,
      text: text ?? this.text,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      startDate: startDate ?? this.startDate,
      priority: priority ?? this.priority,
      tags: tags ?? this.tags,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
      folderId: folderId ?? this.folderId,
      reminderOffsetsMinutes: reminderOffsetsMinutes ?? this.reminderOffsetsMinutes,
    );
  }

  // Convert to/from JSON for potential future use
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
  'startDate': startDate?.toIso8601String(),
      'priority': priority,
      'tags': tags,
      'completedAt': completedAt?.toIso8601String(),
      'notes': notes,
      'folderId': folderId,
      'reminderOffsetsMinutes': reminderOffsetsMinutes,
    };
  }

  static Todo fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'],
      text: json['text'],
      isCompleted: json['isCompleted'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
  startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      priority: json['priority'] ?? 'medium',
      tags: List<String>.from(json['tags'] ?? []),
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
      notes: json['notes'],
      folderId: json['folderId'],
      reminderOffsetsMinutes: List<int>.from(json['reminderOffsetsMinutes'] ?? []),
    );
  }

  // Helper methods
  bool get isOverdue {
    if (dueDate == null || isCompleted) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  bool get isSpan => startDate != null && dueDate != null && !dueDate!.isBefore(startDate!);

  bool activeOn(DateTime day) {
    if (!isSpan) return isDueOn(day);
    final s = DateTime(startDate!.year, startDate!.month, startDate!.day);
    final e = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final d = DateTime(day.year, day.month, day.day);
    return (d.isAtSameMomentAs(s) || d.isAfter(s)) && (d.isAtSameMomentAs(e) || d.isBefore(e));
  }

  bool isDueOn(DateTime day) {
    if (dueDate == null) return false;
    final d = dueDate!;
    return d.year == day.year && d.month == day.month && d.day == day.day;
  }

  bool get isDueToday {
    if (dueDate == null) return false;
    final now = DateTime.now();
    final due = dueDate!;
    return now.year == due.year && now.month == due.month && now.day == due.day;
  }

  bool get isDueSoon {
    if (dueDate == null || isCompleted) return false;
    final now = DateTime.now();
    final difference = dueDate!.difference(now).inDays;
    return difference >= 0 && difference <= 3;
  }

  @override
  String toString() {
    return 'Todo(id: $id, text: $text, isCompleted: $isCompleted, priority: $priority, folderId: $folderId)';
  }
}
