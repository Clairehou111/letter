import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/nlp/application/nlp_review_controller.dart';
import 'package:letter_mobile/features/nlp/domain/local_nlp_parser.dart';
import 'package:letter_mobile/features/nlp/domain/nlp_candidate.dart';

void main() {
  const parser = LocalNlpParser();
  const source = NlpSourceReference(
    source: NlpCandidateSource.typedText,
    reference: 'note-1',
  );
  final today = DateTime(2026, 7, 28);

  NlpCandidate candidate(String text) {
    return parser
        .parse(text, referenceDate: today, source: source)
        .candidates
        .single;
  }

  test(
    'accept requires a user-confirmed severity and only confirmed values map',
    () {
      final controller = NlpReviewController([
        candidate('I had cramps today.'),
      ]);
      controller.accept(controller.candidates.single.id);
      expect(
        controller.candidates.single.status,
        NlpCandidateStatus.unresolved,
      );
      expect(controller.errorMessage, contains('severity'));
      expect(
        controller.confirmedDrafts(fallbackDate: const LocalDate(2026, 7, 28)),
        isEmpty,
      );

      final id = controller.candidates.single.id;
      controller.edit(id, severity: SymptomSeverity.moderate);
      expect(controller.candidates.single.status, NlpCandidateStatus.edited);
      final drafts = controller.confirmedDrafts(
        fallbackDate: const LocalDate(2026, 7, 28),
      );
      expect(drafts, hasLength(1));
      expect(drafts.single.symptom, SymptomType.cramps);
      expect(drafts.single.severity, SymptomSeverity.moderate);
    },
  );

  test('rejected and unresolved candidates never become drafts', () {
    final candidates = [
      candidate('I had mild cramps.'),
      candidate('I had moderate nausea.'),
    ];
    final controller = NlpReviewController(candidates);
    controller.accept(candidates.first.id);
    controller.reject(candidates[1].id);
    expect(
      controller.confirmedDrafts(fallbackDate: const LocalDate(2026, 7, 28)),
      hasLength(1),
    );
  });

  test('provenance follows the confirmed experienced date', () {
    final parsed = parser
        .parse(
          'I had mild cramps yesterday.',
          referenceDate: today,
          source: source,
        )
        .candidates
        .single;
    final controller = NlpReviewController([parsed]);
    controller.accept(parsed.id);
    final drafts = controller.confirmedDrafts(
      fallbackDate: const LocalDate(2026, 7, 28),
    );
    expect(drafts.single.experiencedDate, const LocalDate(2026, 7, 27));
    expect(drafts.single.provenance, HealthRecordProvenance.laterRecall);
  });

  test('pain symptoms use the shared five-level severity', () {
    final candidate = parser
        .parse(
          'I had severe cramps in my lower back.',
          referenceDate: today,
          source: source,
        )
        .candidates
        .single;
    final controller = NlpReviewController([candidate]);
    controller.accept(candidate.id);
    expect(
      controller.confirmedDrafts(fallbackDate: const LocalDate(2026, 7, 28)),
      hasLength(1),
    );
  });
}
