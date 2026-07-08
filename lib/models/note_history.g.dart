// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_history.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetNoteHistoryEntryCollection on Isar {
  IsarCollection<NoteHistoryEntry> get noteHistoryEntrys => this.collection();
}

const NoteHistoryEntrySchema = CollectionSchema(
  name: r'NoteHistoryEntry',
  id: 3009175204927530824,
  properties: {
    r'contentAfter': PropertySchema(
      id: 0,
      name: r'contentAfter',
      type: IsarType.string,
    ),
    r'contentBefore': PropertySchema(
      id: 1,
      name: r'contentBefore',
      type: IsarType.string,
    ),
    r'id': PropertySchema(id: 2, name: r'id', type: IsarType.string),
    r'noteId': PropertySchema(id: 3, name: r'noteId', type: IsarType.string),
    r'timestamp': PropertySchema(
      id: 4,
      name: r'timestamp',
      type: IsarType.dateTime,
    ),
  },

  estimateSize: _noteHistoryEntryEstimateSize,
  serialize: _noteHistoryEntrySerialize,
  deserialize: _noteHistoryEntryDeserialize,
  deserializeProp: _noteHistoryEntryDeserializeProp,
  idName: r'isarId',
  indexes: {
    r'id': IndexSchema(
      id: -3268401673993471357,
      name: r'id',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'noteId': IndexSchema(
      id: -9014133502494436840,
      name: r'noteId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'noteId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _noteHistoryEntryGetId,
  getLinks: _noteHistoryEntryGetLinks,
  attach: _noteHistoryEntryAttach,
  version: '3.3.2',
);

int _noteHistoryEntryEstimateSize(
  NoteHistoryEntry object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.contentAfter;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.contentBefore;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.id.length * 3;
  bytesCount += 3 + object.noteId.length * 3;
  return bytesCount;
}

void _noteHistoryEntrySerialize(
  NoteHistoryEntry object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.contentAfter);
  writer.writeString(offsets[1], object.contentBefore);
  writer.writeString(offsets[2], object.id);
  writer.writeString(offsets[3], object.noteId);
  writer.writeDateTime(offsets[4], object.timestamp);
}

NoteHistoryEntry _noteHistoryEntryDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = NoteHistoryEntry(
    contentAfter: reader.readStringOrNull(offsets[0]),
    contentBefore: reader.readStringOrNull(offsets[1]),
    id: reader.readStringOrNull(offsets[2]) ?? '',
    noteId: reader.readString(offsets[3]),
    timestamp: reader.readDateTimeOrNull(offsets[4]),
  );
  return object;
}

P _noteHistoryEntryDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset) ?? '') as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readDateTimeOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _noteHistoryEntryGetId(NoteHistoryEntry object) {
  return object.isarId;
}

List<IsarLinkBase<dynamic>> _noteHistoryEntryGetLinks(NoteHistoryEntry object) {
  return [];
}

void _noteHistoryEntryAttach(
  IsarCollection<dynamic> col,
  Id id,
  NoteHistoryEntry object,
) {}

extension NoteHistoryEntryByIndex on IsarCollection<NoteHistoryEntry> {
  Future<NoteHistoryEntry?> getById(String id) {
    return getByIndex(r'id', [id]);
  }

  NoteHistoryEntry? getByIdSync(String id) {
    return getByIndexSync(r'id', [id]);
  }

  Future<bool> deleteById(String id) {
    return deleteByIndex(r'id', [id]);
  }

  bool deleteByIdSync(String id) {
    return deleteByIndexSync(r'id', [id]);
  }

  Future<List<NoteHistoryEntry?>> getAllById(List<String> idValues) {
    final values = idValues.map((e) => [e]).toList();
    return getAllByIndex(r'id', values);
  }

  List<NoteHistoryEntry?> getAllByIdSync(List<String> idValues) {
    final values = idValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'id', values);
  }

  Future<int> deleteAllById(List<String> idValues) {
    final values = idValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'id', values);
  }

  int deleteAllByIdSync(List<String> idValues) {
    final values = idValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'id', values);
  }

  Future<Id> putById(NoteHistoryEntry object) {
    return putByIndex(r'id', object);
  }

  Id putByIdSync(NoteHistoryEntry object, {bool saveLinks = true}) {
    return putByIndexSync(r'id', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllById(List<NoteHistoryEntry> objects) {
    return putAllByIndex(r'id', objects);
  }

  List<Id> putAllByIdSync(
    List<NoteHistoryEntry> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'id', objects, saveLinks: saveLinks);
  }
}

extension NoteHistoryEntryQueryWhereSort
    on QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QWhere> {
  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterWhere> anyIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension NoteHistoryEntryQueryWhere
    on QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QWhereClause> {
  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterWhereClause>
  isarIdEqualTo(Id isarId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: isarId, upper: isarId),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterWhereClause>
  isarIdNotEqualTo(Id isarId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: isarId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: isarId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: isarId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: isarId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterWhereClause>
  isarIdGreaterThan(Id isarId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: isarId, includeLower: include),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterWhereClause>
  isarIdLessThan(Id isarId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: isarId, includeUpper: include),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterWhereClause>
  isarIdBetween(
    Id lowerIsarId,
    Id upperIsarId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerIsarId,
          includeLower: includeLower,
          upper: upperIsarId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterWhereClause> idEqualTo(
    String id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'id', value: [id]),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterWhereClause>
  idNotEqualTo(String id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'id',
                lower: [],
                upper: [id],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'id',
                lower: [id],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'id',
                lower: [id],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'id',
                lower: [],
                upper: [id],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterWhereClause>
  noteIdEqualTo(String noteId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'noteId', value: [noteId]),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterWhereClause>
  noteIdNotEqualTo(String noteId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'noteId',
                lower: [],
                upper: [noteId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'noteId',
                lower: [noteId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'noteId',
                lower: [noteId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'noteId',
                lower: [],
                upper: [noteId],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension NoteHistoryEntryQueryFilter
    on QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QFilterCondition> {
  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  contentAfterIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'contentAfter'),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  contentAfterIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'contentAfter'),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  contentAfterEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'contentAfter',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  contentAfterGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'contentAfter',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  contentAfterLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'contentAfter',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  contentAfterBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'contentAfter',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  contentAfterStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'contentAfter',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  contentAfterEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'contentAfter',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  contentAfterContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'contentAfter',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  contentAfterMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'contentAfter',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  contentAfterIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'contentAfter', value: ''),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  contentAfterIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'contentAfter', value: ''),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  contentBeforeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'contentBefore'),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  contentBeforeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'contentBefore'),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  contentBeforeEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'contentBefore',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  contentBeforeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'contentBefore',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  contentBeforeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'contentBefore',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  contentBeforeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'contentBefore',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  contentBeforeStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'contentBefore',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  contentBeforeEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'contentBefore',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  contentBeforeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'contentBefore',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  contentBeforeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'contentBefore',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  contentBeforeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'contentBefore', value: ''),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  contentBeforeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'contentBefore', value: ''),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  idEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  idGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  idLessThan(String value, {bool include = false, bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  idBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  idStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  idEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  idContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  idMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  idIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: ''),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  idIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'id', value: ''),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  isarIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isarId', value: value),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  isarIdGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'isarId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  isarIdLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'isarId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  isarIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'isarId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  noteIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'noteId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  noteIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'noteId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  noteIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'noteId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  noteIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'noteId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  noteIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'noteId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  noteIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'noteId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  noteIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'noteId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  noteIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'noteId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  noteIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'noteId', value: ''),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  noteIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'noteId', value: ''),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  timestampIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'timestamp'),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  timestampIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'timestamp'),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  timestampEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'timestamp', value: value),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  timestampGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'timestamp',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  timestampLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'timestamp',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterFilterCondition>
  timestampBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'timestamp',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension NoteHistoryEntryQueryObject
    on QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QFilterCondition> {}

extension NoteHistoryEntryQueryLinks
    on QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QFilterCondition> {}

extension NoteHistoryEntryQuerySortBy
    on QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QSortBy> {
  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterSortBy>
  sortByContentAfter() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentAfter', Sort.asc);
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterSortBy>
  sortByContentAfterDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentAfter', Sort.desc);
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterSortBy>
  sortByContentBefore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentBefore', Sort.asc);
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterSortBy>
  sortByContentBeforeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentBefore', Sort.desc);
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterSortBy>
  sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterSortBy>
  sortByNoteId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'noteId', Sort.asc);
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterSortBy>
  sortByNoteIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'noteId', Sort.desc);
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterSortBy>
  sortByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterSortBy>
  sortByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }
}

extension NoteHistoryEntryQuerySortThenBy
    on QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QSortThenBy> {
  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterSortBy>
  thenByContentAfter() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentAfter', Sort.asc);
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterSortBy>
  thenByContentAfterDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentAfter', Sort.desc);
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterSortBy>
  thenByContentBefore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentBefore', Sort.asc);
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterSortBy>
  thenByContentBeforeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentBefore', Sort.desc);
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterSortBy>
  thenByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.asc);
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterSortBy>
  thenByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.desc);
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterSortBy>
  thenByNoteId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'noteId', Sort.asc);
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterSortBy>
  thenByNoteIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'noteId', Sort.desc);
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterSortBy>
  thenByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QAfterSortBy>
  thenByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }
}

extension NoteHistoryEntryQueryWhereDistinct
    on QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QDistinct> {
  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QDistinct>
  distinctByContentAfter({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'contentAfter', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QDistinct>
  distinctByContentBefore({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'contentBefore',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QDistinct> distinctById({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QDistinct> distinctByNoteId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'noteId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QDistinct>
  distinctByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timestamp');
    });
  }
}

extension NoteHistoryEntryQueryProperty
    on QueryBuilder<NoteHistoryEntry, NoteHistoryEntry, QQueryProperty> {
  QueryBuilder<NoteHistoryEntry, int, QQueryOperations> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isarId');
    });
  }

  QueryBuilder<NoteHistoryEntry, String?, QQueryOperations>
  contentAfterProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'contentAfter');
    });
  }

  QueryBuilder<NoteHistoryEntry, String?, QQueryOperations>
  contentBeforeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'contentBefore');
    });
  }

  QueryBuilder<NoteHistoryEntry, String, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<NoteHistoryEntry, String, QQueryOperations> noteIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'noteId');
    });
  }

  QueryBuilder<NoteHistoryEntry, DateTime?, QQueryOperations>
  timestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timestamp');
    });
  }
}
