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

  @HiveField(13, defaultValue: 'none')
  String repeatType; // 'none', 'daily', 'weekly', 'monthly', 'custom'

  @HiveField(14)
  int? repeatInterval; // e.g., every 2 days/weeks/months (for custom)

  @HiveField(15)
  List<int>? repeatDays; // e.g., [1, 3, 5] for Mon/Wed/Fri (1=Mon, 7=Sun)

  @HiveField(16)
  DateTime? repeatEndDate; // Optional: when recurrence stops

  @HiveField(17)
  String? parentRecurringTaskId; // Reference to the original recurring task

  @HiveField(18)
  int? sourceCalendarColor; // Color of the calendar this task was imported from

  Todo({
    String? id,
    required this.text,
    this.isCompleted = false,
    DateTime? createdAt,
    this.dueDate,
    this.startDate,
    this.priority = 'none',
    List<String>? tags,
    this.completedAt,
    this.notes,
    this.folderId,
    List<int>? reminderOffsetsMinutes,
    this.repeatType = 'none',
    this.repeatInterval,
    this.repeatDays,
    this.repeatEndDate,
    this.parentRecurringTaskId,
    this.sourceCalendarColor,
  }) : id = id ?? const Uuid().v4(),
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
    String? repeatType,
    int? repeatInterval,
    List<int>? repeatDays,
    DateTime? repeatEndDate,
    String? parentRecurringTaskId,
    int? sourceCalendarColor,
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
      reminderOffsetsMinutes:
          reminderOffsetsMinutes ?? this.reminderOffsetsMinutes,
      repeatType: repeatType ?? this.repeatType,
      repeatInterval: repeatInterval ?? this.repeatInterval,
      repeatDays: repeatDays ?? this.repeatDays,
      repeatEndDate: repeatEndDate ?? this.repeatEndDate,
      parentRecurringTaskId:
          parentRecurringTaskId ?? this.parentRecurringTaskId,
      sourceCalendarColor: sourceCalendarColor ?? this.sourceCalendarColor,
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
      'repeatType': repeatType,
      'repeatInterval': repeatInterval,
      'repeatDays': repeatDays,
      'repeatEndDate': repeatEndDate?.toIso8601String(),
      'parentRecurringTaskId': parentRecurringTaskId,
      'sourceCalendarColor': sourceCalendarColor,
    };
  }

  static Todo fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'],
      text: json['text'],
      isCompleted: json['isCompleted'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'])
          : null,
      priority: json['priority'] ?? 'medium',
      tags: List<String>.from(json['tags'] ?? []),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      notes: json['notes'],
      folderId: json['folderId'],
      reminderOffsetsMinutes: List<int>.from(
        json['reminderOffsetsMinutes'] ?? [],
      ),
      repeatType: json['repeatType'] ?? 'none',
      repeatInterval: json['repeatInterval'],
      repeatDays: json['repeatDays'] != null
          ? List<int>.from(json['repeatDays'])
          : null,
      repeatEndDate: json['repeatEndDate'] != null
          ? DateTime.parse(json['repeatEndDate'])
          : null,
      parentRecurringTaskId: json['parentRecurringTaskId'],
      sourceCalendarColor: json['sourceCalendarColor'],
    );
  }

  // Helper methods

  /// Checks if the task is overdue based on the provided time.
  ///
  /// [now] - The current time to compare against (defaults to DateTime.now())
  bool isOverdueAt([DateTime? now]) {
    if (dueDate == null || isCompleted) return false;
    final currentTime = now ?? DateTime.now();
    return currentTime.isAfter(dueDate!);
  }

  /// Legacy getter for backward compatibility. Prefer isOverdueAt() for testability.
  bool get isOverdue => isOverdueAt();

  bool get isSpan =>
      startDate != null && dueDate != null && !dueDate!.isBefore(startDate!);

  bool activeOn(DateTime day) {
    if (!isSpan) return isDueOn(day);
    final s = DateTime(startDate!.year, startDate!.month, startDate!.day);
    final e = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final d = DateTime(day.year, day.month, day.day);
    return (d.isAtSameMomentAs(s) || d.isAfter(s)) &&
        (d.isAtSameMomentAs(e) || d.isBefore(e));
  }

  bool isDueOn(DateTime day) {
    if (dueDate == null) return false;
    final d = dueDate!;
    return d.year == day.year && d.month == day.month && d.day == day.day;
  }

  /// Checks if the task is due today based on the provided time.
  ///
  /// [now] - The current time to compare against (defaults to DateTime.now())
  bool isDueTodayAt([DateTime? now]) {
    if (dueDate == null) return false;
    final currentTime = now ?? DateTime.now();
    final due = dueDate!;
    return currentTime.year == due.year &&
        currentTime.month == due.month &&
        currentTime.day == due.day;
  }

  /// Legacy getter for backward compatibility. Prefer isDueTodayAt() for testability.
  bool get isDueToday => isDueTodayAt();

  /// Checks if the task is due soon (within 3 days) based on the provided time.
  ///
  /// [now] - The current time to compare against (defaults to DateTime.now())
  bool isDueSoonAt([DateTime? now]) {
    if (dueDate == null || isCompleted) return false;
    final currentTime = now ?? DateTime.now();
    final difference = dueDate!.difference(currentTime).inDays;
    return difference >= 0 && difference <= 3;
  }

  /// Legacy getter for backward compatibility. Prefer isDueSoonAt() for testability.
  bool get isDueSoon => isDueSoonAt();

  // Check if this task is recurring
  bool get isRecurring => repeatType != 'none';

  @override
  String toString() {
    return 'Todo(id: $id, text: $text, isCompleted: $isCompleted, priority: $priority, folderId: $folderId, repeatType: $repeatType)';
  }
}
