import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/care/data/in_memory_care_memory_repository.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/cycle/data/in_memory_period_repository.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/cycle/domain/period_record.dart';
import 'package:letter_mobile/features/entitlement/data/local_entitlement_repository.dart';
import 'package:letter_mobile/features/entitlement/domain/entitlement.dart';
import 'package:letter_mobile/features/entitlement/presentation/entitlement_scope.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/letters/presentation/letters_home_screen.dart';

void main() {
  testWidgets('opens factual Patterns from Letter with local repositories', (
    tester,
  ) async {
    final recordedAt = DateTime.utc(2026, 7, 15);
    final healthRepository = InMemoryHealthRecordRepository(
      seed: [
        HealthRecord(
          id: 'cramps-one',
          symptom: SymptomType.cramps,
          severity: SymptomSeverity.moderate,
          painRating: null,
          painLocations: const {},
          functionalImpacts: const {},
          experiencedDate: const LocalDate(2026, 7, 10),
          recordedAt: recordedAt,
          updatedAt: recordedAt,
          provenance: HealthRecordProvenance.sameDay,
          userConfirmed: true,
          vocabularyVersion: healthRecordVocabularyVersion,
        ),
        HealthRecord(
          id: 'cramps-two',
          symptom: SymptomType.cramps,
          severity: SymptomSeverity.severe,
          painRating: null,
          painLocations: const {},
          functionalImpacts: const {},
          experiencedDate: const LocalDate(2026, 7, 14),
          recordedAt: recordedAt,
          updatedAt: recordedAt,
          provenance: HealthRecordProvenance.laterRecall,
          userConfirmed: true,
          vocabularyVersion: healthRecordVocabularyVersion,
        ),
      ],
    );
    final periodRepository = InMemoryPeriodRepository(
      seed: [
        PeriodRecord(
          id: 'july',
          startDate: const LocalDate(2026, 7, 8),
          endDate: const LocalDate(2026, 7, 12),
          createdAt: recordedAt,
          updatedAt: recordedAt,
        ),
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
          child: LettersHomeScreen(
            periodRepository: periodRepository,
            careMemoryRepository: InMemoryCareMemoryRepository(),
            healthRecordRepository: healthRepository,
            onNavigationSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Patterns'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    await tester.tap(find.text('Patterns'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('personal-patterns-screen')), findsOneWidget);
    expect(find.text('What has repeated'), findsOneWidget);

    // Scroll to find symptom cards — spectrum log may push them below viewport.
    await tester.scrollUntilVisible(
      find.text('Cramps'),
      260,
      scrollable: find.descendant(
        of: find.byKey(const Key('personal-patterns-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cramps'), findsOneWidget);
    expect(find.text('2 confirmed records'), findsOneWidget);
    expect(find.textContaining('diagnos'), findsNothing);
    expect(find.textContaining('cause'), findsNothing);
  });

  testWidgets('saves one reflection for the selected cycle', (tester) async {
    final occurredAt = DateTime(2026, 6, 20, 12);
    final careRecord = CareRecord(
      id: 'care-record',
      mode: CareMode.heavy,
      actionId: 'heavy.quiet-presence',
      actionLabel: 'Quiet presence',
      outcome: CareOutcome.better,
      occurredAt: occurredAt,
      createdAt: occurredAt,
      updatedAt: occurredAt,
      pinned: false,
    );
    final careRepository = InMemoryCareMemoryRepository(
      records: [careRecord],
      idGenerator: () => 'reflection',
      clock: () => DateTime.utc(2026, 7, 8),
    );
    final periodRepository = InMemoryPeriodRepository(
      seed: [
        PeriodRecord(
          id: 'june',
          startDate: const LocalDate(2026, 6, 8),
          endDate: const LocalDate(2026, 6, 12),
          createdAt: DateTime.utc(2026, 6, 8),
          updatedAt: DateTime.utc(2026, 6, 8),
        ),
        PeriodRecord(
          id: 'july',
          startDate: const LocalDate(2026, 7, 7),
          endDate: const LocalDate(2026, 7, 11),
          createdAt: DateTime.utc(2026, 7, 7),
          updatedAt: DateTime.utc(2026, 7, 7),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: LetterTheme.light,
        home: LettersHomeScreen(
          periodRepository: periodRepository,
          careMemoryRepository: careRepository,
          healthRecordRepository: InMemoryHealthRecordRepository(),
          onNavigationSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Letter No. 1'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('cycle-letter-cycle-reflection')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(
      find.byKey(const Key('cycle-letter-detail-scroll-view')),
      const Offset(0, -100),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('cycle-letter-cycle-reflection')));
    await tester.pump();

    expect(find.text('What stood out this cycle?'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('cycle-reflection-observation')),
      'A slower pace helped.',
    );
    await tester.tap(
      find.byKey(const Key('cycle-reflection-need-restOrPhysicalCapacity')),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('cycle-reflection-save')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -100));
    await tester.pump();
    await tester.tap(find.byKey(const Key('cycle-reflection-save')));
    await tester.pumpAndSettle();

    final reflection = (await careRepository.getCycleReflections()).single;
    expect(reflection.cycleStartDay, const LocalDate(2026, 6, 8).epochDay);
    expect(reflection.observation, 'A slower pace helped.');
    expect(reflection.need, ReflectionNeed.restOrPhysicalCapacity);
    expect(find.text('Letter No. 1'), findsOneWidget);
  });
}
