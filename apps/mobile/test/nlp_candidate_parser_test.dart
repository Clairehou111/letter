import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/nlp/domain/local_nlp_parser.dart';
import 'package:letter_mobile/features/nlp/domain/nlp_candidate.dart';

void main() {
  const parser = LocalNlpParser();
  final referenceDate = DateTime(2026, 7, 28);

  NlpSourceReference source({
    NlpCandidateSource kind = NlpCandidateSource.typedText,
    bool sealed = false,
    bool selected = false,
  }) {
    return NlpSourceReference(
      source: kind,
      reference: 'capture-1',
      isSealedAngryDraft: sealed,
      explicitlySelected: selected,
    );
  }

  test('extracts symptom, explicit severity, date, and pain location', () {
    final result = parser.parse(
      'Yesterday I had severe cramps in my lower abdomen.',
      referenceDate: referenceDate,
      source: source(),
    );

    expect(result.candidates, hasLength(1));
    final candidate = result.candidates.single;
    expect(candidate.symptom, SymptomType.cramps);
    expect(candidate.isPresent, isTrue);
    expect(candidate.severity, SymptomSeverity.severe);
    expect(candidate.painLocations, {PainLocation.lowerAbdomen});
    expect(candidate.experiencedDate, const LocalDate(2026, 7, 27));
    expect(candidate.evidence.excerpt, contains('severe cramps'));
    expect(candidate.evidence.sourceReference, 'capture-1');
    expect(candidate.confidence, NlpSuggestionConfidence.clear);
    expect(candidate.status, NlpCandidateStatus.unresolved);
  });

  test('keeps negated symptoms as unresolved absent suggestions', () {
    final result = parser.parse(
      'I had no headache, but moderate nausea today.',
      referenceDate: referenceDate,
      source: source(),
    );

    final headache = result.candidates.firstWhere(
      (candidate) => candidate.symptom == SymptomType.headache,
    );
    final nausea = result.candidates.firstWhere(
      (candidate) => candidate.symptom == SymptomType.nausea,
    );
    expect(headache.isPresent, isFalse);
    expect(headache.status, NlpCandidateStatus.unresolved);
    expect(nausea.isPresent, isTrue);
    expect(nausea.severity, SymptomSeverity.moderate);
    expect(nausea.experiencedDate, const LocalDate(2026, 7, 28));
  });

  test('does not infer clinical severity from emotional text or length', () {
    final result = parser.parse(
      'I was furious and wrote a very long message. I felt irritable.',
      referenceDate: referenceDate,
      source: source(),
    );

    expect(result.candidates, hasLength(1));
    expect(result.candidates.single.symptom, SymptomType.irritability);
    expect(result.candidates.single.severity, isNull);
  });

  test('recognizes explicit calendar dates without a default severity', () {
    final result = parser.parse(
      'On July 4, my headache was mild.',
      referenceDate: referenceDate,
      source: source(kind: NlpCandidateSource.voiceTranscript),
    );

    final candidate = result.candidates.single;
    expect(candidate.experiencedDate, const LocalDate(2026, 7, 4));
    expect(candidate.severity, SymptomSeverity.mild);
    expect(candidate.source, NlpCandidateSource.voiceTranscript);
  });

  test('excludes sealed angry drafts unless an excerpt was selected', () {
    final excluded = parser.parse(
      'I have severe cramps.',
      referenceDate: referenceDate,
      source: source(sealed: true),
    );
    expect(excluded.candidates, isEmpty);
    expect(excluded.excludedByPolicy, isTrue);

    final selected = parser.parse(
      'I have severe cramps.',
      referenceDate: referenceDate,
      source: source(sealed: true, selected: true),
    );
    expect(selected.candidates, hasLength(1));
    expect(
      selected.candidates.single.source,
      NlpCandidateSource.selectedSealedExcerpt,
    );
  });
}
