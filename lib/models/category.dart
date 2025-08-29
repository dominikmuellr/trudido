import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

part 'category.g.dart';

@HiveType(typeId: 1)
class Category extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String description;

  @HiveField(3)
  int colorValue;

  @HiveField(4)
  String icon;

  @HiveField(5)
  DateTime createdAt;

  Category({
    required this.id,
    required this.name,
    this.description = '',
    required this.colorValue,
    this.icon = 'folder',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Color get color => Color(colorValue);

  Category copyWith({
    String? id,
    String? name,
    String? description,
    int? colorValue,
    String? icon,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      colorValue: colorValue ?? this.colorValue,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'colorValue': colorValue,
      'icon': icon,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static Category fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      colorValue: json['colorValue'],
      icon: json['icon'] ?? 'folder',
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  @override
  String toString() {
    return 'Category(id: $id, name: $name, color: $colorValue)';
  }
}

// Predefined categories similar to your React app
class DefaultCategories {
  static final List<Category> all = [
    Category(
      id: 'personal',
      name: 'Personal',
      description: 'Personal tasks and reminders',
      colorValue: Colors.blue.toARGB32(),
      icon: 'person',
    ),
    Category(
      id: 'work',
      name: 'Work',
      description: 'Work-related tasks and projects',
      colorValue: Colors.orange.toARGB32(),
      icon: 'briefcase',
    ),
    Category(
      id: 'shopping',
      name: 'Shopping',
      description: 'Shopping lists and purchases',
      colorValue: Colors.green.toARGB32(),
      icon: 'shopping_cart',
    ),
    Category(
      id: 'health',
      name: 'Health',
      description: 'Health and fitness related tasks',
      colorValue: Colors.red.toARGB32(),
      icon: 'favorite',
    ),
    Category(
      id: 'learning',
      name: 'Learning',
      description: 'Education and skill development',
      colorValue: Colors.purple.toARGB32(),
      icon: 'school',
    ),
  ];
}
