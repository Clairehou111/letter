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

  test('pain locations require an explicit pain score before conversion', () {
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
      isEmpty,
    );
    expect(
      controller.confirmedDrafts(
        fallbackDate: const LocalDate(2026, 7, 28),
        painRatings: {candidate.id: 7},
      ),
      hasLength(1),
    );
  });

  test('cloud preview is minimized and approval is a separate gate', () async {
    final preview = NlpCloudPayloadPreview.fromText(
      'Email claire@example.com or call 555-123-4567. A very long note follows.',
    );
    expect(preview.text, isNot(contains('claire@example.com')));
    expect(preview.text, isNot(contains('555-123-4567')));
    expect(
      preview.characterCount,
      lessThanOrEqualTo(nlpCloudPreviewCharacterLimit),
    );

    var called = false;
    final adapter = PreviewOnlyNlpLlmAdapter(
      enabled: true,
      request: (received) async {
        called = true;
        expect(received, same(preview));
        return [
          NlpCandidate(
            id: 'cloud-1',
            symptom: SymptomType.irritability,
            isPresent: true,
            severity: SymptomSeverity.extreme,
            painLocations: const {},
            experiencedDate: const LocalDate(2026, 7, 28),
            source: NlpCandidateSource.typedText,
            evidence: const NlpEvidence(
              sourceReference: 'preview',
              start: 0,
              end: 8,
              excerpt: 'test text',
            ),
            confidence: NlpSuggestionConfidence.clear,
            status: NlpCandidateStatus.accepted,
          ),
        ];
      },
    );
    expect(
      () => adapter.requestSuggestions(preview, approved: false),
      throwsA(isA<NlpCloudException>()),
    );
    expect(called, isFalse);
    await adapter.requestSuggestions(preview, approved: true);
    expect(called, isTrue);
    final suggestions = await adapter.requestSuggestions(
      preview,
      approved: true,
    );
    expect(suggestions.single.status, NlpCandidateStatus.unresolved);
    expect(suggestions.single.source, NlpCandidateSource.cloudSuggestion);
    expect(suggestions.single.severity, isNull);
  });
}
