import 'package:flutter/foundation.dart';

import '../../cycle/domain/local_date.dart';
import '../../health_records/domain/health_record.dart';

const nlpVocabularyVersion = 1;
const nlpCloudPreviewCharacterLimit = 500;

enum NlpCandidateSource {
  typedText('Typed text'),
  voiceTranscript('Voice transcript'),
  selectedSealedExcerpt('Selected sealed excerpt'),
  cloudSuggestion('Optional cloud suggestion');

  const NlpCandidateSource(this.label);

  final String label;
}

enum NlpCandidateStatus { unresolved, accepted, edited, rejected }

enum NlpSuggestionConfidence {
  possible('Possible phrase'),
  likely('Likely phrase'),
  clear('Clear phrase');

  const NlpSuggestionConfidence(this.label);

  final String label;
}

@immutable
final class NlpSourceReference {
  const NlpSourceReference({
    required this.source,
    required this.reference,
    this.isSealedAngryDraft = false,
    this.explicitlySelected = false,
  });

  final NlpCandidateSource source;
  final String reference;
  final bool isSealedAngryDraft;
  final bool explicitlySelected;

  bool get mayProcess => !isSealedAngryDraft || explicitlySelected;
}

@immutable
final class NlpEvidence {
  const NlpEvidence({
    required this.sourceReference,
    required this.start,
    required this.end,
    required this.excerpt,
  });

  final String sourceReference;
  final int start;
  final int end;
  final String excerpt;
}

@immutable
final class NlpCandidate {
  const NlpCandidate({
    required this.id,
    required this.symptom,
    required this.isPresent,
    required this.severity,
    required this.painLocations,
    required this.experiencedDate,
    required this.source,
    required this.evidence,
    required this.confidence,
    this.status = NlpCandidateStatus.unresolved,
    this.vocabularyVersion = nlpVocabularyVersion,
  });

  final String id;
  final SymptomType symptom;

  /// False means the source explicitly says the symptom is absent. It is not
  /// a sentiment or severity signal.
  final bool isPresent;

  /// This is only populated by an explicit phrase or a user's edit. The
  /// parser never derives it from emotion, length, prosody, or interaction.
  final SymptomSeverity? severity;
  final Set<PainLocation> painLocations;
  final LocalDate? experiencedDate;
  final NlpCandidateSource source;
  final NlpEvidence evidence;
  final NlpSuggestionConfidence confidence;
  final NlpCandidateStatus status;
  final int vocabularyVersion;

  NlpCandidate copyWith({
    SymptomType? symptom,
    bool? isPresent,
    SymptomSeverity? severity,
    bool clearSeverity = false,
    Set<PainLocation>? painLocations,
    LocalDate? experiencedDate,
    bool clearExperiencedDate = false,
    NlpCandidateSource? source,
    NlpCandidateStatus? status,
  }) {
    return NlpCandidate(
      id: id,
      symptom: symptom ?? this.symptom,
      isPresent: isPresent ?? this.isPresent,
      severity: clearSeverity ? null : severity ?? this.severity,
      painLocations: Set.unmodifiable(painLocations ?? this.painLocations),
      experiencedDate: clearExperiencedDate
          ? null
          : experiencedDate ?? this.experiencedDate,
      source: source ?? this.source,
      evidence: evidence,
      confidence: confidence,
      status: status ?? this.status,
      vocabularyVersion: vocabularyVersion,
    );
  }

  /// Converts only an accepted or edited, present candidate after the user
  /// has supplied every field required by the health-record contract.
  HealthRecordDraft? toHealthRecordDraft({
    required LocalDate fallbackDate,
    int? painRating,
  }) {
    if ((status != NlpCandidateStatus.accepted &&
            status != NlpCandidateStatus.edited) ||
        !isPresent ||
        severity == null ||
        (painLocations.isNotEmpty && painRating == null) ||
        (painLocations.isEmpty && painRating != null) ||
        (painRating != null && (painRating < 0 || painRating > 10))) {
      return null;
    }
    final date = experiencedDate ?? fallbackDate;
    return validateHealthRecordDraft(
      HealthRecordDraft(
        symptom: symptom,
        severity: severity!,
        painRating: painRating,
        painLocations: painLocations,
        functionalImpacts: const {},
        experiencedDate: date,
        provenance: date == fallbackDate
            ? HealthRecordProvenance.sameDay
            : HealthRecordProvenance.laterRecall,
      ),
    );
  }
}

@immutable
final class NlpParseResult {
  const NlpParseResult({
    required this.candidates,
    this.excludedByPolicy = false,
    this.exclusionMessage,
  });

  final List<NlpCandidate> candidates;
  final bool excludedByPolicy;
  final String? exclusionMessage;
}

@immutable
final class NlpCloudPayloadPreview {
  const NlpCloudPayloadPreview({
    required this.text,
    required this.characterCount,
  });

  factory NlpCloudPayloadPreview.fromText(String input) {
    final redacted = input
        .replaceAll(RegExp(r'https?://\S+', caseSensitive: false), '[link]')
        .replaceAll(RegExp(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}'), '[email]')
        .replaceAll(RegExp(r'(?<!\d)(?:\+?\d[\d .()-]{7,}\d)(?!\d)'), '[phone]')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final clipped = redacted.length <= nlpCloudPreviewCharacterLimit
        ? redacted
        : '${redacted.substring(0, nlpCloudPreviewCharacterLimit)}…';
    return NlpCloudPayloadPreview(
      text: clipped,
      characterCount: clipped.length,
    );
  }

  final String text;
  final int characterCount;
}

enum NlpCloudFailure { unavailable, approvalRequired }

final class NlpCloudException implements Exception {
  const NlpCloudException(this.failure);

  final NlpCloudFailure failure;
}

/// An interface-only gate. It accepts a minimized preview rather than source
/// content and has no provider, network, persistence, or request logging.
abstract interface class OptionalNlpLlmAdapter {
  bool get enabled;

  Future<List<NlpCandidate>> requestSuggestions(
    NlpCloudPayloadPreview preview, {
    required bool approved,
  });
}

final class PreviewOnlyNlpLlmAdapter implements OptionalNlpLlmAdapter {
  PreviewOnlyNlpLlmAdapter({required this.enabled, required this.request});

  @override
  final bool enabled;

  final Future<List<NlpCandidate>> Function(NlpCloudPayloadPreview preview)
  request;

  @override
  Future<List<NlpCandidate>> requestSuggestions(
    NlpCloudPayloadPreview preview, {
    required bool approved,
  }) async {
    if (!enabled) {
      throw const NlpCloudException(NlpCloudFailure.unavailable);
    }
    if (!approved) {
      throw const NlpCloudException(NlpCloudFailure.approvalRequired);
    }
    final suggestions = await request(preview);
    return List.unmodifiable(
      suggestions.map(
        (candidate) => candidate.copyWith(
          source: NlpCandidateSource.cloudSuggestion,
          clearSeverity: true,
          status: NlpCandidateStatus.unresolved,
        ),
      ),
    );
  }
}
