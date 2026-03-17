// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_history.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NoteHistoryEntryAdapter extends TypeAdapter<NoteHistoryEntry> {
  @override
  final int typeId = 9;

  @override
  NoteHistoryEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NoteHistoryEntry(
      id: fields[0] as String?,
      noteId: fields[1] as String,
      contentBefore: fields[2] as String?,
      contentAfter: fields[3] as String?,
      timestamp: fields[4] as DateTime?,
      // fields[5] (parentEntryId) and fields[6] (branchLabel) are intentionally
      // ignored - branching was removed. Old entries with these fields are
      // read safely and the values discarded.
    );
  }

  @override
  void write(BinaryWriter writer, NoteHistoryEntry obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.noteId)
      ..writeByte(2)
      ..write(obj.contentBefore)
      ..writeByte(3)
      ..write(obj.contentAfter)
      ..writeByte(4)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteHistoryEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
