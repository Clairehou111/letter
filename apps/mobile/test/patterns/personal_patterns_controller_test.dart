import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/patterns/application/personal_patterns_controller.dart';
import 'package:letter_mobile/features/patterns/domain/pattern_source.dart';
import 'package:letter_mobile/features/patterns/domain/personal_pattern_engine.dart';

final class _Source implements PatternSourceReader {
  _Source(this.snapshot);

  PatternSourceSnapshot snapshot;

  @override
  Future<PatternSourceSnapshot> read() async => snapshot;
}

CareRecord record(String id, CareMode mode) {
  final time = DateTime.utc(2026, 7, id == 'one' ? 1 : 4);
  return CareRecord(
    id: id,
    mode: mode,
    actionId: 'lower-input',
    actionLabel: 'Lower the input',
    outcome: CareOutcome.same,
    occurredAt: time,
    createdAt: time,
    updatedAt: time,
    pinned: false,
  );
}

void main() {
  test(
    'loads, filters by Care mode, and dismisses only the local view',
    () async {
      final source = _Source(
        PatternSourceSnapshot(
          careRecords: [
            record('one', CareMode.physical),
            record('two', CareMode.physical),
            record('other', CareMode.heavy),
          ],
        ),
      );
      final controller = PersonalPatternsController(
        source: source,
        engine: const PersonalPatternEngine(),
      );
      addTearDown(controller.dispose);

      await controller.load();
      expect(controller.analysis.supportActions, hasLength(2));
      expect(controller.error, isNull);

      final physicalId = controller.analysis.supportActions
          .singleWhere((action) => action.mode == CareMode.physical)
          .id;
      controller.dismissPattern(physicalId);
      expect(controller.analysis.supportActions, hasLength(1));
      controller.restorePattern(physicalId);
      expect(controller.analysis.supportActions, hasLength(2));

      await controller.selectCareMode(CareMode.heavy);
      expect(controller.analysis.supportActions.single.mode, CareMode.heavy);
    },
  );

  test(
    'source is read again after refresh so derived views never own data',
    () async {
      final source = _Source(
        PatternSourceSnapshot(
          careRecords: [
            record('one', CareMode.physical),
            record('two', CareMode.physical),
          ],
        ),
      );
      final controller = PersonalPatternsController(source: source);
      addTearDown(controller.dispose);

      await controller.load();
      expect(controller.analysis.supportActions, hasLength(1));
      source.snapshot = const PatternSourceSnapshot();
      await controller.refresh();
      expect(controller.analysis.supportActions, isEmpty);
    },
  );
}
