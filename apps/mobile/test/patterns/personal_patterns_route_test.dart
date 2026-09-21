import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/experience/plus/plus_experience.dart';
import 'package:letter_mobile/features/care/data/in_memory_care_memory_repository.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/entitlement/data/local_entitlement_repository.dart';
import 'package:letter_mobile/features/entitlement/domain/entitlement.dart';
import 'package:letter_mobile/features/entitlement/presentation/entitlement_scope.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/patterns/data/repository_pattern_source.dart';
import 'package:letter_mobile/features/patterns/data/personal_pattern_preview_repository.dart';
import 'package:letter_mobile/features/patterns/presentation/personal_patterns_route.dart';

Finder _verticalPatternsScrollable() {
  return find
      .descendant(
        of: find.byKey(const Key('patterns-experience-scroll')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      )
      .first;
}

final class _FailingPreviewRepository
    implements PersonalPatternPreviewRepository {
  bool markAttempted = false;

  @override
  Future<bool> hasViewedPreview() async => false;

  @override
  Future<void> markPreviewViewed() async {
    markAttempted = true;
    throw StateError('Secure storage unavailable');
  }
}

Future<void> revealPatternContent(
  WidgetTester tester,
  Finder content, {
  double coarseDelta = -600,
}) async {
  final scrollable = _verticalPatternsScrollable();
  for (var index = 0; index < 8 && content.evaluate().isEmpty; index++) {
    await tester.drag(scrollable, Offset(0, coarseDelta), warnIfMissed: false);
    await tester.pump();
  }
  if (content.evaluate().isEmpty) return;
  await tester.scrollUntilVisible(content, 260, scrollable: scrollable);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('eligible free user sees one real data-backed preview', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 12);
    final source = RepositoryPatternSource(
      healthRecords: InMemoryHealthRecordRepository(
        seed: [
          _healthRecord(
            id: 'one',
            date: const LocalDate(2026, 6, 25),
            timestamp: timestamp,
          ),
          _healthRecord(
            id: 'two',
            date: const LocalDate(2026, 7, 25),
            timestamp: timestamp,
          ),
        ],
      ),
      careMemory: InMemoryCareMemoryRepository(),
      periods: InMemoryPeriodRepository(
        seed: [
          _period('june', const LocalDate(2026, 6, 8), timestamp),
          _period('july', const LocalDate(2026, 7, 8), timestamp),
          _period('august', const LocalDate(2026, 8, 8), timestamp),
        ],
      ),
    );
    final preview = InMemoryPersonalPatternPreviewRepository();
    final entitlement = LocalEntitlementRepository(
      initial: const EntitlementState(status: EntitlementStatus.freeOrUnknown),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: LetterTheme.light,
        home: EntitlementScope(
          repository: entitlement,
          child: PersonalPatternsRoute(
            source: source,
            previewRepository: preview,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('personal-patterns-real-preview')),
      findsOneWidget,
    );
    expect(find.text('Cramps returned twice.'), findsOneWidget);
    expect(find.textContaining('remembers what helped'), findsNothing);
    expect(await preview.hasViewedPreview(), isTrue);

    await tester.tap(find.byKey(const Key('personal-patterns-preview-plans')));
    await tester.pumpAndSettle();
    expect(find.byType(PlusExperience), findsOneWidget);
    expect(find.text('Yearly'), findsOneWidget);
    expect(find.text('Choose a plan'), findsNothing);
  });

  testWidgets('secure preview flag failure does not interrupt Patterns', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 12);
    final preview = _FailingPreviewRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: LetterTheme.light,
        home: EntitlementScope(
          repository: LocalEntitlementRepository(
            initial: const EntitlementState(
              status: EntitlementStatus.freeOrUnknown,
            ),
          ),
          child: PersonalPatternsRoute(
            source: RepositoryPatternSource(
              healthRecords: InMemoryHealthRecordRepository(
                seed: [
                  _healthRecord(
                    id: 'one',
                    date: const LocalDate(2026, 6, 25),
                    timestamp: timestamp,
                  ),
                  _healthRecord(
                    id: 'two',
                    date: const LocalDate(2026, 7, 25),
                    timestamp: timestamp,
                  ),
                ],
              ),
              careMemory: InMemoryCareMemoryRepository(),
              periods: InMemoryPeriodRepository(
                seed: [
                  _period('june', const LocalDate(2026, 6, 8), timestamp),
                  _period('july', const LocalDate(2026, 7, 8), timestamp),
                  _period('august', const LocalDate(2026, 8, 8), timestamp),
                ],
              ),
            ),
            previewRepository: preview,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(preview.markAttempted, isTrue);
    expect(
      find.byKey(const Key('personal-patterns-real-preview')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('one Care check-back previews honestly without a Plus ask', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 12);
    final preview = InMemoryPersonalPatternPreviewRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: LetterTheme.light,
        home: EntitlementScope(
          repository: LocalEntitlementRepository(
            initial: const EntitlementState(
              status: EntitlementStatus.freeOrUnknown,
            ),
          ),
          child: PersonalPatternsRoute(
            source: RepositoryPatternSource(
              healthRecords: InMemoryHealthRecordRepository(),
              careMemory: InMemoryCareMemoryRepository(
                records: [
                  CareRecord(
                    id: 'quiet-once',
                    mode: CareMode.heavy,
                    actionId: 'quiet',
                    actionLabel: 'Quiet presence',
                    outcome: CareOutcome.better,
                    occurredAt: DateTime.utc(2026, 7, 12),
                    createdAt: DateTime.utc(2026, 7, 12),
                    updatedAt: DateTime.utc(2026, 7, 12),
                    pinned: false,
                  ),
                ],
              ),
              periods: InMemoryPeriodRepository(
                seed: [
                  _period('june', const LocalDate(2026, 6, 8), timestamp),
                  _period('july', const LocalDate(2026, 7, 8), timestamp),
                  _period('august', const LocalDate(2026, 8, 8), timestamp),
                ],
              ),
            ),
            previewRepository: preview,
            now: () => DateTime.utc(2026, 8, 16),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quiet presence was recorded once.'), findsOneWidget);
    expect(
      find.text(
        'Save one more check-back and Patterns can start comparing what helped.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('personal-patterns-preview-plans')),
      findsNothing,
    );
    expect(await preview.hasViewedPreview(), isFalse);
  });

  testWidgets('locked Patterns route keeps an explicit way back', (
    tester,
  ) async {
    final source = RepositoryPatternSource(
      healthRecords: InMemoryHealthRecordRepository(),
      careMemory: InMemoryCareMemoryRepository(),
      periods: InMemoryPeriodRepository(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: LetterTheme.light,
        home: EntitlementScope(
          repository: LocalEntitlementRepository(
            initial: const EntitlementState(
              status: EntitlementStatus.freeOrUnknown,
            ),
          ),
          initialState: const EntitlementState(
            status: EntitlementStatus.freeOrUnknown,
          ),
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const Key('open-locked-patterns'),
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => EntitlementScope(
                      repository: LocalEntitlementRepository(
                        initial: const EntitlementState(
                          status: EntitlementStatus.freeOrUnknown,
                        ),
                      ),
                      initialState: const EntitlementState(
                        status: EntitlementStatus.freeOrUnknown,
                      ),
                      child: PersonalPatternsRoute(
                        source: source,
                        previewRepository:
                            InMemoryPersonalPatternPreviewRepository(true),
                      ),
                    ),
                  ),
                ),
                child: const Text('Open Patterns'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-locked-patterns')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('personal-patterns-locked-back')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('personal-patterns-locked-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open-locked-patterns')), findsOneWidget);
  });

  testWidgets('renders intentional zero- and one-period states', (
    tester,
  ) async {
    Future<void> pumpRoute(RepositoryPatternSource source) {
      return tester.pumpWidget(
        MaterialApp(
          theme: LetterTheme.light,
          home: EntitlementScope(
            repository: LocalEntitlementRepository(
              initial: const EntitlementState(
                status: EntitlementStatus.activePaid,
              ),
            ),
            initialState: const EntitlementState(
              status: EntitlementStatus.activePaid,
            ),
            child: PersonalPatternsRoute(
              key: ValueKey(source),
              source: source,
              now: () => DateTime.utc(2026, 8, 16),
            ),
          ),
        ),
      );
    }

    await pumpRoute(
      RepositoryPatternSource(
        healthRecords: InMemoryHealthRecordRepository(),
        careMemory: InMemoryCareMemoryRepository(),
        periods: InMemoryPeriodRepository(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('patterns-empty-state')), findsOneWidget);
    expect(find.text('Patterns begin with a first record.'), findsOneWidget);

    final timestamp = DateTime.utc(2026, 8, 10);
    await pumpRoute(
      RepositoryPatternSource(
        healthRecords: InMemoryHealthRecordRepository(),
        careMemory: InMemoryCareMemoryRepository(),
        periods: InMemoryPeriodRepository(
          seed: [_period('august', const LocalDate(2026, 8, 10), timestamp)],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('patterns-tab-cycles')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('patterns-current-state')), findsOneWidget);
    expect(find.textContaining('No flow detail saved yet'), findsOneWidget);
    expect(find.byKey(const Key('patterns-line-point-august')), findsNothing);
  });

  testWidgets('loads confirmed local health, Care, and period facts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final timestamp = DateTime.utc(2026, 8, 12);
    final healthRecords = InMemoryHealthRecordRepository(
      seed: [
        _healthRecord(
          id: 'cramps-july',
          date: const LocalDate(2026, 7, 25),
          timestamp: timestamp,
        ),
        _healthRecord(
          id: 'cramps-august',
          date: const LocalDate(2026, 8, 25),
          timestamp: timestamp,
        ),
      ],
    );
    final careMemory = InMemoryCareMemoryRepository(
      records: [
        CareRecord(
          id: 'care-one',
          mode: CareMode.physical,
          actionId: 'physical.lower-input',
          actionLabel: 'Lower the input',
          outcome: CareOutcome.better,
          occurredAt: timestamp,
          createdAt: timestamp,
          updatedAt: timestamp,
          pinned: true,
        ),
      ],
    );
    final periods = InMemoryPeriodRepository(
      seed: [
        _period('july', const LocalDate(2026, 7, 8), timestamp),
        _period('august', const LocalDate(2026, 8, 8), timestamp),
        _period('september', const LocalDate(2026, 9, 8), timestamp),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: LetterTheme.light,
        home: EntitlementScope(
          repository: LocalEntitlementRepository(
            initial: const EntitlementState(
              status: EntitlementStatus.activePaid,
            ),
          ),
          initialState: const EntitlementState(
            status: EntitlementStatus.activePaid,
          ),
          child: PersonalPatternsRoute(
            source: RepositoryPatternSource(
              healthRecords: healthRecords,
              careMemory: careMemory,
              periods: periods,
            ),
            now: () => DateTime.utc(2026, 9, 16),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('patterns-experience-screen')), findsOneWidget);
    expect(find.text('Patterns, held gently.'), findsOneWidget);
    expect(find.text('Jul 8 – Sep 7, 2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('patterns-tab-cycles')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Jul 8 – Sep 7, 2026'), findsNWidgets(2));
    final firstCycle = find.byKey(const Key('patterns-line-point-july'));
    await revealPatternContent(tester, firstCycle);
    expect(firstCycle, findsOneWidget);
    await tester.tap(firstCycle);
    await tester.pumpAndSettle();
    expect(find.textContaining('Cycle 1'), findsWidgets);
    Navigator.of(tester.element(find.textContaining('Cycle 1').first)).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('patterns-tab-mood')));
    await tester.pumpAndSettle();
    final pain = find.byKey(const Key('patterns-category-row-pain'));
    await revealPatternContent(tester, pain);
    await tester.tap(pain);
    await tester.pumpAndSettle();
    expect(find.text('Cramps'), findsWidgets);
    Navigator.of(tester.element(find.text('Cramps').first)).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('patterns-tab-helped')));
    await tester.pumpAndSettle();
    final careRow = find.byKey(const Key('patterns-care-row-Lower the input'));
    await revealPatternContent(tester, careRow);
    await tester.tap(careRow);
    await tester.pumpAndSettle();
    expect(find.text('Lower the input'), findsWidgets);
    expect(find.textContaining('Better'), findsWidgets);
  });
}

HealthRecord _healthRecord({
  required String id,
  required LocalDate date,
  required DateTime timestamp,
}) {
  return HealthRecord(
    id: id,
    symptom: SymptomType.cramps,
    severity: SymptomSeverity.severe,
    functionalImpacts: const {},
    experiencedDate: date,
    recordedAt: timestamp,
    updatedAt: timestamp,
    provenance: HealthRecordProvenance.sameDay,
    userConfirmed: true,
    vocabularyVersion: healthRecordVocabularyVersion,
  );
}

PeriodRecord _period(String id, LocalDate startDate, DateTime timestamp) {
  return PeriodRecord(
    id: id,
    startDate: startDate,
    endDate: startDate.addDays(4),
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
