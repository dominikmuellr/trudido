// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'folder_template.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FolderTemplateAdapter extends TypeAdapter<FolderTemplate> {
  @override
  final int typeId = 4;

  @override
  FolderTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FolderTemplate(
      id: fields[0] as String?,
      name: fields[1] as String,
      description: fields[2] as String?,
      keywords: (fields[3] as List).cast<String>(),
      taskTemplates: (fields[4] as List).cast<TaskTemplate>(),
      createdAt: fields[5] as DateTime?,
      updatedAt: fields[6] as DateTime?,
      isBuiltIn: fields[7] as bool,
      isCustomized: fields[8] as bool,
      originalTemplateId: fields[9] as String?,
      useCount: fields[10] as int,
    );
  }

  @override
  void write(BinaryWriter writer, FolderTemplate obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.keywords)
      ..writeByte(4)
      ..write(obj.taskTemplates)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.updatedAt)
      ..writeByte(7)
      ..write(obj.isBuiltIn)
      ..writeByte(8)
      ..write(obj.isCustomized)
      ..writeByte(9)
      ..write(obj.originalTemplateId)
      ..writeByte(10)
      ..write(obj.useCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FolderTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TaskTemplateAdapter extends TypeAdapter<TaskTemplate> {
  @override
  final int typeId = 5;

  @override
  TaskTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaskTemplate(
      text: fields[0] as String,
      priority: fields[1] as String,
      tags: (fields[3] as List).cast<String>(),
      notes: fields[4] as String?,
      sortOrder: fields[5] as int,
      dueDateOffset: fields[6] as int?,
      reminderOffsets: (fields[7] as List).cast<int>(),
      estimatedMinutes: fields[8] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, TaskTemplate obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.text)
      ..writeByte(1)
      ..write(obj.priority)
      ..writeByte(3)
      ..write(obj.tags)
      ..writeByte(4)
      ..write(obj.notes)
      ..writeByte(5)
      ..write(obj.sortOrder)
      ..writeByte(6)
      ..write(obj.dueDateOffset)
      ..writeByte(7)
      ..write(obj.reminderOffsets)
      ..writeByte(8)
      ..write(obj.estimatedMinutes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
