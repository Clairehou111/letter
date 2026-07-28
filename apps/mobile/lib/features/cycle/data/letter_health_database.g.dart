// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'letter_health_database.dart';

// ignore_for_file: type=lint
class $PeriodRowsTable extends PeriodRows
    with TableInfo<$PeriodRowsTable, PeriodRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PeriodRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startDayMeta = const VerificationMeta(
    'startDay',
  );
  @override
  late final GeneratedColumn<int> startDay = GeneratedColumn<int>(
    'start_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDayMeta = const VerificationMeta('endDay');
  @override
  late final GeneratedColumn<int> endDay = GeneratedColumn<int>(
    'end_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMillisMeta = const VerificationMeta(
    'createdAtMillis',
  );
  @override
  late final GeneratedColumn<int> createdAtMillis = GeneratedColumn<int>(
    'created_at_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMillisMeta = const VerificationMeta(
    'updatedAtMillis',
  );
  @override
  late final GeneratedColumn<int> updatedAtMillis = GeneratedColumn<int>(
    'updated_at_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startDay,
    endDay,
    createdAtMillis,
    updatedAtMillis,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'period_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<PeriodRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('start_day')) {
      context.handle(
        _startDayMeta,
        startDay.isAcceptableOrUnknown(data['start_day']!, _startDayMeta),
      );
    } else if (isInserting) {
      context.missing(_startDayMeta);
    }
    if (data.containsKey('end_day')) {
      context.handle(
        _endDayMeta,
        endDay.isAcceptableOrUnknown(data['end_day']!, _endDayMeta),
      );
    }
    if (data.containsKey('created_at_millis')) {
      context.handle(
        _createdAtMillisMeta,
        createdAtMillis.isAcceptableOrUnknown(
          data['created_at_millis']!,
          _createdAtMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMillisMeta);
    }
    if (data.containsKey('updated_at_millis')) {
      context.handle(
        _updatedAtMillisMeta,
        updatedAtMillis.isAcceptableOrUnknown(
          data['updated_at_millis']!,
          _updatedAtMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMillisMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PeriodRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PeriodRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      startDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_day'],
      )!,
      endDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_day'],
      ),
      createdAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_millis'],
      )!,
      updatedAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_millis'],
      )!,
    );
  }

  @override
  $PeriodRowsTable createAlias(String alias) {
    return $PeriodRowsTable(attachedDatabase, alias);
  }
}

class PeriodRow extends DataClass implements Insertable<PeriodRow> {
  final String id;
  final int startDay;
  final int? endDay;
  final int createdAtMillis;
  final int updatedAtMillis;
  const PeriodRow({
    required this.id,
    required this.startDay,
    this.endDay,
    required this.createdAtMillis,
    required this.updatedAtMillis,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['start_day'] = Variable<int>(startDay);
    if (!nullToAbsent || endDay != null) {
      map['end_day'] = Variable<int>(endDay);
    }
    map['created_at_millis'] = Variable<int>(createdAtMillis);
    map['updated_at_millis'] = Variable<int>(updatedAtMillis);
    return map;
  }

  PeriodRowsCompanion toCompanion(bool nullToAbsent) {
    return PeriodRowsCompanion(
      id: Value(id),
      startDay: Value(startDay),
      endDay: endDay == null && nullToAbsent
          ? const Value.absent()
          : Value(endDay),
      createdAtMillis: Value(createdAtMillis),
      updatedAtMillis: Value(updatedAtMillis),
    );
  }

  factory PeriodRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PeriodRow(
      id: serializer.fromJson<String>(json['id']),
      startDay: serializer.fromJson<int>(json['startDay']),
      endDay: serializer.fromJson<int?>(json['endDay']),
      createdAtMillis: serializer.fromJson<int>(json['createdAtMillis']),
      updatedAtMillis: serializer.fromJson<int>(json['updatedAtMillis']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'startDay': serializer.toJson<int>(startDay),
      'endDay': serializer.toJson<int?>(endDay),
      'createdAtMillis': serializer.toJson<int>(createdAtMillis),
      'updatedAtMillis': serializer.toJson<int>(updatedAtMillis),
    };
  }

  PeriodRow copyWith({
    String? id,
    int? startDay,
    Value<int?> endDay = const Value.absent(),
    int? createdAtMillis,
    int? updatedAtMillis,
  }) => PeriodRow(
    id: id ?? this.id,
    startDay: startDay ?? this.startDay,
    endDay: endDay.present ? endDay.value : this.endDay,
    createdAtMillis: createdAtMillis ?? this.createdAtMillis,
    updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
  );
  PeriodRow copyWithCompanion(PeriodRowsCompanion data) {
    return PeriodRow(
      id: data.id.present ? data.id.value : this.id,
      startDay: data.startDay.present ? data.startDay.value : this.startDay,
      endDay: data.endDay.present ? data.endDay.value : this.endDay,
      createdAtMillis: data.createdAtMillis.present
          ? data.createdAtMillis.value
          : this.createdAtMillis,
      updatedAtMillis: data.updatedAtMillis.present
          ? data.updatedAtMillis.value
          : this.updatedAtMillis,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PeriodRow(')
          ..write('id: $id, ')
          ..write('startDay: $startDay, ')
          ..write('endDay: $endDay, ')
          ..write('createdAtMillis: $createdAtMillis, ')
          ..write('updatedAtMillis: $updatedAtMillis')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, startDay, endDay, createdAtMillis, updatedAtMillis);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PeriodRow &&
          other.id == this.id &&
          other.startDay == this.startDay &&
          other.endDay == this.endDay &&
          other.createdAtMillis == this.createdAtMillis &&
          other.updatedAtMillis == this.updatedAtMillis);
}

class PeriodRowsCompanion extends UpdateCompanion<PeriodRow> {
  final Value<String> id;
  final Value<int> startDay;
  final Value<int?> endDay;
  final Value<int> createdAtMillis;
  final Value<int> updatedAtMillis;
  final Value<int> rowid;
  const PeriodRowsCompanion({
    this.id = const Value.absent(),
    this.startDay = const Value.absent(),
    this.endDay = const Value.absent(),
    this.createdAtMillis = const Value.absent(),
    this.updatedAtMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PeriodRowsCompanion.insert({
    required String id,
    required int startDay,
    this.endDay = const Value.absent(),
    required int createdAtMillis,
    required int updatedAtMillis,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startDay = Value(startDay),
       createdAtMillis = Value(createdAtMillis),
       updatedAtMillis = Value(updatedAtMillis);
  static Insertable<PeriodRow> custom({
    Expression<String>? id,
    Expression<int>? startDay,
    Expression<int>? endDay,
    Expression<int>? createdAtMillis,
    Expression<int>? updatedAtMillis,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startDay != null) 'start_day': startDay,
      if (endDay != null) 'end_day': endDay,
      if (createdAtMillis != null) 'created_at_millis': createdAtMillis,
      if (updatedAtMillis != null) 'updated_at_millis': updatedAtMillis,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PeriodRowsCompanion copyWith({
    Value<String>? id,
    Value<int>? startDay,
    Value<int?>? endDay,
    Value<int>? createdAtMillis,
    Value<int>? updatedAtMillis,
    Value<int>? rowid,
  }) {
    return PeriodRowsCompanion(
      id: id ?? this.id,
      startDay: startDay ?? this.startDay,
      endDay: endDay ?? this.endDay,
      createdAtMillis: createdAtMillis ?? this.createdAtMillis,
      updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (startDay.present) {
      map['start_day'] = Variable<int>(startDay.value);
    }
    if (endDay.present) {
      map['end_day'] = Variable<int>(endDay.value);
    }
    if (createdAtMillis.present) {
      map['created_at_millis'] = Variable<int>(createdAtMillis.value);
    }
    if (updatedAtMillis.present) {
      map['updated_at_millis'] = Variable<int>(updatedAtMillis.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PeriodRowsCompanion(')
          ..write('id: $id, ')
          ..write('startDay: $startDay, ')
          ..write('endDay: $endDay, ')
          ..write('createdAtMillis: $createdAtMillis, ')
          ..write('updatedAtMillis: $updatedAtMillis, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LetterHealthDatabase extends GeneratedDatabase {
  _$LetterHealthDatabase(QueryExecutor e) : super(e);
  $LetterHealthDatabaseManager get managers =>
      $LetterHealthDatabaseManager(this);
  late final $PeriodRowsTable periodRows = $PeriodRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [periodRows];
}

typedef $$PeriodRowsTableCreateCompanionBuilder =
    PeriodRowsCompanion Function({
      required String id,
      required int startDay,
      Value<int?> endDay,
      required int createdAtMillis,
      required int updatedAtMillis,
      Value<int> rowid,
    });
typedef $$PeriodRowsTableUpdateCompanionBuilder =
    PeriodRowsCompanion Function({
      Value<String> id,
      Value<int> startDay,
      Value<int?> endDay,
      Value<int> createdAtMillis,
      Value<int> updatedAtMillis,
      Value<int> rowid,
    });

class $$PeriodRowsTableFilterComposer
    extends Composer<_$LetterHealthDatabase, $PeriodRowsTable> {
  $$PeriodRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startDay => $composableBuilder(
    column: $table.startDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endDay => $composableBuilder(
    column: $table.endDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMillis => $composableBuilder(
    column: $table.updatedAtMillis,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PeriodRowsTableOrderingComposer
    extends Composer<_$LetterHealthDatabase, $PeriodRowsTable> {
  $$PeriodRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startDay => $composableBuilder(
    column: $table.startDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endDay => $composableBuilder(
    column: $table.endDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMillis => $composableBuilder(
    column: $table.updatedAtMillis,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PeriodRowsTableAnnotationComposer
    extends Composer<_$LetterHealthDatabase, $PeriodRowsTable> {
  $$PeriodRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get startDay =>
      $composableBuilder(column: $table.startDay, builder: (column) => column);

  GeneratedColumn<int> get endDay =>
      $composableBuilder(column: $table.endDay, builder: (column) => column);

  GeneratedColumn<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMillis => $composableBuilder(
    column: $table.updatedAtMillis,
    builder: (column) => column,
  );
}

class $$PeriodRowsTableTableManager
    extends
        RootTableManager<
          _$LetterHealthDatabase,
          $PeriodRowsTable,
          PeriodRow,
          $$PeriodRowsTableFilterComposer,
          $$PeriodRowsTableOrderingComposer,
          $$PeriodRowsTableAnnotationComposer,
          $$PeriodRowsTableCreateCompanionBuilder,
          $$PeriodRowsTableUpdateCompanionBuilder,
          (
            PeriodRow,
            BaseReferences<_$LetterHealthDatabase, $PeriodRowsTable, PeriodRow>,
          ),
          PeriodRow,
          PrefetchHooks Function()
        > {
  $$PeriodRowsTableTableManager(
    _$LetterHealthDatabase db,
    $PeriodRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PeriodRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PeriodRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PeriodRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> startDay = const Value.absent(),
                Value<int?> endDay = const Value.absent(),
                Value<int> createdAtMillis = const Value.absent(),
                Value<int> updatedAtMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PeriodRowsCompanion(
                id: id,
                startDay: startDay,
                endDay: endDay,
                createdAtMillis: createdAtMillis,
                updatedAtMillis: updatedAtMillis,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int startDay,
                Value<int?> endDay = const Value.absent(),
                required int createdAtMillis,
                required int updatedAtMillis,
                Value<int> rowid = const Value.absent(),
              }) => PeriodRowsCompanion.insert(
                id: id,
                startDay: startDay,
                endDay: endDay,
                createdAtMillis: createdAtMillis,
                updatedAtMillis: updatedAtMillis,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PeriodRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$LetterHealthDatabase,
      $PeriodRowsTable,
      PeriodRow,
      $$PeriodRowsTableFilterComposer,
      $$PeriodRowsTableOrderingComposer,
      $$PeriodRowsTableAnnotationComposer,
      $$PeriodRowsTableCreateCompanionBuilder,
      $$PeriodRowsTableUpdateCompanionBuilder,
      (
        PeriodRow,
        BaseReferences<_$LetterHealthDatabase, $PeriodRowsTable, PeriodRow>,
      ),
      PeriodRow,
      PrefetchHooks Function()
    >;

class $LetterHealthDatabaseManager {
  final _$LetterHealthDatabase _db;
  $LetterHealthDatabaseManager(this._db);
  $$PeriodRowsTableTableManager get periodRows =>
      $$PeriodRowsTableTableManager(_db, _db.periodRows);
}
