// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dropdown_options.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMaritalStatusOptionCollection on Isar {
  IsarCollection<MaritalStatusOption> get maritalStatusOptions =>
      this.collection();
}

const MaritalStatusOptionSchema = CollectionSchema(
  name: r'MaritalStatusOption',
  id: -851899765713777984,
  properties: {
    r'accountKey': PropertySchema(
      id: 0,
      name: r'accountKey',
      type: IsarType.string,
    ),
    r'label': PropertySchema(id: 1, name: r'label', type: IsarType.string),
    r'value': PropertySchema(id: 2, name: r'value', type: IsarType.string),
  },

  estimateSize: _maritalStatusOptionEstimateSize,
  serialize: _maritalStatusOptionSerialize,
  deserialize: _maritalStatusOptionDeserialize,
  deserializeProp: _maritalStatusOptionDeserializeProp,
  idName: r'id',
  indexes: {
    r'value_accountKey': IndexSchema(
      id: 1133278974822809210,
      name: r'value_accountKey',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'value',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'accountKey',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _maritalStatusOptionGetId,
  getLinks: _maritalStatusOptionGetLinks,
  attach: _maritalStatusOptionAttach,
  version: '3.3.0',
);

int _maritalStatusOptionEstimateSize(
  MaritalStatusOption object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.accountKey.length * 3;
  bytesCount += 3 + object.label.length * 3;
  bytesCount += 3 + object.value.length * 3;
  return bytesCount;
}

void _maritalStatusOptionSerialize(
  MaritalStatusOption object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.accountKey);
  writer.writeString(offsets[1], object.label);
  writer.writeString(offsets[2], object.value);
}

MaritalStatusOption _maritalStatusOptionDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = MaritalStatusOption();
  object.accountKey = reader.readString(offsets[0]);
  object.id = id;
  object.label = reader.readString(offsets[1]);
  object.value = reader.readString(offsets[2]);
  return object;
}

P _maritalStatusOptionDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _maritalStatusOptionGetId(MaritalStatusOption object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _maritalStatusOptionGetLinks(
  MaritalStatusOption object,
) {
  return [];
}

void _maritalStatusOptionAttach(
  IsarCollection<dynamic> col,
  Id id,
  MaritalStatusOption object,
) {
  object.id = id;
}

extension MaritalStatusOptionByIndex on IsarCollection<MaritalStatusOption> {
  Future<MaritalStatusOption?> getByValueAccountKey(
    String value,
    String accountKey,
  ) {
    return getByIndex(r'value_accountKey', [value, accountKey]);
  }

  MaritalStatusOption? getByValueAccountKeySync(
    String value,
    String accountKey,
  ) {
    return getByIndexSync(r'value_accountKey', [value, accountKey]);
  }

  Future<bool> deleteByValueAccountKey(String value, String accountKey) {
    return deleteByIndex(r'value_accountKey', [value, accountKey]);
  }

  bool deleteByValueAccountKeySync(String value, String accountKey) {
    return deleteByIndexSync(r'value_accountKey', [value, accountKey]);
  }

  Future<List<MaritalStatusOption?>> getAllByValueAccountKey(
    List<String> valueValues,
    List<String> accountKeyValues,
  ) {
    final len = valueValues.length;
    assert(
      accountKeyValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([valueValues[i], accountKeyValues[i]]);
    }

    return getAllByIndex(r'value_accountKey', values);
  }

  List<MaritalStatusOption?> getAllByValueAccountKeySync(
    List<String> valueValues,
    List<String> accountKeyValues,
  ) {
    final len = valueValues.length;
    assert(
      accountKeyValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([valueValues[i], accountKeyValues[i]]);
    }

    return getAllByIndexSync(r'value_accountKey', values);
  }

  Future<int> deleteAllByValueAccountKey(
    List<String> valueValues,
    List<String> accountKeyValues,
  ) {
    final len = valueValues.length;
    assert(
      accountKeyValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([valueValues[i], accountKeyValues[i]]);
    }

    return deleteAllByIndex(r'value_accountKey', values);
  }

  int deleteAllByValueAccountKeySync(
    List<String> valueValues,
    List<String> accountKeyValues,
  ) {
    final len = valueValues.length;
    assert(
      accountKeyValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([valueValues[i], accountKeyValues[i]]);
    }

    return deleteAllByIndexSync(r'value_accountKey', values);
  }

  Future<Id> putByValueAccountKey(MaritalStatusOption object) {
    return putByIndex(r'value_accountKey', object);
  }

  Id putByValueAccountKeySync(
    MaritalStatusOption object, {
    bool saveLinks = true,
  }) {
    return putByIndexSync(r'value_accountKey', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByValueAccountKey(List<MaritalStatusOption> objects) {
    return putAllByIndex(r'value_accountKey', objects);
  }

  List<Id> putAllByValueAccountKeySync(
    List<MaritalStatusOption> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'value_accountKey',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension MaritalStatusOptionQueryWhereSort
    on QueryBuilder<MaritalStatusOption, MaritalStatusOption, QWhere> {
  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension MaritalStatusOptionQueryWhere
    on QueryBuilder<MaritalStatusOption, MaritalStatusOption, QWhereClause> {
  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterWhereClause>
  idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterWhereClause>
  idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterWhereClause>
  valueEqualToAnyAccountKey(String value) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'value_accountKey',
          value: [value],
        ),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterWhereClause>
  valueNotEqualToAnyAccountKey(String value) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'value_accountKey',
                lower: [],
                upper: [value],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'value_accountKey',
                lower: [value],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'value_accountKey',
                lower: [value],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'value_accountKey',
                lower: [],
                upper: [value],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterWhereClause>
  valueAccountKeyEqualTo(String value, String accountKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'value_accountKey',
          value: [value, accountKey],
        ),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterWhereClause>
  valueEqualToAccountKeyNotEqualTo(String value, String accountKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'value_accountKey',
                lower: [value],
                upper: [value, accountKey],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'value_accountKey',
                lower: [value, accountKey],
                includeLower: false,
                upper: [value],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'value_accountKey',
                lower: [value, accountKey],
                includeLower: false,
                upper: [value],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'value_accountKey',
                lower: [value],
                upper: [value, accountKey],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension MaritalStatusOptionQueryFilter
    on
        QueryBuilder<
          MaritalStatusOption,
          MaritalStatusOption,
          QFilterCondition
        > {
  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  accountKeyEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'accountKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  accountKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'accountKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  accountKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'accountKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  accountKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'accountKey',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  accountKeyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'accountKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  accountKeyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'accountKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  accountKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'accountKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  accountKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'accountKey',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  accountKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'accountKey', value: ''),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  accountKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'accountKey', value: ''),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  labelEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'label',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  labelGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'label',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  labelLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'label',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  labelBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'label',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  labelStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'label',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  labelEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'label',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  labelContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'label',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  labelMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'label',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  labelIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'label', value: ''),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  labelIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'label', value: ''),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  valueEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'value',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  valueGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'value',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  valueLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'value',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  valueBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'value',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  valueStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'value',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  valueEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'value',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  valueContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'value',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  valueMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'value',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  valueIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'value', value: ''),
      );
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterFilterCondition>
  valueIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'value', value: ''),
      );
    });
  }
}

extension MaritalStatusOptionQueryObject
    on
        QueryBuilder<
          MaritalStatusOption,
          MaritalStatusOption,
          QFilterCondition
        > {}

extension MaritalStatusOptionQueryLinks
    on
        QueryBuilder<
          MaritalStatusOption,
          MaritalStatusOption,
          QFilterCondition
        > {}

extension MaritalStatusOptionQuerySortBy
    on QueryBuilder<MaritalStatusOption, MaritalStatusOption, QSortBy> {
  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterSortBy>
  sortByAccountKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountKey', Sort.asc);
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterSortBy>
  sortByAccountKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountKey', Sort.desc);
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterSortBy>
  sortByLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.asc);
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterSortBy>
  sortByLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.desc);
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterSortBy>
  sortByValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'value', Sort.asc);
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterSortBy>
  sortByValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'value', Sort.desc);
    });
  }
}

extension MaritalStatusOptionQuerySortThenBy
    on QueryBuilder<MaritalStatusOption, MaritalStatusOption, QSortThenBy> {
  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterSortBy>
  thenByAccountKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountKey', Sort.asc);
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterSortBy>
  thenByAccountKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountKey', Sort.desc);
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterSortBy>
  thenByLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.asc);
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterSortBy>
  thenByLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.desc);
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterSortBy>
  thenByValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'value', Sort.asc);
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QAfterSortBy>
  thenByValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'value', Sort.desc);
    });
  }
}

extension MaritalStatusOptionQueryWhereDistinct
    on QueryBuilder<MaritalStatusOption, MaritalStatusOption, QDistinct> {
  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QDistinct>
  distinctByAccountKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'accountKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QDistinct>
  distinctByLabel({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'label', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MaritalStatusOption, MaritalStatusOption, QDistinct>
  distinctByValue({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'value', caseSensitive: caseSensitive);
    });
  }
}

extension MaritalStatusOptionQueryProperty
    on QueryBuilder<MaritalStatusOption, MaritalStatusOption, QQueryProperty> {
  QueryBuilder<MaritalStatusOption, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<MaritalStatusOption, String, QQueryOperations>
  accountKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'accountKey');
    });
  }

  QueryBuilder<MaritalStatusOption, String, QQueryOperations> labelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'label');
    });
  }

  QueryBuilder<MaritalStatusOption, String, QQueryOperations> valueProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'value');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetTimezoneOptionCollection on Isar {
  IsarCollection<TimezoneOption> get timezoneOptions => this.collection();
}

const TimezoneOptionSchema = CollectionSchema(
  name: r'TimezoneOption',
  id: -7103708088976468801,
  properties: {
    r'accountKey': PropertySchema(
      id: 0,
      name: r'accountKey',
      type: IsarType.string,
    ),
    r'label': PropertySchema(id: 1, name: r'label', type: IsarType.string),
    r'value': PropertySchema(id: 2, name: r'value', type: IsarType.string),
  },

  estimateSize: _timezoneOptionEstimateSize,
  serialize: _timezoneOptionSerialize,
  deserialize: _timezoneOptionDeserialize,
  deserializeProp: _timezoneOptionDeserializeProp,
  idName: r'id',
  indexes: {
    r'value_accountKey': IndexSchema(
      id: 1133278974822809210,
      name: r'value_accountKey',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'value',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'accountKey',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _timezoneOptionGetId,
  getLinks: _timezoneOptionGetLinks,
  attach: _timezoneOptionAttach,
  version: '3.3.0',
);

int _timezoneOptionEstimateSize(
  TimezoneOption object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.accountKey.length * 3;
  bytesCount += 3 + object.label.length * 3;
  bytesCount += 3 + object.value.length * 3;
  return bytesCount;
}

void _timezoneOptionSerialize(
  TimezoneOption object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.accountKey);
  writer.writeString(offsets[1], object.label);
  writer.writeString(offsets[2], object.value);
}

TimezoneOption _timezoneOptionDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = TimezoneOption();
  object.accountKey = reader.readString(offsets[0]);
  object.id = id;
  object.label = reader.readString(offsets[1]);
  object.value = reader.readString(offsets[2]);
  return object;
}

P _timezoneOptionDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _timezoneOptionGetId(TimezoneOption object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _timezoneOptionGetLinks(TimezoneOption object) {
  return [];
}

void _timezoneOptionAttach(
  IsarCollection<dynamic> col,
  Id id,
  TimezoneOption object,
) {
  object.id = id;
}

extension TimezoneOptionByIndex on IsarCollection<TimezoneOption> {
  Future<TimezoneOption?> getByValueAccountKey(
    String value,
    String accountKey,
  ) {
    return getByIndex(r'value_accountKey', [value, accountKey]);
  }

  TimezoneOption? getByValueAccountKeySync(String value, String accountKey) {
    return getByIndexSync(r'value_accountKey', [value, accountKey]);
  }

  Future<bool> deleteByValueAccountKey(String value, String accountKey) {
    return deleteByIndex(r'value_accountKey', [value, accountKey]);
  }

  bool deleteByValueAccountKeySync(String value, String accountKey) {
    return deleteByIndexSync(r'value_accountKey', [value, accountKey]);
  }

  Future<List<TimezoneOption?>> getAllByValueAccountKey(
    List<String> valueValues,
    List<String> accountKeyValues,
  ) {
    final len = valueValues.length;
    assert(
      accountKeyValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([valueValues[i], accountKeyValues[i]]);
    }

    return getAllByIndex(r'value_accountKey', values);
  }

  List<TimezoneOption?> getAllByValueAccountKeySync(
    List<String> valueValues,
    List<String> accountKeyValues,
  ) {
    final len = valueValues.length;
    assert(
      accountKeyValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([valueValues[i], accountKeyValues[i]]);
    }

    return getAllByIndexSync(r'value_accountKey', values);
  }

  Future<int> deleteAllByValueAccountKey(
    List<String> valueValues,
    List<String> accountKeyValues,
  ) {
    final len = valueValues.length;
    assert(
      accountKeyValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([valueValues[i], accountKeyValues[i]]);
    }

    return deleteAllByIndex(r'value_accountKey', values);
  }

  int deleteAllByValueAccountKeySync(
    List<String> valueValues,
    List<String> accountKeyValues,
  ) {
    final len = valueValues.length;
    assert(
      accountKeyValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([valueValues[i], accountKeyValues[i]]);
    }

    return deleteAllByIndexSync(r'value_accountKey', values);
  }

  Future<Id> putByValueAccountKey(TimezoneOption object) {
    return putByIndex(r'value_accountKey', object);
  }

  Id putByValueAccountKeySync(TimezoneOption object, {bool saveLinks = true}) {
    return putByIndexSync(r'value_accountKey', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByValueAccountKey(List<TimezoneOption> objects) {
    return putAllByIndex(r'value_accountKey', objects);
  }

  List<Id> putAllByValueAccountKeySync(
    List<TimezoneOption> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'value_accountKey',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension TimezoneOptionQueryWhereSort
    on QueryBuilder<TimezoneOption, TimezoneOption, QWhere> {
  QueryBuilder<TimezoneOption, TimezoneOption, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension TimezoneOptionQueryWhere
    on QueryBuilder<TimezoneOption, TimezoneOption, QWhereClause> {
  QueryBuilder<TimezoneOption, TimezoneOption, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterWhereClause> idNotEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterWhereClause>
  valueEqualToAnyAccountKey(String value) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'value_accountKey',
          value: [value],
        ),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterWhereClause>
  valueNotEqualToAnyAccountKey(String value) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'value_accountKey',
                lower: [],
                upper: [value],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'value_accountKey',
                lower: [value],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'value_accountKey',
                lower: [value],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'value_accountKey',
                lower: [],
                upper: [value],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterWhereClause>
  valueAccountKeyEqualTo(String value, String accountKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'value_accountKey',
          value: [value, accountKey],
        ),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterWhereClause>
  valueEqualToAccountKeyNotEqualTo(String value, String accountKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'value_accountKey',
                lower: [value],
                upper: [value, accountKey],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'value_accountKey',
                lower: [value, accountKey],
                includeLower: false,
                upper: [value],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'value_accountKey',
                lower: [value, accountKey],
                includeLower: false,
                upper: [value],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'value_accountKey',
                lower: [value],
                upper: [value, accountKey],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension TimezoneOptionQueryFilter
    on QueryBuilder<TimezoneOption, TimezoneOption, QFilterCondition> {
  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  accountKeyEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'accountKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  accountKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'accountKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  accountKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'accountKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  accountKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'accountKey',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  accountKeyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'accountKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  accountKeyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'accountKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  accountKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'accountKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  accountKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'accountKey',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  accountKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'accountKey', value: ''),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  accountKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'accountKey', value: ''),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  labelEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'label',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  labelGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'label',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  labelLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'label',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  labelBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'label',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  labelStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'label',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  labelEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'label',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  labelContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'label',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  labelMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'label',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  labelIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'label', value: ''),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  labelIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'label', value: ''),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  valueEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'value',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  valueGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'value',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  valueLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'value',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  valueBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'value',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  valueStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'value',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  valueEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'value',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  valueContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'value',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  valueMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'value',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  valueIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'value', value: ''),
      );
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterFilterCondition>
  valueIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'value', value: ''),
      );
    });
  }
}

extension TimezoneOptionQueryObject
    on QueryBuilder<TimezoneOption, TimezoneOption, QFilterCondition> {}

extension TimezoneOptionQueryLinks
    on QueryBuilder<TimezoneOption, TimezoneOption, QFilterCondition> {}

extension TimezoneOptionQuerySortBy
    on QueryBuilder<TimezoneOption, TimezoneOption, QSortBy> {
  QueryBuilder<TimezoneOption, TimezoneOption, QAfterSortBy>
  sortByAccountKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountKey', Sort.asc);
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterSortBy>
  sortByAccountKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountKey', Sort.desc);
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterSortBy> sortByLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.asc);
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterSortBy> sortByLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.desc);
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterSortBy> sortByValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'value', Sort.asc);
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterSortBy> sortByValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'value', Sort.desc);
    });
  }
}

extension TimezoneOptionQuerySortThenBy
    on QueryBuilder<TimezoneOption, TimezoneOption, QSortThenBy> {
  QueryBuilder<TimezoneOption, TimezoneOption, QAfterSortBy>
  thenByAccountKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountKey', Sort.asc);
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterSortBy>
  thenByAccountKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountKey', Sort.desc);
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterSortBy> thenByLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.asc);
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterSortBy> thenByLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.desc);
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterSortBy> thenByValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'value', Sort.asc);
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QAfterSortBy> thenByValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'value', Sort.desc);
    });
  }
}

extension TimezoneOptionQueryWhereDistinct
    on QueryBuilder<TimezoneOption, TimezoneOption, QDistinct> {
  QueryBuilder<TimezoneOption, TimezoneOption, QDistinct> distinctByAccountKey({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'accountKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QDistinct> distinctByLabel({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'label', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TimezoneOption, TimezoneOption, QDistinct> distinctByValue({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'value', caseSensitive: caseSensitive);
    });
  }
}

extension TimezoneOptionQueryProperty
    on QueryBuilder<TimezoneOption, TimezoneOption, QQueryProperty> {
  QueryBuilder<TimezoneOption, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<TimezoneOption, String, QQueryOperations> accountKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'accountKey');
    });
  }

  QueryBuilder<TimezoneOption, String, QQueryOperations> labelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'label');
    });
  }

  QueryBuilder<TimezoneOption, String, QQueryOperations> valueProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'value');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetDepartmentOptionCollection on Isar {
  IsarCollection<DepartmentOption> get departmentOptions => this.collection();
}

const DepartmentOptionSchema = CollectionSchema(
  name: r'DepartmentOption',
  id: 7804729398454466524,
  properties: {
    r'accountKey': PropertySchema(
      id: 0,
      name: r'accountKey',
      type: IsarType.string,
    ),
    r'idValue': PropertySchema(id: 1, name: r'idValue', type: IsarType.string),
    r'name': PropertySchema(id: 2, name: r'name', type: IsarType.string),
  },

  estimateSize: _departmentOptionEstimateSize,
  serialize: _departmentOptionSerialize,
  deserialize: _departmentOptionDeserialize,
  deserializeProp: _departmentOptionDeserializeProp,
  idName: r'id',
  indexes: {
    r'idValue_accountKey': IndexSchema(
      id: 1562423008944942083,
      name: r'idValue_accountKey',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'idValue',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'accountKey',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _departmentOptionGetId,
  getLinks: _departmentOptionGetLinks,
  attach: _departmentOptionAttach,
  version: '3.3.0',
);

int _departmentOptionEstimateSize(
  DepartmentOption object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.accountKey.length * 3;
  bytesCount += 3 + object.idValue.length * 3;
  bytesCount += 3 + object.name.length * 3;
  return bytesCount;
}

void _departmentOptionSerialize(
  DepartmentOption object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.accountKey);
  writer.writeString(offsets[1], object.idValue);
  writer.writeString(offsets[2], object.name);
}

DepartmentOption _departmentOptionDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = DepartmentOption();
  object.accountKey = reader.readString(offsets[0]);
  object.id = id;
  object.idValue = reader.readString(offsets[1]);
  object.name = reader.readString(offsets[2]);
  return object;
}

P _departmentOptionDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _departmentOptionGetId(DepartmentOption object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _departmentOptionGetLinks(DepartmentOption object) {
  return [];
}

void _departmentOptionAttach(
  IsarCollection<dynamic> col,
  Id id,
  DepartmentOption object,
) {
  object.id = id;
}

extension DepartmentOptionByIndex on IsarCollection<DepartmentOption> {
  Future<DepartmentOption?> getByIdValueAccountKey(
    String idValue,
    String accountKey,
  ) {
    return getByIndex(r'idValue_accountKey', [idValue, accountKey]);
  }

  DepartmentOption? getByIdValueAccountKeySync(
    String idValue,
    String accountKey,
  ) {
    return getByIndexSync(r'idValue_accountKey', [idValue, accountKey]);
  }

  Future<bool> deleteByIdValueAccountKey(String idValue, String accountKey) {
    return deleteByIndex(r'idValue_accountKey', [idValue, accountKey]);
  }

  bool deleteByIdValueAccountKeySync(String idValue, String accountKey) {
    return deleteByIndexSync(r'idValue_accountKey', [idValue, accountKey]);
  }

  Future<List<DepartmentOption?>> getAllByIdValueAccountKey(
    List<String> idValueValues,
    List<String> accountKeyValues,
  ) {
    final len = idValueValues.length;
    assert(
      accountKeyValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([idValueValues[i], accountKeyValues[i]]);
    }

    return getAllByIndex(r'idValue_accountKey', values);
  }

  List<DepartmentOption?> getAllByIdValueAccountKeySync(
    List<String> idValueValues,
    List<String> accountKeyValues,
  ) {
    final len = idValueValues.length;
    assert(
      accountKeyValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([idValueValues[i], accountKeyValues[i]]);
    }

    return getAllByIndexSync(r'idValue_accountKey', values);
  }

  Future<int> deleteAllByIdValueAccountKey(
    List<String> idValueValues,
    List<String> accountKeyValues,
  ) {
    final len = idValueValues.length;
    assert(
      accountKeyValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([idValueValues[i], accountKeyValues[i]]);
    }

    return deleteAllByIndex(r'idValue_accountKey', values);
  }

  int deleteAllByIdValueAccountKeySync(
    List<String> idValueValues,
    List<String> accountKeyValues,
  ) {
    final len = idValueValues.length;
    assert(
      accountKeyValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([idValueValues[i], accountKeyValues[i]]);
    }

    return deleteAllByIndexSync(r'idValue_accountKey', values);
  }

  Future<Id> putByIdValueAccountKey(DepartmentOption object) {
    return putByIndex(r'idValue_accountKey', object);
  }

  Id putByIdValueAccountKeySync(
    DepartmentOption object, {
    bool saveLinks = true,
  }) {
    return putByIndexSync(r'idValue_accountKey', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByIdValueAccountKey(List<DepartmentOption> objects) {
    return putAllByIndex(r'idValue_accountKey', objects);
  }

  List<Id> putAllByIdValueAccountKeySync(
    List<DepartmentOption> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'idValue_accountKey',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension DepartmentOptionQueryWhereSort
    on QueryBuilder<DepartmentOption, DepartmentOption, QWhere> {
  QueryBuilder<DepartmentOption, DepartmentOption, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension DepartmentOptionQueryWhere
    on QueryBuilder<DepartmentOption, DepartmentOption, QWhereClause> {
  QueryBuilder<DepartmentOption, DepartmentOption, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterWhereClause>
  idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterWhereClause>
  idValueEqualToAnyAccountKey(String idValue) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'idValue_accountKey',
          value: [idValue],
        ),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterWhereClause>
  idValueNotEqualToAnyAccountKey(String idValue) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'idValue_accountKey',
                lower: [],
                upper: [idValue],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'idValue_accountKey',
                lower: [idValue],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'idValue_accountKey',
                lower: [idValue],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'idValue_accountKey',
                lower: [],
                upper: [idValue],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterWhereClause>
  idValueAccountKeyEqualTo(String idValue, String accountKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'idValue_accountKey',
          value: [idValue, accountKey],
        ),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterWhereClause>
  idValueEqualToAccountKeyNotEqualTo(String idValue, String accountKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'idValue_accountKey',
                lower: [idValue],
                upper: [idValue, accountKey],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'idValue_accountKey',
                lower: [idValue, accountKey],
                includeLower: false,
                upper: [idValue],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'idValue_accountKey',
                lower: [idValue, accountKey],
                includeLower: false,
                upper: [idValue],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'idValue_accountKey',
                lower: [idValue],
                upper: [idValue, accountKey],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension DepartmentOptionQueryFilter
    on QueryBuilder<DepartmentOption, DepartmentOption, QFilterCondition> {
  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  accountKeyEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'accountKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  accountKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'accountKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  accountKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'accountKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  accountKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'accountKey',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  accountKeyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'accountKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  accountKeyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'accountKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  accountKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'accountKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  accountKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'accountKey',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  accountKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'accountKey', value: ''),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  accountKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'accountKey', value: ''),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  idValueEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'idValue',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  idValueGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'idValue',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  idValueLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'idValue',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  idValueBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'idValue',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  idValueStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'idValue',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  idValueEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'idValue',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  idValueContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'idValue',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  idValueMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'idValue',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  idValueIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'idValue', value: ''),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  idValueIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'idValue', value: ''),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  nameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'name',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  nameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  nameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  nameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  nameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterFilterCondition>
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }
}

extension DepartmentOptionQueryObject
    on QueryBuilder<DepartmentOption, DepartmentOption, QFilterCondition> {}

extension DepartmentOptionQueryLinks
    on QueryBuilder<DepartmentOption, DepartmentOption, QFilterCondition> {}

extension DepartmentOptionQuerySortBy
    on QueryBuilder<DepartmentOption, DepartmentOption, QSortBy> {
  QueryBuilder<DepartmentOption, DepartmentOption, QAfterSortBy>
  sortByAccountKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountKey', Sort.asc);
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterSortBy>
  sortByAccountKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountKey', Sort.desc);
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterSortBy>
  sortByIdValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'idValue', Sort.asc);
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterSortBy>
  sortByIdValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'idValue', Sort.desc);
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterSortBy>
  sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }
}

extension DepartmentOptionQuerySortThenBy
    on QueryBuilder<DepartmentOption, DepartmentOption, QSortThenBy> {
  QueryBuilder<DepartmentOption, DepartmentOption, QAfterSortBy>
  thenByAccountKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountKey', Sort.asc);
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterSortBy>
  thenByAccountKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountKey', Sort.desc);
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterSortBy>
  thenByIdValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'idValue', Sort.asc);
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterSortBy>
  thenByIdValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'idValue', Sort.desc);
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QAfterSortBy>
  thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }
}

extension DepartmentOptionQueryWhereDistinct
    on QueryBuilder<DepartmentOption, DepartmentOption, QDistinct> {
  QueryBuilder<DepartmentOption, DepartmentOption, QDistinct>
  distinctByAccountKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'accountKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QDistinct>
  distinctByIdValue({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'idValue', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DepartmentOption, DepartmentOption, QDistinct> distinctByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }
}

extension DepartmentOptionQueryProperty
    on QueryBuilder<DepartmentOption, DepartmentOption, QQueryProperty> {
  QueryBuilder<DepartmentOption, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<DepartmentOption, String, QQueryOperations>
  accountKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'accountKey');
    });
  }

  QueryBuilder<DepartmentOption, String, QQueryOperations> idValueProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'idValue');
    });
  }

  QueryBuilder<DepartmentOption, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }
}
