import 'package:flutter/foundation.dart';

import '../../cycle/domain/local_date.dart';
import '../../health_records/domain/health_record.dart';
import '../domain/nlp_candidate.dart';

final class NlpReviewController extends ChangeNotifier {
  NlpReviewController(Iterable<NlpCandidate> candidates)
    : _candidates = List.unmodifiable(candidates);

  List<NlpCandidate> _candidates;
  String? _errorMessage;

  List<NlpCandidate> get candidates => _candidates;
  String? get errorMessage => _errorMessage;
  bool get hasPendingCandidates => _candidates.any(
    (candidate) => candidate.status == NlpCandidateStatus.unresolved,
  );

  void accept(String id) {
    final candidate = _find(id);
    if (candidate == null) {
      return;
    }
    if (!candidate.isPresent) {
      _errorMessage =
          'This suggestion says the symptom was not present. Edit it first if that is not right.';
      notifyListeners();
      return;
    }
    if (candidate.severity == null) {
      _errorMessage =
          'Choose the symptom severity yourself before accepting it.';
      notifyListeners();
      return;
    }
    _replace(candidate.copyWith(status: NlpCandidateStatus.accepted));
  }

  void edit(
    String id, {
    SymptomType? symptom,
    bool? isPresent,
    SymptomSeverity? severity,
    bool clearSeverity = false,
    Set<PainLocation>? painLocations,
    LocalDate? experiencedDate,
    bool clearExperiencedDate = false,
  }) {
    final candidate = _find(id);
    if (candidate == null) {
      return;
    }
    _replace(
      candidate.copyWith(
        symptom: symptom,
        isPresent: isPresent,
        severity: severity,
        clearSeverity: clearSeverity,
        painLocations: painLocations,
        experiencedDate: experiencedDate,
        clearExperiencedDate: clearExperiencedDate,
        status: NlpCandidateStatus.edited,
      ),
    );
  }

  void reject(String id) {
    final candidate = _find(id);
    if (candidate == null) {
      return;
    }
    _replace(candidate.copyWith(status: NlpCandidateStatus.rejected));
  }

  void leaveUnresolved(String id) {
    final candidate = _find(id);
    if (candidate == null) {
      return;
    }
    _replace(candidate.copyWith(status: NlpCandidateStatus.unresolved));
  }

  List<HealthRecordDraft> confirmedDrafts({
    required LocalDate fallbackDate,
    Map<String, int?> painRatings = const {},
  }) {
    final drafts = <HealthRecordDraft>[];
    for (final candidate in _candidates) {
      final draft = candidate.toHealthRecordDraft(
        fallbackDate: fallbackDate,
        painRating: painRatings[candidate.id],
      );
      if (draft != null) {
        drafts.add(draft);
      }
    }
    return List.unmodifiable(drafts);
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }
    _errorMessage = null;
    notifyListeners();
  }

  NlpCandidate? _find(String id) {
    for (final candidate in _candidates) {
      if (candidate.id == id) {
        return candidate;
      }
    }
    return null;
  }

  void _replace(NlpCandidate replacement) {
    _candidates = List.unmodifiable(
      _candidates
          .map(
            (candidate) =>
                candidate.id == replacement.id ? replacement : candidate,
          )
          .toList(),
    );
    _errorMessage = null;
    notifyListeners();
  }
}
