import '../../cycle/domain/local_date.dart';
import '../../health_records/domain/health_record.dart';
import 'nlp_candidate.dart';

final class LocalNlpParser {
  const LocalNlpParser();

  NlpParseResult parse(
    String text, {
    required DateTime referenceDate,
    required NlpSourceReference source,
  }) {
    if (!source.mayProcess) {
      return const NlpParseResult(
        candidates: [],
        excludedByPolicy: true,
        exclusionMessage:
            'This sealed note stays private unless you select an excerpt for review.',
      );
    }
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return const NlpParseResult(candidates: []);
    }

    final mentions = _findSymptomMentions(normalized);
    final candidates = <NlpCandidate>[];
    for (final mention in mentions) {
      final evidence = _evidenceFor(
        normalized,
        mention.start,
        mention.end,
        source,
      );
      final severity = _explicitSeverity(
        evidence.excerpt,
        mention.start - evidence.start,
      );
      final locations = _painLocations(evidence.excerpt);
      final date = _dateMention(evidence.excerpt, referenceDate);
      final negated = _isNegated(
        evidence.excerpt,
        mention.start - evidence.start,
      );
      candidates.add(
        NlpCandidate(
          id: '${mention.symptom.name}-${mention.start}',
          symptom: mention.symptom,
          isPresent: !negated,
          severity: severity,
          painLocations: locations,
          experiencedDate: date,
          source: source.isSealedAngryDraft
              ? NlpCandidateSource.selectedSealedExcerpt
              : source.source,
          evidence: evidence,
          confidence: _confidence(mention.term, severity),
        ),
      );
    }
    return NlpParseResult(candidates: List.unmodifiable(candidates));
  }

  List<_SymptomMention> _findSymptomMentions(String text) {
    final matches = <_SymptomMention>[];
    for (final entry in _vocabulary) {
      final expression = RegExp(
        RegExp.escape(entry.term),
        caseSensitive: false,
      );
      for (final match in expression.allMatches(text)) {
        if (!_hasWordBoundaries(text, match.start, match.end)) {
          continue;
        }
        matches.add(
          _SymptomMention(
            symptom: entry.symptom,
            term: entry.term,
            start: match.start,
            end: match.end,
          ),
        );
      }
    }
    matches.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      if (byStart != 0) {
        return byStart;
      }
      return (b.end - b.start).compareTo(a.end - a.start);
    });
    final selected = <_SymptomMention>[];
    for (final mention in matches) {
      if (selected.any(
        (existing) =>
            mention.start < existing.end && existing.start < mention.end,
      )) {
        continue;
      }
      selected.add(mention);
    }
    selected.sort((a, b) => a.start.compareTo(b.start));
    return selected;
  }

  NlpEvidence _evidenceFor(
    String text,
    int start,
    int end,
    NlpSourceReference source,
  ) {
    var evidenceStart = start;
    while (evidenceStart > 0 && !_isSentenceBoundary(text[evidenceStart - 1])) {
      evidenceStart--;
    }
    var evidenceEnd = end;
    while (evidenceEnd < text.length &&
        !_isSentenceBoundary(text[evidenceEnd])) {
      evidenceEnd++;
    }
    final excerpt = text.substring(evidenceStart, evidenceEnd).trim();
    final trimOffset = text
        .substring(evidenceStart, evidenceEnd)
        .indexOf(excerpt);
    final actualStart = evidenceStart + (trimOffset < 0 ? 0 : trimOffset);
    return NlpEvidence(
      sourceReference: source.reference,
      start: actualStart,
      end: actualStart + excerpt.length,
      excerpt: excerpt,
    );
  }

  SymptomSeverity? _explicitSeverity(String excerpt, int symptomOffset) {
    final nearbyStart = (symptomOffset - 48).clamp(0, excerpt.length);
    final nearbyEnd = (symptomOffset + 64).clamp(0, excerpt.length);
    final nearby = excerpt.substring(nearbyStart, nearbyEnd);
    for (final entry in _severityPhrases.entries) {
      if (RegExp(
        r'\b' + RegExp.escape(entry.key) + r'\b',
        caseSensitive: false,
      ).hasMatch(nearby)) {
        return entry.value;
      }
    }
    return null;
  }

  Set<PainLocation> _painLocations(String excerpt) {
    final locations = <PainLocation>{};
    for (final entry in _locationPhrases.entries) {
      if (RegExp(
        r'\b' + RegExp.escape(entry.key) + r'\b',
        caseSensitive: false,
      ).hasMatch(excerpt)) {
        locations.add(entry.value);
      }
    }
    return Set.unmodifiable(locations);
  }

  bool _isNegated(String excerpt, int symptomOffset) {
    final before = excerpt.substring(0, symptomOffset);
    final clauseStart = [
      before.lastIndexOf(','),
      before.lastIndexOf(';'),
      before.lastIndexOf(':'),
    ].reduce((left, right) => left > right ? left : right);
    final clause = before.substring(clauseStart + 1);
    final recent = clause.length > 32
        ? clause.substring(clause.length - 32)
        : clause;
    return RegExp(
      r'\b(?:no|not|without|never|don\x27t have|do not have|didn\x27t have|'
      r'did not have|haven\x27t had|have not had)\b(?:\s+\w+){0,3}\s*$',
      caseSensitive: false,
    ).hasMatch(recent);
  }

  NlpSuggestionConfidence _confidence(String term, SymptomSeverity? severity) {
    if (severity != null || term.contains(' ')) {
      return NlpSuggestionConfidence.clear;
    }
    return NlpSuggestionConfidence.likely;
  }

  LocalDate? _dateMention(String excerpt, DateTime referenceDate) {
    final relative = RegExp(
      r'\b(today|yesterday|tomorrow)\b',
      caseSensitive: false,
    ).firstMatch(excerpt);
    if (relative != null) {
      final offset = switch (relative.group(1)!.toLowerCase()) {
        'yesterday' => -1,
        'tomorrow' => 1,
        _ => 0,
      };
      return LocalDate.fromDateTime(referenceDate).addDays(offset);
    }

    final iso = RegExp(
      r'\b(20\d{2})-(\d{1,2})-(\d{1,2})\b',
    ).firstMatch(excerpt);
    if (iso != null) {
      return _validDate(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }

    final numeric = RegExp(
      r'\b(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?\b',
    ).firstMatch(excerpt);
    if (numeric != null) {
      final rawYear = numeric.group(3);
      final year = rawYear == null
          ? referenceDate.year
          : (rawYear.length == 2
                ? 2000 + int.parse(rawYear)
                : int.parse(rawYear));
      return _validDate(
        year,
        int.parse(numeric.group(1)!),
        int.parse(numeric.group(2)!),
      );
    }

    final month = RegExp(
      r'\b(january|february|march|april|may|june|july|august|september|'
      r'october|november|december)\s+(\d{1,2})(?:,?\s+(20\d{2}))?\b',
      caseSensitive: false,
    ).firstMatch(excerpt);
    if (month != null) {
      final monthNumber =
          _monthNames.indexOf(month.group(1)!.toLowerCase()) + 1;
      return _validDate(
        month.group(3) == null
            ? referenceDate.year
            : int.parse(month.group(3)!),
        monthNumber,
        int.parse(month.group(2)!),
      );
    }
    return null;
  }

  LocalDate? _validDate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    final value = DateTime(year, month, day);
    if (value.year != year || value.month != month || value.day != day) {
      return null;
    }
    return LocalDate(year, month, day);
  }

  bool _hasWordBoundaries(String text, int start, int end) {
    bool isWord(int codeUnit) =>
        (codeUnit >= 48 && codeUnit <= 57) ||
        (codeUnit >= 65 && codeUnit <= 90) ||
        (codeUnit >= 97 && codeUnit <= 122) ||
        codeUnit == 95;
    return (start == 0 || !isWord(text.codeUnitAt(start - 1))) &&
        (end == text.length || !isWord(text.codeUnitAt(end)));
  }

  bool _isSentenceBoundary(String character) =>
      character == '.' ||
      character == '!' ||
      character == '?' ||
      character == '\n';
}

final class _SymptomMention {
  const _SymptomMention({
    required this.symptom,
    required this.term,
    required this.start,
    required this.end,
  });

  final SymptomType symptom;
  final String term;
  final int start;
  final int end;
}

const _vocabulary = <_VocabularyEntry>[
  _VocabularyEntry('breast tenderness', SymptomType.breastTenderness),
  _VocabularyEntry('sore breasts', SymptomType.breastTenderness),
  _VocabularyEntry('difficulty concentrating', SymptomType.brainFog),
  _VocabularyEntry('trouble concentrating', SymptomType.brainFog),
  _VocabularyEntry('brain fog', SymptomType.brainFog),
  _VocabularyEntry('difficulty sleeping', SymptomType.sleepDifficulty),
  _VocabularyEntry('trouble sleeping', SymptomType.sleepDifficulty),
  _VocabularyEntry('broken sleep', SymptomType.sleepDisruption),
  _VocabularyEntry('disrupted sleep', SymptomType.sleepDisruption),
  _VocabularyEntry('sleeping all day', SymptomType.hypersomnia),
  _VocabularyEntry('sleeping for days', SymptomType.hypersomnia),
  _VocabularyEntry('lower back pain', SymptomType.backPain),
  _VocabularyEntry('back pain', SymptomType.backPain),
  _VocabularyEntry('pelvic pain', SymptomType.pelvicPain),
  _VocabularyEntry('joint pain', SymptomType.jointMusclePain),
  _VocabularyEntry('muscle pain', SymptomType.jointMusclePain),
  _VocabularyEntry('period pain', SymptomType.cramps),
  _VocabularyEntry('head pain', SymptomType.headache),
  _VocabularyEntry('body aches', SymptomType.bodyAches),
  _VocabularyEntry('low energy', SymptomType.lowEnergy),
  _VocabularyEntry('sleepy', SymptomType.sleepiness),
  _VocabularyEntry('cramps', SymptomType.cramps),
  _VocabularyEntry('cramping', SymptomType.cramps),
  _VocabularyEntry('headache', SymptomType.headache),
  _VocabularyEntry('bloating', SymptomType.bloating),
  _VocabularyEntry('bloated', SymptomType.bloating),
  _VocabularyEntry('nausea', SymptomType.nausea),
  _VocabularyEntry('nauseous', SymptomType.nausea),
  _VocabularyEntry('irritability', SymptomType.irritability),
  _VocabularyEntry('irritable', SymptomType.irritability),
  _VocabularyEntry('rage', SymptomType.rage),
  _VocabularyEntry('mood swings', SymptomType.moodSwings),
  _VocabularyEntry('anxiety', SymptomType.anxiety),
  _VocabularyEntry('anxious', SymptomType.anxiety),
  _VocabularyEntry('panic attack', SymptomType.panicAttack),
  _VocabularyEntry('depressed', SymptomType.lowMood),
  _VocabularyEntry('depression', SymptomType.lowMood),
  _VocabularyEntry('low mood', SymptomType.lowMood),
  _VocabularyEntry('crying', SymptomType.crying),
  _VocabularyEntry('cannot stop crying', SymptomType.crying),
  _VocabularyEntry('hopeless', SymptomType.hopelessness),
  _VocabularyEntry('despair', SymptomType.hopelessness),
  _VocabularyEntry('lost interest', SymptomType.anhedonia),
  _VocabularyEntry('no pleasure', SymptomType.anhedonia),
  _VocabularyEntry('social withdrawal', SymptomType.socialWithdrawal),
  _VocabularyEntry('withdrawing from everyone', SymptomType.socialWithdrawal),
  _VocabularyEntry('exhausted', SymptomType.fatigue),
  _VocabularyEntry('fatigue', SymptomType.fatigue),
  _VocabularyEntry('tired', SymptomType.fatigue),
  _VocabularyEntry('insomnia', SymptomType.insomnia),
  _VocabularyEntry('sleepiness', SymptomType.sleepiness),
  _VocabularyEntry('water retention', SymptomType.waterRetention),
  _VocabularyEntry('food cravings', SymptomType.appetiteChange),
  _VocabularyEntry('appetite change', SymptomType.appetiteChange),
  _VocabularyEntry('constipation', SymptomType.constipation),
  _VocabularyEntry('hot flashes', SymptomType.hotFlashes),
  _VocabularyEntry('hot flushes', SymptomType.hotFlashes),
  _VocabularyEntry('heart palpitations', SymptomType.palpitations),
  _VocabularyEntry('palpitations', SymptomType.palpitations),
  _VocabularyEntry('ache', SymptomType.bodyAches),
  _VocabularyEntry('pain', SymptomType.cramps),
];

final class _VocabularyEntry {
  const _VocabularyEntry(this.term, this.symptom);

  final String term;
  final SymptomType symptom;
}

const _severityPhrases = <String, SymptomSeverity>{
  'not at all': SymptomSeverity.notAtAll,
  'minimal': SymptomSeverity.minimal,
  'slight': SymptomSeverity.minimal,
  'a little': SymptomSeverity.minimal,
  'mild': SymptomSeverity.mild,
  'moderate': SymptomSeverity.moderate,
  'strong': SymptomSeverity.severe,
  'severe': SymptomSeverity.severe,
  'extreme': SymptomSeverity.extreme,
  'unbearable': SymptomSeverity.extreme,
};

const _locationPhrases = <String, PainLocation>{
  'lower abdomen': PainLocation.lowerAbdomen,
  'lower belly': PainLocation.lowerAbdomen,
  'belly': PainLocation.lowerAbdomen,
  'stomach': PainLocation.lowerAbdomen,
  'lower back': PainLocation.lowerBack,
  'pelvis': PainLocation.pelvis,
  'pelvic': PainLocation.pelvis,
  'head': PainLocation.head,
  'joints': PainLocation.jointsOrMuscles,
  'muscles': PainLocation.jointsOrMuscles,
};

const _monthNames = <String>[
  'january',
  'february',
  'march',
  'april',
  'may',
  'june',
  'july',
  'august',
  'september',
  'october',
  'november',
  'december',
];
