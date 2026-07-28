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

class $ImpulseDraftRowsTable extends ImpulseDraftRows
    with TableInfo<$ImpulseDraftRowsTable, ImpulseDraftRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImpulseDraftRowsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _sealedAtMillisMeta = const VerificationMeta(
    'sealedAtMillis',
  );
  @override
  late final GeneratedColumn<int> sealedAtMillis = GeneratedColumn<int>(
    'sealed_at_millis',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unlockAtMillisMeta = const VerificationMeta(
    'unlockAtMillis',
  );
  @override
  late final GeneratedColumn<int> unlockAtMillis = GeneratedColumn<int>(
    'unlock_at_millis',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    content,
    createdAtMillis,
    updatedAtMillis,
    sealedAtMillis,
    unlockAtMillis,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'impulse_draft_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImpulseDraftRow> instance, {
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
    if (data.containsKey('sealed_at_millis')) {
      context.handle(
        _sealedAtMillisMeta,
        sealedAtMillis.isAcceptableOrUnknown(
          data['sealed_at_millis']!,
          _sealedAtMillisMeta,
        ),
      );
    }
    if (data.containsKey('unlock_at_millis')) {
      context.handle(
        _unlockAtMillisMeta,
        unlockAtMillis.isAcceptableOrUnknown(
          data['unlock_at_millis']!,
          _unlockAtMillisMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ImpulseDraftRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImpulseDraftRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      createdAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_millis'],
      )!,
      updatedAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_millis'],
      )!,
      sealedAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sealed_at_millis'],
      ),
      unlockAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unlock_at_millis'],
      ),
    );
  }

  @override
  $ImpulseDraftRowsTable createAlias(String alias) {
    return $ImpulseDraftRowsTable(attachedDatabase, alias);
  }
}

class ImpulseDraftRow extends DataClass implements Insertable<ImpulseDraftRow> {
  final String id;
  final String content;
  final int createdAtMillis;
  final int updatedAtMillis;
  final int? sealedAtMillis;
  final int? unlockAtMillis;
  const ImpulseDraftRow({
    required this.id,
    required this.content,
    required this.createdAtMillis,
    required this.updatedAtMillis,
    this.sealedAtMillis,
    this.unlockAtMillis,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['content'] = Variable<String>(content);
    map['created_at_millis'] = Variable<int>(createdAtMillis);
    map['updated_at_millis'] = Variable<int>(updatedAtMillis);
    if (!nullToAbsent || sealedAtMillis != null) {
      map['sealed_at_millis'] = Variable<int>(sealedAtMillis);
    }
    if (!nullToAbsent || unlockAtMillis != null) {
      map['unlock_at_millis'] = Variable<int>(unlockAtMillis);
    }
    return map;
  }

  ImpulseDraftRowsCompanion toCompanion(bool nullToAbsent) {
    return ImpulseDraftRowsCompanion(
      id: Value(id),
      content: Value(content),
      createdAtMillis: Value(createdAtMillis),
      updatedAtMillis: Value(updatedAtMillis),
      sealedAtMillis: sealedAtMillis == null && nullToAbsent
          ? const Value.absent()
          : Value(sealedAtMillis),
      unlockAtMillis: unlockAtMillis == null && nullToAbsent
          ? const Value.absent()
          : Value(unlockAtMillis),
    );
  }

  factory ImpulseDraftRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImpulseDraftRow(
      id: serializer.fromJson<String>(json['id']),
      content: serializer.fromJson<String>(json['content']),
      createdAtMillis: serializer.fromJson<int>(json['createdAtMillis']),
      updatedAtMillis: serializer.fromJson<int>(json['updatedAtMillis']),
      sealedAtMillis: serializer.fromJson<int?>(json['sealedAtMillis']),
      unlockAtMillis: serializer.fromJson<int?>(json['unlockAtMillis']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'content': serializer.toJson<String>(content),
      'createdAtMillis': serializer.toJson<int>(createdAtMillis),
      'updatedAtMillis': serializer.toJson<int>(updatedAtMillis),
      'sealedAtMillis': serializer.toJson<int?>(sealedAtMillis),
      'unlockAtMillis': serializer.toJson<int?>(unlockAtMillis),
    };
  }

  ImpulseDraftRow copyWith({
    String? id,
    String? content,
    int? createdAtMillis,
    int? updatedAtMillis,
    Value<int?> sealedAtMillis = const Value.absent(),
    Value<int?> unlockAtMillis = const Value.absent(),
  }) => ImpulseDraftRow(
    id: id ?? this.id,
    content: content ?? this.content,
    createdAtMillis: createdAtMillis ?? this.createdAtMillis,
    updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
    sealedAtMillis: sealedAtMillis.present
        ? sealedAtMillis.value
        : this.sealedAtMillis,
    unlockAtMillis: unlockAtMillis.present
        ? unlockAtMillis.value
        : this.unlockAtMillis,
  );
  ImpulseDraftRow copyWithCompanion(ImpulseDraftRowsCompanion data) {
    return ImpulseDraftRow(
      id: data.id.present ? data.id.value : this.id,
      content: data.content.present ? data.content.value : this.content,
      createdAtMillis: data.createdAtMillis.present
          ? data.createdAtMillis.value
          : this.createdAtMillis,
      updatedAtMillis: data.updatedAtMillis.present
          ? data.updatedAtMillis.value
          : this.updatedAtMillis,
      sealedAtMillis: data.sealedAtMillis.present
          ? data.sealedAtMillis.value
          : this.sealedAtMillis,
      unlockAtMillis: data.unlockAtMillis.present
          ? data.unlockAtMillis.value
          : this.unlockAtMillis,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImpulseDraftRow(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('createdAtMillis: $createdAtMillis, ')
          ..write('updatedAtMillis: $updatedAtMillis, ')
          ..write('sealedAtMillis: $sealedAtMillis, ')
          ..write('unlockAtMillis: $unlockAtMillis')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    content,
    createdAtMillis,
    updatedAtMillis,
    sealedAtMillis,
    unlockAtMillis,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImpulseDraftRow &&
          other.id == this.id &&
          other.content == this.content &&
          other.createdAtMillis == this.createdAtMillis &&
          other.updatedAtMillis == this.updatedAtMillis &&
          other.sealedAtMillis == this.sealedAtMillis &&
          other.unlockAtMillis == this.unlockAtMillis);
}

class ImpulseDraftRowsCompanion extends UpdateCompanion<ImpulseDraftRow> {
  final Value<String> id;
  final Value<String> content;
  final Value<int> createdAtMillis;
  final Value<int> updatedAtMillis;
  final Value<int?> sealedAtMillis;
  final Value<int?> unlockAtMillis;
  final Value<int> rowid;
  const ImpulseDraftRowsCompanion({
    this.id = const Value.absent(),
    this.content = const Value.absent(),
    this.createdAtMillis = const Value.absent(),
    this.updatedAtMillis = const Value.absent(),
    this.sealedAtMillis = const Value.absent(),
    this.unlockAtMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImpulseDraftRowsCompanion.insert({
    required String id,
    required String content,
    required int createdAtMillis,
    required int updatedAtMillis,
    this.sealedAtMillis = const Value.absent(),
    this.unlockAtMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       content = Value(content),
       createdAtMillis = Value(createdAtMillis),
       updatedAtMillis = Value(updatedAtMillis);
  static Insertable<ImpulseDraftRow> custom({
    Expression<String>? id,
    Expression<String>? content,
    Expression<int>? createdAtMillis,
    Expression<int>? updatedAtMillis,
    Expression<int>? sealedAtMillis,
    Expression<int>? unlockAtMillis,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (content != null) 'content': content,
      if (createdAtMillis != null) 'created_at_millis': createdAtMillis,
      if (updatedAtMillis != null) 'updated_at_millis': updatedAtMillis,
      if (sealedAtMillis != null) 'sealed_at_millis': sealedAtMillis,
      if (unlockAtMillis != null) 'unlock_at_millis': unlockAtMillis,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImpulseDraftRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? content,
    Value<int>? createdAtMillis,
    Value<int>? updatedAtMillis,
    Value<int?>? sealedAtMillis,
    Value<int?>? unlockAtMillis,
    Value<int>? rowid,
  }) {
    return ImpulseDraftRowsCompanion(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAtMillis: createdAtMillis ?? this.createdAtMillis,
      updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
      sealedAtMillis: sealedAtMillis ?? this.sealedAtMillis,
      unlockAtMillis: unlockAtMillis ?? this.unlockAtMillis,
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
    if (createdAtMillis.present) {
      map['created_at_millis'] = Variable<int>(createdAtMillis.value);
    }
    if (updatedAtMillis.present) {
      map['updated_at_millis'] = Variable<int>(updatedAtMillis.value);
    }
    if (sealedAtMillis.present) {
      map['sealed_at_millis'] = Variable<int>(sealedAtMillis.value);
    }
    if (unlockAtMillis.present) {
      map['unlock_at_millis'] = Variable<int>(unlockAtMillis.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImpulseDraftRowsCompanion(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('createdAtMillis: $createdAtMillis, ')
          ..write('updatedAtMillis: $updatedAtMillis, ')
          ..write('sealedAtMillis: $sealedAtMillis, ')
          ..write('unlockAtMillis: $unlockAtMillis, ')
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
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
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

abstract class _$LetterHealthDatabase extends GeneratedDatabase {
  _$LetterHealthDatabase(QueryExecutor e) : super(e);
  $LetterHealthDatabaseManager get managers =>
      $LetterHealthDatabaseManager(this);
  late final $PeriodRowsTable periodRows = $PeriodRowsTable(this);
  late final $ImpulseDraftRowsTable impulseDraftRows = $ImpulseDraftRowsTable(
    this,
  );
  late final $CareRecordRowsTable careRecordRows = $CareRecordRowsTable(this);
  late final $CareReflectionRowsTable careReflectionRows =
      $CareReflectionRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    periodRows,
    impulseDraftRows,
    careRecordRows,
    careReflectionRows,
  ];
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
typedef $$ImpulseDraftRowsTableCreateCompanionBuilder =
    ImpulseDraftRowsCompanion Function({
      required String id,
      required String content,
      required int createdAtMillis,
      required int updatedAtMillis,
      Value<int?> sealedAtMillis,
      Value<int?> unlockAtMillis,
      Value<int> rowid,
    });
typedef $$ImpulseDraftRowsTableUpdateCompanionBuilder =
    ImpulseDraftRowsCompanion Function({
      Value<String> id,
      Value<String> content,
      Value<int> createdAtMillis,
      Value<int> updatedAtMillis,
      Value<int?> sealedAtMillis,
      Value<int?> unlockAtMillis,
      Value<int> rowid,
    });

class $$ImpulseDraftRowsTableFilterComposer
    extends Composer<_$LetterHealthDatabase, $ImpulseDraftRowsTable> {
  $$ImpulseDraftRowsTableFilterComposer({
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

  ColumnFilters<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMillis => $composableBuilder(
    column: $table.updatedAtMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sealedAtMillis => $composableBuilder(
    column: $table.sealedAtMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unlockAtMillis => $composableBuilder(
    column: $table.unlockAtMillis,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ImpulseDraftRowsTableOrderingComposer
    extends Composer<_$LetterHealthDatabase, $ImpulseDraftRowsTable> {
  $$ImpulseDraftRowsTableOrderingComposer({
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

  ColumnOrderings<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMillis => $composableBuilder(
    column: $table.updatedAtMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sealedAtMillis => $composableBuilder(
    column: $table.sealedAtMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unlockAtMillis => $composableBuilder(
    column: $table.unlockAtMillis,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ImpulseDraftRowsTableAnnotationComposer
    extends Composer<_$LetterHealthDatabase, $ImpulseDraftRowsTable> {
  $$ImpulseDraftRowsTableAnnotationComposer({
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

  GeneratedColumn<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMillis => $composableBuilder(
    column: $table.updatedAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sealedAtMillis => $composableBuilder(
    column: $table.sealedAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unlockAtMillis => $composableBuilder(
    column: $table.unlockAtMillis,
    builder: (column) => column,
  );
}

class $$ImpulseDraftRowsTableTableManager
    extends
        RootTableManager<
          _$LetterHealthDatabase,
          $ImpulseDraftRowsTable,
          ImpulseDraftRow,
          $$ImpulseDraftRowsTableFilterComposer,
          $$ImpulseDraftRowsTableOrderingComposer,
          $$ImpulseDraftRowsTableAnnotationComposer,
          $$ImpulseDraftRowsTableCreateCompanionBuilder,
          $$ImpulseDraftRowsTableUpdateCompanionBuilder,
          (
            ImpulseDraftRow,
            BaseReferences<
              _$LetterHealthDatabase,
              $ImpulseDraftRowsTable,
              ImpulseDraftRow
            >,
          ),
          ImpulseDraftRow,
          PrefetchHooks Function()
        > {
  $$ImpulseDraftRowsTableTableManager(
    _$LetterHealthDatabase db,
    $ImpulseDraftRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImpulseDraftRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImpulseDraftRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImpulseDraftRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int> createdAtMillis = const Value.absent(),
                Value<int> updatedAtMillis = const Value.absent(),
                Value<int?> sealedAtMillis = const Value.absent(),
                Value<int?> unlockAtMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImpulseDraftRowsCompanion(
                id: id,
                content: content,
                createdAtMillis: createdAtMillis,
                updatedAtMillis: updatedAtMillis,
                sealedAtMillis: sealedAtMillis,
                unlockAtMillis: unlockAtMillis,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String content,
                required int createdAtMillis,
                required int updatedAtMillis,
                Value<int?> sealedAtMillis = const Value.absent(),
                Value<int?> unlockAtMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImpulseDraftRowsCompanion.insert(
                id: id,
                content: content,
                createdAtMillis: createdAtMillis,
                updatedAtMillis: updatedAtMillis,
                sealedAtMillis: sealedAtMillis,
                unlockAtMillis: unlockAtMillis,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ImpulseDraftRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$LetterHealthDatabase,
      $ImpulseDraftRowsTable,
      ImpulseDraftRow,
      $$ImpulseDraftRowsTableFilterComposer,
      $$ImpulseDraftRowsTableOrderingComposer,
      $$ImpulseDraftRowsTableAnnotationComposer,
      $$ImpulseDraftRowsTableCreateCompanionBuilder,
      $$ImpulseDraftRowsTableUpdateCompanionBuilder,
      (
        ImpulseDraftRow,
        BaseReferences<
          _$LetterHealthDatabase,
          $ImpulseDraftRowsTable,
          ImpulseDraftRow
        >,
      ),
      ImpulseDraftRow,
      PrefetchHooks Function()
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
          (
            CareRecordRow,
            BaseReferences<
              _$LetterHealthDatabase,
              $CareRecordRowsTable,
              CareRecordRow
            >,
          ),
          CareRecordRow,
          PrefetchHooks Function()
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
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
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
      (
        CareRecordRow,
        BaseReferences<
          _$LetterHealthDatabase,
          $CareRecordRowsTable,
          CareRecordRow
        >,
      ),
      CareRecordRow,
      PrefetchHooks Function()
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

  ColumnFilters<String> get careRecordId => $composableBuilder(
    column: $table.careRecordId,
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

  ColumnOrderings<String> get careRecordId => $composableBuilder(
    column: $table.careRecordId,
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

  GeneratedColumn<String> get careRecordId => $composableBuilder(
    column: $table.careRecordId,
    builder: (column) => column,
  );

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
          (
            CareReflectionRow,
            BaseReferences<
              _$LetterHealthDatabase,
              $CareReflectionRowsTable,
              CareReflectionRow
            >,
          ),
          CareReflectionRow,
          PrefetchHooks Function()
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
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
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
      (
        CareReflectionRow,
        BaseReferences<
          _$LetterHealthDatabase,
          $CareReflectionRowsTable,
          CareReflectionRow
        >,
      ),
      CareReflectionRow,
      PrefetchHooks Function()
    >;

class $LetterHealthDatabaseManager {
  final _$LetterHealthDatabase _db;
  $LetterHealthDatabaseManager(this._db);
  $$PeriodRowsTableTableManager get periodRows =>
      $$PeriodRowsTableTableManager(_db, _db.periodRows);
  $$ImpulseDraftRowsTableTableManager get impulseDraftRows =>
      $$ImpulseDraftRowsTableTableManager(_db, _db.impulseDraftRows);
  $$CareRecordRowsTableTableManager get careRecordRows =>
      $$CareRecordRowsTableTableManager(_db, _db.careRecordRows);
  $$CareReflectionRowsTableTableManager get careReflectionRows =>
      $$CareReflectionRowsTableTableManager(_db, _db.careReflectionRows);
}
