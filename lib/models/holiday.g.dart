// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'holiday.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HolidayAdapter extends TypeAdapter<Holiday> {
  @override
  final int typeId = 8;

  @override
  Holiday read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Holiday(
      id: fields[0] as String?,
      name: fields[1] as String,
      date: fields[2] as DateTime,
      description: fields[3] == null ? '' : fields[3] as String,
      sourceCalendar: fields[4] as String,
      isHidden: fields[5] == null ? false : fields[5] as bool,
      endDate: fields[6] as DateTime?,
      uid: fields[7] == null ? '' : fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Holiday obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.sourceCalendar)
      ..writeByte(5)
      ..write(obj.isHidden)
      ..writeByte(6)
      ..write(obj.endDate)
      ..writeByte(7)
      ..write(obj.uid);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HolidayAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
