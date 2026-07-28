import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/recovery_receipt/domain/recovery_receipt.dart';

CareRecord care(CareMode mode) {
  final time = DateTime.utc(2026, 7, 28, 10);
  return CareRecord(
    id: 'care-${mode.name}',
    mode: mode,
    actionId: 'action',
    actionLabel: 'A safe action',
    outcome: CareOutcome.better,
    occurredAt: time,
    createdAt: time,
    updatedAt: time,
    pinned: false,
  );
}

void main() {
  test('Care suggestions are candidates and never contain a severity', () {
    expect(
      suggestedSymptomForCare(care(CareMode.explode)),
      SymptomType.irritability,
    );
    expect(
      suggestedSymptomForCare(care(CareMode.physical)),
      SymptomType.cramps,
    );
    expect(suggestedSymptomForCare(care(CareMode.space)), isNull);
  });

  test('same local calendar day is distinct from later recall', () {
    const day = LocalDate(2026, 7, 28);
    expect(
      recoveryReceiptProvenance(
        experiencedDate: day,
        recordedAt: DateTime.utc(2026, 7, 28, 12),
      ),
      HealthRecordProvenance.sameDay,
    );
    expect(
      recoveryReceiptProvenance(
        experiencedDate: day,
        recordedAt: DateTime.utc(2026, 7, 28, 15),
      ),
      HealthRecordProvenance.laterRecall,
    );
  });
}
