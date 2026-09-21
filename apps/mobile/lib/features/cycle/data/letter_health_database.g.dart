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

class $PeriodFlowRowsTable extends PeriodFlowRows
    with TableInfo<$PeriodFlowRowsTable, PeriodFlowRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PeriodFlowRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _periodIdMeta = const VerificationMeta(
    'periodId',
  );
  @override
  late final GeneratedColumn<String> periodId = GeneratedColumn<String>(
    'period_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES period_rows (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<int> day = GeneratedColumn<int>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _flowMeta = const VerificationMeta('flow');
  @override
  late final GeneratedColumn<String> flow = GeneratedColumn<String>(
    'flow',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    periodId,
    day,
    flow,
    color,
    createdAtMillis,
    updatedAtMillis,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'period_flow_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<PeriodFlowRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('period_id')) {
      context.handle(
        _periodIdMeta,
        periodId.isAcceptableOrUnknown(data['period_id']!, _periodIdMeta),
      );
    } else if (isInserting) {
      context.missing(_periodIdMeta);
    }
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('flow')) {
      context.handle(
        _flowMeta,
        flow.isAcceptableOrUnknown(data['flow']!, _flowMeta),
      );
    } else if (isInserting) {
      context.missing(_flowMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
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
  Set<GeneratedColumn> get $primaryKey => {periodId, day};
  @override
  PeriodFlowRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PeriodFlowRow(
      periodId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period_id'],
      )!,
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day'],
      )!,
      flow: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}flow'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
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
  $PeriodFlowRowsTable createAlias(String alias) {
    return $PeriodFlowRowsTable(attachedDatabase, alias);
  }
}

class PeriodFlowRow extends DataClass implements Insertable<PeriodFlowRow> {
  final String periodId;
  final int day;
  final String flow;
  final String? color;
  final int createdAtMillis;
  final int updatedAtMillis;
  const PeriodFlowRow({
    required this.periodId,
    required this.day,
    required this.flow,
    this.color,
    required this.createdAtMillis,
    required this.updatedAtMillis,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['period_id'] = Variable<String>(periodId);
    map['day'] = Variable<int>(day);
    map['flow'] = Variable<String>(flow);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    map['created_at_millis'] = Variable<int>(createdAtMillis);
    map['updated_at_millis'] = Variable<int>(updatedAtMillis);
    return map;
  }

  PeriodFlowRowsCompanion toCompanion(bool nullToAbsent) {
    return PeriodFlowRowsCompanion(
      periodId: Value(periodId),
      day: Value(day),
      flow: Value(flow),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      createdAtMillis: Value(createdAtMillis),
      updatedAtMillis: Value(updatedAtMillis),
    );
  }

  factory PeriodFlowRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PeriodFlowRow(
      periodId: serializer.fromJson<String>(json['periodId']),
      day: serializer.fromJson<int>(json['day']),
      flow: serializer.fromJson<String>(json['flow']),
      color: serializer.fromJson<String?>(json['color']),
      createdAtMillis: serializer.fromJson<int>(json['createdAtMillis']),
      updatedAtMillis: serializer.fromJson<int>(json['updatedAtMillis']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'periodId': serializer.toJson<String>(periodId),
      'day': serializer.toJson<int>(day),
      'flow': serializer.toJson<String>(flow),
      'color': serializer.toJson<String?>(color),
      'createdAtMillis': serializer.toJson<int>(createdAtMillis),
      'updatedAtMillis': serializer.toJson<int>(updatedAtMillis),
    };
  }

  PeriodFlowRow copyWith({
    String? periodId,
    int? day,
    String? flow,
    Value<String?> color = const Value.absent(),
    int? createdAtMillis,
    int? updatedAtMillis,
  }) => PeriodFlowRow(
    periodId: periodId ?? this.periodId,
    day: day ?? this.day,
    flow: flow ?? this.flow,
    color: color.present ? color.value : this.color,
    createdAtMillis: createdAtMillis ?? this.createdAtMillis,
    updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
  );
  PeriodFlowRow copyWithCompanion(PeriodFlowRowsCompanion data) {
    return PeriodFlowRow(
      periodId: data.periodId.present ? data.periodId.value : this.periodId,
      day: data.day.present ? data.day.value : this.day,
      flow: data.flow.present ? data.flow.value : this.flow,
      color: data.color.present ? data.color.value : this.color,
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
    return (StringBuffer('PeriodFlowRow(')
          ..write('periodId: $periodId, ')
          ..write('day: $day, ')
          ..write('flow: $flow, ')
          ..write('color: $color, ')
          ..write('createdAtMillis: $createdAtMillis, ')
          ..write('updatedAtMillis: $updatedAtMillis')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(periodId, day, flow, color, createdAtMillis, updatedAtMillis);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PeriodFlowRow &&
          other.periodId == this.periodId &&
          other.day == this.day &&
          other.flow == this.flow &&
          other.color == this.color &&
          other.createdAtMillis == this.createdAtMillis &&
          other.updatedAtMillis == this.updatedAtMillis);
}

class PeriodFlowRowsCompanion extends UpdateCompanion<PeriodFlowRow> {
  final Value<String> periodId;
  final Value<int> day;
  final Value<String> flow;
  final Value<String?> color;
  final Value<int> createdAtMillis;
  final Value<int> updatedAtMillis;
  final Value<int> rowid;
  const PeriodFlowRowsCompanion({
    this.periodId = const Value.absent(),
    this.day = const Value.absent(),
    this.flow = const Value.absent(),
    this.color = const Value.absent(),
    this.createdAtMillis = const Value.absent(),
    this.updatedAtMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PeriodFlowRowsCompanion.insert({
    required String periodId,
    required int day,
    required String flow,
    this.color = const Value.absent(),
    required int createdAtMillis,
    required int updatedAtMillis,
    this.rowid = const Value.absent(),
  }) : periodId = Value(periodId),
       day = Value(day),
       flow = Value(flow),
       createdAtMillis = Value(createdAtMillis),
       updatedAtMillis = Value(updatedAtMillis);
  static Insertable<PeriodFlowRow> custom({
    Expression<String>? periodId,
    Expression<int>? day,
    Expression<String>? flow,
    Expression<String>? color,
    Expression<int>? createdAtMillis,
    Expression<int>? updatedAtMillis,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (periodId != null) 'period_id': periodId,
      if (day != null) 'day': day,
      if (flow != null) 'flow': flow,
      if (color != null) 'color': color,
      if (createdAtMillis != null) 'created_at_millis': createdAtMillis,
      if (updatedAtMillis != null) 'updated_at_millis': updatedAtMillis,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PeriodFlowRowsCompanion copyWith({
    Value<String>? periodId,
    Value<int>? day,
    Value<String>? flow,
    Value<String?>? color,
    Value<int>? createdAtMillis,
    Value<int>? updatedAtMillis,
    Value<int>? rowid,
  }) {
    return PeriodFlowRowsCompanion(
      periodId: periodId ?? this.periodId,
      day: day ?? this.day,
      flow: flow ?? this.flow,
      color: color ?? this.color,
      createdAtMillis: createdAtMillis ?? this.createdAtMillis,
      updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (periodId.present) {
      map['period_id'] = Variable<String>(periodId.value);
    }
    if (day.present) {
      map['day'] = Variable<int>(day.value);
    }
    if (flow.present) {
      map['flow'] = Variable<String>(flow.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
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
    return (StringBuffer('PeriodFlowRowsCompanion(')
          ..write('periodId: $periodId, ')
          ..write('day: $day, ')
          ..write('flow: $flow, ')
          ..write('color: $color, ')
          ..write('createdAtMillis: $createdAtMillis, ')
          ..write('updatedAtMillis: $updatedAtMillis, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CareRecordRowsTable extends CareRecordRows
    with TableInfo<$CareRecordRowsTable, CareRecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CareRecordRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionIdMeta = const VerificationMeta(
    'actionId',
  );
  @override
  late final GeneratedColumn<String> actionId = GeneratedColumn<String>(
    'action_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionLabelMeta = const VerificationMeta(
    'actionLabel',
  );
  @override
  late final GeneratedColumn<String> actionLabel = GeneratedColumn<String>(
    'action_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outcomeMeta = const VerificationMeta(
    'outcome',
  );
  @override
  late final GeneratedColumn<String> outcome = GeneratedColumn<String>(
    'outcome',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMillisMeta = const VerificationMeta(
    'occurredAtMillis',
  );
  @override
  late final GeneratedColumn<int> occurredAtMillis = GeneratedColumn<int>(
    'occurred_at_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mode,
    actionId,
    actionLabel,
    outcome,
    occurredAtMillis,
    createdAtMillis,
    updatedAtMillis,
    pinned,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'care_record_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<CareRecordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('action_id')) {
      context.handle(
        _actionIdMeta,
        actionId.isAcceptableOrUnknown(data['action_id']!, _actionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_actionIdMeta);
    }
    if (data.containsKey('action_label')) {
      context.handle(
        _actionLabelMeta,
        actionLabel.isAcceptableOrUnknown(
          data['action_label']!,
          _actionLabelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_actionLabelMeta);
    }
    if (data.containsKey('outcome')) {
      context.handle(
        _outcomeMeta,
        outcome.isAcceptableOrUnknown(data['outcome']!, _outcomeMeta),
      );
    } else if (isInserting) {
      context.missing(_outcomeMeta);
    }
    if (data.containsKey('occurred_at_millis')) {
      context.handle(
        _occurredAtMillisMeta,
        occurredAtMillis.isAcceptableOrUnknown(
          data['occurred_at_millis']!,
          _occurredAtMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMillisMeta);
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
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CareRecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CareRecordRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      actionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action_id'],
      )!,
      actionLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action_label'],
      )!,
      outcome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outcome'],
      )!,
      occurredAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}occurred_at_millis'],
      )!,
      createdAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_millis'],
      )!,
      updatedAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_millis'],
      )!,
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pinned'],
      )!,
    );
  }

  @override
  $CareRecordRowsTable createAlias(String alias) {
    return $CareRecordRowsTable(attachedDatabase, alias);
  }
}

class CareRecordRow extends DataClass implements Insertable<CareRecordRow> {
  final String id;
  final String mode;
  final String actionId;
  final String actionLabel;
  final String outcome;
  final int occurredAtMillis;
  final int createdAtMillis;
  final int updatedAtMillis;
  final bool pinned;
  const CareRecordRow({
    required this.id,
    required this.mode,
    required this.actionId,
    required this.actionLabel,
    required this.outcome,
    required this.occurredAtMillis,
    required this.createdAtMillis,
    required this.updatedAtMillis,
    required this.pinned,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['mode'] = Variable<String>(mode);
    map['action_id'] = Variable<String>(actionId);
    map['action_label'] = Variable<String>(actionLabel);
    map['outcome'] = Variable<String>(outcome);
    map['occurred_at_millis'] = Variable<int>(occurredAtMillis);
    map['created_at_millis'] = Variable<int>(createdAtMillis);
    map['updated_at_millis'] = Variable<int>(updatedAtMillis);
    map['pinned'] = Variable<bool>(pinned);
    return map;
  }

  CareRecordRowsCompanion toCompanion(bool nullToAbsent) {
    return CareRecordRowsCompanion(
      id: Value(id),
      mode: Value(mode),
      actionId: Value(actionId),
      actionLabel: Value(actionLabel),
      outcome: Value(outcome),
      occurredAtMillis: Value(occurredAtMillis),
      createdAtMillis: Value(createdAtMillis),
      updatedAtMillis: Value(updatedAtMillis),
      pinned: Value(pinned),
    );
  }

  factory CareRecordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CareRecordRow(
      id: serializer.fromJson<String>(json['id']),
      mode: serializer.fromJson<String>(json['mode']),
      actionId: serializer.fromJson<String>(json['actionId']),
      actionLabel: serializer.fromJson<String>(json['actionLabel']),
      outcome: serializer.fromJson<String>(json['outcome']),
      occurredAtMillis: serializer.fromJson<int>(json['occurredAtMillis']),
      createdAtMillis: serializer.fromJson<int>(json['createdAtMillis']),
      updatedAtMillis: serializer.fromJson<int>(json['updatedAtMillis']),
      pinned: serializer.fromJson<bool>(json['pinned']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'mode': serializer.toJson<String>(mode),
      'actionId': serializer.toJson<String>(actionId),
      'actionLabel': serializer.toJson<String>(actionLabel),
      'outcome': serializer.toJson<String>(outcome),
      'occurredAtMillis': serializer.toJson<int>(occurredAtMillis),
      'createdAtMillis': serializer.toJson<int>(createdAtMillis),
      'updatedAtMillis': serializer.toJson<int>(updatedAtMillis),
      'pinned': serializer.toJson<bool>(pinned),
    };
  }

  CareRecordRow copyWith({
    String? id,
    String? mode,
    String? actionId,
    String? actionLabel,
    String? outcome,
    int? occurredAtMillis,
    int? createdAtMillis,
    int? updatedAtMillis,
    bool? pinned,
  }) => CareRecordRow(
    id: id ?? this.id,
    mode: mode ?? this.mode,
    actionId: actionId ?? this.actionId,
    actionLabel: actionLabel ?? this.actionLabel,
    outcome: outcome ?? this.outcome,
    occurredAtMillis: occurredAtMillis ?? this.occurredAtMillis,
    createdAtMillis: createdAtMillis ?? this.createdAtMillis,
    updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
    pinned: pinned ?? this.pinned,
  );
  CareRecordRow copyWithCompanion(CareRecordRowsCompanion data) {
    return CareRecordRow(
      id: data.id.present ? data.id.value : this.id,
      mode: data.mode.present ? data.mode.value : this.mode,
      actionId: data.actionId.present ? data.actionId.value : this.actionId,
      actionLabel: data.actionLabel.present
          ? data.actionLabel.value
          : this.actionLabel,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      occurredAtMillis: data.occurredAtMillis.present
          ? data.occurredAtMillis.value
          : this.occurredAtMillis,
      createdAtMillis: data.createdAtMillis.present
          ? data.createdAtMillis.value
          : this.createdAtMillis,
      updatedAtMillis: data.updatedAtMillis.present
          ? data.updatedAtMillis.value
          : this.updatedAtMillis,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CareRecordRow(')
          ..write('id: $id, ')
          ..write('mode: $mode, ')
          ..write('actionId: $actionId, ')
          ..write('actionLabel: $actionLabel, ')
          ..write('outcome: $outcome, ')
          ..write('occurredAtMillis: $occurredAtMillis, ')
          ..write('createdAtMillis: $createdAtMillis, ')
          ..write('updatedAtMillis: $updatedAtMillis, ')
          ..write('pinned: $pinned')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    mode,
    actionId,
    actionLabel,
    outcome,
    occurredAtMillis,
    createdAtMillis,
    updatedAtMillis,
    pinned,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CareRecordRow &&
          other.id == this.id &&
          other.mode == this.mode &&
          other.actionId == this.actionId &&
          other.actionLabel == this.actionLabel &&
          other.outcome == this.outcome &&
          other.occurredAtMillis == this.occurredAtMillis &&
          other.createdAtMillis == this.createdAtMillis &&
          other.updatedAtMillis == this.updatedAtMillis &&
          other.pinned == this.pinned);
}

class CareRecordRowsCompanion extends UpdateCompanion<CareRecordRow> {
  final Value<String> id;
  final Value<String> mode;
  final Value<String> actionId;
  final Value<String> actionLabel;
  final Value<String> outcome;
  final Value<int> occurredAtMillis;
  final Value<int> createdAtMillis;
  final Value<int> updatedAtMillis;
  final Value<bool> pinned;
  final Value<int> rowid;
  const CareRecordRowsCompanion({
    this.id = const Value.absent(),
    this.mode = const Value.absent(),
    this.actionId = const Value.absent(),
    this.actionLabel = const Value.absent(),
    this.outcome = const Value.absent(),
    this.occurredAtMillis = const Value.absent(),
    this.createdAtMillis = const Value.absent(),
    this.updatedAtMillis = const Value.absent(),
    this.pinned = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CareRecordRowsCompanion.insert({
    required String id,
    required String mode,
    required String actionId,
    required String actionLabel,
    required String outcome,
    required int occurredAtMillis,
    required int createdAtMillis,
    required int updatedAtMillis,
    this.pinned = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       mode = Value(mode),
       actionId = Value(actionId),
       actionLabel = Value(actionLabel),
       outcome = Value(outcome),
       occurredAtMillis = Value(occurredAtMillis),
       createdAtMillis = Value(createdAtMillis),
       updatedAtMillis = Value(updatedAtMillis);
  static Insertable<CareRecordRow> custom({
    Expression<String>? id,
    Expression<String>? mode,
    Expression<String>? actionId,
    Expression<String>? actionLabel,
    Expression<String>? outcome,
    Expression<int>? occurredAtMillis,
    Expression<int>? createdAtMillis,
    Expression<int>? updatedAtMillis,
    Expression<bool>? pinned,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mode != null) 'mode': mode,
      if (actionId != null) 'action_id': actionId,
      if (actionLabel != null) 'action_label': actionLabel,
      if (outcome != null) 'outcome': outcome,
      if (occurredAtMillis != null) 'occurred_at_millis': occurredAtMillis,
      if (createdAtMillis != null) 'created_at_millis': createdAtMillis,
      if (updatedAtMillis != null) 'updated_at_millis': updatedAtMillis,
      if (pinned != null) 'pinned': pinned,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CareRecordRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? mode,
    Value<String>? actionId,
    Value<String>? actionLabel,
    Value<String>? outcome,
    Value<int>? occurredAtMillis,
    Value<int>? createdAtMillis,
    Value<int>? updatedAtMillis,
    Value<bool>? pinned,
    Value<int>? rowid,
  }) {
    return CareRecordRowsCompanion(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      actionId: actionId ?? this.actionId,
      actionLabel: actionLabel ?? this.actionLabel,
      outcome: outcome ?? this.outcome,
      occurredAtMillis: occurredAtMillis ?? this.occurredAtMillis,
      createdAtMillis: createdAtMillis ?? this.createdAtMillis,
      updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
      pinned: pinned ?? this.pinned,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (actionId.present) {
      map['action_id'] = Variable<String>(actionId.value);
    }
    if (actionLabel.present) {
      map['action_label'] = Variable<String>(actionLabel.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(outcome.value);
    }
    if (occurredAtMillis.present) {
      map['occurred_at_millis'] = Variable<int>(occurredAtMillis.value);
    }
    if (createdAtMillis.present) {
      map['created_at_millis'] = Variable<int>(createdAtMillis.value);
    }
    if (updatedAtMillis.present) {
      map['updated_at_millis'] = Variable<int>(updatedAtMillis.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CareRecordRowsCompanion(')
          ..write('id: $id, ')
          ..write('mode: $mode, ')
          ..write('actionId: $actionId, ')
          ..write('actionLabel: $actionLabel, ')
          ..write('outcome: $outcome, ')
          ..write('occurredAtMillis: $occurredAtMillis, ')
          ..write('createdAtMillis: $createdAtMillis, ')
          ..write('updatedAtMillis: $updatedAtMillis, ')
          ..write('pinned: $pinned, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CareReflectionRowsTable extends CareReflectionRows
    with TableInfo<$CareReflectionRowsTable, CareReflectionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CareReflectionRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _careRecordIdMeta = const VerificationMeta(
    'careRecordId',
  );
  @override
  late final GeneratedColumn<String> careRecordId = GeneratedColumn<String>(
    'care_record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'UNIQUE REFERENCES care_record_rows (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _observationMeta = const VerificationMeta(
    'observation',
  );
  @override
  late final GeneratedColumn<String> observation = GeneratedColumn<String>(
    'observation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _needMeta = const VerificationMeta('need');
  @override
  late final GeneratedColumn<String> need = GeneratedColumn<String>(
    'need',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _whatHelpedMeta = const VerificationMeta(
    'whatHelped',
  );
  @override
  late final GeneratedColumn<String> whatHelped = GeneratedColumn<String>(
    'what_helped',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _futureSelfNoteMeta = const VerificationMeta(
    'futureSelfNote',
  );
  @override
  late final GeneratedColumn<String> futureSelfNote = GeneratedColumn<String>(
    'future_self_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    careRecordId,
    mode,
    observation,
    need,
    whatHelped,
    futureSelfNote,
    createdAtMillis,
    updatedAtMillis,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'care_reflection_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<CareReflectionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('care_record_id')) {
      context.handle(
        _careRecordIdMeta,
        careRecordId.isAcceptableOrUnknown(
          data['care_record_id']!,
          _careRecordIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_careRecordIdMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('observation')) {
      context.handle(
        _observationMeta,
        observation.isAcceptableOrUnknown(
          data['observation']!,
          _observationMeta,
        ),
      );
    }
    if (data.containsKey('need')) {
      context.handle(
        _needMeta,
        need.isAcceptableOrUnknown(data['need']!, _needMeta),
      );
    }
    if (data.containsKey('what_helped')) {
      context.handle(
        _whatHelpedMeta,
        whatHelped.isAcceptableOrUnknown(data['what_helped']!, _whatHelpedMeta),
      );
    }
    if (data.containsKey('future_self_note')) {
      context.handle(
        _futureSelfNoteMeta,
        futureSelfNote.isAcceptableOrUnknown(
          data['future_self_note']!,
          _futureSelfNoteMeta,
        ),
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
  CareReflectionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CareReflectionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      careRecordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}care_record_id'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      observation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}observation'],
      ),
      need: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}need'],
      ),
      whatHelped: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}what_helped'],
      ),
      futureSelfNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}future_self_note'],
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
  $CareReflectionRowsTable createAlias(String alias) {
    return $CareReflectionRowsTable(attachedDatabase, alias);
  }
}

class CareReflectionRow extends DataClass
    implements Insertable<CareReflectionRow> {
  final String id;
  final String careRecordId;
  final String mode;
  final String? observation;
  final String? need;
  final String? whatHelped;
  final String? futureSelfNote;
  final int createdAtMillis;
  final int updatedAtMillis;
  const CareReflectionRow({
    required this.id,
    required this.careRecordId,
    required this.mode,
    this.observation,
    this.need,
    this.whatHelped,
    this.futureSelfNote,
    required this.createdAtMillis,
    required this.updatedAtMillis,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['care_record_id'] = Variable<String>(careRecordId);
    map['mode'] = Variable<String>(mode);
    if (!nullToAbsent || observation != null) {
      map['observation'] = Variable<String>(observation);
    }
    if (!nullToAbsent || need != null) {
      map['need'] = Variable<String>(need);
    }
    if (!nullToAbsent || whatHelped != null) {
      map['what_helped'] = Variable<String>(whatHelped);
    }
    if (!nullToAbsent || futureSelfNote != null) {
      map['future_self_note'] = Variable<String>(futureSelfNote);
    }
    map['created_at_millis'] = Variable<int>(createdAtMillis);
    map['updated_at_millis'] = Variable<int>(updatedAtMillis);
    return map;
  }

  CareReflectionRowsCompanion toCompanion(bool nullToAbsent) {
    return CareReflectionRowsCompanion(
      id: Value(id),
      careRecordId: Value(careRecordId),
      mode: Value(mode),
      observation: observation == null && nullToAbsent
          ? const Value.absent()
          : Value(observation),
      need: need == null && nullToAbsent ? const Value.absent() : Value(need),
      whatHelped: whatHelped == null && nullToAbsent
          ? const Value.absent()
          : Value(whatHelped),
      futureSelfNote: futureSelfNote == null && nullToAbsent
          ? const Value.absent()
          : Value(futureSelfNote),
      createdAtMillis: Value(createdAtMillis),
      updatedAtMillis: Value(updatedAtMillis),
    );
  }

  factory CareReflectionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CareReflectionRow(
      id: serializer.fromJson<String>(json['id']),
      careRecordId: serializer.fromJson<String>(json['careRecordId']),
      mode: serializer.fromJson<String>(json['mode']),
      observation: serializer.fromJson<String?>(json['observation']),
      need: serializer.fromJson<String?>(json['need']),
      whatHelped: serializer.fromJson<String?>(json['whatHelped']),
      futureSelfNote: serializer.fromJson<String?>(json['futureSelfNote']),
      createdAtMillis: serializer.fromJson<int>(json['createdAtMillis']),
      updatedAtMillis: serializer.fromJson<int>(json['updatedAtMillis']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'careRecordId': serializer.toJson<String>(careRecordId),
      'mode': serializer.toJson<String>(mode),
      'observation': serializer.toJson<String?>(observation),
      'need': serializer.toJson<String?>(need),
      'whatHelped': serializer.toJson<String?>(whatHelped),
      'futureSelfNote': serializer.toJson<String?>(futureSelfNote),
      'createdAtMillis': serializer.toJson<int>(createdAtMillis),
      'updatedAtMillis': serializer.toJson<int>(updatedAtMillis),
    };
  }

  CareReflectionRow copyWith({
    String? id,
    String? careRecordId,
    String? mode,
    Value<String?> observation = const Value.absent(),
    Value<String?> need = const Value.absent(),
    Value<String?> whatHelped = const Value.absent(),
    Value<String?> futureSelfNote = const Value.absent(),
    int? createdAtMillis,
    int? updatedAtMillis,
  }) => CareReflectionRow(
    id: id ?? this.id,
    careRecordId: careRecordId ?? this.careRecordId,
    mode: mode ?? this.mode,
    observation: observation.present ? observation.value : this.observation,
    need: need.present ? need.value : this.need,
    whatHelped: whatHelped.present ? whatHelped.value : this.whatHelped,
    futureSelfNote: futureSelfNote.present
        ? futureSelfNote.value
        : this.futureSelfNote,
    createdAtMillis: createdAtMillis ?? this.createdAtMillis,
    updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
  );
  CareReflectionRow copyWithCompanion(CareReflectionRowsCompanion data) {
    return CareReflectionRow(
      id: data.id.present ? data.id.value : this.id,
      careRecordId: data.careRecordId.present
          ? data.careRecordId.value
          : this.careRecordId,
      mode: data.mode.present ? data.mode.value : this.mode,
      observation: data.observation.present
          ? data.observation.value
          : this.observation,
      need: data.need.present ? data.need.value : this.need,
      whatHelped: data.whatHelped.present
          ? data.whatHelped.value
          : this.whatHelped,
      futureSelfNote: data.futureSelfNote.present
          ? data.futureSelfNote.value
          : this.futureSelfNote,
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
    return (StringBuffer('CareReflectionRow(')
          ..write('id: $id, ')
          ..write('careRecordId: $careRecordId, ')
          ..write('mode: $mode, ')
          ..write('observation: $observation, ')
          ..write('need: $need, ')
          ..write('whatHelped: $whatHelped, ')
          ..write('futureSelfNote: $futureSelfNote, ')
          ..write('createdAtMillis: $createdAtMillis, ')
          ..write('updatedAtMillis: $updatedAtMillis')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    careRecordId,
    mode,
    observation,
    need,
    whatHelped,
    futureSelfNote,
    createdAtMillis,
    updatedAtMillis,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CareReflectionRow &&
          other.id == this.id &&
          other.careRecordId == this.careRecordId &&
          other.mode == this.mode &&
          other.observation == this.observation &&
          other.need == this.need &&
          other.whatHelped == this.whatHelped &&
          other.futureSelfNote == this.futureSelfNote &&
          other.createdAtMillis == this.createdAtMillis &&
          other.updatedAtMillis == this.updatedAtMillis);
}

class CareReflectionRowsCompanion extends UpdateCompanion<CareReflectionRow> {
  final Value<String> id;
  final Value<String> careRecordId;
  final Value<String> mode;
  final Value<String?> observation;
  final Value<String?> need;
  final Value<String?> whatHelped;
  final Value<String?> futureSelfNote;
  final Value<int> createdAtMillis;
  final Value<int> updatedAtMillis;
  final Value<int> rowid;
  const CareReflectionRowsCompanion({
    this.id = const Value.absent(),
    this.careRecordId = const Value.absent(),
    this.mode = const Value.absent(),
    this.observation = const Value.absent(),
    this.need = const Value.absent(),
    this.whatHelped = const Value.absent(),
    this.futureSelfNote = const Value.absent(),
    this.createdAtMillis = const Value.absent(),
    this.updatedAtMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CareReflectionRowsCompanion.insert({
    required String id,
    required String careRecordId,
    required String mode,
    this.observation = const Value.absent(),
    this.need = const Value.absent(),
    this.whatHelped = const Value.absent(),
    this.futureSelfNote = const Value.absent(),
    required int createdAtMillis,
    required int updatedAtMillis,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       careRecordId = Value(careRecordId),
       mode = Value(mode),
       createdAtMillis = Value(createdAtMillis),
       updatedAtMillis = Value(updatedAtMillis);
  static Insertable<CareReflectionRow> custom({
    Expression<String>? id,
    Expression<String>? careRecordId,
    Expression<String>? mode,
    Expression<String>? observation,
    Expression<String>? need,
    Expression<String>? whatHelped,
    Expression<String>? futureSelfNote,
    Expression<int>? createdAtMillis,
    Expression<int>? updatedAtMillis,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (careRecordId != null) 'care_record_id': careRecordId,
      if (mode != null) 'mode': mode,
      if (observation != null) 'observation': observation,
      if (need != null) 'need': need,
      if (whatHelped != null) 'what_helped': whatHelped,
      if (futureSelfNote != null) 'future_self_note': futureSelfNote,
      if (createdAtMillis != null) 'created_at_millis': createdAtMillis,
      if (updatedAtMillis != null) 'updated_at_millis': updatedAtMillis,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CareReflectionRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? careRecordId,
    Value<String>? mode,
    Value<String?>? observation,
    Value<String?>? need,
    Value<String?>? whatHelped,
    Value<String?>? futureSelfNote,
    Value<int>? createdAtMillis,
    Value<int>? updatedAtMillis,
    Value<int>? rowid,
  }) {
    return CareReflectionRowsCompanion(
      id: id ?? this.id,
      careRecordId: careRecordId ?? this.careRecordId,
      mode: mode ?? this.mode,
      observation: observation ?? this.observation,
      need: need ?? this.need,
      whatHelped: whatHelped ?? this.whatHelped,
      futureSelfNote: futureSelfNote ?? this.futureSelfNote,
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
    if (careRecordId.present) {
      map['care_record_id'] = Variable<String>(careRecordId.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (observation.present) {
      map['observation'] = Variable<String>(observation.value);
    }
    if (need.present) {
      map['need'] = Variable<String>(need.value);
    }
    if (whatHelped.present) {
      map['what_helped'] = Variable<String>(whatHelped.value);
    }
    if (futureSelfNote.present) {
      map['future_self_note'] = Variable<String>(futureSelfNote.value);
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
    return (StringBuffer('CareReflectionRowsCompanion(')
          ..write('id: $id, ')
          ..write('careRecordId: $careRecordId, ')
          ..write('mode: $mode, ')
          ..write('observation: $observation, ')
          ..write('need: $need, ')
          ..write('whatHelped: $whatHelped, ')
          ..write('futureSelfNote: $futureSelfNote, ')
          ..write('createdAtMillis: $createdAtMillis, ')
          ..write('updatedAtMillis: $updatedAtMillis, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CycleReflectionRowsTable extends CycleReflectionRows
    with TableInfo<$CycleReflectionRowsTable, CycleReflectionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CycleReflectionRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startingPeriodIdMeta = const VerificationMeta(
    'startingPeriodId',
  );
  @override
  late final GeneratedColumn<String> startingPeriodId = GeneratedColumn<String>(
    'starting_period_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES period_rows (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _cycleStartDayMeta = const VerificationMeta(
    'cycleStartDay',
  );
  @override
  late final GeneratedColumn<int> cycleStartDay = GeneratedColumn<int>(
    'cycle_start_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _observationMeta = const VerificationMeta(
    'observation',
  );
  @override
  late final GeneratedColumn<String> observation = GeneratedColumn<String>(
    'observation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _needMeta = const VerificationMeta('need');
  @override
  late final GeneratedColumn<String> need = GeneratedColumn<String>(
    'need',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _whatHelpedMeta = const VerificationMeta(
    'whatHelped',
  );
  @override
  late final GeneratedColumn<String> whatHelped = GeneratedColumn<String>(
    'what_helped',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _futureSelfNoteMeta = const VerificationMeta(
    'futureSelfNote',
  );
  @override
  late final GeneratedColumn<String> futureSelfNote = GeneratedColumn<String>(
    'future_self_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    startingPeriodId,
    cycleStartDay,
    observation,
    need,
    whatHelped,
    futureSelfNote,
    createdAtMillis,
    updatedAtMillis,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cycle_reflection_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<CycleReflectionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('starting_period_id')) {
      context.handle(
        _startingPeriodIdMeta,
        startingPeriodId.isAcceptableOrUnknown(
          data['starting_period_id']!,
          _startingPeriodIdMeta,
        ),
      );
    }
    if (data.containsKey('cycle_start_day')) {
      context.handle(
        _cycleStartDayMeta,
        cycleStartDay.isAcceptableOrUnknown(
          data['cycle_start_day']!,
          _cycleStartDayMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_cycleStartDayMeta);
    }
    if (data.containsKey('observation')) {
      context.handle(
        _observationMeta,
        observation.isAcceptableOrUnknown(
          data['observation']!,
          _observationMeta,
        ),
      );
    }
    if (data.containsKey('need')) {
      context.handle(
        _needMeta,
        need.isAcceptableOrUnknown(data['need']!, _needMeta),
      );
    }
    if (data.containsKey('what_helped')) {
      context.handle(
        _whatHelpedMeta,
        whatHelped.isAcceptableOrUnknown(data['what_helped']!, _whatHelpedMeta),
      );
    }
    if (data.containsKey('future_self_note')) {
      context.handle(
        _futureSelfNoteMeta,
        futureSelfNote.isAcceptableOrUnknown(
          data['future_self_note']!,
          _futureSelfNoteMeta,
        ),
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
  CycleReflectionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CycleReflectionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      startingPeriodId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}starting_period_id'],
      ),
      cycleStartDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cycle_start_day'],
      )!,
      observation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}observation'],
      ),
      need: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}need'],
      ),
      whatHelped: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}what_helped'],
      ),
      futureSelfNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}future_self_note'],
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
  $CycleReflectionRowsTable createAlias(String alias) {
    return $CycleReflectionRowsTable(attachedDatabase, alias);
  }
}

class CycleReflectionRow extends DataClass
    implements Insertable<CycleReflectionRow> {
  final String id;
  final String? startingPeriodId;
  final int cycleStartDay;
  final String? observation;
  final String? need;
  final String? whatHelped;
  final String? futureSelfNote;
  final int createdAtMillis;
  final int updatedAtMillis;
  const CycleReflectionRow({
    required this.id,
    this.startingPeriodId,
    required this.cycleStartDay,
    this.observation,
    this.need,
    this.whatHelped,
    this.futureSelfNote,
    required this.createdAtMillis,
    required this.updatedAtMillis,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || startingPeriodId != null) {
      map['starting_period_id'] = Variable<String>(startingPeriodId);
    }
    map['cycle_start_day'] = Variable<int>(cycleStartDay);
    if (!nullToAbsent || observation != null) {
      map['observation'] = Variable<String>(observation);
    }
    if (!nullToAbsent || need != null) {
      map['need'] = Variable<String>(need);
    }
    if (!nullToAbsent || whatHelped != null) {
      map['what_helped'] = Variable<String>(whatHelped);
    }
    if (!nullToAbsent || futureSelfNote != null) {
      map['future_self_note'] = Variable<String>(futureSelfNote);
    }
    map['created_at_millis'] = Variable<int>(createdAtMillis);
    map['updated_at_millis'] = Variable<int>(updatedAtMillis);
    return map;
  }

  CycleReflectionRowsCompanion toCompanion(bool nullToAbsent) {
    return CycleReflectionRowsCompanion(
      id: Value(id),
      startingPeriodId: startingPeriodId == null && nullToAbsent
          ? const Value.absent()
          : Value(startingPeriodId),
      cycleStartDay: Value(cycleStartDay),
      observation: observation == null && nullToAbsent
          ? const Value.absent()
          : Value(observation),
      need: need == null && nullToAbsent ? const Value.absent() : Value(need),
      whatHelped: whatHelped == null && nullToAbsent
          ? const Value.absent()
          : Value(whatHelped),
      futureSelfNote: futureSelfNote == null && nullToAbsent
          ? const Value.absent()
          : Value(futureSelfNote),
      createdAtMillis: Value(createdAtMillis),
      updatedAtMillis: Value(updatedAtMillis),
    );
  }

  factory CycleReflectionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CycleReflectionRow(
      id: serializer.fromJson<String>(json['id']),
      startingPeriodId: serializer.fromJson<String?>(json['startingPeriodId']),
      cycleStartDay: serializer.fromJson<int>(json['cycleStartDay']),
      observation: serializer.fromJson<String?>(json['observation']),
      need: serializer.fromJson<String?>(json['need']),
      whatHelped: serializer.fromJson<String?>(json['whatHelped']),
      futureSelfNote: serializer.fromJson<String?>(json['futureSelfNote']),
      createdAtMillis: serializer.fromJson<int>(json['createdAtMillis']),
      updatedAtMillis: serializer.fromJson<int>(json['updatedAtMillis']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'startingPeriodId': serializer.toJson<String?>(startingPeriodId),
      'cycleStartDay': serializer.toJson<int>(cycleStartDay),
      'observation': serializer.toJson<String?>(observation),
      'need': serializer.toJson<String?>(need),
      'whatHelped': serializer.toJson<String?>(whatHelped),
      'futureSelfNote': serializer.toJson<String?>(futureSelfNote),
      'createdAtMillis': serializer.toJson<int>(createdAtMillis),
      'updatedAtMillis': serializer.toJson<int>(updatedAtMillis),
    };
  }

  CycleReflectionRow copyWith({
    String? id,
    Value<String?> startingPeriodId = const Value.absent(),
    int? cycleStartDay,
    Value<String?> observation = const Value.absent(),
    Value<String?> need = const Value.absent(),
    Value<String?> whatHelped = const Value.absent(),
    Value<String?> futureSelfNote = const Value.absent(),
    int? createdAtMillis,
    int? updatedAtMillis,
  }) => CycleReflectionRow(
    id: id ?? this.id,
    startingPeriodId: startingPeriodId.present
        ? startingPeriodId.value
        : this.startingPeriodId,
    cycleStartDay: cycleStartDay ?? this.cycleStartDay,
    observation: observation.present ? observation.value : this.observation,
    need: need.present ? need.value : this.need,
    whatHelped: whatHelped.present ? whatHelped.value : this.whatHelped,
    futureSelfNote: futureSelfNote.present
        ? futureSelfNote.value
        : this.futureSelfNote,
    createdAtMillis: createdAtMillis ?? this.createdAtMillis,
    updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
  );
  CycleReflectionRow copyWithCompanion(CycleReflectionRowsCompanion data) {
    return CycleReflectionRow(
      id: data.id.present ? data.id.value : this.id,
      startingPeriodId: data.startingPeriodId.present
          ? data.startingPeriodId.value
          : this.startingPeriodId,
      cycleStartDay: data.cycleStartDay.present
          ? data.cycleStartDay.value
          : this.cycleStartDay,
      observation: data.observation.present
          ? data.observation.value
          : this.observation,
      need: data.need.present ? data.need.value : this.need,
      whatHelped: data.whatHelped.present
          ? data.whatHelped.value
          : this.whatHelped,
      futureSelfNote: data.futureSelfNote.present
          ? data.futureSelfNote.value
          : this.futureSelfNote,
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
    return (StringBuffer('CycleReflectionRow(')
          ..write('id: $id, ')
          ..write('startingPeriodId: $startingPeriodId, ')
          ..write('cycleStartDay: $cycleStartDay, ')
          ..write('observation: $observation, ')
          ..write('need: $need, ')
          ..write('whatHelped: $whatHelped, ')
          ..write('futureSelfNote: $futureSelfNote, ')
          ..write('createdAtMillis: $createdAtMillis, ')
          ..write('updatedAtMillis: $updatedAtMillis')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    startingPeriodId,
    cycleStartDay,
    observation,
    need,
    whatHelped,
    futureSelfNote,
    createdAtMillis,
    updatedAtMillis,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CycleReflectionRow &&
          other.id == this.id &&
          other.startingPeriodId == this.startingPeriodId &&
          other.cycleStartDay == this.cycleStartDay &&
          other.observation == this.observation &&
          other.need == this.need &&
          other.whatHelped == this.whatHelped &&
          other.futureSelfNote == this.futureSelfNote &&
          other.createdAtMillis == this.createdAtMillis &&
          other.updatedAtMillis == this.updatedAtMillis);
}

class CycleReflectionRowsCompanion extends UpdateCompanion<CycleReflectionRow> {
  final Value<String> id;
  final Value<String?> startingPeriodId;
  final Value<int> cycleStartDay;
  final Value<String?> observation;
  final Value<String?> need;
  final Value<String?> whatHelped;
  final Value<String?> futureSelfNote;
  final Value<int> createdAtMillis;
  final Value<int> updatedAtMillis;
  final Value<int> rowid;
  const CycleReflectionRowsCompanion({
    this.id = const Value.absent(),
    this.startingPeriodId = const Value.absent(),
    this.cycleStartDay = const Value.absent(),
    this.observation = const Value.absent(),
    this.need = const Value.absent(),
    this.whatHelped = const Value.absent(),
    this.futureSelfNote = const Value.absent(),
    this.createdAtMillis = const Value.absent(),
    this.updatedAtMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CycleReflectionRowsCompanion.insert({
    required String id,
    this.startingPeriodId = const Value.absent(),
    required int cycleStartDay,
    this.observation = const Value.absent(),
    this.need = const Value.absent(),
    this.whatHelped = const Value.absent(),
    this.futureSelfNote = const Value.absent(),
    required int createdAtMillis,
    required int updatedAtMillis,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       cycleStartDay = Value(cycleStartDay),
       createdAtMillis = Value(createdAtMillis),
       updatedAtMillis = Value(updatedAtMillis);
  static Insertable<CycleReflectionRow> custom({
    Expression<String>? id,
    Expression<String>? startingPeriodId,
    Expression<int>? cycleStartDay,
    Expression<String>? observation,
    Expression<String>? need,
    Expression<String>? whatHelped,
    Expression<String>? futureSelfNote,
    Expression<int>? createdAtMillis,
    Expression<int>? updatedAtMillis,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startingPeriodId != null) 'starting_period_id': startingPeriodId,
      if (cycleStartDay != null) 'cycle_start_day': cycleStartDay,
      if (observation != null) 'observation': observation,
      if (need != null) 'need': need,
      if (whatHelped != null) 'what_helped': whatHelped,
      if (futureSelfNote != null) 'future_self_note': futureSelfNote,
      if (createdAtMillis != null) 'created_at_millis': createdAtMillis,
      if (updatedAtMillis != null) 'updated_at_millis': updatedAtMillis,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CycleReflectionRowsCompanion copyWith({
    Value<String>? id,
    Value<String?>? startingPeriodId,
    Value<int>? cycleStartDay,
    Value<String?>? observation,
    Value<String?>? need,
    Value<String?>? whatHelped,
    Value<String?>? futureSelfNote,
    Value<int>? createdAtMillis,
    Value<int>? updatedAtMillis,
    Value<int>? rowid,
  }) {
    return CycleReflectionRowsCompanion(
      id: id ?? this.id,
      startingPeriodId: startingPeriodId ?? this.startingPeriodId,
      cycleStartDay: cycleStartDay ?? this.cycleStartDay,
      observation: observation ?? this.observation,
      need: need ?? this.need,
      whatHelped: whatHelped ?? this.whatHelped,
      futureSelfNote: futureSelfNote ?? this.futureSelfNote,
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
    if (startingPeriodId.present) {
      map['starting_period_id'] = Variable<String>(startingPeriodId.value);
    }
    if (cycleStartDay.present) {
      map['cycle_start_day'] = Variable<int>(cycleStartDay.value);
    }
    if (observation.present) {
      map['observation'] = Variable<String>(observation.value);
    }
    if (need.present) {
      map['need'] = Variable<String>(need.value);
    }
    if (whatHelped.present) {
      map['what_helped'] = Variable<String>(whatHelped.value);
    }
    if (futureSelfNote.present) {
      map['future_self_note'] = Variable<String>(futureSelfNote.value);
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
    return (StringBuffer('CycleReflectionRowsCompanion(')
          ..write('id: $id, ')
          ..write('startingPeriodId: $startingPeriodId, ')
          ..write('cycleStartDay: $cycleStartDay, ')
          ..write('observation: $observation, ')
          ..write('need: $need, ')
          ..write('whatHelped: $whatHelped, ')
          ..write('futureSelfNote: $futureSelfNote, ')
          ..write('createdAtMillis: $createdAtMillis, ')
          ..write('updatedAtMillis: $updatedAtMillis, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HealthRecordRowsTable extends HealthRecordRows
    with TableInfo<$HealthRecordRowsTable, HealthRecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HealthRecordRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _symptomMeta = const VerificationMeta(
    'symptom',
  );
  @override
  late final GeneratedColumn<String> symptom = GeneratedColumn<String>(
    'symptom',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _severityMeta = const VerificationMeta(
    'severity',
  );
  @override
  late final GeneratedColumn<int> severity = GeneratedColumn<int>(
    'severity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _functionalImpactsJsonMeta =
      const VerificationMeta('functionalImpactsJson');
  @override
  late final GeneratedColumn<String> functionalImpactsJson =
      GeneratedColumn<String>(
        'functional_impacts_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _experiencedDayMeta = const VerificationMeta(
    'experiencedDay',
  );
  @override
  late final GeneratedColumn<int> experiencedDay = GeneratedColumn<int>(
    'experienced_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordedAtMillisMeta = const VerificationMeta(
    'recordedAtMillis',
  );
  @override
  late final GeneratedColumn<int> recordedAtMillis = GeneratedColumn<int>(
    'recorded_at_millis',
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
  static const VerificationMeta _provenanceMeta = const VerificationMeta(
    'provenance',
  );
  @override
  late final GeneratedColumn<String> provenance = GeneratedColumn<String>(
    'provenance',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userConfirmedMeta = const VerificationMeta(
    'userConfirmed',
  );
  @override
  late final GeneratedColumn<bool> userConfirmed = GeneratedColumn<bool>(
    'user_confirmed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("user_confirmed" IN (0, 1))',
    ),
  );
  static const VerificationMeta _vocabularyVersionMeta = const VerificationMeta(
    'vocabularyVersion',
  );
  @override
  late final GeneratedColumn<int> vocabularyVersion = GeneratedColumn<int>(
    'vocabulary_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    symptom,
    severity,
    functionalImpactsJson,
    experiencedDay,
    recordedAtMillis,
    updatedAtMillis,
    provenance,
    userConfirmed,
    vocabularyVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'health_record_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<HealthRecordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('symptom')) {
      context.handle(
        _symptomMeta,
        symptom.isAcceptableOrUnknown(data['symptom']!, _symptomMeta),
      );
    } else if (isInserting) {
      context.missing(_symptomMeta);
    }
    if (data.containsKey('severity')) {
      context.handle(
        _severityMeta,
        severity.isAcceptableOrUnknown(data['severity']!, _severityMeta),
      );
    } else if (isInserting) {
      context.missing(_severityMeta);
    }
    if (data.containsKey('functional_impacts_json')) {
      context.handle(
        _functionalImpactsJsonMeta,
        functionalImpactsJson.isAcceptableOrUnknown(
          data['functional_impacts_json']!,
          _functionalImpactsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_functionalImpactsJsonMeta);
    }
    if (data.containsKey('experienced_day')) {
      context.handle(
        _experiencedDayMeta,
        experiencedDay.isAcceptableOrUnknown(
          data['experienced_day']!,
          _experiencedDayMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_experiencedDayMeta);
    }
    if (data.containsKey('recorded_at_millis')) {
      context.handle(
        _recordedAtMillisMeta,
        recordedAtMillis.isAcceptableOrUnknown(
          data['recorded_at_millis']!,
          _recordedAtMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recordedAtMillisMeta);
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
    if (data.containsKey('provenance')) {
      context.handle(
        _provenanceMeta,
        provenance.isAcceptableOrUnknown(data['provenance']!, _provenanceMeta),
      );
    } else if (isInserting) {
      context.missing(_provenanceMeta);
    }
    if (data.containsKey('user_confirmed')) {
      context.handle(
        _userConfirmedMeta,
        userConfirmed.isAcceptableOrUnknown(
          data['user_confirmed']!,
          _userConfirmedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_userConfirmedMeta);
    }
    if (data.containsKey('vocabulary_version')) {
      context.handle(
        _vocabularyVersionMeta,
        vocabularyVersion.isAcceptableOrUnknown(
          data['vocabulary_version']!,
          _vocabularyVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_vocabularyVersionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {symptom, experiencedDay},
  ];
  @override
  HealthRecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HealthRecordRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      symptom: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symptom'],
      )!,
      severity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}severity'],
      )!,
      functionalImpactsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}functional_impacts_json'],
      )!,
      experiencedDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}experienced_day'],
      )!,
      recordedAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recorded_at_millis'],
      )!,
      updatedAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_millis'],
      )!,
      provenance: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provenance'],
      )!,
      userConfirmed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}user_confirmed'],
      )!,
      vocabularyVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}vocabulary_version'],
      )!,
    );
  }

  @override
  $HealthRecordRowsTable createAlias(String alias) {
    return $HealthRecordRowsTable(attachedDatabase, alias);
  }
}

class HealthRecordRow extends DataClass implements Insertable<HealthRecordRow> {
  final String id;
  final String symptom;
  final int severity;
  final String functionalImpactsJson;
  final int experiencedDay;
  final int recordedAtMillis;
  final int updatedAtMillis;
  final String provenance;
  final bool userConfirmed;
  final int vocabularyVersion;
  const HealthRecordRow({
    required this.id,
    required this.symptom,
    required this.severity,
    required this.functionalImpactsJson,
    required this.experiencedDay,
    required this.recordedAtMillis,
    required this.updatedAtMillis,
    required this.provenance,
    required this.userConfirmed,
    required this.vocabularyVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['symptom'] = Variable<String>(symptom);
    map['severity'] = Variable<int>(severity);
    map['functional_impacts_json'] = Variable<String>(functionalImpactsJson);
    map['experienced_day'] = Variable<int>(experiencedDay);
    map['recorded_at_millis'] = Variable<int>(recordedAtMillis);
    map['updated_at_millis'] = Variable<int>(updatedAtMillis);
    map['provenance'] = Variable<String>(provenance);
    map['user_confirmed'] = Variable<bool>(userConfirmed);
    map['vocabulary_version'] = Variable<int>(vocabularyVersion);
    return map;
  }

  HealthRecordRowsCompanion toCompanion(bool nullToAbsent) {
    return HealthRecordRowsCompanion(
      id: Value(id),
      symptom: Value(symptom),
      severity: Value(severity),
      functionalImpactsJson: Value(functionalImpactsJson),
      experiencedDay: Value(experiencedDay),
      recordedAtMillis: Value(recordedAtMillis),
      updatedAtMillis: Value(updatedAtMillis),
      provenance: Value(provenance),
      userConfirmed: Value(userConfirmed),
      vocabularyVersion: Value(vocabularyVersion),
    );
  }

  factory HealthRecordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HealthRecordRow(
      id: serializer.fromJson<String>(json['id']),
      symptom: serializer.fromJson<String>(json['symptom']),
      severity: serializer.fromJson<int>(json['severity']),
      functionalImpactsJson: serializer.fromJson<String>(
        json['functionalImpactsJson'],
      ),
      experiencedDay: serializer.fromJson<int>(json['experiencedDay']),
      recordedAtMillis: serializer.fromJson<int>(json['recordedAtMillis']),
      updatedAtMillis: serializer.fromJson<int>(json['updatedAtMillis']),
      provenance: serializer.fromJson<String>(json['provenance']),
      userConfirmed: serializer.fromJson<bool>(json['userConfirmed']),
      vocabularyVersion: serializer.fromJson<int>(json['vocabularyVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'symptom': serializer.toJson<String>(symptom),
      'severity': serializer.toJson<int>(severity),
      'functionalImpactsJson': serializer.toJson<String>(functionalImpactsJson),
      'experiencedDay': serializer.toJson<int>(experiencedDay),
      'recordedAtMillis': serializer.toJson<int>(recordedAtMillis),
      'updatedAtMillis': serializer.toJson<int>(updatedAtMillis),
      'provenance': serializer.toJson<String>(provenance),
      'userConfirmed': serializer.toJson<bool>(userConfirmed),
      'vocabularyVersion': serializer.toJson<int>(vocabularyVersion),
    };
  }

  HealthRecordRow copyWith({
    String? id,
    String? symptom,
    int? severity,
    String? functionalImpactsJson,
    int? experiencedDay,
    int? recordedAtMillis,
    int? updatedAtMillis,
    String? provenance,
    bool? userConfirmed,
    int? vocabularyVersion,
  }) => HealthRecordRow(
    id: id ?? this.id,
    symptom: symptom ?? this.symptom,
    severity: severity ?? this.severity,
    functionalImpactsJson: functionalImpactsJson ?? this.functionalImpactsJson,
    experiencedDay: experiencedDay ?? this.experiencedDay,
    recordedAtMillis: recordedAtMillis ?? this.recordedAtMillis,
    updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
    provenance: provenance ?? this.provenance,
    userConfirmed: userConfirmed ?? this.userConfirmed,
    vocabularyVersion: vocabularyVersion ?? this.vocabularyVersion,
  );
  HealthRecordRow copyWithCompanion(HealthRecordRowsCompanion data) {
    return HealthRecordRow(
      id: data.id.present ? data.id.value : this.id,
      symptom: data.symptom.present ? data.symptom.value : this.symptom,
      severity: data.severity.present ? data.severity.value : this.severity,
      functionalImpactsJson: data.functionalImpactsJson.present
          ? data.functionalImpactsJson.value
          : this.functionalImpactsJson,
      experiencedDay: data.experiencedDay.present
          ? data.experiencedDay.value
          : this.experiencedDay,
      recordedAtMillis: data.recordedAtMillis.present
          ? data.recordedAtMillis.value
          : this.recordedAtMillis,
      updatedAtMillis: data.updatedAtMillis.present
          ? data.updatedAtMillis.value
          : this.updatedAtMillis,
      provenance: data.provenance.present
          ? data.provenance.value
          : this.provenance,
      userConfirmed: data.userConfirmed.present
          ? data.userConfirmed.value
          : this.userConfirmed,
      vocabularyVersion: data.vocabularyVersion.present
          ? data.vocabularyVersion.value
          : this.vocabularyVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HealthRecordRow(')
          ..write('id: $id, ')
          ..write('symptom: $symptom, ')
          ..write('severity: $severity, ')
          ..write('functionalImpactsJson: $functionalImpactsJson, ')
          ..write('experiencedDay: $experiencedDay, ')
          ..write('recordedAtMillis: $recordedAtMillis, ')
          ..write('updatedAtMillis: $updatedAtMillis, ')
          ..write('provenance: $provenance, ')
          ..write('userConfirmed: $userConfirmed, ')
          ..write('vocabularyVersion: $vocabularyVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    symptom,
    severity,
    functionalImpactsJson,
    experiencedDay,
    recordedAtMillis,
    updatedAtMillis,
    provenance,
    userConfirmed,
    vocabularyVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HealthRecordRow &&
          other.id == this.id &&
          other.symptom == this.symptom &&
          other.severity == this.severity &&
          other.functionalImpactsJson == this.functionalImpactsJson &&
          other.experiencedDay == this.experiencedDay &&
          other.recordedAtMillis == this.recordedAtMillis &&
          other.updatedAtMillis == this.updatedAtMillis &&
          other.provenance == this.provenance &&
          other.userConfirmed == this.userConfirmed &&
          other.vocabularyVersion == this.vocabularyVersion);
}

class HealthRecordRowsCompanion extends UpdateCompanion<HealthRecordRow> {
  final Value<String> id;
  final Value<String> symptom;
  final Value<int> severity;
  final Value<String> functionalImpactsJson;
  final Value<int> experiencedDay;
  final Value<int> recordedAtMillis;
  final Value<int> updatedAtMillis;
  final Value<String> provenance;
  final Value<bool> userConfirmed;
  final Value<int> vocabularyVersion;
  final Value<int> rowid;
  const HealthRecordRowsCompanion({
    this.id = const Value.absent(),
    this.symptom = const Value.absent(),
    this.severity = const Value.absent(),
    this.functionalImpactsJson = const Value.absent(),
    this.experiencedDay = const Value.absent(),
    this.recordedAtMillis = const Value.absent(),
    this.updatedAtMillis = const Value.absent(),
    this.provenance = const Value.absent(),
    this.userConfirmed = const Value.absent(),
    this.vocabularyVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HealthRecordRowsCompanion.insert({
    required String id,
    required String symptom,
    required int severity,
    required String functionalImpactsJson,
    required int experiencedDay,
    required int recordedAtMillis,
    required int updatedAtMillis,
    required String provenance,
    required bool userConfirmed,
    required int vocabularyVersion,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       symptom = Value(symptom),
       severity = Value(severity),
       functionalImpactsJson = Value(functionalImpactsJson),
       experiencedDay = Value(experiencedDay),
       recordedAtMillis = Value(recordedAtMillis),
       updatedAtMillis = Value(updatedAtMillis),
       provenance = Value(provenance),
       userConfirmed = Value(userConfirmed),
       vocabularyVersion = Value(vocabularyVersion);
  static Insertable<HealthRecordRow> custom({
    Expression<String>? id,
    Expression<String>? symptom,
    Expression<int>? severity,
    Expression<String>? functionalImpactsJson,
    Expression<int>? experiencedDay,
    Expression<int>? recordedAtMillis,
    Expression<int>? updatedAtMillis,
    Expression<String>? provenance,
    Expression<bool>? userConfirmed,
    Expression<int>? vocabularyVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (symptom != null) 'symptom': symptom,
      if (severity != null) 'severity': severity,
      if (functionalImpactsJson != null)
        'functional_impacts_json': functionalImpactsJson,
      if (experiencedDay != null) 'experienced_day': experiencedDay,
      if (recordedAtMillis != null) 'recorded_at_millis': recordedAtMillis,
      if (updatedAtMillis != null) 'updated_at_millis': updatedAtMillis,
      if (provenance != null) 'provenance': provenance,
      if (userConfirmed != null) 'user_confirmed': userConfirmed,
      if (vocabularyVersion != null) 'vocabulary_version': vocabularyVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HealthRecordRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? symptom,
    Value<int>? severity,
    Value<String>? functionalImpactsJson,
    Value<int>? experiencedDay,
    Value<int>? recordedAtMillis,
    Value<int>? updatedAtMillis,
    Value<String>? provenance,
    Value<bool>? userConfirmed,
    Value<int>? vocabularyVersion,
    Value<int>? rowid,
  }) {
    return HealthRecordRowsCompanion(
      id: id ?? this.id,
      symptom: symptom ?? this.symptom,
      severity: severity ?? this.severity,
      functionalImpactsJson:
          functionalImpactsJson ?? this.functionalImpactsJson,
      experiencedDay: experiencedDay ?? this.experiencedDay,
      recordedAtMillis: recordedAtMillis ?? this.recordedAtMillis,
      updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
      provenance: provenance ?? this.provenance,
      userConfirmed: userConfirmed ?? this.userConfirmed,
      vocabularyVersion: vocabularyVersion ?? this.vocabularyVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (symptom.present) {
      map['symptom'] = Variable<String>(symptom.value);
    }
    if (severity.present) {
      map['severity'] = Variable<int>(severity.value);
    }
    if (functionalImpactsJson.present) {
      map['functional_impacts_json'] = Variable<String>(
        functionalImpactsJson.value,
      );
    }
    if (experiencedDay.present) {
      map['experienced_day'] = Variable<int>(experiencedDay.value);
    }
    if (recordedAtMillis.present) {
      map['recorded_at_millis'] = Variable<int>(recordedAtMillis.value);
    }
    if (updatedAtMillis.present) {
      map['updated_at_millis'] = Variable<int>(updatedAtMillis.value);
    }
    if (provenance.present) {
      map['provenance'] = Variable<String>(provenance.value);
    }
    if (userConfirmed.present) {
      map['user_confirmed'] = Variable<bool>(userConfirmed.value);
    }
    if (vocabularyVersion.present) {
      map['vocabulary_version'] = Variable<int>(vocabularyVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HealthRecordRowsCompanion(')
          ..write('id: $id, ')
          ..write('symptom: $symptom, ')
          ..write('severity: $severity, ')
          ..write('functionalImpactsJson: $functionalImpactsJson, ')
          ..write('experiencedDay: $experiencedDay, ')
          ..write('recordedAtMillis: $recordedAtMillis, ')
          ..write('updatedAtMillis: $updatedAtMillis, ')
          ..write('provenance: $provenance, ')
          ..write('userConfirmed: $userConfirmed, ')
          ..write('vocabularyVersion: $vocabularyVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CaptureNoteRowsTable extends CaptureNoteRows
    with TableInfo<$CaptureNoteRowsTable, CaptureNoteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CaptureNoteRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  @override
  List<GeneratedColumn> get $columns => [id, content, source, createdAtMillis];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'capture_note_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<CaptureNoteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CaptureNoteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CaptureNoteRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      createdAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_millis'],
      )!,
    );
  }

  @override
  $CaptureNoteRowsTable createAlias(String alias) {
    return $CaptureNoteRowsTable(attachedDatabase, alias);
  }
}

class CaptureNoteRow extends DataClass implements Insertable<CaptureNoteRow> {
  final String id;
  final String content;
  final String source;
  final int createdAtMillis;
  const CaptureNoteRow({
    required this.id,
    required this.content,
    required this.source,
    required this.createdAtMillis,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['content'] = Variable<String>(content);
    map['source'] = Variable<String>(source);
    map['created_at_millis'] = Variable<int>(createdAtMillis);
    return map;
  }

  CaptureNoteRowsCompanion toCompanion(bool nullToAbsent) {
    return CaptureNoteRowsCompanion(
      id: Value(id),
      content: Value(content),
      source: Value(source),
      createdAtMillis: Value(createdAtMillis),
    );
  }

  factory CaptureNoteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CaptureNoteRow(
      id: serializer.fromJson<String>(json['id']),
      content: serializer.fromJson<String>(json['content']),
      source: serializer.fromJson<String>(json['source']),
      createdAtMillis: serializer.fromJson<int>(json['createdAtMillis']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'content': serializer.toJson<String>(content),
      'source': serializer.toJson<String>(source),
      'createdAtMillis': serializer.toJson<int>(createdAtMillis),
    };
  }

  CaptureNoteRow copyWith({
    String? id,
    String? content,
    String? source,
    int? createdAtMillis,
  }) => CaptureNoteRow(
    id: id ?? this.id,
    content: content ?? this.content,
    source: source ?? this.source,
    createdAtMillis: createdAtMillis ?? this.createdAtMillis,
  );
  CaptureNoteRow copyWithCompanion(CaptureNoteRowsCompanion data) {
    return CaptureNoteRow(
      id: data.id.present ? data.id.value : this.id,
      content: data.content.present ? data.content.value : this.content,
      source: data.source.present ? data.source.value : this.source,
      createdAtMillis: data.createdAtMillis.present
          ? data.createdAtMillis.value
          : this.createdAtMillis,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CaptureNoteRow(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('source: $source, ')
          ..write('createdAtMillis: $createdAtMillis')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, content, source, createdAtMillis);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CaptureNoteRow &&
          other.id == this.id &&
          other.content == this.content &&
          other.source == this.source &&
          other.createdAtMillis == this.createdAtMillis);
}

class CaptureNoteRowsCompanion extends UpdateCompanion<CaptureNoteRow> {
  final Value<String> id;
  final Value<String> content;
  final Value<String> source;
  final Value<int> createdAtMillis;
  final Value<int> rowid;
  const CaptureNoteRowsCompanion({
    this.id = const Value.absent(),
    this.content = const Value.absent(),
    this.source = const Value.absent(),
    this.createdAtMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CaptureNoteRowsCompanion.insert({
    required String id,
    required String content,
    required String source,
    required int createdAtMillis,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       content = Value(content),
       source = Value(source),
       createdAtMillis = Value(createdAtMillis);
  static Insertable<CaptureNoteRow> custom({
    Expression<String>? id,
    Expression<String>? content,
    Expression<String>? source,
    Expression<int>? createdAtMillis,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (content != null) 'content': content,
      if (source != null) 'source': source,
      if (createdAtMillis != null) 'created_at_millis': createdAtMillis,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CaptureNoteRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? content,
    Value<String>? source,
    Value<int>? createdAtMillis,
    Value<int>? rowid,
  }) {
    return CaptureNoteRowsCompanion(
      id: id ?? this.id,
      content: content ?? this.content,
      source: source ?? this.source,
      createdAtMillis: createdAtMillis ?? this.createdAtMillis,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (createdAtMillis.present) {
      map['created_at_millis'] = Variable<int>(createdAtMillis.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CaptureNoteRowsCompanion(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('source: $source, ')
          ..write('createdAtMillis: $createdAtMillis, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MomentCheckInRowsTable extends MomentCheckInRows
    with TableInfo<$MomentCheckInRowsTable, MomentCheckInRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MomentCheckInRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMillisMeta = const VerificationMeta(
    'occurredAtMillis',
  );
  @override
  late final GeneratedColumn<int> occurredAtMillis = GeneratedColumn<int>(
    'occurred_at_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    state,
    occurredAtMillis,
    createdAtMillis,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'moment_check_in_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<MomentCheckInRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('occurred_at_millis')) {
      context.handle(
        _occurredAtMillisMeta,
        occurredAtMillis.isAcceptableOrUnknown(
          data['occurred_at_millis']!,
          _occurredAtMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMillisMeta);
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MomentCheckInRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MomentCheckInRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      occurredAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}occurred_at_millis'],
      )!,
      createdAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_millis'],
      )!,
    );
  }

  @override
  $MomentCheckInRowsTable createAlias(String alias) {
    return $MomentCheckInRowsTable(attachedDatabase, alias);
  }
}

class MomentCheckInRow extends DataClass
    implements Insertable<MomentCheckInRow> {
  final String id;
  final String state;
  final int occurredAtMillis;
  final int createdAtMillis;
  const MomentCheckInRow({
    required this.id,
    required this.state,
    required this.occurredAtMillis,
    required this.createdAtMillis,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['state'] = Variable<String>(state);
    map['occurred_at_millis'] = Variable<int>(occurredAtMillis);
    map['created_at_millis'] = Variable<int>(createdAtMillis);
    return map;
  }

  MomentCheckInRowsCompanion toCompanion(bool nullToAbsent) {
    return MomentCheckInRowsCompanion(
      id: Value(id),
      state: Value(state),
      occurredAtMillis: Value(occurredAtMillis),
      createdAtMillis: Value(createdAtMillis),
    );
  }

  factory MomentCheckInRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MomentCheckInRow(
      id: serializer.fromJson<String>(json['id']),
      state: serializer.fromJson<String>(json['state']),
      occurredAtMillis: serializer.fromJson<int>(json['occurredAtMillis']),
      createdAtMillis: serializer.fromJson<int>(json['createdAtMillis']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'state': serializer.toJson<String>(state),
      'occurredAtMillis': serializer.toJson<int>(occurredAtMillis),
      'createdAtMillis': serializer.toJson<int>(createdAtMillis),
    };
  }

  MomentCheckInRow copyWith({
    String? id,
    String? state,
    int? occurredAtMillis,
    int? createdAtMillis,
  }) => MomentCheckInRow(
    id: id ?? this.id,
    state: state ?? this.state,
    occurredAtMillis: occurredAtMillis ?? this.occurredAtMillis,
    createdAtMillis: createdAtMillis ?? this.createdAtMillis,
  );
  MomentCheckInRow copyWithCompanion(MomentCheckInRowsCompanion data) {
    return MomentCheckInRow(
      id: data.id.present ? data.id.value : this.id,
      state: data.state.present ? data.state.value : this.state,
      occurredAtMillis: data.occurredAtMillis.present
          ? data.occurredAtMillis.value
          : this.occurredAtMillis,
      createdAtMillis: data.createdAtMillis.present
          ? data.createdAtMillis.value
          : this.createdAtMillis,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MomentCheckInRow(')
          ..write('id: $id, ')
          ..write('state: $state, ')
          ..write('occurredAtMillis: $occurredAtMillis, ')
          ..write('createdAtMillis: $createdAtMillis')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, state, occurredAtMillis, createdAtMillis);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MomentCheckInRow &&
          other.id == this.id &&
          other.state == this.state &&
          other.occurredAtMillis == this.occurredAtMillis &&
          other.createdAtMillis == this.createdAtMillis);
}

class MomentCheckInRowsCompanion extends UpdateCompanion<MomentCheckInRow> {
  final Value<String> id;
  final Value<String> state;
  final Value<int> occurredAtMillis;
  final Value<int> createdAtMillis;
  final Value<int> rowid;
  const MomentCheckInRowsCompanion({
    this.id = const Value.absent(),
    this.state = const Value.absent(),
    this.occurredAtMillis = const Value.absent(),
    this.createdAtMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MomentCheckInRowsCompanion.insert({
    required String id,
    required String state,
    required int occurredAtMillis,
    required int createdAtMillis,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       state = Value(state),
       occurredAtMillis = Value(occurredAtMillis),
       createdAtMillis = Value(createdAtMillis);
  static Insertable<MomentCheckInRow> custom({
    Expression<String>? id,
    Expression<String>? state,
    Expression<int>? occurredAtMillis,
    Expression<int>? createdAtMillis,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (state != null) 'state': state,
      if (occurredAtMillis != null) 'occurred_at_millis': occurredAtMillis,
      if (createdAtMillis != null) 'created_at_millis': createdAtMillis,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MomentCheckInRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? state,
    Value<int>? occurredAtMillis,
    Value<int>? createdAtMillis,
    Value<int>? rowid,
  }) {
    return MomentCheckInRowsCompanion(
      id: id ?? this.id,
      state: state ?? this.state,
      occurredAtMillis: occurredAtMillis ?? this.occurredAtMillis,
      createdAtMillis: createdAtMillis ?? this.createdAtMillis,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (occurredAtMillis.present) {
      map['occurred_at_millis'] = Variable<int>(occurredAtMillis.value);
    }
    if (createdAtMillis.present) {
      map['created_at_millis'] = Variable<int>(createdAtMillis.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MomentCheckInRowsCompanion(')
          ..write('id: $id, ')
          ..write('state: $state, ')
          ..write('occurredAtMillis: $occurredAtMillis, ')
          ..write('createdAtMillis: $createdAtMillis, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PreparationPlanRowsTable extends PreparationPlanRows
    with TableInfo<$PreparationPlanRowsTable, PreparationPlanRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PreparationPlanRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _evidenceFingerprintMeta =
      const VerificationMeta('evidenceFingerprint');
  @override
  late final GeneratedColumn<String> evidenceFingerprint =
      GeneratedColumn<String>(
        'evidence_fingerprint',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _sourceRecordIdsJsonMeta =
      const VerificationMeta('sourceRecordIdsJson');
  @override
  late final GeneratedColumn<String> sourceRecordIdsJson =
      GeneratedColumn<String>(
        'source_record_ids_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _includeCareMeta = const VerificationMeta(
    'includeCare',
  );
  @override
  late final GeneratedColumn<bool> includeCare = GeneratedColumn<bool>(
    'include_care',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("include_care" IN (0, 1))',
    ),
  );
  static const VerificationMeta _careActionIdMeta = const VerificationMeta(
    'careActionId',
  );
  @override
  late final GeneratedColumn<String> careActionId = GeneratedColumn<String>(
    'care_action_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _careActionLabelMeta = const VerificationMeta(
    'careActionLabel',
  );
  @override
  late final GeneratedColumn<String> careActionLabel = GeneratedColumn<String>(
    'care_action_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _careModeMeta = const VerificationMeta(
    'careMode',
  );
  @override
  late final GeneratedColumn<String> careMode = GeneratedColumn<String>(
    'care_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _betterCountMeta = const VerificationMeta(
    'betterCount',
  );
  @override
  late final GeneratedColumn<int> betterCount = GeneratedColumn<int>(
    'better_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sameCountMeta = const VerificationMeta(
    'sameCount',
  );
  @override
  late final GeneratedColumn<int> sameCount = GeneratedColumn<int>(
    'same_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _worseCountMeta = const VerificationMeta(
    'worseCount',
  );
  @override
  late final GeneratedColumn<int> worseCount = GeneratedColumn<int>(
    'worse_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteTextMeta = const VerificationMeta(
    'noteText',
  );
  @override
  late final GeneratedColumn<String> noteText = GeneratedColumn<String>(
    'note_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _personalTextMeta = const VerificationMeta(
    'personalText',
  );
  @override
  late final GeneratedColumn<String> personalText = GeneratedColumn<String>(
    'personal_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    status,
    evidenceFingerprint,
    sourceRecordIdsJson,
    includeCare,
    careActionId,
    careActionLabel,
    careMode,
    betterCount,
    sameCount,
    worseCount,
    noteText,
    personalText,
    createdAtMillis,
    updatedAtMillis,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'preparation_plan_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<PreparationPlanRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('evidence_fingerprint')) {
      context.handle(
        _evidenceFingerprintMeta,
        evidenceFingerprint.isAcceptableOrUnknown(
          data['evidence_fingerprint']!,
          _evidenceFingerprintMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_evidenceFingerprintMeta);
    }
    if (data.containsKey('source_record_ids_json')) {
      context.handle(
        _sourceRecordIdsJsonMeta,
        sourceRecordIdsJson.isAcceptableOrUnknown(
          data['source_record_ids_json']!,
          _sourceRecordIdsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceRecordIdsJsonMeta);
    }
    if (data.containsKey('include_care')) {
      context.handle(
        _includeCareMeta,
        includeCare.isAcceptableOrUnknown(
          data['include_care']!,
          _includeCareMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_includeCareMeta);
    }
    if (data.containsKey('care_action_id')) {
      context.handle(
        _careActionIdMeta,
        careActionId.isAcceptableOrUnknown(
          data['care_action_id']!,
          _careActionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_careActionIdMeta);
    }
    if (data.containsKey('care_action_label')) {
      context.handle(
        _careActionLabelMeta,
        careActionLabel.isAcceptableOrUnknown(
          data['care_action_label']!,
          _careActionLabelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_careActionLabelMeta);
    }
    if (data.containsKey('care_mode')) {
      context.handle(
        _careModeMeta,
        careMode.isAcceptableOrUnknown(data['care_mode']!, _careModeMeta),
      );
    } else if (isInserting) {
      context.missing(_careModeMeta);
    }
    if (data.containsKey('better_count')) {
      context.handle(
        _betterCountMeta,
        betterCount.isAcceptableOrUnknown(
          data['better_count']!,
          _betterCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_betterCountMeta);
    }
    if (data.containsKey('same_count')) {
      context.handle(
        _sameCountMeta,
        sameCount.isAcceptableOrUnknown(data['same_count']!, _sameCountMeta),
      );
    } else if (isInserting) {
      context.missing(_sameCountMeta);
    }
    if (data.containsKey('worse_count')) {
      context.handle(
        _worseCountMeta,
        worseCount.isAcceptableOrUnknown(data['worse_count']!, _worseCountMeta),
      );
    } else if (isInserting) {
      context.missing(_worseCountMeta);
    }
    if (data.containsKey('note_text')) {
      context.handle(
        _noteTextMeta,
        noteText.isAcceptableOrUnknown(data['note_text']!, _noteTextMeta),
      );
    }
    if (data.containsKey('personal_text')) {
      context.handle(
        _personalTextMeta,
        personalText.isAcceptableOrUnknown(
          data['personal_text']!,
          _personalTextMeta,
        ),
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
  PreparationPlanRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PreparationPlanRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      evidenceFingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}evidence_fingerprint'],
      )!,
      sourceRecordIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_record_ids_json'],
      )!,
      includeCare: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}include_care'],
      )!,
      careActionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}care_action_id'],
      )!,
      careActionLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}care_action_label'],
      )!,
      careMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}care_mode'],
      )!,
      betterCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}better_count'],
      )!,
      sameCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}same_count'],
      )!,
      worseCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}worse_count'],
      )!,
      noteText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_text'],
      ),
      personalText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}personal_text'],
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
  $PreparationPlanRowsTable createAlias(String alias) {
    return $PreparationPlanRowsTable(attachedDatabase, alias);
  }
}

class PreparationPlanRow extends DataClass
    implements Insertable<PreparationPlanRow> {
  final String id;
  final String status;
  final String evidenceFingerprint;
  final String sourceRecordIdsJson;
  final bool includeCare;
  final String careActionId;
  final String careActionLabel;
  final String careMode;
  final int betterCount;
  final int sameCount;
  final int worseCount;
  final String? noteText;
  final String? personalText;
  final int createdAtMillis;
  final int updatedAtMillis;
  const PreparationPlanRow({
    required this.id,
    required this.status,
    required this.evidenceFingerprint,
    required this.sourceRecordIdsJson,
    required this.includeCare,
    required this.careActionId,
    required this.careActionLabel,
    required this.careMode,
    required this.betterCount,
    required this.sameCount,
    required this.worseCount,
    this.noteText,
    this.personalText,
    required this.createdAtMillis,
    required this.updatedAtMillis,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['status'] = Variable<String>(status);
    map['evidence_fingerprint'] = Variable<String>(evidenceFingerprint);
    map['source_record_ids_json'] = Variable<String>(sourceRecordIdsJson);
    map['include_care'] = Variable<bool>(includeCare);
    map['care_action_id'] = Variable<String>(careActionId);
    map['care_action_label'] = Variable<String>(careActionLabel);
    map['care_mode'] = Variable<String>(careMode);
    map['better_count'] = Variable<int>(betterCount);
    map['same_count'] = Variable<int>(sameCount);
    map['worse_count'] = Variable<int>(worseCount);
    if (!nullToAbsent || noteText != null) {
      map['note_text'] = Variable<String>(noteText);
    }
    if (!nullToAbsent || personalText != null) {
      map['personal_text'] = Variable<String>(personalText);
    }
    map['created_at_millis'] = Variable<int>(createdAtMillis);
    map['updated_at_millis'] = Variable<int>(updatedAtMillis);
    return map;
  }

  PreparationPlanRowsCompanion toCompanion(bool nullToAbsent) {
    return PreparationPlanRowsCompanion(
      id: Value(id),
      status: Value(status),
      evidenceFingerprint: Value(evidenceFingerprint),
      sourceRecordIdsJson: Value(sourceRecordIdsJson),
      includeCare: Value(includeCare),
      careActionId: Value(careActionId),
      careActionLabel: Value(careActionLabel),
      careMode: Value(careMode),
      betterCount: Value(betterCount),
      sameCount: Value(sameCount),
      worseCount: Value(worseCount),
      noteText: noteText == null && nullToAbsent
          ? const Value.absent()
          : Value(noteText),
      personalText: personalText == null && nullToAbsent
          ? const Value.absent()
          : Value(personalText),
      createdAtMillis: Value(createdAtMillis),
      updatedAtMillis: Value(updatedAtMillis),
    );
  }

  factory PreparationPlanRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PreparationPlanRow(
      id: serializer.fromJson<String>(json['id']),
      status: serializer.fromJson<String>(json['status']),
      evidenceFingerprint: serializer.fromJson<String>(
        json['evidenceFingerprint'],
      ),
      sourceRecordIdsJson: serializer.fromJson<String>(
        json['sourceRecordIdsJson'],
      ),
      includeCare: serializer.fromJson<bool>(json['includeCare']),
      careActionId: serializer.fromJson<String>(json['careActionId']),
      careActionLabel: serializer.fromJson<String>(json['careActionLabel']),
      careMode: serializer.fromJson<String>(json['careMode']),
      betterCount: serializer.fromJson<int>(json['betterCount']),
      sameCount: serializer.fromJson<int>(json['sameCount']),
      worseCount: serializer.fromJson<int>(json['worseCount']),
      noteText: serializer.fromJson<String?>(json['noteText']),
      personalText: serializer.fromJson<String?>(json['personalText']),
      createdAtMillis: serializer.fromJson<int>(json['createdAtMillis']),
      updatedAtMillis: serializer.fromJson<int>(json['updatedAtMillis']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'status': serializer.toJson<String>(status),
      'evidenceFingerprint': serializer.toJson<String>(evidenceFingerprint),
      'sourceRecordIdsJson': serializer.toJson<String>(sourceRecordIdsJson),
      'includeCare': serializer.toJson<bool>(includeCare),
      'careActionId': serializer.toJson<String>(careActionId),
      'careActionLabel': serializer.toJson<String>(careActionLabel),
      'careMode': serializer.toJson<String>(careMode),
      'betterCount': serializer.toJson<int>(betterCount),
      'sameCount': serializer.toJson<int>(sameCount),
      'worseCount': serializer.toJson<int>(worseCount),
      'noteText': serializer.toJson<String?>(noteText),
      'personalText': serializer.toJson<String?>(personalText),
      'createdAtMillis': serializer.toJson<int>(createdAtMillis),
      'updatedAtMillis': serializer.toJson<int>(updatedAtMillis),
    };
  }

  PreparationPlanRow copyWith({
    String? id,
    String? status,
    String? evidenceFingerprint,
    String? sourceRecordIdsJson,
    bool? includeCare,
    String? careActionId,
    String? careActionLabel,
    String? careMode,
    int? betterCount,
    int? sameCount,
    int? worseCount,
    Value<String?> noteText = const Value.absent(),
    Value<String?> personalText = const Value.absent(),
    int? createdAtMillis,
    int? updatedAtMillis,
  }) => PreparationPlanRow(
    id: id ?? this.id,
    status: status ?? this.status,
    evidenceFingerprint: evidenceFingerprint ?? this.evidenceFingerprint,
    sourceRecordIdsJson: sourceRecordIdsJson ?? this.sourceRecordIdsJson,
    includeCare: includeCare ?? this.includeCare,
    careActionId: careActionId ?? this.careActionId,
    careActionLabel: careActionLabel ?? this.careActionLabel,
    careMode: careMode ?? this.careMode,
    betterCount: betterCount ?? this.betterCount,
    sameCount: sameCount ?? this.sameCount,
    worseCount: worseCount ?? this.worseCount,
    noteText: noteText.present ? noteText.value : this.noteText,
    personalText: personalText.present ? personalText.value : this.personalText,
    createdAtMillis: createdAtMillis ?? this.createdAtMillis,
    updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
  );
  PreparationPlanRow copyWithCompanion(PreparationPlanRowsCompanion data) {
    return PreparationPlanRow(
      id: data.id.present ? data.id.value : this.id,
      status: data.status.present ? data.status.value : this.status,
      evidenceFingerprint: data.evidenceFingerprint.present
          ? data.evidenceFingerprint.value
          : this.evidenceFingerprint,
      sourceRecordIdsJson: data.sourceRecordIdsJson.present
          ? data.sourceRecordIdsJson.value
          : this.sourceRecordIdsJson,
      includeCare: data.includeCare.present
          ? data.includeCare.value
          : this.includeCare,
      careActionId: data.careActionId.present
          ? data.careActionId.value
          : this.careActionId,
      careActionLabel: data.careActionLabel.present
          ? data.careActionLabel.value
          : this.careActionLabel,
      careMode: data.careMode.present ? data.careMode.value : this.careMode,
      betterCount: data.betterCount.present
          ? data.betterCount.value
          : this.betterCount,
      sameCount: data.sameCount.present ? data.sameCount.value : this.sameCount,
      worseCount: data.worseCount.present
          ? data.worseCount.value
          : this.worseCount,
      noteText: data.noteText.present ? data.noteText.value : this.noteText,
      personalText: data.personalText.present
          ? data.personalText.value
          : this.personalText,
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
    return (StringBuffer('PreparationPlanRow(')
          ..write('id: $id, ')
          ..write('status: $status, ')
          ..write('evidenceFingerprint: $evidenceFingerprint, ')
          ..write('sourceRecordIdsJson: $sourceRecordIdsJson, ')
          ..write('includeCare: $includeCare, ')
          ..write('careActionId: $careActionId, ')
          ..write('careActionLabel: $careActionLabel, ')
          ..write('careMode: $careMode, ')
          ..write('betterCount: $betterCount, ')
          ..write('sameCount: $sameCount, ')
          ..write('worseCount: $worseCount, ')
          ..write('noteText: $noteText, ')
          ..write('personalText: $personalText, ')
          ..write('createdAtMillis: $createdAtMillis, ')
          ..write('updatedAtMillis: $updatedAtMillis')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    status,
    evidenceFingerprint,
    sourceRecordIdsJson,
    includeCare,
    careActionId,
    careActionLabel,
    careMode,
    betterCount,
    sameCount,
    worseCount,
    noteText,
    personalText,
    createdAtMillis,
    updatedAtMillis,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PreparationPlanRow &&
          other.id == this.id &&
          other.status == this.status &&
          other.evidenceFingerprint == this.evidenceFingerprint &&
          other.sourceRecordIdsJson == this.sourceRecordIdsJson &&
          other.includeCare == this.includeCare &&
          other.careActionId == this.careActionId &&
          other.careActionLabel == this.careActionLabel &&
          other.careMode == this.careMode &&
          other.betterCount == this.betterCount &&
          other.sameCount == this.sameCount &&
          other.worseCount == this.worseCount &&
          other.noteText == this.noteText &&
          other.personalText == this.personalText &&
          other.createdAtMillis == this.createdAtMillis &&
          other.updatedAtMillis == this.updatedAtMillis);
}

class PreparationPlanRowsCompanion extends UpdateCompanion<PreparationPlanRow> {
  final Value<String> id;
  final Value<String> status;
  final Value<String> evidenceFingerprint;
  final Value<String> sourceRecordIdsJson;
  final Value<bool> includeCare;
  final Value<String> careActionId;
  final Value<String> careActionLabel;
  final Value<String> careMode;
  final Value<int> betterCount;
  final Value<int> sameCount;
  final Value<int> worseCount;
  final Value<String?> noteText;
  final Value<String?> personalText;
  final Value<int> createdAtMillis;
  final Value<int> updatedAtMillis;
  final Value<int> rowid;
  const PreparationPlanRowsCompanion({
    this.id = const Value.absent(),
    this.status = const Value.absent(),
    this.evidenceFingerprint = const Value.absent(),
    this.sourceRecordIdsJson = const Value.absent(),
    this.includeCare = const Value.absent(),
    this.careActionId = const Value.absent(),
    this.careActionLabel = const Value.absent(),
    this.careMode = const Value.absent(),
    this.betterCount = const Value.absent(),
    this.sameCount = const Value.absent(),
    this.worseCount = const Value.absent(),
    this.noteText = const Value.absent(),
    this.personalText = const Value.absent(),
    this.createdAtMillis = const Value.absent(),
    this.updatedAtMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PreparationPlanRowsCompanion.insert({
    required String id,
    required String status,
    required String evidenceFingerprint,
    required String sourceRecordIdsJson,
    required bool includeCare,
    required String careActionId,
    required String careActionLabel,
    required String careMode,
    required int betterCount,
    required int sameCount,
    required int worseCount,
    this.noteText = const Value.absent(),
    this.personalText = const Value.absent(),
    required int createdAtMillis,
    required int updatedAtMillis,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       status = Value(status),
       evidenceFingerprint = Value(evidenceFingerprint),
       sourceRecordIdsJson = Value(sourceRecordIdsJson),
       includeCare = Value(includeCare),
       careActionId = Value(careActionId),
       careActionLabel = Value(careActionLabel),
       careMode = Value(careMode),
       betterCount = Value(betterCount),
       sameCount = Value(sameCount),
       worseCount = Value(worseCount),
       createdAtMillis = Value(createdAtMillis),
       updatedAtMillis = Value(updatedAtMillis);
  static Insertable<PreparationPlanRow> custom({
    Expression<String>? id,
    Expression<String>? status,
    Expression<String>? evidenceFingerprint,
    Expression<String>? sourceRecordIdsJson,
    Expression<bool>? includeCare,
    Expression<String>? careActionId,
    Expression<String>? careActionLabel,
    Expression<String>? careMode,
    Expression<int>? betterCount,
    Expression<int>? sameCount,
    Expression<int>? worseCount,
    Expression<String>? noteText,
    Expression<String>? personalText,
    Expression<int>? createdAtMillis,
    Expression<int>? updatedAtMillis,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (status != null) 'status': status,
      if (evidenceFingerprint != null)
        'evidence_fingerprint': evidenceFingerprint,
      if (sourceRecordIdsJson != null)
        'source_record_ids_json': sourceRecordIdsJson,
      if (includeCare != null) 'include_care': includeCare,
      if (careActionId != null) 'care_action_id': careActionId,
      if (careActionLabel != null) 'care_action_label': careActionLabel,
      if (careMode != null) 'care_mode': careMode,
      if (betterCount != null) 'better_count': betterCount,
      if (sameCount != null) 'same_count': sameCount,
      if (worseCount != null) 'worse_count': worseCount,
      if (noteText != null) 'note_text': noteText,
      if (personalText != null) 'personal_text': personalText,
      if (createdAtMillis != null) 'created_at_millis': createdAtMillis,
      if (updatedAtMillis != null) 'updated_at_millis': updatedAtMillis,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PreparationPlanRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? status,
    Value<String>? evidenceFingerprint,
    Value<String>? sourceRecordIdsJson,
    Value<bool>? includeCare,
    Value<String>? careActionId,
    Value<String>? careActionLabel,
    Value<String>? careMode,
    Value<int>? betterCount,
    Value<int>? sameCount,
    Value<int>? worseCount,
    Value<String?>? noteText,
    Value<String?>? personalText,
    Value<int>? createdAtMillis,
    Value<int>? updatedAtMillis,
    Value<int>? rowid,
  }) {
    return PreparationPlanRowsCompanion(
      id: id ?? this.id,
      status: status ?? this.status,
      evidenceFingerprint: evidenceFingerprint ?? this.evidenceFingerprint,
      sourceRecordIdsJson: sourceRecordIdsJson ?? this.sourceRecordIdsJson,
      includeCare: includeCare ?? this.includeCare,
      careActionId: careActionId ?? this.careActionId,
      careActionLabel: careActionLabel ?? this.careActionLabel,
      careMode: careMode ?? this.careMode,
      betterCount: betterCount ?? this.betterCount,
      sameCount: sameCount ?? this.sameCount,
      worseCount: worseCount ?? this.worseCount,
      noteText: noteText ?? this.noteText,
      personalText: personalText ?? this.personalText,
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
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (evidenceFingerprint.present) {
      map['evidence_fingerprint'] = Variable<String>(evidenceFingerprint.value);
    }
    if (sourceRecordIdsJson.present) {
      map['source_record_ids_json'] = Variable<String>(
        sourceRecordIdsJson.value,
      );
    }
    if (includeCare.present) {
      map['include_care'] = Variable<bool>(includeCare.value);
    }
    if (careActionId.present) {
      map['care_action_id'] = Variable<String>(careActionId.value);
    }
    if (careActionLabel.present) {
      map['care_action_label'] = Variable<String>(careActionLabel.value);
    }
    if (careMode.present) {
      map['care_mode'] = Variable<String>(careMode.value);
    }
    if (betterCount.present) {
      map['better_count'] = Variable<int>(betterCount.value);
    }
    if (sameCount.present) {
      map['same_count'] = Variable<int>(sameCount.value);
    }
    if (worseCount.present) {
      map['worse_count'] = Variable<int>(worseCount.value);
    }
    if (noteText.present) {
      map['note_text'] = Variable<String>(noteText.value);
    }
    if (personalText.present) {
      map['personal_text'] = Variable<String>(personalText.value);
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
    return (StringBuffer('PreparationPlanRowsCompanion(')
          ..write('id: $id, ')
          ..write('status: $status, ')
          ..write('evidenceFingerprint: $evidenceFingerprint, ')
          ..write('sourceRecordIdsJson: $sourceRecordIdsJson, ')
          ..write('includeCare: $includeCare, ')
          ..write('careActionId: $careActionId, ')
          ..write('careActionLabel: $careActionLabel, ')
          ..write('careMode: $careMode, ')
          ..write('betterCount: $betterCount, ')
          ..write('sameCount: $sameCount, ')
          ..write('worseCount: $worseCount, ')
          ..write('noteText: $noteText, ')
          ..write('personalText: $personalText, ')
          ..write('createdAtMillis: $createdAtMillis, ')
          ..write('updatedAtMillis: $updatedAtMillis, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PreparationDismissalRowsTable extends PreparationDismissalRows
    with TableInfo<$PreparationDismissalRowsTable, PreparationDismissalRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PreparationDismissalRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _fingerprintMeta = const VerificationMeta(
    'fingerprint',
  );
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
    'fingerprint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _evidenceLineMeta = const VerificationMeta(
    'evidenceLine',
  );
  @override
  late final GeneratedColumn<String> evidenceLine = GeneratedColumn<String>(
    'evidence_line',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dismissedAtMillisMeta = const VerificationMeta(
    'dismissedAtMillis',
  );
  @override
  late final GeneratedColumn<int> dismissedAtMillis = GeneratedColumn<int>(
    'dismissed_at_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    fingerprint,
    evidenceLine,
    dismissedAtMillis,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'preparation_dismissal_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<PreparationDismissalRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('fingerprint')) {
      context.handle(
        _fingerprintMeta,
        fingerprint.isAcceptableOrUnknown(
          data['fingerprint']!,
          _fingerprintMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fingerprintMeta);
    }
    if (data.containsKey('evidence_line')) {
      context.handle(
        _evidenceLineMeta,
        evidenceLine.isAcceptableOrUnknown(
          data['evidence_line']!,
          _evidenceLineMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_evidenceLineMeta);
    }
    if (data.containsKey('dismissed_at_millis')) {
      context.handle(
        _dismissedAtMillisMeta,
        dismissedAtMillis.isAcceptableOrUnknown(
          data['dismissed_at_millis']!,
          _dismissedAtMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dismissedAtMillisMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {fingerprint};
  @override
  PreparationDismissalRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PreparationDismissalRow(
      fingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fingerprint'],
      )!,
      evidenceLine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}evidence_line'],
      )!,
      dismissedAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dismissed_at_millis'],
      )!,
    );
  }

  @override
  $PreparationDismissalRowsTable createAlias(String alias) {
    return $PreparationDismissalRowsTable(attachedDatabase, alias);
  }
}

class PreparationDismissalRow extends DataClass
    implements Insertable<PreparationDismissalRow> {
  final String fingerprint;
  final String evidenceLine;
  final int dismissedAtMillis;
  const PreparationDismissalRow({
    required this.fingerprint,
    required this.evidenceLine,
    required this.dismissedAtMillis,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['fingerprint'] = Variable<String>(fingerprint);
    map['evidence_line'] = Variable<String>(evidenceLine);
    map['dismissed_at_millis'] = Variable<int>(dismissedAtMillis);
    return map;
  }

  PreparationDismissalRowsCompanion toCompanion(bool nullToAbsent) {
    return PreparationDismissalRowsCompanion(
      fingerprint: Value(fingerprint),
      evidenceLine: Value(evidenceLine),
      dismissedAtMillis: Value(dismissedAtMillis),
    );
  }

  factory PreparationDismissalRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PreparationDismissalRow(
      fingerprint: serializer.fromJson<String>(json['fingerprint']),
      evidenceLine: serializer.fromJson<String>(json['evidenceLine']),
      dismissedAtMillis: serializer.fromJson<int>(json['dismissedAtMillis']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'fingerprint': serializer.toJson<String>(fingerprint),
      'evidenceLine': serializer.toJson<String>(evidenceLine),
      'dismissedAtMillis': serializer.toJson<int>(dismissedAtMillis),
    };
  }

  PreparationDismissalRow copyWith({
    String? fingerprint,
    String? evidenceLine,
    int? dismissedAtMillis,
  }) => PreparationDismissalRow(
    fingerprint: fingerprint ?? this.fingerprint,
    evidenceLine: evidenceLine ?? this.evidenceLine,
    dismissedAtMillis: dismissedAtMillis ?? this.dismissedAtMillis,
  );
  PreparationDismissalRow copyWithCompanion(
    PreparationDismissalRowsCompanion data,
  ) {
    return PreparationDismissalRow(
      fingerprint: data.fingerprint.present
          ? data.fingerprint.value
          : this.fingerprint,
      evidenceLine: data.evidenceLine.present
          ? data.evidenceLine.value
          : this.evidenceLine,
      dismissedAtMillis: data.dismissedAtMillis.present
          ? data.dismissedAtMillis.value
          : this.dismissedAtMillis,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PreparationDismissalRow(')
          ..write('fingerprint: $fingerprint, ')
          ..write('evidenceLine: $evidenceLine, ')
          ..write('dismissedAtMillis: $dismissedAtMillis')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(fingerprint, evidenceLine, dismissedAtMillis);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PreparationDismissalRow &&
          other.fingerprint == this.fingerprint &&
          other.evidenceLine == this.evidenceLine &&
          other.dismissedAtMillis == this.dismissedAtMillis);
}

class PreparationDismissalRowsCompanion
    extends UpdateCompanion<PreparationDismissalRow> {
  final Value<String> fingerprint;
  final Value<String> evidenceLine;
  final Value<int> dismissedAtMillis;
  final Value<int> rowid;
  const PreparationDismissalRowsCompanion({
    this.fingerprint = const Value.absent(),
    this.evidenceLine = const Value.absent(),
    this.dismissedAtMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PreparationDismissalRowsCompanion.insert({
    required String fingerprint,
    required String evidenceLine,
    required int dismissedAtMillis,
    this.rowid = const Value.absent(),
  }) : fingerprint = Value(fingerprint),
       evidenceLine = Value(evidenceLine),
       dismissedAtMillis = Value(dismissedAtMillis);
  static Insertable<PreparationDismissalRow> custom({
    Expression<String>? fingerprint,
    Expression<String>? evidenceLine,
    Expression<int>? dismissedAtMillis,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (evidenceLine != null) 'evidence_line': evidenceLine,
      if (dismissedAtMillis != null) 'dismissed_at_millis': dismissedAtMillis,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PreparationDismissalRowsCompanion copyWith({
    Value<String>? fingerprint,
    Value<String>? evidenceLine,
    Value<int>? dismissedAtMillis,
    Value<int>? rowid,
  }) {
    return PreparationDismissalRowsCompanion(
      fingerprint: fingerprint ?? this.fingerprint,
      evidenceLine: evidenceLine ?? this.evidenceLine,
      dismissedAtMillis: dismissedAtMillis ?? this.dismissedAtMillis,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
    }
    if (evidenceLine.present) {
      map['evidence_line'] = Variable<String>(evidenceLine.value);
    }
    if (dismissedAtMillis.present) {
      map['dismissed_at_millis'] = Variable<int>(dismissedAtMillis.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PreparationDismissalRowsCompanion(')
          ..write('fingerprint: $fingerprint, ')
          ..write('evidenceLine: $evidenceLine, ')
          ..write('dismissedAtMillis: $dismissedAtMillis, ')
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
  late final $PeriodFlowRowsTable periodFlowRows = $PeriodFlowRowsTable(this);
  late final $CareRecordRowsTable careRecordRows = $CareRecordRowsTable(this);
  late final $CareReflectionRowsTable careReflectionRows =
      $CareReflectionRowsTable(this);
  late final $CycleReflectionRowsTable cycleReflectionRows =
      $CycleReflectionRowsTable(this);
  late final $HealthRecordRowsTable healthRecordRows = $HealthRecordRowsTable(
    this,
  );
  late final $CaptureNoteRowsTable captureNoteRows = $CaptureNoteRowsTable(
    this,
  );
  late final $MomentCheckInRowsTable momentCheckInRows =
      $MomentCheckInRowsTable(this);
  late final $PreparationPlanRowsTable preparationPlanRows =
      $PreparationPlanRowsTable(this);
  late final $PreparationDismissalRowsTable preparationDismissalRows =
      $PreparationDismissalRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    periodRows,
    periodFlowRows,
    careRecordRows,
    careReflectionRows,
    cycleReflectionRows,
    healthRecordRows,
    captureNoteRows,
    momentCheckInRows,
    preparationPlanRows,
    preparationDismissalRows,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'period_rows',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('period_flow_rows', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'care_record_rows',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('care_reflection_rows', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'period_rows',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('cycle_reflection_rows', kind: UpdateKind.update)],
    ),
  ]);
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

final class $$PeriodRowsTableReferences
    extends
        BaseReferences<_$LetterHealthDatabase, $PeriodRowsTable, PeriodRow> {
  $$PeriodRowsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PeriodFlowRowsTable, List<PeriodFlowRow>>
  _periodFlowRowsRefsTable(_$LetterHealthDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.periodFlowRows,
        aliasName: 'period_rows__id__period_flow_rows__period_id',
      );

  $$PeriodFlowRowsTableProcessedTableManager get periodFlowRowsRefs {
    final manager = $$PeriodFlowRowsTableTableManager(
      $_db,
      $_db.periodFlowRows,
    ).filter((f) => f.periodId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_periodFlowRowsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $CycleReflectionRowsTable,
    List<CycleReflectionRow>
  >
  _cycleReflectionRowsRefsTable(_$LetterHealthDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.cycleReflectionRows,
        aliasName: 'period_rows__id__cycle_reflection_rows__starting_period_id',
      );

  $$CycleReflectionRowsTableProcessedTableManager get cycleReflectionRowsRefs {
    final manager =
        $$CycleReflectionRowsTableTableManager(
          $_db,
          $_db.cycleReflectionRows,
        ).filter(
          (f) => f.startingPeriodId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _cycleReflectionRowsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

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

  Expression<bool> periodFlowRowsRefs(
    Expression<bool> Function($$PeriodFlowRowsTableFilterComposer f) f,
  ) {
    final $$PeriodFlowRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.periodFlowRows,
      getReferencedColumn: (t) => t.periodId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeriodFlowRowsTableFilterComposer(
            $db: $db,
            $table: $db.periodFlowRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cycleReflectionRowsRefs(
    Expression<bool> Function($$CycleReflectionRowsTableFilterComposer f) f,
  ) {
    final $$CycleReflectionRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cycleReflectionRows,
      getReferencedColumn: (t) => t.startingPeriodId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CycleReflectionRowsTableFilterComposer(
            $db: $db,
            $table: $db.cycleReflectionRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
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

  Expression<T> periodFlowRowsRefs<T extends Object>(
    Expression<T> Function($$PeriodFlowRowsTableAnnotationComposer a) f,
  ) {
    final $$PeriodFlowRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.periodFlowRows,
      getReferencedColumn: (t) => t.periodId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeriodFlowRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.periodFlowRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> cycleReflectionRowsRefs<T extends Object>(
    Expression<T> Function($$CycleReflectionRowsTableAnnotationComposer a) f,
  ) {
    final $$CycleReflectionRowsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.cycleReflectionRows,
          getReferencedColumn: (t) => t.startingPeriodId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CycleReflectionRowsTableAnnotationComposer(
                $db: $db,
                $table: $db.cycleReflectionRows,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
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
          (PeriodRow, $$PeriodRowsTableReferences),
          PeriodRow,
          PrefetchHooks Function({
            bool periodFlowRowsRefs,
            bool cycleReflectionRowsRefs,
          })
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
              .map(
                (e) => (
                  e.readTable(table),
                  $$PeriodRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({periodFlowRowsRefs = false, cycleReflectionRowsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (periodFlowRowsRefs) db.periodFlowRows,
                    if (cycleReflectionRowsRefs) db.cycleReflectionRows,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (periodFlowRowsRefs)
                        await $_getPrefetchedData<
                          PeriodRow,
                          $PeriodRowsTable,
                          PeriodFlowRow
                        >(
                          currentTable: table,
                          referencedTable: $$PeriodRowsTableReferences
                              ._periodFlowRowsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PeriodRowsTableReferences(
                                db,
                                table,
                                p0,
                              ).periodFlowRowsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.periodId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (cycleReflectionRowsRefs)
                        await $_getPrefetchedData<
                          PeriodRow,
                          $PeriodRowsTable,
                          CycleReflectionRow
                        >(
                          currentTable: table,
                          referencedTable: $$PeriodRowsTableReferences
                              ._cycleReflectionRowsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PeriodRowsTableReferences(
                                db,
                                table,
                                p0,
                              ).cycleReflectionRowsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.startingPeriodId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
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
      (PeriodRow, $$PeriodRowsTableReferences),
      PeriodRow,
      PrefetchHooks Function({
        bool periodFlowRowsRefs,
        bool cycleReflectionRowsRefs,
      })
    >;
typedef $$PeriodFlowRowsTableCreateCompanionBuilder =
    PeriodFlowRowsCompanion Function({
      required String periodId,
      required int day,
      required String flow,
      Value<String?> color,
      required int createdAtMillis,
      required int updatedAtMillis,
      Value<int> rowid,
    });
typedef $$PeriodFlowRowsTableUpdateCompanionBuilder =
    PeriodFlowRowsCompanion Function({
      Value<String> periodId,
      Value<int> day,
      Value<String> flow,
      Value<String?> color,
      Value<int> createdAtMillis,
      Value<int> updatedAtMillis,
      Value<int> rowid,
    });

final class $$PeriodFlowRowsTableReferences
    extends
        BaseReferences<
          _$LetterHealthDatabase,
          $PeriodFlowRowsTable,
          PeriodFlowRow
        > {
  $$PeriodFlowRowsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PeriodRowsTable _periodIdTable(_$LetterHealthDatabase db) =>
      db.periodRows.createAlias('period_flow_rows__period_id__period_rows__id');

  $$PeriodRowsTableProcessedTableManager get periodId {
    final $_column = $_itemColumn<String>('period_id')!;

    final manager = $$PeriodRowsTableTableManager(
      $_db,
      $_db.periodRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_periodIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PeriodFlowRowsTableFilterComposer
    extends Composer<_$LetterHealthDatabase, $PeriodFlowRowsTable> {
  $$PeriodFlowRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get flow => $composableBuilder(
    column: $table.flow,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
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

  $$PeriodRowsTableFilterComposer get periodId {
    final $$PeriodRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.periodId,
      referencedTable: $db.periodRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeriodRowsTableFilterComposer(
            $db: $db,
            $table: $db.periodRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PeriodFlowRowsTableOrderingComposer
    extends Composer<_$LetterHealthDatabase, $PeriodFlowRowsTable> {
  $$PeriodFlowRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get flow => $composableBuilder(
    column: $table.flow,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
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

  $$PeriodRowsTableOrderingComposer get periodId {
    final $$PeriodRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.periodId,
      referencedTable: $db.periodRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeriodRowsTableOrderingComposer(
            $db: $db,
            $table: $db.periodRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PeriodFlowRowsTableAnnotationComposer
    extends Composer<_$LetterHealthDatabase, $PeriodFlowRowsTable> {
  $$PeriodFlowRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<String> get flow =>
      $composableBuilder(column: $table.flow, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMillis => $composableBuilder(
    column: $table.updatedAtMillis,
    builder: (column) => column,
  );

  $$PeriodRowsTableAnnotationComposer get periodId {
    final $$PeriodRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.periodId,
      referencedTable: $db.periodRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeriodRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.periodRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PeriodFlowRowsTableTableManager
    extends
        RootTableManager<
          _$LetterHealthDatabase,
          $PeriodFlowRowsTable,
          PeriodFlowRow,
          $$PeriodFlowRowsTableFilterComposer,
          $$PeriodFlowRowsTableOrderingComposer,
          $$PeriodFlowRowsTableAnnotationComposer,
          $$PeriodFlowRowsTableCreateCompanionBuilder,
          $$PeriodFlowRowsTableUpdateCompanionBuilder,
          (PeriodFlowRow, $$PeriodFlowRowsTableReferences),
          PeriodFlowRow,
          PrefetchHooks Function({bool periodId})
        > {
  $$PeriodFlowRowsTableTableManager(
    _$LetterHealthDatabase db,
    $PeriodFlowRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PeriodFlowRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PeriodFlowRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PeriodFlowRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> periodId = const Value.absent(),
                Value<int> day = const Value.absent(),
                Value<String> flow = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<int> createdAtMillis = const Value.absent(),
                Value<int> updatedAtMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PeriodFlowRowsCompanion(
                periodId: periodId,
                day: day,
                flow: flow,
                color: color,
                createdAtMillis: createdAtMillis,
                updatedAtMillis: updatedAtMillis,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String periodId,
                required int day,
                required String flow,
                Value<String?> color = const Value.absent(),
                required int createdAtMillis,
                required int updatedAtMillis,
                Value<int> rowid = const Value.absent(),
              }) => PeriodFlowRowsCompanion.insert(
                periodId: periodId,
                day: day,
                flow: flow,
                color: color,
                createdAtMillis: createdAtMillis,
                updatedAtMillis: updatedAtMillis,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PeriodFlowRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({periodId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (periodId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.periodId,
                                referencedTable: $$PeriodFlowRowsTableReferences
                                    ._periodIdTable(db),
                                referencedColumn:
                                    $$PeriodFlowRowsTableReferences
                                        ._periodIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PeriodFlowRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$LetterHealthDatabase,
      $PeriodFlowRowsTable,
      PeriodFlowRow,
      $$PeriodFlowRowsTableFilterComposer,
      $$PeriodFlowRowsTableOrderingComposer,
      $$PeriodFlowRowsTableAnnotationComposer,
      $$PeriodFlowRowsTableCreateCompanionBuilder,
      $$PeriodFlowRowsTableUpdateCompanionBuilder,
      (PeriodFlowRow, $$PeriodFlowRowsTableReferences),
      PeriodFlowRow,
      PrefetchHooks Function({bool periodId})
    >;
typedef $$CareRecordRowsTableCreateCompanionBuilder =
    CareRecordRowsCompanion Function({
      required String id,
      required String mode,
      required String actionId,
      required String actionLabel,
      required String outcome,
      required int occurredAtMillis,
      required int createdAtMillis,
      required int updatedAtMillis,
      Value<bool> pinned,
      Value<int> rowid,
    });
typedef $$CareRecordRowsTableUpdateCompanionBuilder =
    CareRecordRowsCompanion Function({
      Value<String> id,
      Value<String> mode,
      Value<String> actionId,
      Value<String> actionLabel,
      Value<String> outcome,
      Value<int> occurredAtMillis,
      Value<int> createdAtMillis,
      Value<int> updatedAtMillis,
      Value<bool> pinned,
      Value<int> rowid,
    });

final class $$CareRecordRowsTableReferences
    extends
        BaseReferences<
          _$LetterHealthDatabase,
          $CareRecordRowsTable,
          CareRecordRow
        > {
  $$CareRecordRowsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$CareReflectionRowsTable, List<CareReflectionRow>>
  _careReflectionRowsRefsTable(_$LetterHealthDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.careReflectionRows,
        aliasName: 'care_record_rows__id__care_reflection_rows__care_record_id',
      );

  $$CareReflectionRowsTableProcessedTableManager get careReflectionRowsRefs {
    final manager = $$CareReflectionRowsTableTableManager(
      $_db,
      $_db.careReflectionRows,
    ).filter((f) => f.careRecordId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _careReflectionRowsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CareRecordRowsTableFilterComposer
    extends Composer<_$LetterHealthDatabase, $CareRecordRowsTable> {
  $$CareRecordRowsTableFilterComposer({
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

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actionId => $composableBuilder(
    column: $table.actionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actionLabel => $composableBuilder(
    column: $table.actionLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get occurredAtMillis => $composableBuilder(
    column: $table.occurredAtMillis,
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

  ColumnFilters<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> careReflectionRowsRefs(
    Expression<bool> Function($$CareReflectionRowsTableFilterComposer f) f,
  ) {
    final $$CareReflectionRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.careReflectionRows,
      getReferencedColumn: (t) => t.careRecordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CareReflectionRowsTableFilterComposer(
            $db: $db,
            $table: $db.careReflectionRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CareRecordRowsTableOrderingComposer
    extends Composer<_$LetterHealthDatabase, $CareRecordRowsTable> {
  $$CareRecordRowsTableOrderingComposer({
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

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actionId => $composableBuilder(
    column: $table.actionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actionLabel => $composableBuilder(
    column: $table.actionLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get occurredAtMillis => $composableBuilder(
    column: $table.occurredAtMillis,
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

  ColumnOrderings<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CareRecordRowsTableAnnotationComposer
    extends Composer<_$LetterHealthDatabase, $CareRecordRowsTable> {
  $$CareRecordRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get actionId =>
      $composableBuilder(column: $table.actionId, builder: (column) => column);

  GeneratedColumn<String> get actionLabel => $composableBuilder(
    column: $table.actionLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumn<int> get occurredAtMillis => $composableBuilder(
    column: $table.occurredAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMillis => $composableBuilder(
    column: $table.updatedAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  Expression<T> careReflectionRowsRefs<T extends Object>(
    Expression<T> Function($$CareReflectionRowsTableAnnotationComposer a) f,
  ) {
    final $$CareReflectionRowsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.careReflectionRows,
          getReferencedColumn: (t) => t.careRecordId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CareReflectionRowsTableAnnotationComposer(
                $db: $db,
                $table: $db.careReflectionRows,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CareRecordRowsTableTableManager
    extends
        RootTableManager<
          _$LetterHealthDatabase,
          $CareRecordRowsTable,
          CareRecordRow,
          $$CareRecordRowsTableFilterComposer,
          $$CareRecordRowsTableOrderingComposer,
          $$CareRecordRowsTableAnnotationComposer,
          $$CareRecordRowsTableCreateCompanionBuilder,
          $$CareRecordRowsTableUpdateCompanionBuilder,
          (CareRecordRow, $$CareRecordRowsTableReferences),
          CareRecordRow,
          PrefetchHooks Function({bool careReflectionRowsRefs})
        > {
  $$CareRecordRowsTableTableManager(
    _$LetterHealthDatabase db,
    $CareRecordRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CareRecordRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CareRecordRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CareRecordRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<String> actionId = const Value.absent(),
                Value<String> actionLabel = const Value.absent(),
                Value<String> outcome = const Value.absent(),
                Value<int> occurredAtMillis = const Value.absent(),
                Value<int> createdAtMillis = const Value.absent(),
                Value<int> updatedAtMillis = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CareRecordRowsCompanion(
                id: id,
                mode: mode,
                actionId: actionId,
                actionLabel: actionLabel,
                outcome: outcome,
                occurredAtMillis: occurredAtMillis,
                createdAtMillis: createdAtMillis,
                updatedAtMillis: updatedAtMillis,
                pinned: pinned,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String mode,
                required String actionId,
                required String actionLabel,
                required String outcome,
                required int occurredAtMillis,
                required int createdAtMillis,
                required int updatedAtMillis,
                Value<bool> pinned = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CareRecordRowsCompanion.insert(
                id: id,
                mode: mode,
                actionId: actionId,
                actionLabel: actionLabel,
                outcome: outcome,
                occurredAtMillis: occurredAtMillis,
                createdAtMillis: createdAtMillis,
                updatedAtMillis: updatedAtMillis,
                pinned: pinned,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CareRecordRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({careReflectionRowsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (careReflectionRowsRefs) db.careReflectionRows,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (careReflectionRowsRefs)
                    await $_getPrefetchedData<
                      CareRecordRow,
                      $CareRecordRowsTable,
                      CareReflectionRow
                    >(
                      currentTable: table,
                      referencedTable: $$CareRecordRowsTableReferences
                          ._careReflectionRowsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CareRecordRowsTableReferences(
                            db,
                            table,
                            p0,
                          ).careReflectionRowsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.careRecordId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CareRecordRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$LetterHealthDatabase,
      $CareRecordRowsTable,
      CareRecordRow,
      $$CareRecordRowsTableFilterComposer,
      $$CareRecordRowsTableOrderingComposer,
      $$CareRecordRowsTableAnnotationComposer,
      $$CareRecordRowsTableCreateCompanionBuilder,
      $$CareRecordRowsTableUpdateCompanionBuilder,
      (CareRecordRow, $$CareRecordRowsTableReferences),
      CareRecordRow,
      PrefetchHooks Function({bool careReflectionRowsRefs})
    >;
typedef $$CareReflectionRowsTableCreateCompanionBuilder =
    CareReflectionRowsCompanion Function({
      required String id,
      required String careRecordId,
      required String mode,
      Value<String?> observation,
      Value<String?> need,
      Value<String?> whatHelped,
      Value<String?> futureSelfNote,
      required int createdAtMillis,
      required int updatedAtMillis,
      Value<int> rowid,
    });
typedef $$CareReflectionRowsTableUpdateCompanionBuilder =
    CareReflectionRowsCompanion Function({
      Value<String> id,
      Value<String> careRecordId,
      Value<String> mode,
      Value<String?> observation,
      Value<String?> need,
      Value<String?> whatHelped,
      Value<String?> futureSelfNote,
      Value<int> createdAtMillis,
      Value<int> updatedAtMillis,
      Value<int> rowid,
    });

final class $$CareReflectionRowsTableReferences
    extends
        BaseReferences<
          _$LetterHealthDatabase,
          $CareReflectionRowsTable,
          CareReflectionRow
        > {
  $$CareReflectionRowsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CareRecordRowsTable _careRecordIdTable(_$LetterHealthDatabase db) =>
      db.careRecordRows.createAlias(
        'care_reflection_rows__care_record_id__care_record_rows__id',
      );

  $$CareRecordRowsTableProcessedTableManager get careRecordId {
    final $_column = $_itemColumn<String>('care_record_id')!;

    final manager = $$CareRecordRowsTableTableManager(
      $_db,
      $_db.careRecordRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_careRecordIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CareReflectionRowsTableFilterComposer
    extends Composer<_$LetterHealthDatabase, $CareReflectionRowsTable> {
  $$CareReflectionRowsTableFilterComposer({
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

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get observation => $composableBuilder(
    column: $table.observation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get need => $composableBuilder(
    column: $table.need,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get whatHelped => $composableBuilder(
    column: $table.whatHelped,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get futureSelfNote => $composableBuilder(
    column: $table.futureSelfNote,
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

  $$CareRecordRowsTableFilterComposer get careRecordId {
    final $$CareRecordRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.careRecordId,
      referencedTable: $db.careRecordRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CareRecordRowsTableFilterComposer(
            $db: $db,
            $table: $db.careRecordRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CareReflectionRowsTableOrderingComposer
    extends Composer<_$LetterHealthDatabase, $CareReflectionRowsTable> {
  $$CareReflectionRowsTableOrderingComposer({
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

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get observation => $composableBuilder(
    column: $table.observation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get need => $composableBuilder(
    column: $table.need,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get whatHelped => $composableBuilder(
    column: $table.whatHelped,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get futureSelfNote => $composableBuilder(
    column: $table.futureSelfNote,
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

  $$CareRecordRowsTableOrderingComposer get careRecordId {
    final $$CareRecordRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.careRecordId,
      referencedTable: $db.careRecordRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CareRecordRowsTableOrderingComposer(
            $db: $db,
            $table: $db.careRecordRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CareReflectionRowsTableAnnotationComposer
    extends Composer<_$LetterHealthDatabase, $CareReflectionRowsTable> {
  $$CareReflectionRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get observation => $composableBuilder(
    column: $table.observation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get need =>
      $composableBuilder(column: $table.need, builder: (column) => column);

  GeneratedColumn<String> get whatHelped => $composableBuilder(
    column: $table.whatHelped,
    builder: (column) => column,
  );

  GeneratedColumn<String> get futureSelfNote => $composableBuilder(
    column: $table.futureSelfNote,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMillis => $composableBuilder(
    column: $table.updatedAtMillis,
    builder: (column) => column,
  );

  $$CareRecordRowsTableAnnotationComposer get careRecordId {
    final $$CareRecordRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.careRecordId,
      referencedTable: $db.careRecordRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CareRecordRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.careRecordRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CareReflectionRowsTableTableManager
    extends
        RootTableManager<
          _$LetterHealthDatabase,
          $CareReflectionRowsTable,
          CareReflectionRow,
          $$CareReflectionRowsTableFilterComposer,
          $$CareReflectionRowsTableOrderingComposer,
          $$CareReflectionRowsTableAnnotationComposer,
          $$CareReflectionRowsTableCreateCompanionBuilder,
          $$CareReflectionRowsTableUpdateCompanionBuilder,
          (CareReflectionRow, $$CareReflectionRowsTableReferences),
          CareReflectionRow,
          PrefetchHooks Function({bool careRecordId})
        > {
  $$CareReflectionRowsTableTableManager(
    _$LetterHealthDatabase db,
    $CareReflectionRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CareReflectionRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CareReflectionRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CareReflectionRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> careRecordId = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<String?> observation = const Value.absent(),
                Value<String?> need = const Value.absent(),
                Value<String?> whatHelped = const Value.absent(),
                Value<String?> futureSelfNote = const Value.absent(),
                Value<int> createdAtMillis = const Value.absent(),
                Value<int> updatedAtMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CareReflectionRowsCompanion(
                id: id,
                careRecordId: careRecordId,
                mode: mode,
                observation: observation,
                need: need,
                whatHelped: whatHelped,
                futureSelfNote: futureSelfNote,
                createdAtMillis: createdAtMillis,
                updatedAtMillis: updatedAtMillis,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String careRecordId,
                required String mode,
                Value<String?> observation = const Value.absent(),
                Value<String?> need = const Value.absent(),
                Value<String?> whatHelped = const Value.absent(),
                Value<String?> futureSelfNote = const Value.absent(),
                required int createdAtMillis,
                required int updatedAtMillis,
                Value<int> rowid = const Value.absent(),
              }) => CareReflectionRowsCompanion.insert(
                id: id,
                careRecordId: careRecordId,
                mode: mode,
                observation: observation,
                need: need,
                whatHelped: whatHelped,
                futureSelfNote: futureSelfNote,
                createdAtMillis: createdAtMillis,
                updatedAtMillis: updatedAtMillis,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CareReflectionRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({careRecordId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (careRecordId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.careRecordId,
                                referencedTable:
                                    $$CareReflectionRowsTableReferences
                                        ._careRecordIdTable(db),
                                referencedColumn:
                                    $$CareReflectionRowsTableReferences
                                        ._careRecordIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CareReflectionRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$LetterHealthDatabase,
      $CareReflectionRowsTable,
      CareReflectionRow,
      $$CareReflectionRowsTableFilterComposer,
      $$CareReflectionRowsTableOrderingComposer,
      $$CareReflectionRowsTableAnnotationComposer,
      $$CareReflectionRowsTableCreateCompanionBuilder,
      $$CareReflectionRowsTableUpdateCompanionBuilder,
      (CareReflectionRow, $$CareReflectionRowsTableReferences),
      CareReflectionRow,
      PrefetchHooks Function({bool careRecordId})
    >;
typedef $$CycleReflectionRowsTableCreateCompanionBuilder =
    CycleReflectionRowsCompanion Function({
      required String id,
      Value<String?> startingPeriodId,
      required int cycleStartDay,
      Value<String?> observation,
      Value<String?> need,
      Value<String?> whatHelped,
      Value<String?> futureSelfNote,
      required int createdAtMillis,
      required int updatedAtMillis,
      Value<int> rowid,
    });
typedef $$CycleReflectionRowsTableUpdateCompanionBuilder =
    CycleReflectionRowsCompanion Function({
      Value<String> id,
      Value<String?> startingPeriodId,
      Value<int> cycleStartDay,
      Value<String?> observation,
      Value<String?> need,
      Value<String?> whatHelped,
      Value<String?> futureSelfNote,
      Value<int> createdAtMillis,
      Value<int> updatedAtMillis,
      Value<int> rowid,
    });

final class $$CycleReflectionRowsTableReferences
    extends
        BaseReferences<
          _$LetterHealthDatabase,
          $CycleReflectionRowsTable,
          CycleReflectionRow
        > {
  $$CycleReflectionRowsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PeriodRowsTable _startingPeriodIdTable(_$LetterHealthDatabase db) =>
      db.periodRows.createAlias(
        'cycle_reflection_rows__starting_period_id__period_rows__id',
      );

  $$PeriodRowsTableProcessedTableManager? get startingPeriodId {
    final $_column = $_itemColumn<String>('starting_period_id');
    if ($_column == null) return null;
    final manager = $$PeriodRowsTableTableManager(
      $_db,
      $_db.periodRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_startingPeriodIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CycleReflectionRowsTableFilterComposer
    extends Composer<_$LetterHealthDatabase, $CycleReflectionRowsTable> {
  $$CycleReflectionRowsTableFilterComposer({
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

  ColumnFilters<int> get cycleStartDay => $composableBuilder(
    column: $table.cycleStartDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get observation => $composableBuilder(
    column: $table.observation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get need => $composableBuilder(
    column: $table.need,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get whatHelped => $composableBuilder(
    column: $table.whatHelped,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get futureSelfNote => $composableBuilder(
    column: $table.futureSelfNote,
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

  $$PeriodRowsTableFilterComposer get startingPeriodId {
    final $$PeriodRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.startingPeriodId,
      referencedTable: $db.periodRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeriodRowsTableFilterComposer(
            $db: $db,
            $table: $db.periodRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CycleReflectionRowsTableOrderingComposer
    extends Composer<_$LetterHealthDatabase, $CycleReflectionRowsTable> {
  $$CycleReflectionRowsTableOrderingComposer({
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

  ColumnOrderings<int> get cycleStartDay => $composableBuilder(
    column: $table.cycleStartDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get observation => $composableBuilder(
    column: $table.observation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get need => $composableBuilder(
    column: $table.need,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get whatHelped => $composableBuilder(
    column: $table.whatHelped,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get futureSelfNote => $composableBuilder(
    column: $table.futureSelfNote,
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

  $$PeriodRowsTableOrderingComposer get startingPeriodId {
    final $$PeriodRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.startingPeriodId,
      referencedTable: $db.periodRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeriodRowsTableOrderingComposer(
            $db: $db,
            $table: $db.periodRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CycleReflectionRowsTableAnnotationComposer
    extends Composer<_$LetterHealthDatabase, $CycleReflectionRowsTable> {
  $$CycleReflectionRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get cycleStartDay => $composableBuilder(
    column: $table.cycleStartDay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get observation => $composableBuilder(
    column: $table.observation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get need =>
      $composableBuilder(column: $table.need, builder: (column) => column);

  GeneratedColumn<String> get whatHelped => $composableBuilder(
    column: $table.whatHelped,
    builder: (column) => column,
  );

  GeneratedColumn<String> get futureSelfNote => $composableBuilder(
    column: $table.futureSelfNote,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMillis => $composableBuilder(
    column: $table.updatedAtMillis,
    builder: (column) => column,
  );

  $$PeriodRowsTableAnnotationComposer get startingPeriodId {
    final $$PeriodRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.startingPeriodId,
      referencedTable: $db.periodRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeriodRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.periodRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CycleReflectionRowsTableTableManager
    extends
        RootTableManager<
          _$LetterHealthDatabase,
          $CycleReflectionRowsTable,
          CycleReflectionRow,
          $$CycleReflectionRowsTableFilterComposer,
          $$CycleReflectionRowsTableOrderingComposer,
          $$CycleReflectionRowsTableAnnotationComposer,
          $$CycleReflectionRowsTableCreateCompanionBuilder,
          $$CycleReflectionRowsTableUpdateCompanionBuilder,
          (CycleReflectionRow, $$CycleReflectionRowsTableReferences),
          CycleReflectionRow,
          PrefetchHooks Function({bool startingPeriodId})
        > {
  $$CycleReflectionRowsTableTableManager(
    _$LetterHealthDatabase db,
    $CycleReflectionRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CycleReflectionRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CycleReflectionRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CycleReflectionRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> startingPeriodId = const Value.absent(),
                Value<int> cycleStartDay = const Value.absent(),
                Value<String?> observation = const Value.absent(),
                Value<String?> need = const Value.absent(),
                Value<String?> whatHelped = const Value.absent(),
                Value<String?> futureSelfNote = const Value.absent(),
                Value<int> createdAtMillis = const Value.absent(),
                Value<int> updatedAtMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CycleReflectionRowsCompanion(
                id: id,
                startingPeriodId: startingPeriodId,
                cycleStartDay: cycleStartDay,
                observation: observation,
                need: need,
                whatHelped: whatHelped,
                futureSelfNote: futureSelfNote,
                createdAtMillis: createdAtMillis,
                updatedAtMillis: updatedAtMillis,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> startingPeriodId = const Value.absent(),
                required int cycleStartDay,
                Value<String?> observation = const Value.absent(),
                Value<String?> need = const Value.absent(),
                Value<String?> whatHelped = const Value.absent(),
                Value<String?> futureSelfNote = const Value.absent(),
                required int createdAtMillis,
                required int updatedAtMillis,
                Value<int> rowid = const Value.absent(),
              }) => CycleReflectionRowsCompanion.insert(
                id: id,
                startingPeriodId: startingPeriodId,
                cycleStartDay: cycleStartDay,
                observation: observation,
                need: need,
                whatHelped: whatHelped,
                futureSelfNote: futureSelfNote,
                createdAtMillis: createdAtMillis,
                updatedAtMillis: updatedAtMillis,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CycleReflectionRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({startingPeriodId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (startingPeriodId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.startingPeriodId,
                                referencedTable:
                                    $$CycleReflectionRowsTableReferences
                                        ._startingPeriodIdTable(db),
                                referencedColumn:
                                    $$CycleReflectionRowsTableReferences
                                        ._startingPeriodIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CycleReflectionRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$LetterHealthDatabase,
      $CycleReflectionRowsTable,
      CycleReflectionRow,
      $$CycleReflectionRowsTableFilterComposer,
      $$CycleReflectionRowsTableOrderingComposer,
      $$CycleReflectionRowsTableAnnotationComposer,
      $$CycleReflectionRowsTableCreateCompanionBuilder,
      $$CycleReflectionRowsTableUpdateCompanionBuilder,
      (CycleReflectionRow, $$CycleReflectionRowsTableReferences),
      CycleReflectionRow,
      PrefetchHooks Function({bool startingPeriodId})
    >;
typedef $$HealthRecordRowsTableCreateCompanionBuilder =
    HealthRecordRowsCompanion Function({
      required String id,
      required String symptom,
      required int severity,
      required String functionalImpactsJson,
      required int experiencedDay,
      required int recordedAtMillis,
      required int updatedAtMillis,
      required String provenance,
      required bool userConfirmed,
      required int vocabularyVersion,
      Value<int> rowid,
    });
typedef $$HealthRecordRowsTableUpdateCompanionBuilder =
    HealthRecordRowsCompanion Function({
      Value<String> id,
      Value<String> symptom,
      Value<int> severity,
      Value<String> functionalImpactsJson,
      Value<int> experiencedDay,
      Value<int> recordedAtMillis,
      Value<int> updatedAtMillis,
      Value<String> provenance,
      Value<bool> userConfirmed,
      Value<int> vocabularyVersion,
      Value<int> rowid,
    });

class $$HealthRecordRowsTableFilterComposer
    extends Composer<_$LetterHealthDatabase, $HealthRecordRowsTable> {
  $$HealthRecordRowsTableFilterComposer({
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

  ColumnFilters<String> get symptom => $composableBuilder(
    column: $table.symptom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get functionalImpactsJson => $composableBuilder(
    column: $table.functionalImpactsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get experiencedDay => $composableBuilder(
    column: $table.experiencedDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get recordedAtMillis => $composableBuilder(
    column: $table.recordedAtMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMillis => $composableBuilder(
    column: $table.updatedAtMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provenance => $composableBuilder(
    column: $table.provenance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get userConfirmed => $composableBuilder(
    column: $table.userConfirmed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get vocabularyVersion => $composableBuilder(
    column: $table.vocabularyVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HealthRecordRowsTableOrderingComposer
    extends Composer<_$LetterHealthDatabase, $HealthRecordRowsTable> {
  $$HealthRecordRowsTableOrderingComposer({
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

  ColumnOrderings<String> get symptom => $composableBuilder(
    column: $table.symptom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get functionalImpactsJson => $composableBuilder(
    column: $table.functionalImpactsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get experiencedDay => $composableBuilder(
    column: $table.experiencedDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recordedAtMillis => $composableBuilder(
    column: $table.recordedAtMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMillis => $composableBuilder(
    column: $table.updatedAtMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provenance => $composableBuilder(
    column: $table.provenance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get userConfirmed => $composableBuilder(
    column: $table.userConfirmed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get vocabularyVersion => $composableBuilder(
    column: $table.vocabularyVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HealthRecordRowsTableAnnotationComposer
    extends Composer<_$LetterHealthDatabase, $HealthRecordRowsTable> {
  $$HealthRecordRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get symptom =>
      $composableBuilder(column: $table.symptom, builder: (column) => column);

  GeneratedColumn<int> get severity =>
      $composableBuilder(column: $table.severity, builder: (column) => column);

  GeneratedColumn<String> get functionalImpactsJson => $composableBuilder(
    column: $table.functionalImpactsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get experiencedDay => $composableBuilder(
    column: $table.experiencedDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get recordedAtMillis => $composableBuilder(
    column: $table.recordedAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMillis => $composableBuilder(
    column: $table.updatedAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<String> get provenance => $composableBuilder(
    column: $table.provenance,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get userConfirmed => $composableBuilder(
    column: $table.userConfirmed,
    builder: (column) => column,
  );

  GeneratedColumn<int> get vocabularyVersion => $composableBuilder(
    column: $table.vocabularyVersion,
    builder: (column) => column,
  );
}

class $$HealthRecordRowsTableTableManager
    extends
        RootTableManager<
          _$LetterHealthDatabase,
          $HealthRecordRowsTable,
          HealthRecordRow,
          $$HealthRecordRowsTableFilterComposer,
          $$HealthRecordRowsTableOrderingComposer,
          $$HealthRecordRowsTableAnnotationComposer,
          $$HealthRecordRowsTableCreateCompanionBuilder,
          $$HealthRecordRowsTableUpdateCompanionBuilder,
          (
            HealthRecordRow,
            BaseReferences<
              _$LetterHealthDatabase,
              $HealthRecordRowsTable,
              HealthRecordRow
            >,
          ),
          HealthRecordRow,
          PrefetchHooks Function()
        > {
  $$HealthRecordRowsTableTableManager(
    _$LetterHealthDatabase db,
    $HealthRecordRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HealthRecordRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HealthRecordRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HealthRecordRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> symptom = const Value.absent(),
                Value<int> severity = const Value.absent(),
                Value<String> functionalImpactsJson = const Value.absent(),
                Value<int> experiencedDay = const Value.absent(),
                Value<int> recordedAtMillis = const Value.absent(),
                Value<int> updatedAtMillis = const Value.absent(),
                Value<String> provenance = const Value.absent(),
                Value<bool> userConfirmed = const Value.absent(),
                Value<int> vocabularyVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HealthRecordRowsCompanion(
                id: id,
                symptom: symptom,
                severity: severity,
                functionalImpactsJson: functionalImpactsJson,
                experiencedDay: experiencedDay,
                recordedAtMillis: recordedAtMillis,
                updatedAtMillis: updatedAtMillis,
                provenance: provenance,
                userConfirmed: userConfirmed,
                vocabularyVersion: vocabularyVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String symptom,
                required int severity,
                required String functionalImpactsJson,
                required int experiencedDay,
                required int recordedAtMillis,
                required int updatedAtMillis,
                required String provenance,
                required bool userConfirmed,
                required int vocabularyVersion,
                Value<int> rowid = const Value.absent(),
              }) => HealthRecordRowsCompanion.insert(
                id: id,
                symptom: symptom,
                severity: severity,
                functionalImpactsJson: functionalImpactsJson,
                experiencedDay: experiencedDay,
                recordedAtMillis: recordedAtMillis,
                updatedAtMillis: updatedAtMillis,
                provenance: provenance,
                userConfirmed: userConfirmed,
                vocabularyVersion: vocabularyVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HealthRecordRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$LetterHealthDatabase,
      $HealthRecordRowsTable,
      HealthRecordRow,
      $$HealthRecordRowsTableFilterComposer,
      $$HealthRecordRowsTableOrderingComposer,
      $$HealthRecordRowsTableAnnotationComposer,
      $$HealthRecordRowsTableCreateCompanionBuilder,
      $$HealthRecordRowsTableUpdateCompanionBuilder,
      (
        HealthRecordRow,
        BaseReferences<
          _$LetterHealthDatabase,
          $HealthRecordRowsTable,
          HealthRecordRow
        >,
      ),
      HealthRecordRow,
      PrefetchHooks Function()
    >;
typedef $$CaptureNoteRowsTableCreateCompanionBuilder =
    CaptureNoteRowsCompanion Function({
      required String id,
      required String content,
      required String source,
      required int createdAtMillis,
      Value<int> rowid,
    });
typedef $$CaptureNoteRowsTableUpdateCompanionBuilder =
    CaptureNoteRowsCompanion Function({
      Value<String> id,
      Value<String> content,
      Value<String> source,
      Value<int> createdAtMillis,
      Value<int> rowid,
    });

class $$CaptureNoteRowsTableFilterComposer
    extends Composer<_$LetterHealthDatabase, $CaptureNoteRowsTable> {
  $$CaptureNoteRowsTableFilterComposer({
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

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CaptureNoteRowsTableOrderingComposer
    extends Composer<_$LetterHealthDatabase, $CaptureNoteRowsTable> {
  $$CaptureNoteRowsTableOrderingComposer({
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

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CaptureNoteRowsTableAnnotationComposer
    extends Composer<_$LetterHealthDatabase, $CaptureNoteRowsTable> {
  $$CaptureNoteRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => column,
  );
}

class $$CaptureNoteRowsTableTableManager
    extends
        RootTableManager<
          _$LetterHealthDatabase,
          $CaptureNoteRowsTable,
          CaptureNoteRow,
          $$CaptureNoteRowsTableFilterComposer,
          $$CaptureNoteRowsTableOrderingComposer,
          $$CaptureNoteRowsTableAnnotationComposer,
          $$CaptureNoteRowsTableCreateCompanionBuilder,
          $$CaptureNoteRowsTableUpdateCompanionBuilder,
          (
            CaptureNoteRow,
            BaseReferences<
              _$LetterHealthDatabase,
              $CaptureNoteRowsTable,
              CaptureNoteRow
            >,
          ),
          CaptureNoteRow,
          PrefetchHooks Function()
        > {
  $$CaptureNoteRowsTableTableManager(
    _$LetterHealthDatabase db,
    $CaptureNoteRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CaptureNoteRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CaptureNoteRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CaptureNoteRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> createdAtMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CaptureNoteRowsCompanion(
                id: id,
                content: content,
                source: source,
                createdAtMillis: createdAtMillis,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String content,
                required String source,
                required int createdAtMillis,
                Value<int> rowid = const Value.absent(),
              }) => CaptureNoteRowsCompanion.insert(
                id: id,
                content: content,
                source: source,
                createdAtMillis: createdAtMillis,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CaptureNoteRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$LetterHealthDatabase,
      $CaptureNoteRowsTable,
      CaptureNoteRow,
      $$CaptureNoteRowsTableFilterComposer,
      $$CaptureNoteRowsTableOrderingComposer,
      $$CaptureNoteRowsTableAnnotationComposer,
      $$CaptureNoteRowsTableCreateCompanionBuilder,
      $$CaptureNoteRowsTableUpdateCompanionBuilder,
      (
        CaptureNoteRow,
        BaseReferences<
          _$LetterHealthDatabase,
          $CaptureNoteRowsTable,
          CaptureNoteRow
        >,
      ),
      CaptureNoteRow,
      PrefetchHooks Function()
    >;
typedef $$MomentCheckInRowsTableCreateCompanionBuilder =
    MomentCheckInRowsCompanion Function({
      required String id,
      required String state,
      required int occurredAtMillis,
      required int createdAtMillis,
      Value<int> rowid,
    });
typedef $$MomentCheckInRowsTableUpdateCompanionBuilder =
    MomentCheckInRowsCompanion Function({
      Value<String> id,
      Value<String> state,
      Value<int> occurredAtMillis,
      Value<int> createdAtMillis,
      Value<int> rowid,
    });

class $$MomentCheckInRowsTableFilterComposer
    extends Composer<_$LetterHealthDatabase, $MomentCheckInRowsTable> {
  $$MomentCheckInRowsTableFilterComposer({
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

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get occurredAtMillis => $composableBuilder(
    column: $table.occurredAtMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MomentCheckInRowsTableOrderingComposer
    extends Composer<_$LetterHealthDatabase, $MomentCheckInRowsTable> {
  $$MomentCheckInRowsTableOrderingComposer({
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

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get occurredAtMillis => $composableBuilder(
    column: $table.occurredAtMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MomentCheckInRowsTableAnnotationComposer
    extends Composer<_$LetterHealthDatabase, $MomentCheckInRowsTable> {
  $$MomentCheckInRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get occurredAtMillis => $composableBuilder(
    column: $table.occurredAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => column,
  );
}

class $$MomentCheckInRowsTableTableManager
    extends
        RootTableManager<
          _$LetterHealthDatabase,
          $MomentCheckInRowsTable,
          MomentCheckInRow,
          $$MomentCheckInRowsTableFilterComposer,
          $$MomentCheckInRowsTableOrderingComposer,
          $$MomentCheckInRowsTableAnnotationComposer,
          $$MomentCheckInRowsTableCreateCompanionBuilder,
          $$MomentCheckInRowsTableUpdateCompanionBuilder,
          (
            MomentCheckInRow,
            BaseReferences<
              _$LetterHealthDatabase,
              $MomentCheckInRowsTable,
              MomentCheckInRow
            >,
          ),
          MomentCheckInRow,
          PrefetchHooks Function()
        > {
  $$MomentCheckInRowsTableTableManager(
    _$LetterHealthDatabase db,
    $MomentCheckInRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MomentCheckInRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MomentCheckInRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MomentCheckInRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> occurredAtMillis = const Value.absent(),
                Value<int> createdAtMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MomentCheckInRowsCompanion(
                id: id,
                state: state,
                occurredAtMillis: occurredAtMillis,
                createdAtMillis: createdAtMillis,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String state,
                required int occurredAtMillis,
                required int createdAtMillis,
                Value<int> rowid = const Value.absent(),
              }) => MomentCheckInRowsCompanion.insert(
                id: id,
                state: state,
                occurredAtMillis: occurredAtMillis,
                createdAtMillis: createdAtMillis,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MomentCheckInRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$LetterHealthDatabase,
      $MomentCheckInRowsTable,
      MomentCheckInRow,
      $$MomentCheckInRowsTableFilterComposer,
      $$MomentCheckInRowsTableOrderingComposer,
      $$MomentCheckInRowsTableAnnotationComposer,
      $$MomentCheckInRowsTableCreateCompanionBuilder,
      $$MomentCheckInRowsTableUpdateCompanionBuilder,
      (
        MomentCheckInRow,
        BaseReferences<
          _$LetterHealthDatabase,
          $MomentCheckInRowsTable,
          MomentCheckInRow
        >,
      ),
      MomentCheckInRow,
      PrefetchHooks Function()
    >;
typedef $$PreparationPlanRowsTableCreateCompanionBuilder =
    PreparationPlanRowsCompanion Function({
      required String id,
      required String status,
      required String evidenceFingerprint,
      required String sourceRecordIdsJson,
      required bool includeCare,
      required String careActionId,
      required String careActionLabel,
      required String careMode,
      required int betterCount,
      required int sameCount,
      required int worseCount,
      Value<String?> noteText,
      Value<String?> personalText,
      required int createdAtMillis,
      required int updatedAtMillis,
      Value<int> rowid,
    });
typedef $$PreparationPlanRowsTableUpdateCompanionBuilder =
    PreparationPlanRowsCompanion Function({
      Value<String> id,
      Value<String> status,
      Value<String> evidenceFingerprint,
      Value<String> sourceRecordIdsJson,
      Value<bool> includeCare,
      Value<String> careActionId,
      Value<String> careActionLabel,
      Value<String> careMode,
      Value<int> betterCount,
      Value<int> sameCount,
      Value<int> worseCount,
      Value<String?> noteText,
      Value<String?> personalText,
      Value<int> createdAtMillis,
      Value<int> updatedAtMillis,
      Value<int> rowid,
    });

class $$PreparationPlanRowsTableFilterComposer
    extends Composer<_$LetterHealthDatabase, $PreparationPlanRowsTable> {
  $$PreparationPlanRowsTableFilterComposer({
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

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get evidenceFingerprint => $composableBuilder(
    column: $table.evidenceFingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceRecordIdsJson => $composableBuilder(
    column: $table.sourceRecordIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get includeCare => $composableBuilder(
    column: $table.includeCare,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get careActionId => $composableBuilder(
    column: $table.careActionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get careActionLabel => $composableBuilder(
    column: $table.careActionLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get careMode => $composableBuilder(
    column: $table.careMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get betterCount => $composableBuilder(
    column: $table.betterCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sameCount => $composableBuilder(
    column: $table.sameCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get worseCount => $composableBuilder(
    column: $table.worseCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get noteText => $composableBuilder(
    column: $table.noteText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get personalText => $composableBuilder(
    column: $table.personalText,
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

class $$PreparationPlanRowsTableOrderingComposer
    extends Composer<_$LetterHealthDatabase, $PreparationPlanRowsTable> {
  $$PreparationPlanRowsTableOrderingComposer({
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

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get evidenceFingerprint => $composableBuilder(
    column: $table.evidenceFingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceRecordIdsJson => $composableBuilder(
    column: $table.sourceRecordIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get includeCare => $composableBuilder(
    column: $table.includeCare,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get careActionId => $composableBuilder(
    column: $table.careActionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get careActionLabel => $composableBuilder(
    column: $table.careActionLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get careMode => $composableBuilder(
    column: $table.careMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get betterCount => $composableBuilder(
    column: $table.betterCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sameCount => $composableBuilder(
    column: $table.sameCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get worseCount => $composableBuilder(
    column: $table.worseCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get noteText => $composableBuilder(
    column: $table.noteText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get personalText => $composableBuilder(
    column: $table.personalText,
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

class $$PreparationPlanRowsTableAnnotationComposer
    extends Composer<_$LetterHealthDatabase, $PreparationPlanRowsTable> {
  $$PreparationPlanRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get evidenceFingerprint => $composableBuilder(
    column: $table.evidenceFingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceRecordIdsJson => $composableBuilder(
    column: $table.sourceRecordIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get includeCare => $composableBuilder(
    column: $table.includeCare,
    builder: (column) => column,
  );

  GeneratedColumn<String> get careActionId => $composableBuilder(
    column: $table.careActionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get careActionLabel => $composableBuilder(
    column: $table.careActionLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get careMode =>
      $composableBuilder(column: $table.careMode, builder: (column) => column);

  GeneratedColumn<int> get betterCount => $composableBuilder(
    column: $table.betterCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sameCount =>
      $composableBuilder(column: $table.sameCount, builder: (column) => column);

  GeneratedColumn<int> get worseCount => $composableBuilder(
    column: $table.worseCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get noteText =>
      $composableBuilder(column: $table.noteText, builder: (column) => column);

  GeneratedColumn<String> get personalText => $composableBuilder(
    column: $table.personalText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMillis => $composableBuilder(
    column: $table.updatedAtMillis,
    builder: (column) => column,
  );
}

class $$PreparationPlanRowsTableTableManager
    extends
        RootTableManager<
          _$LetterHealthDatabase,
          $PreparationPlanRowsTable,
          PreparationPlanRow,
          $$PreparationPlanRowsTableFilterComposer,
          $$PreparationPlanRowsTableOrderingComposer,
          $$PreparationPlanRowsTableAnnotationComposer,
          $$PreparationPlanRowsTableCreateCompanionBuilder,
          $$PreparationPlanRowsTableUpdateCompanionBuilder,
          (
            PreparationPlanRow,
            BaseReferences<
              _$LetterHealthDatabase,
              $PreparationPlanRowsTable,
              PreparationPlanRow
            >,
          ),
          PreparationPlanRow,
          PrefetchHooks Function()
        > {
  $$PreparationPlanRowsTableTableManager(
    _$LetterHealthDatabase db,
    $PreparationPlanRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PreparationPlanRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PreparationPlanRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PreparationPlanRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> evidenceFingerprint = const Value.absent(),
                Value<String> sourceRecordIdsJson = const Value.absent(),
                Value<bool> includeCare = const Value.absent(),
                Value<String> careActionId = const Value.absent(),
                Value<String> careActionLabel = const Value.absent(),
                Value<String> careMode = const Value.absent(),
                Value<int> betterCount = const Value.absent(),
                Value<int> sameCount = const Value.absent(),
                Value<int> worseCount = const Value.absent(),
                Value<String?> noteText = const Value.absent(),
                Value<String?> personalText = const Value.absent(),
                Value<int> createdAtMillis = const Value.absent(),
                Value<int> updatedAtMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PreparationPlanRowsCompanion(
                id: id,
                status: status,
                evidenceFingerprint: evidenceFingerprint,
                sourceRecordIdsJson: sourceRecordIdsJson,
                includeCare: includeCare,
                careActionId: careActionId,
                careActionLabel: careActionLabel,
                careMode: careMode,
                betterCount: betterCount,
                sameCount: sameCount,
                worseCount: worseCount,
                noteText: noteText,
                personalText: personalText,
                createdAtMillis: createdAtMillis,
                updatedAtMillis: updatedAtMillis,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String status,
                required String evidenceFingerprint,
                required String sourceRecordIdsJson,
                required bool includeCare,
                required String careActionId,
                required String careActionLabel,
                required String careMode,
                required int betterCount,
                required int sameCount,
                required int worseCount,
                Value<String?> noteText = const Value.absent(),
                Value<String?> personalText = const Value.absent(),
                required int createdAtMillis,
                required int updatedAtMillis,
                Value<int> rowid = const Value.absent(),
              }) => PreparationPlanRowsCompanion.insert(
                id: id,
                status: status,
                evidenceFingerprint: evidenceFingerprint,
                sourceRecordIdsJson: sourceRecordIdsJson,
                includeCare: includeCare,
                careActionId: careActionId,
                careActionLabel: careActionLabel,
                careMode: careMode,
                betterCount: betterCount,
                sameCount: sameCount,
                worseCount: worseCount,
                noteText: noteText,
                personalText: personalText,
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

typedef $$PreparationPlanRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$LetterHealthDatabase,
      $PreparationPlanRowsTable,
      PreparationPlanRow,
      $$PreparationPlanRowsTableFilterComposer,
      $$PreparationPlanRowsTableOrderingComposer,
      $$PreparationPlanRowsTableAnnotationComposer,
      $$PreparationPlanRowsTableCreateCompanionBuilder,
      $$PreparationPlanRowsTableUpdateCompanionBuilder,
      (
        PreparationPlanRow,
        BaseReferences<
          _$LetterHealthDatabase,
          $PreparationPlanRowsTable,
          PreparationPlanRow
        >,
      ),
      PreparationPlanRow,
      PrefetchHooks Function()
    >;
typedef $$PreparationDismissalRowsTableCreateCompanionBuilder =
    PreparationDismissalRowsCompanion Function({
      required String fingerprint,
      required String evidenceLine,
      required int dismissedAtMillis,
      Value<int> rowid,
    });
typedef $$PreparationDismissalRowsTableUpdateCompanionBuilder =
    PreparationDismissalRowsCompanion Function({
      Value<String> fingerprint,
      Value<String> evidenceLine,
      Value<int> dismissedAtMillis,
      Value<int> rowid,
    });

class $$PreparationDismissalRowsTableFilterComposer
    extends Composer<_$LetterHealthDatabase, $PreparationDismissalRowsTable> {
  $$PreparationDismissalRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get evidenceLine => $composableBuilder(
    column: $table.evidenceLine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dismissedAtMillis => $composableBuilder(
    column: $table.dismissedAtMillis,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PreparationDismissalRowsTableOrderingComposer
    extends Composer<_$LetterHealthDatabase, $PreparationDismissalRowsTable> {
  $$PreparationDismissalRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get evidenceLine => $composableBuilder(
    column: $table.evidenceLine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dismissedAtMillis => $composableBuilder(
    column: $table.dismissedAtMillis,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PreparationDismissalRowsTableAnnotationComposer
    extends Composer<_$LetterHealthDatabase, $PreparationDismissalRowsTable> {
  $$PreparationDismissalRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get evidenceLine => $composableBuilder(
    column: $table.evidenceLine,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dismissedAtMillis => $composableBuilder(
    column: $table.dismissedAtMillis,
    builder: (column) => column,
  );
}

class $$PreparationDismissalRowsTableTableManager
    extends
        RootTableManager<
          _$LetterHealthDatabase,
          $PreparationDismissalRowsTable,
          PreparationDismissalRow,
          $$PreparationDismissalRowsTableFilterComposer,
          $$PreparationDismissalRowsTableOrderingComposer,
          $$PreparationDismissalRowsTableAnnotationComposer,
          $$PreparationDismissalRowsTableCreateCompanionBuilder,
          $$PreparationDismissalRowsTableUpdateCompanionBuilder,
          (
            PreparationDismissalRow,
            BaseReferences<
              _$LetterHealthDatabase,
              $PreparationDismissalRowsTable,
              PreparationDismissalRow
            >,
          ),
          PreparationDismissalRow,
          PrefetchHooks Function()
        > {
  $$PreparationDismissalRowsTableTableManager(
    _$LetterHealthDatabase db,
    $PreparationDismissalRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PreparationDismissalRowsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$PreparationDismissalRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PreparationDismissalRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> fingerprint = const Value.absent(),
                Value<String> evidenceLine = const Value.absent(),
                Value<int> dismissedAtMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PreparationDismissalRowsCompanion(
                fingerprint: fingerprint,
                evidenceLine: evidenceLine,
                dismissedAtMillis: dismissedAtMillis,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String fingerprint,
                required String evidenceLine,
                required int dismissedAtMillis,
                Value<int> rowid = const Value.absent(),
              }) => PreparationDismissalRowsCompanion.insert(
                fingerprint: fingerprint,
                evidenceLine: evidenceLine,
                dismissedAtMillis: dismissedAtMillis,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PreparationDismissalRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$LetterHealthDatabase,
      $PreparationDismissalRowsTable,
      PreparationDismissalRow,
      $$PreparationDismissalRowsTableFilterComposer,
      $$PreparationDismissalRowsTableOrderingComposer,
      $$PreparationDismissalRowsTableAnnotationComposer,
      $$PreparationDismissalRowsTableCreateCompanionBuilder,
      $$PreparationDismissalRowsTableUpdateCompanionBuilder,
      (
        PreparationDismissalRow,
        BaseReferences<
          _$LetterHealthDatabase,
          $PreparationDismissalRowsTable,
          PreparationDismissalRow
        >,
      ),
      PreparationDismissalRow,
      PrefetchHooks Function()
    >;

class $LetterHealthDatabaseManager {
  final _$LetterHealthDatabase _db;
  $LetterHealthDatabaseManager(this._db);
  $$PeriodRowsTableTableManager get periodRows =>
      $$PeriodRowsTableTableManager(_db, _db.periodRows);
  $$PeriodFlowRowsTableTableManager get periodFlowRows =>
      $$PeriodFlowRowsTableTableManager(_db, _db.periodFlowRows);
  $$CareRecordRowsTableTableManager get careRecordRows =>
      $$CareRecordRowsTableTableManager(_db, _db.careRecordRows);
  $$CareReflectionRowsTableTableManager get careReflectionRows =>
      $$CareReflectionRowsTableTableManager(_db, _db.careReflectionRows);
  $$CycleReflectionRowsTableTableManager get cycleReflectionRows =>
      $$CycleReflectionRowsTableTableManager(_db, _db.cycleReflectionRows);
  $$HealthRecordRowsTableTableManager get healthRecordRows =>
      $$HealthRecordRowsTableTableManager(_db, _db.healthRecordRows);
  $$CaptureNoteRowsTableTableManager get captureNoteRows =>
      $$CaptureNoteRowsTableTableManager(_db, _db.captureNoteRows);
  $$MomentCheckInRowsTableTableManager get momentCheckInRows =>
      $$MomentCheckInRowsTableTableManager(_db, _db.momentCheckInRows);
  $$PreparationPlanRowsTableTableManager get preparationPlanRows =>
      $$PreparationPlanRowsTableTableManager(_db, _db.preparationPlanRows);
  $$PreparationDismissalRowsTableTableManager get preparationDismissalRows =>
      $$PreparationDismissalRowsTableTableManager(
        _db,
        _db.preparationDismissalRows,
      );
}
