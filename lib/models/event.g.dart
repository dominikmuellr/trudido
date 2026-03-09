// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EventAdapter extends TypeAdapter<Event> {
  @override
  final int typeId = 10;

  @override
  Event read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Event(
      id: fields[0] as String?,
      text: fields[1] as String,
      isCompleted: fields[2] as bool,
      createdAt: fields[3] as DateTime?,
      startDateTime: fields[4] as DateTime,
      endDateTime: fields[5] as DateTime,
      priority: fields[6] as String,
      tags: (fields[7] as List?)?.cast<String>(),
      completedAt: fields[8] as DateTime?,
      notes: fields[9] as String?,
      folderId: fields[10] as String?,
      reminderOffsetsMinutes: (fields[11] as List?)?.cast<int>(),
      repeatType: fields[12] == null ? 'none' : fields[12] as String,
      repeatInterval: fields[13] as int?,
      repeatDays: (fields[14] as List?)?.cast<int>(),
      repeatEndDate: fields[15] as DateTime?,
      parentRecurringEventId: fields[16] as String?,
      sourceCalendarColor: fields[17] as int?,
      sourceCalendarName: fields[18] as String?,
      isDeleted: fields[19] == null ? false : fields[19] as bool,
      deletedAt: fields[20] as DateTime?,
      color: fields[21] as int?,
      uid: fields[22] == null ? '' : fields[22] as String,
      location: fields[23] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Event obj) {
    writer
      ..writeByte(24)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.text)
      ..writeByte(2)
      ..write(obj.isCompleted)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.startDateTime)
      ..writeByte(5)
      ..write(obj.endDateTime)
      ..writeByte(6)
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
      ..write(obj.repeatType)
      ..writeByte(13)
      ..write(obj.repeatInterval)
      ..writeByte(14)
      ..write(obj.repeatDays)
      ..writeByte(15)
      ..write(obj.repeatEndDate)
      ..writeByte(16)
      ..write(obj.parentRecurringEventId)
      ..writeByte(17)
      ..write(obj.sourceCalendarColor)
      ..writeByte(18)
      ..write(obj.sourceCalendarName)
      ..writeByte(19)
      ..write(obj.isDeleted)
      ..writeByte(20)
      ..write(obj.deletedAt)
      ..writeByte(21)
      ..write(obj.color)
      ..writeByte(22)
      ..write(obj.uid)
      ..writeByte(23)
      ..write(obj.location);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
