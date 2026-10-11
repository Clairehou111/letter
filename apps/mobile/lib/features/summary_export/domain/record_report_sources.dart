import '../../care/domain/care_memory.dart';
import '../../capture/domain/capture_models.dart';
import '../../check_in/domain/moment_check_in.dart';
import '../../cycle/domain/local_date.dart';
import '../../cycle/domain/period_record.dart';
import '../../health_records/domain/health_record.dart';
import '../../record_hub/domain/record_hub_facts.dart';
import '../../record_hub/domain/record_interventions.dart';
import 'record_report_selection.dart';

Map<String, String> _present(Map<String, Object?> values) => {
  for (final e in values.entries)
    if (e.value != null) e.key: e.value.toString(),
};

Map<String, String> _times(DateTime recorded, DateTime updated) => {
  'recorded_at_utc': recorded.toUtc().toIso8601String(),
  'updated_at_utc': updated.toUtc().toIso8601String(),
};

Map<String, String> _metadata(RecordFactMetadata m) => {
  ..._times(m.recordedAt, m.updatedAt),
  ..._present({
    'timing': m.provenance.storageKey,
    'original_timing': m.originalProvenance.storageKey,
    'write_zone': m.writeZoneId,
    'utc_offset_minutes': m.utcOffsetMinutes,
    'original_write_zone': m.originalWriteZoneId,
    'original_utc_offset_minutes': m.originalUtcOffsetMinutes,
    'vocabulary_version': m.vocabularyVersion,
  }),
};

Map<String, String> _duration(RecordedDuration? duration) => duration == null
    ? {}
    : _present({
        'duration_bucket': duration.bucket?.name,
        'duration_label': duration.label,
        'duration_catalog_version': duration.catalogVersion,
        'duration_exact_minutes': duration.exactMinutes,
      });

String _names(Iterable<Enum> values) =>
    (values.map((v) => v.name).toList()..sort()).join('; ');

/// Converts only saved, declared models. Form drafts, programme plans, forecasts,
/// audio and future record types cannot enter this explicit source adapter.
List<RecordReportSource> recordReportSources({
  required LocalDate today,
  required List<PeriodRecord> periods,
  required List<HealthRecord> health,
  required List<MomentCheckIn> moments,
  required List<CareRecord> care,
  required List<CaptureNote> notes,
  required List<CareReflection> reflections,
  required List<CycleReflection> cycleLetters,
  List<RecordHubDateFacts> facts = const [],
  List<ProductEpisode> episodes = const [],
  List<ProductUseRecord> uses = const [],
  List<TriedActionRecord> actions = const [],
  List<ActionCheckbackRecord> checkbacks = const [],
}) {
  final rows = <RecordReportSource>[];
  void add(
    String id,
    RecordReportCategory category,
    String type,
    LocalDate? date,
    Map<String, String> fields, {
    LocalDate? end,
    String? consentId,
    RecordReportCategory? requiredCategory,
  }) {
    final vocabulary = int.tryParse(fields['vocabulary_version'] ?? '');
    final supported = type == 'symptom_rating'
        ? healthRecordVocabularyVersion
        : recordHubVocabularyVersion;
    if (vocabulary != null && (vocabulary < 1 || vocabulary > supported)) {
      return;
    }
    rows.add(
      RecordReportSource(
        id: id,
        category: category,
        sourceType: type,
        date: date,
        fields: fields,
        intervalEnd: end,
        consentId: consentId,
        requiredCategory: requiredCategory,
      ),
    );
  }

  void text(
    String id,
    String type,
    LocalDate? date,
    String? content,
    Map<String, String> metadata, {
    String? owner,
    RecordReportCategory? requiredCategory,
  }) {
    if (content == null || content.isEmpty) return;
    add(
      id,
      RecordReportCategory.privateNotes,
      type,
      date,
      {
        ...metadata,
        'text': content,
        ..._present({'owner_id': owner}),
      },
      consentId: 'private:$type:$id',
      requiredCategory: requiredCategory,
    );
  }

  void fact<T extends DatedRecordDraft>(
    RecordHubFact<T> r,
    RecordReportCategory c,
    String type,
    Map<String, String> fields,
  ) => add(r.id, c, type, r.experiencedDate, {
    ..._metadata(r.metadata),
    ...fields,
  });

  for (final p in periods) {
    add(
      p.id,
      RecordReportCategory.periods,
      'period_range',
      p.startDate,
      {
        ..._times(p.createdAt, p.updatedAt),
        'timing': 'timing_unknown',
        'original_timing': 'timing_unknown',
        ..._present({
          'start_date': p.startDate,
          'end_date': p.endDate,
          'open': p.isOpen,
        }),
      },
      end: p.endDate ?? today,
    );
  }
  for (final r in health.where((r) => r.userConfirmed)) {
    add(
      r.id,
      RecordReportCategory.symptoms,
      'symptom_rating',
      r.experiencedDate,
      {
        ..._times(r.recordedAt, r.updatedAt),
        ..._present({
          'timing': r.provenance.storageKey,
          'original_timing': r.effectiveOriginalProvenance.storageKey,
          'write_zone':
              r.updatedZoneName ??
              (r.updatedAt == r.recordedAt ? r.writeZoneName : null),
          'utc_offset_minutes':
              r.updatedZoneOffsetMinutes ??
              (r.updatedAt == r.recordedAt ? r.writeZoneOffsetMinutes : null),
          'original_write_zone': r.writeZoneName,
          'original_utc_offset_minutes': r.writeZoneOffsetMinutes,
          'vocabulary_version': r.vocabularyVersion,
        }),
        'symptom': r.symptom.name,
        'degree': '${r.severity.score}',
        'functional_impacts': _names(r.functionalImpacts),
      },
    );
  }
  for (final r in moments) {
    add(
      r.id,
      RecordReportCategory.moments,
      'moment_check_in',
      r.experiencedDate,
      {
        ..._times(r.createdAt, r.updatedAt),
        ..._present({
          'state': r.state.name,
          'occurred_at_utc': r.occurredAt.toUtc().toIso8601String(),
          'timing': r.provenance.storageKey,
          'original_timing': r.originalProvenance.storageKey,
          'write_zone':
              r.updatedZoneName ??
              (r.updatedAt == r.createdAt ? r.writeZoneName : null),
          'utc_offset_minutes':
              r.updatedZoneOffsetMinutes ??
              (r.updatedAt == r.createdAt ? r.writeZoneOffsetMinutes : null),
          'original_write_zone': r.writeZoneName,
          'original_utc_offset_minutes': r.writeZoneOffsetMinutes,
        }),
      },
    );
  }
  // Legacy Care has no frozen local experienced date. Include it in All
  // records with unknown date, instead of recomputing it in today's zone.
  for (final r in care) {
    add(r.id, RecordReportCategory.careActions, 'legacy_care_action', null, {
      ..._times(r.createdAt, r.updatedAt),
      'timing': 'timing_unknown',
      'original_timing': 'timing_unknown',
      'actions': r.actionId,
      'status': 'completed',
      'source': 'inAppCare',
      'completion_occurred_at_utc': r.occurredAt.toUtc().toIso8601String(),
    });
    add(r.id, RecordReportCategory.careOutcomes, 'legacy_care_outcome', null, {
      ..._times(r.createdAt, r.updatedAt),
      'timing': 'timing_unknown',
      'original_timing': 'timing_unknown',
      'action_id': r.id,
      'outcome': r.outcome.name,
    });
  }
  for (final n in notes) {
    add(
      n.id,
      RecordReportCategory.privateNotes,
      'capture_note',
      n.experiencedDate,
      {
        ..._times(n.createdAt, n.effectiveUpdatedAt),
        ..._present({
          'timing': n.provenance.storageKey,
          'original_timing': n.effectiveOriginalProvenance.storageKey,
          'original_write_zone': n.writeZoneName,
          'original_utc_offset_minutes': n.writeZoneOffsetMinutes,
          'write_zone': n.effectiveUpdatedAt == n.createdAt
              ? n.writeZoneName
              : null,
          'utc_offset_minutes': n.effectiveUpdatedAt == n.createdAt
              ? n.writeZoneOffsetMinutes
              : null,
          'text': n.text,
          'source': n.source.name,
        }),
      },
      consentId: 'private:capture_note:${n.id}',
    );
  }
  for (final r in reflections) {
    add(
      r.id,
      RecordReportCategory.careReflections,
      'care_reflection',
      null,
      {
        ..._times(r.createdAt, r.updatedAt),
        'timing': 'timing_unknown',
        'original_timing': 'timing_unknown',
        ..._present({
          'owner_id': r.careRecordId,
          'observation': r.observation,
          'need': r.need?.name,
          'what_helped': r.whatHelped,
          'future_self_note': r.futureSelfNote,
        }),
      },
      consentId: 'reflection:${r.id}',
    );
  }
  final periodById = {for (final p in periods) p.id: p};
  for (final r in cycleLetters) {
    final owner = periodById[r.startingPeriodId];
    final date = r.startingPeriodId != null
        ? owner?.startDate
        : LocalDate.fromEpochDay(r.cycleStartDay);
    add(
      r.id,
      RecordReportCategory.cycleLetters,
      'cycle_letter',
      date,
      {
        ..._times(r.createdAt, r.updatedAt),
        'timing': 'timing_unknown',
        'original_timing': 'timing_unknown',
        ..._present({
          'starting_period_id': r.startingPeriodId,
          'observation': r.observation,
          'need': r.need?.name,
          'what_helped': r.whatHelped,
          'future_self_note': r.futureSelfNote,
        }),
      },
      consentId: 'cycle_letter:${r.id}',
    );
  }
  for (final day in facts) {
    final impact = day.impact;
    if (impact != null) {
      fact(impact, RecordReportCategory.dailyImpact, 'daily_impact', {
        'overall_degree': '${impact.value.overall}',
        'domains': _names(impact.value.domains),
      });
    }
    final bleeding = day.bleeding;
    if (bleeding != null) {
      fact(
        bleeding,
        RecordReportCategory.bleeding,
        'bleeding_observation',
        _present({
          'flow': bleeding.value.flow?.name ?? 'none',
          'color': bleeding.value.color?.name,
          'clots': bleeding.value.clots?.name,
          'period_id': bleeding.value.periodId,
        }),
      );
    }
    final sleep = day.sleep;
    if (sleep != null) {
      fact(sleep, RecordReportCategory.sleep, 'sleep', {
        ..._duration(sleep.value.duration),
        ..._present({
          'quality_degree': sleep.value.quality?.score,
          'quality_label': sleep.value.quality?.label,
        }),
        'signals': _names(sleep.value.signals),
      });
    }
    final appetite = day.appetite;
    if (appetite != null) {
      fact(
        appetite,
        RecordReportCategory.appetite,
        'appetite',
        _present({
          'appetite': appetite.value.appetite?.name,
          'craving_degree': appetite.value.cravingScore,
          'craving_type': appetite.value.cravingType?.name,
        }),
      );
      text(
        appetite.id,
        'custom_craving',
        appetite.experiencedDate,
        appetite.value.customCraving,
        _metadata(appetite.metadata),
        owner: appetite.id,
      );
    }
    for (final r in day.activities) {
      fact(r, RecordReportCategory.activity, 'activity', {
        ..._duration(r.value.duration),
        ..._present({
          'type': r.value.type.name,
          'intensity': r.value.intensity?.name,
        }),
      });
      text(
        r.id,
        'custom_activity',
        r.experiencedDate,
        r.value.customName,
        _metadata(r.metadata),
        owner: r.id,
      );
    }
    for (final r in day.events) {
      fact(
        r,
        RecordReportCategory.contextEvents,
        'significant_event',
        _present({
          'type': r.value.type.name,
          'intensity': r.value.intensity?.name,
        }),
      );
      // Event text additionally requires selecting its individual source.
      text(
        r.id,
        'event_text',
        r.experiencedDate,
        [r.value.customName, r.value.note].whereType<String>().join('\n'),
        _metadata(r.metadata),
        owner: r.id,
        requiredCategory: RecordReportCategory.contextEvents,
      );
    }
    for (final r in day.temperatures) {
      final time = r.value.measuredAt;
      fact(
        r,
        RecordReportCategory.temperature,
        'manual_bbt',
        _present({
          'entered_value': r.value.enteredValue,
          'unit': r.value.unit.label,
          'method': r.value.method.name,
          'measured_local_time': time == null
              ? null
              : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
          'quality_flags': _names(r.value.flags),
        }),
      );
    }
  }
  RecordReportCategory productCategory(ProductFamily family) =>
      switch (family) {
        ProductFamily.medication => RecordReportCategory.medication,
        ProductFamily.supplement => RecordReportCategory.supplement,
        ProductFamily.birthControl => RecordReportCategory.birthControl,
      };
  Map<String, String> details(ProductDetails d) => _present({
    'family': d.family.name,
    'exact_name': d.exactName,
    'type': d.medicationType?.name ?? d.supplementType?.name,
    'method': d.birthControlMethod?.name,
    'dose': d.dose,
    'unit': d.unit?.name,
    'custom_unit': d.customUnit,
    'route': d.route?.name,
    'custom_route': d.customRoute,
    'target': d.target,
  });
  final versions = <String, ProductVersion>{};
  for (final e in episodes) {
    final c = productCategory(e.family);
    add(e.id, c, 'product_episode', e.startDate, {
      ..._metadata(e.metadata),
      ..._present({
        'family': e.family.name,
        'start_date': e.startDate,
        'end_date': e.endDate,
        'archived': e.archived,
      }),
    }, end: e.endDate ?? today);
    for (var i = 0; i < e.versions.length; i++) {
      final v = e.versions[i];
      versions[v.id] = v;
      add(
        v.id,
        c,
        'product_version',
        v.effectiveFrom,
        {
          ..._metadata(v.metadata),
          ...details(v.details),
          'episode_id': v.episodeId,
          'version_number': '${v.versionNumber}',
          'effective_from': '${v.effectiveFrom}',
        },
        end: i + 1 < e.versions.length
            ? e.versions[i + 1].effectiveFrom.addDays(-1)
            : e.endDate ?? today,
      );
    }
  }
  for (final r in uses) {
    final v = versions[r.versionId];
    if (v == null) throw const FormatException('Missing product use version.');
    add(
      r.id,
      r.value.status == ProductUseStatus.emergency
          ? RecordReportCategory.emergencyContraception
          : productCategory(v.details.family),
      'product_use',
      r.value.experiencedDate,
      {
        ..._metadata(r.metadata),
        ...details(v.details),
        'episode_id': r.value.episodeId,
        'version_id': r.versionId,
        'use_status': r.value.status.name,
        'daily_shortcut': '${r.dailyShortcut}',
      },
    );
  }
  for (final r in actions) {
    fact(r, RecordReportCategory.careActions, 'tried_action', {
      ..._duration(r.value.duration),
      ..._present({
        'actions': r.value.actions.map((a) => a.kind.name).join('; '),
        'bundle': r.value.bundle,
        'status': r.value.status.name,
        'source': r.value.source.name,
        'care_source_id': r.value.careSourceId,
        'completion_occurred_at_utc': r.value.completionOccurredAt
            ?.toUtc()
            .toIso8601String(),
        'completion_utc_offset_minutes': r.value.completionUtcOffsetMinutes,
      }),
    });
    text(
      r.id,
      'action_context',
      r.experiencedDate,
      [
        r.value.target,
        ...r.value.actions.map((a) => a.customName),
      ].whereType<String>().join('\n'),
      _metadata(r.metadata),
      owner: r.id,
    );
  }
  for (final r in checkbacks) {
    fact(
      r,
      RecordReportCategory.careOutcomes,
      'action_checkback',
      _present({
        'action_id': r.value.actionId,
        'outcome': r.value.outcome.name,
        'target_degree': r.value.targetDegree,
      }),
    );
    if (r.value.unexpected != null) {
      fact(r, RecordReportCategory.adverseText, 'unexpected_observation', {
        'action_id': r.value.actionId,
        'unexpected': r.value.unexpected!.name,
      });
    }
    if (r.value.reflection != null) {
      add(
        r.id,
        RecordReportCategory.careReflections,
        'action_reflection',
        r.experiencedDate,
        {
          ..._metadata(r.metadata),
          'owner_id': r.value.actionId,
          'reflection': r.value.reflection!,
        },
        consentId: 'action_reflection:${r.id}',
      );
    }
  }
  return List.unmodifiable(rows);
}
