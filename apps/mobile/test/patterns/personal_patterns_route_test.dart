import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
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
import 'package:letter_mobile/features/patterns/presentation/personal_patterns_route.dart';

void main() {
  testWidgets('loads confirmed local health, Care, and period facts', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 12);
    final healthRecords = InMemoryHealthRecordRepository(
      seed: [
        _healthRecord(
          id: 'cramps-july',
          date: const LocalDate(2026, 7, 10),
          timestamp: timestamp,
        ),
        _healthRecord(
          id: 'cramps-august',
          date: const LocalDate(2026, 8, 10),
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
          initialState: const EntitlementState(status: EntitlementStatus.activePaid),
          child: PersonalPatternsRoute(
            source: RepositoryPatternSource(
              healthRecords: healthRecords,
              careMemory: careMemory,
              periods: periods,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('personal-patterns-screen')), findsOneWidget);

    // Scroll to visible content — spectrum log may push cards below viewport.
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
    expect(find.textContaining('same cycle day in 2 records'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Lower the input'),
      260,
      scrollable: find.descendant(
        of: find.byKey(const Key('personal-patterns-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Lower the input'), findsOneWidget);
    expect(find.text('Better in 1 of 1 check-backs'), findsOneWidget);
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
    painRating: null,
    painLocations: const {},
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
