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

part of 'note_folder.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NoteFolderAdapter extends TypeAdapter<NoteFolder> {
  @override
  final int typeId = 7;

  @override
  NoteFolder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NoteFolder(
      id: fields[0] as String?,
      name: fields[1] as String,
      description: fields[2] as String?,
      createdAt: fields[3] as DateTime?,
      updatedAt: fields[4] as DateTime?,
      isVault: fields[5] == null ? false : fields[5] as bool,
      sortOrder: fields[6] as int,
      hasPassword: fields[7] == null ? false : fields[7] as bool,
      useBiometric: fields[8] == null ? true : fields[8] as bool,
      noteFormat: fields[9] == null ? 'markdown' : fields[9] as String,
    );
  }

  @override
  void write(BinaryWriter writer, NoteFolder obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.updatedAt)
      ..writeByte(5)
      ..write(obj.isVault)
      ..writeByte(6)
      ..write(obj.sortOrder)
      ..writeByte(7)
      ..write(obj.hasPassword)
      ..writeByte(8)
      ..write(obj.useBiometric)
      ..writeByte(9)
      ..write(obj.noteFormat);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteFolderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
