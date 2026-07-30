import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/entitlement/data/local_entitlement_repository.dart';
import 'package:letter_mobile/features/entitlement/domain/entitlement.dart';

void main() {
  const freeCapabilities = [
    LetterCapability.acuteCareFlows,
    LetterCapability.safetyRoutes,
    LetterCapability.periodTracking,
    LetterCapability.cyclePrediction,
    LetterCapability.localBackupExport,
    LetterCapability.localDataDelete,
  ];
  const premiumCapabilities = [
    LetterCapability.careKitMemory,
    LetterCapability.futureSelfNotes,
    LetterCapability.prepareSurface,
    LetterCapability.personalPatterns,
    LetterCapability.lettersArchiveDetail,
  ];

  group('capability map', () {
    test('REQ-001 capabilities are never premium', () {
      for (final capability in freeCapabilities) {
        expect(isPremiumCapability(capability), isFalse, reason: '$capability');
      }
    });

    test('REQ-002 capabilities are premium', () {
      for (final capability in premiumCapabilities) {
        expect(isPremiumCapability(capability), isTrue, reason: '$capability');
      }
    });
  });

  group('EntitlementState.canUse', () {
    for (final status in EntitlementStatus.values) {
      test('free capabilities survive $status', () {
        final state = EntitlementState(status: status);
        for (final capability in freeCapabilities) {
          expect(state.canUse(capability), isTrue, reason: '$capability');
        }
      });
    }

    test('premium requires intro or paid', () {
      for (final capability in premiumCapabilities) {
        expect(
          const EntitlementState(
            status: EntitlementStatus.activeIntro,
          ).canUse(capability),
          isTrue,
        );
        expect(
          const EntitlementState(
            status: EntitlementStatus.activePaid,
          ).canUse(capability),
          isTrue,
        );
        expect(
          const EntitlementState(
            status: EntitlementStatus.lapsed,
          ).canUse(capability),
          isFalse,
        );
        expect(
          const EntitlementState(
            status: EntitlementStatus.freeOrUnknown,
          ).canUse(capability),
          isFalse,
        );
      }
    });
  });

  group('LocalEntitlementRepository', () {
    test('starts free and completes intro month on a plan', () async {
      final repo = LocalEntitlementRepository();
      expect(repo.current.status, EntitlementStatus.freeOrUnknown);

      final states = <EntitlementState>[];
      final sub = repo.watch().listen(states.add);
      await repo.startIntroMonth('letter_yearly');

      expect(repo.current.status, EntitlementStatus.activeIntro);
      expect(repo.current.planId, 'letter_yearly');
      expect(states.single.status, EntitlementStatus.activeIntro);
      await sub.cancel();
      await repo.dispose();
    });

    test('lapse keeps free capabilities', () {
      final repo = LocalEntitlementRepository();
      repo.debugSet(const EntitlementState(status: EntitlementStatus.lapsed));
      expect(repo.current.canUse(LetterCapability.acuteCareFlows), isTrue);
      expect(repo.current.canUse(LetterCapability.localBackupExport), isTrue);
      expect(repo.current.canUse(LetterCapability.careKitMemory), isFalse);
    });
  });
}
