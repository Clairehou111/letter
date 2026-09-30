import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/capture/domain/capture_models.dart';
import 'package:letter_mobile/features/comfort_kit/domain/comfort_kit.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/patterns/domain/personal_pattern.dart';

void main() {
  const assembler = ComfortKitAssembler();

  test('forms only from explicitly eligible personal evidence', () {
    final result = assembler.compose(
      supportActions: [
        _action(id: 'unknown', better: 0, pinned: false),
        _action(id: 'better', better: 1, pinned: false),
      ],
      careReflections: [_careReflection('care-note', 'You can pause.')],
      cycleReflections: [_cycleReflection('cycle-note', 'Cancel one thing.')],
      quickNotes: [_note('ordinary', keep: false), _note('kept', keep: true)],
    );

    expect(result.isFormed, isTrue);
    expect(result.items.map((item) => item.sourceId), [
      'action:better',
      'care-reflection:care-note',
      'cycle-reflection:cycle-note',
      'quick-note:kept',
    ]);
  });

  test('ranks repeated Better before pinned and recent Better', () {
    final result = assembler.compose(
      supportActions: [
        _action(id: 'recent', better: 1, pinned: false, day: 20),
        _action(id: 'pinned', better: 0, pinned: true, day: 10),
        _action(id: 'repeated', better: 2, pinned: false, day: 5),
      ],
      careReflections: const [],
      cycleReflections: const [],
      quickNotes: const [],
    );

    expect(result.items.map((item) => item.sourceId), [
      'action:repeated',
      'action:pinned',
      'action:recent',
    ]);
  });

  test('remove hides one version while do-not-show hides later versions', () {
    final original = _action(id: 'care', better: 1, pinned: false);
    final first = assembler
        .compose(
          supportActions: [original],
          careReflections: const [],
          cycleReflections: const [],
          quickNotes: const [],
        )
        .items
        .single;
    final removed = ComfortKitItemOverride(
      sourceId: first.sourceId,
      sourceVersion: first.sourceVersion,
      action: ComfortKitOverrideAction.removeUntilChanged,
      updatedAt: DateTime.utc(2026, 1, 1),
    );

    expect(
      assembler
          .compose(
            supportActions: [original],
            careReflections: const [],
            cycleReflections: const [],
            quickNotes: const [],
            overrides: [removed],
          )
          .items,
      isEmpty,
    );
    expect(
      assembler
          .compose(
            supportActions: [_action(id: 'care', better: 2, pinned: false)],
            careReflections: const [],
            cycleReflections: const [],
            quickNotes: const [],
            overrides: [removed],
          )
          .items,
      hasLength(1),
    );

    final forever = ComfortKitItemOverride(
      sourceId: first.sourceId,
      action: ComfortKitOverrideAction.dontShowAgain,
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    expect(
      assembler
          .compose(
            supportActions: [_action(id: 'care', better: 3, pinned: true)],
            careReflections: const [],
            cycleReflections: const [],
            quickNotes: const [],
            overrides: [forever],
          )
          .items,
      isEmpty,
    );
  });

  test('shows only three items proactively and keeps replacements ordered', () {
    final result = assembler.compose(
      supportActions: [
        _action(id: 'a', better: 3, pinned: false, day: 1),
        _action(id: 'b', better: 2, pinned: false, day: 2),
        _action(id: 'c', better: 1, pinned: true, day: 3),
        _action(id: 'd', better: 1, pinned: false, day: 4),
      ],
      careReflections: const [],
      cycleReflections: const [],
      quickNotes: const [],
    );

    expect(result.visibleItems, hasLength(3));
    expect(result.replacementItems.single.sourceId, 'action:d');
  });

  test('formed kit is proactive only around the forecast window', () {
    final kit = assembler.compose(
      supportActions: [_action(id: 'care', better: 1, pinned: false)],
      careReflections: const [],
      cycleReflections: const [],
      quickNotes: const [],
    );
    const start = LocalDate(2026, 6, 10);
    const end = LocalDate(2026, 6, 13);

    expect(
      ComfortKitWindowState.resolve(
        kit: kit,
        today: const LocalDate(2026, 6, 7),
        forecastStart: start,
        forecastEnd: end,
      ).proactivelyVisible,
      isFalse,
    );
    expect(
      ComfortKitWindowState.resolve(
        kit: kit,
        today: const LocalDate(2026, 6, 8),
        forecastStart: start,
        forecastEnd: end,
      ).proactivelyVisible,
      isTrue,
    );
    expect(
      ComfortKitWindowState.resolve(
        kit: kit,
        today: const LocalDate(2026, 6, 14),
        forecastStart: start,
        forecastEnd: end,
      ).proactivelyVisible,
      isFalse,
    );
  });
}

SupportActionPattern _action({
  required String id,
  required int better,
  required bool pinned,
  int day = 1,
}) => SupportActionPattern(
  id: 'action:$id',
  actionId: id,
  actionLabel: 'Care $id',
  mode: CareMode.heavy,
  count: better == 0 ? 1 : better,
  firstDate: LocalDate(2026, 1, day),
  lastDate: LocalDate(2026, 1, day),
  coveredDates: [LocalDate(2026, 1, day)],
  betterCount: better,
  sameCount: better == 0 ? 1 : 0,
  worseCount: 0,
  sources: [
    PatternSourceReference(
      id: 'record-$id',
      kind: PatternSourceKind.careRecord,
      date: LocalDate(2026, 1, day),
    ),
  ],
  pinned: pinned,
  reflections: const [],
);

CareReflection _careReflection(String id, String note) => CareReflection(
  id: id,
  careRecordId: 'record-$id',
  mode: CareMode.heavy,
  observation: null,
  need: null,
  whatHelped: null,
  futureSelfNote: note,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 2),
);

CycleReflection _cycleReflection(String id, String note) => CycleReflection(
  id: id,
  cycleStartDay: const LocalDate(2026, 1, 1).epochDay,
  observation: null,
  need: null,
  whatHelped: null,
  futureSelfNote: note,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 2),
);

CaptureNote _note(String id, {required bool keep}) => CaptureNote(
  id: id,
  text: 'Note $id',
  source: CaptureSource.typed,
  createdAt: DateTime.utc(2026, 1, 1),
  keepInComfortKit: keep,
);
