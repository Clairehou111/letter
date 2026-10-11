import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/record_hub/domain/record_hub_facts.dart';
import 'package:letter_mobile/features/record_hub/domain/record_interventions.dart';

void main() {
  const date = LocalDate(2026, 10, 8);
  test(
    'products preserve exact fields without default dose unit route target',
    () {
      final details = ProductDetails(
        family: ProductFamily.medication,
        exactName: '  Fictional product  ',
        dose: '1/2',
      );
      expect(details.displayName, '  Fictional product  ');
      expect(details.dose, '1/2');
      expect(details.unit, isNull);
      expect(details.route, isNull);
      expect(details.target, isNull);
      expect(
        () => ProductDetails(family: ProductFamily.supplement, exactName: ' '),
        throwsA(isA<RecordHubException>()),
      );
      expect(
        () => ProductDetails(
          family: ProductFamily.medication,
          exactName: 'Fictional',
          unit: DoseUnit.other,
        ),
        throwsA(isA<RecordHubException>()),
      );
      expect(
        () => ProductDetails(
          family: ProductFamily.medication,
          exactName: 'Fictional',
          birthControlMethod: BirthControlMethod.ring,
        ),
        throwsA(isA<RecordHubException>()),
      );
    },
  );
  test(
    'birth control requires selected method, optional product name stays absent',
    () {
      final method = ProductDetails(
        family: ProductFamily.birthControl,
        birthControlMethod: BirthControlMethod.copperIud,
      );
      expect(method.exactName, isNull);
      expect(method.displayName, 'Copper IUD');
      expect(
        () => ProductDetails(family: ProductFamily.birthControl),
        throwsA(isA<RecordHubException>()),
      );
    },
  );
  test(
    'bundle identity canonicalizes exact set but keeps bundle target and custom strings',
    () {
      final meditation = TriedActionSelection(TriedActionKind.meditation);
      final heat = TriedActionSelection(TriedActionKind.heat);
      final a = TriedActionDraft(
        experiencedDate: date,
        actions: [meditation, heat],
        bundle: true,
        status: TriedActionStatus.completed,
        target: 'Cramps',
      );
      final b = TriedActionDraft(
        experiencedDate: date,
        actions: [heat, meditation],
        bundle: true,
        status: TriedActionStatus.completed,
        target: 'Cramps',
      );
      final unspecified = TriedActionDraft(
        experiencedDate: date,
        actions: [meditation, heat],
        bundle: true,
        status: TriedActionStatus.completed,
      );
      expect(a.groupingIdentity, b.groupingIdentity);
      expect(a.groupingIdentity, isNot(unspecified.groupingIdentity));
      final custom = TriedActionSelection(
        TriedActionKind.other,
        customName: ' My action ',
      );
      expect(custom.label, ' My action ');
      expect(
        () => TriedActionDraft(
          experiencedDate: date,
          actions: [heat, meditation],
          bundle: false,
          status: TriedActionStatus.completed,
        ),
        throwsA(isA<RecordHubException>()),
      );
      expect(
        () => TriedActionDraft(
          experiencedDate: date,
          actions: [heat, heat],
          bundle: true,
          status: TriedActionStatus.completed,
        ),
        throwsA(isA<RecordHubException>()),
      );
    },
  );
  test(
    'manual and deliberate in-app completion have distinct source requirements',
    () {
      final action = TriedActionSelection(TriedActionKind.breathing);
      expect(TriedActionKind.values.length, 8);
      expect(
        () => TriedActionDraft(
          experiencedDate: date,
          actions: [action],
          bundle: false,
          status: TriedActionStatus.completed,
          source: TriedActionSource.inAppCare,
        ),
        throwsA(isA<RecordHubException>()),
      );
      expect(
        () => TriedActionDraft(
          experiencedDate: date,
          actions: [action],
          bundle: false,
          status: TriedActionStatus.couldntTry,
          source: TriedActionSource.inAppCare,
          completionToken: 'fictional',
        ),
        throwsA(isA<RecordHubException>()),
      );
      final manual = TriedActionDraft(
        experiencedDate: date,
        actions: [action],
        bundle: false,
        status: TriedActionStatus.couldntTry,
        duration: RecordedDuration.bucket(DurationBucket.care30PlusMinutes),
      );
      expect(manual.source, TriedActionSource.outsideApp);
      expect(manual.duration!.exactMinutes, isNull);
    },
  );
  test(
    'checkback target degree is optional independently from explicit outcome',
    () {
      final outcome = ActionCheckbackDraft(
        experiencedDate: date,
        actionId: 'fictional',
        outcome: ActionOutcome.mixed,
      );
      expect(outcome.targetDegree, isNull);
      expect(outcome.unexpected, isNull);
      expect(
        () => ActionCheckbackDraft(
          experiencedDate: date,
          actionId: 'fictional',
          outcome: ActionOutcome.better,
          targetDegree: 6,
        ),
        throwsA(isA<RecordHubException>()),
      );
    },
  );
  test(
    'factual memory keeps bundle outcomes whole and unspecified targets separate',
    () {
      RecordFactMetadata metadata(String id) => RecordFactMetadata(
        id: id,
        experiencedDate: date,
        recordedAt: DateTime.utc(2026, 10, 8),
        updatedAt: DateTime.utc(2026, 10, 8),
        originalProvenance: HealthRecordProvenance.sameDay,
        provenance: HealthRecordProvenance.sameDay,
      );
      TriedActionRecord action(
        String id, {
        bool bundle = true,
        String? target = 'Fictional target',
      }) => TriedActionRecord(
        metadata: metadata(id),
        value: TriedActionDraft(
          experiencedDate: date,
          actions: [
            TriedActionSelection(TriedActionKind.meditation),
            if (bundle) TriedActionSelection(TriedActionKind.heat),
          ],
          bundle: bundle,
          status: TriedActionStatus.completed,
          target: target,
        ),
      );
      ActionCheckbackRecord outcome(String actionId, ActionOutcome value) =>
          ActionCheckbackRecord(
            metadata: metadata('outcome-$actionId'),
            value: ActionCheckbackDraft(
              experiencedDate: date,
              actionId: actionId,
              outcome: value,
            ),
          );
      final groups = factualTriedActionMemory(
        [
          action('bundle-a'),
          action('bundle-b'),
          action('bundle-c'),
          action('bundle-unchecked'),
          action('single', bundle: false),
          action('unspecified', target: null),
        ],
        [
          outcome('bundle-a', ActionOutcome.better),
          outcome('bundle-b', ActionOutcome.mixed),
          outcome('bundle-c', ActionOutcome.couldntTry),
          outcome('single', ActionOutcome.worse),
        ],
      );
      expect(groups.length, 3);
      final bundle = groups.singleWhere(
        (group) => group.bundle && group.target != null,
      );
      expect(bundle.total, 4);
      expect(bundle.uncheckedCount, 1);
      expect(bundle.outcomes[ActionOutcome.better], 1);
      expect(bundle.outcomes[ActionOutcome.mixed], 1);
      expect(bundle.outcomes[ActionOutcome.couldntTry], 1);
      expect(
        groups
            .singleWhere((group) => !group.bundle)
            .outcomes[ActionOutcome.better],
        0,
      );
      expect(
        groups.singleWhere((group) => group.target == null).uncheckedCount,
        1,
      );
    },
  );
}
