import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'folder_template.g.dart';

@HiveType(typeId: 4)
class FolderTemplate extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? description;

  @HiveField(3)
  List<String> keywords; // For auto-suggestion matching

  @HiveField(4)
  List<TaskTemplate> taskTemplates;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  DateTime updatedAt;

  @HiveField(7)
  bool isBuiltIn; // Built-in vs user-created

  @HiveField(8)
  bool isCustomized; // Built-in template that user modified

  @HiveField(9)
  String? originalTemplateId; // For tracking customized built-ins

  @HiveField(10)
  int useCount; // Track how often template is used

  FolderTemplate({
    String? id,
    required this.name,
    this.description,
    required this.keywords,
    required this.taskTemplates,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isBuiltIn = false,
    this.isCustomized = false,
    this.originalTemplateId,
    this.useCount = 0,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  FolderTemplate copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? keywords,
    List<TaskTemplate>? taskTemplates,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isBuiltIn,
    bool? isCustomized,
    String? originalTemplateId,
    int? useCount,
  }) {
    return FolderTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      keywords: keywords ?? this.keywords,
      taskTemplates: taskTemplates ?? this.taskTemplates,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      isCustomized: isCustomized ?? this.isCustomized,
      originalTemplateId: originalTemplateId ?? this.originalTemplateId,
      useCount: useCount ?? this.useCount,
    );
  }

  @override
  String toString() {
    return 'FolderTemplate(id: $id, name: $name, taskCount: ${taskTemplates.length}, useCount: $useCount)';
  }

  /// Convert to JSON for export
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'keywords': keywords,
      'taskTemplates': taskTemplates.map((t) => t.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isBuiltIn': isBuiltIn,
      'isCustomized': isCustomized,
      'originalTemplateId': originalTemplateId,
      'useCount': useCount,
    };
  }

  /// Create from JSON for import
  static FolderTemplate fromJson(Map<String, dynamic> json) {
    return FolderTemplate(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      keywords: List<String>.from(json['keywords'] ?? []),
      taskTemplates:
          (json['taskTemplates'] as List?)
              ?.map((t) => TaskTemplate.fromJson(t))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      isBuiltIn: json['isBuiltIn'] ?? false,
      isCustomized: json['isCustomized'] ?? false,
      originalTemplateId: json['originalTemplateId'],
      useCount: json['useCount'] ?? 0,
    );
  }
}

@HiveType(typeId: 5)
class TaskTemplate extends HiveObject {
  @HiveField(0)
  String text;

  @HiveField(1)
  String priority; // high, medium, low

  @HiveField(3)
  List<String> tags;

  @HiveField(4)
  String? notes;

  @HiveField(5)
  int sortOrder; // Order within template

  @HiveField(6)
  int? dueDateOffset; // Days from folder creation

  @HiveField(7)
  List<int> reminderOffsets; // Reminder times in minutes

  @HiveField(8)
  int? estimatedMinutes; // Time estimation

  TaskTemplate({
    required this.text,
    this.priority = 'medium',
    this.tags = const [],
    this.notes,
    this.sortOrder = 0,
    this.dueDateOffset,
    this.reminderOffsets = const [],
    this.estimatedMinutes,
  });

  TaskTemplate copyWith({
    String? text,
    String? priority,
    List<String>? tags,
    String? notes,
    int? sortOrder,
    int? dueDateOffset,
    List<int>? reminderOffsets,
    int? estimatedMinutes,
  }) {
    return TaskTemplate(
      text: text ?? this.text,
      priority: priority ?? this.priority,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
      sortOrder: sortOrder ?? this.sortOrder,
      dueDateOffset: dueDateOffset ?? this.dueDateOffset,
      reminderOffsets: reminderOffsets ?? this.reminderOffsets,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
    );
  }

  @override
  String toString() {
    return 'TaskTemplate(text: $text, priority: $priority, order: $sortOrder)';
  }

  /// Convert to JSON for export
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'priority': priority,
      'tags': tags,
      'notes': notes,
      'sortOrder': sortOrder,
      'dueDateOffset': dueDateOffset,
      'reminderOffsets': reminderOffsets,
      'estimatedMinutes': estimatedMinutes,
    };
  }

  /// Create from JSON for import
  static TaskTemplate fromJson(Map<String, dynamic> json) {
    return TaskTemplate(
      text: json['text'],
      priority: json['priority'] ?? 'medium',
      tags: List<String>.from(json['tags'] ?? []),
      notes: json['notes'],
      sortOrder: json['sortOrder'] ?? 0,
      dueDateOffset: json['dueDateOffset'],
      reminderOffsets: List<int>.from(json['reminderOffsets'] ?? []),
      estimatedMinutes: json['estimatedMinutes'],
    );
  }
}
