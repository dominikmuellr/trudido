// Trudido - A privacy-focused todo and notes app
// Copyright (C) 2025 Dominik Müller
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

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TodoAdapter extends TypeAdapter<Todo> {
  @override
  final int typeId = 0;

  @override
  Todo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Todo(
      id: fields[0] as String?,
      text: fields[1] as String,
      isCompleted: fields[2] as bool,
      createdAt: fields[3] as DateTime?,
      dueDate: fields[4] as DateTime?,
      startDate: fields[12] as DateTime?,
      priority: fields[5] as String,
      tags: (fields[7] as List?)?.cast<String>(),
      completedAt: fields[8] as DateTime?,
      notes: fields[9] as String?,
      folderId: fields[10] as String?,
      reminderOffsetsMinutes: (fields[11] as List?)?.cast<int>(),
      repeatType: fields[13] == null ? 'none' : fields[13] as String,
      repeatInterval: fields[14] as int?,
      repeatDays: (fields[15] as List?)?.cast<int>(),
      repeatEndDate: fields[16] as DateTime?,
      parentRecurringTaskId: fields[17] as String?,
      sourceCalendarColor: fields[18] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Todo obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.text)
      ..writeByte(2)
      ..write(obj.isCompleted)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.dueDate)
      ..writeByte(5)
      ..write(obj.priority)
      ..writeByte(7)
      ..write(obj.tags)
      ..writeByte(8)
      ..write(obj.completedAt)
      ..writeByte(9)
      ..write(obj.notes)
      ..writeByte(10)
      ..write(obj.folderId)
      ..writeByte(11)
      ..write(obj.reminderOffsetsMinutes)
      ..writeByte(12)
      ..write(obj.startDate)
      ..writeByte(13)
      ..write(obj.repeatType)
      ..writeByte(14)
      ..write(obj.repeatInterval)
      ..writeByte(15)
      ..write(obj.repeatDays)
      ..writeByte(16)
      ..write(obj.repeatEndDate)
      ..writeByte(17)
      ..write(obj.parentRecurringTaskId)
      ..writeByte(18)
      ..write(obj.sourceCalendarColor);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
