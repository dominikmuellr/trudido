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

part 'folder_template.g.dart';

@collection
class FolderTemplate {
  Id get isarId => fastHash(id);

  @Index(unique: true, replace: true)
  String id;

  String name;

  String? description;

  List<String> keywords; // For auto-suggestion matching

  List<TaskTemplate> taskTemplates;

  DateTime? createdAt;

  DateTime? updatedAt;

  bool isBuiltIn; // Built-in vs user-created

  bool isCustomized; // Built-in template that user modified

  String? originalTemplateId; // For tracking customized built-ins

  int useCount; // Track how often template is used

  FolderTemplate({
    String id = '',
    required this.name,
    this.description,
    required this.keywords,
    this.taskTemplates = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isBuiltIn = false,
    this.isCustomized = false,
    this.originalTemplateId,
    this.useCount = 0,
  }) : id = id.isEmpty ? const Uuid().v4() : id,
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
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
      'isBuiltIn': isBuiltIn,
      'isCustomized': isCustomized,
      'originalTemplateId': originalTemplateId,
      'useCount': useCount,
    };
  }

  /// Create from JSON for import
  static FolderTemplate fromJson(Map<String, dynamic> json) {
    return FolderTemplate(
      id: json['id'] ?? '',
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

@embedded
class TaskTemplate {
  String text;

  String priority; // high, medium, low

  List<String> tags;

  String? notes;

  int sortOrder; // Order within template

  int? dueDateOffset; // Days from folder creation

  List<int> reminderOffsets; // Reminder times in minutes

  int? estimatedMinutes; // Time estimation

  TaskTemplate({
    this.text = '',
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
