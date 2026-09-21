import '../../check_in/domain/moment_check_in.dart';
import 'health_record.dart';

/// Presentation-facing groups. These are intentionally independent from the
/// legacy algorithm groups on [SymptomCategory].
enum ObservationCategory {
  physical('Physical'),
  mood('Mood'),
  cognitive('Mind'),
  energy('Energy'),
  sleep('Sleep'),
  digestion('Digestion');

  const ObservationCategory(this.label);

  final String label;
}

enum ObservationRecordingKind { severity, pain, medicalAttention }

enum ObservationPatternRole { spectrum, relationshipOnly, reportOnly, excluded }

enum ObservationSafetyRoute { none, medicalAttention }

enum ObservationQuickPickPriority { defaultPick, contextual, searchOnly }

final class ObservationDefinition {
  const ObservationDefinition({
    required this.id,
    required this.symptom,
    required this.label,
    required this.category,
    required this.recordingKind,
    required this.patternRole,
    this.searchAliases = const <String>[],
    this.safetyRoute = ObservationSafetyRoute.none,
    this.quickPickPriority = ObservationQuickPickPriority.contextual,
  });

  final String id;
  final SymptomType symptom;
  final String label;
  final ObservationCategory category;
  final ObservationRecordingKind recordingKind;
  final ObservationPatternRole patternRole;
  final List<String> searchAliases;
  final ObservationSafetyRoute safetyRoute;
  final ObservationQuickPickPriority quickPickPriority;

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return label.toLowerCase().contains(normalized) ||
        id.toLowerCase().contains(normalized) ||
        searchAliases.any((alias) => alias.toLowerCase().contains(normalized));
  }
}

final class MomentStateDefinition {
  const MomentStateDefinition({
    required this.id,
    required this.state,
    required this.label,
    required this.tone,
    this.searchAliases = const <String>[],
    this.defaultPick = false,
    this.suggestsCare = false,
  });

  final String id;
  final MomentCheckInState state;
  final String label;
  final MomentStateTone tone;
  final List<String> searchAliases;
  final bool defaultPick;
  final bool suggestsCare;

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return label.toLowerCase().contains(normalized) ||
        id.toLowerCase().contains(normalized) ||
        searchAliases.any((alias) => alias.toLowerCase().contains(normalized));
  }
}

enum MomentStateTone { positive, settled, tender, difficult, physical }

/// Versioned, local and deterministic vocabulary used by recording UI.
///
/// Storage and existing algorithms retain [SymptomType] compatibility while
/// presentation code consumes metadata here instead of iterating and styling
/// enum values itself.
abstract final class ObservationCatalog {
  static const version = healthRecordVocabularyVersion;

  static final List<ObservationDefinition> symptoms = List.unmodifiable([
    _symptom(
      SymptomType.cramps,
      ObservationCategory.physical,
      recordingKind: ObservationRecordingKind.pain,
      aliases: const ['period pain', 'stomach cramps'],
      quick: ObservationQuickPickPriority.defaultPick,
    ),
    _symptom(
      SymptomType.pelvicPain,
      ObservationCategory.physical,
      recordingKind: ObservationRecordingKind.pain,
    ),
    _symptom(
      SymptomType.backPain,
      ObservationCategory.physical,
      recordingKind: ObservationRecordingKind.pain,
      aliases: const ['lower back pain'],
      quick: ObservationQuickPickPriority.defaultPick,
    ),
    _symptom(
      SymptomType.headache,
      ObservationCategory.physical,
      recordingKind: ObservationRecordingKind.pain,
      quick: ObservationQuickPickPriority.defaultPick,
    ),
    _symptom(
      SymptomType.migraine,
      ObservationCategory.physical,
      recordingKind: ObservationRecordingKind.pain,
    ),
    _symptom(SymptomType.breastTenderness, ObservationCategory.physical),
    _symptom(SymptomType.bodyAches, ObservationCategory.physical),
    _symptom(
      SymptomType.jointMusclePain,
      ObservationCategory.physical,
      recordingKind: ObservationRecordingKind.pain,
    ),
    _symptom(
      SymptomType.waterRetention,
      ObservationCategory.physical,
      aliases: const ['swelling'],
    ),
    _symptom(
      SymptomType.hotFlashes,
      ObservationCategory.physical,
      aliases: const ['sweating'],
    ),
    _symptom(
      SymptomType.acne,
      ObservationCategory.physical,
      aliases: const ['skin changes', 'breakout'],
    ),
    _symptom(
      SymptomType.dizziness,
      ObservationCategory.physical,
      aliases: const ['lightheaded'],
    ),
    _symptom(
      SymptomType.palpitations,
      ObservationCategory.physical,
      recordingKind: ObservationRecordingKind.medicalAttention,
      patternRole: ObservationPatternRole.reportOnly,
      safetyRoute: ObservationSafetyRoute.medicalAttention,
      quick: ObservationQuickPickPriority.searchOnly,
    ),

    _symptom(
      SymptomType.bloating,
      ObservationCategory.digestion,
      quick: ObservationQuickPickPriority.defaultPick,
    ),
    _symptom(
      SymptomType.nausea,
      ObservationCategory.digestion,
      quick: ObservationQuickPickPriority.defaultPick,
    ),
    _symptom(
      SymptomType.appetiteChange,
      ObservationCategory.digestion,
      aliases: const ['cravings'],
    ),
    _symptom(SymptomType.constipation, ObservationCategory.digestion),
    _symptom(SymptomType.diarrhea, ObservationCategory.digestion),

    _symptom(
      SymptomType.lowMood,
      ObservationCategory.mood,
      aliases: const ['depressed mood'],
      quick: ObservationQuickPickPriority.defaultPick,
    ),
    _symptom(SymptomType.crying, ObservationCategory.mood),
    _symptom(
      SymptomType.hopelessness,
      ObservationCategory.mood,
      aliases: const ['despair'],
    ),
    _symptom(
      SymptomType.anhedonia,
      ObservationCategory.mood,
      aliases: const ['loss of interest', 'no pleasure'],
    ),
    _symptom(
      SymptomType.irritability,
      ObservationCategory.mood,
      quick: ObservationQuickPickPriority.defaultPick,
    ),
    _symptom(SymptomType.rage, ObservationCategory.mood),
    _symptom(SymptomType.moodSwings, ObservationCategory.mood),
    _symptom(
      SymptomType.anxiety,
      ObservationCategory.mood,
      aliases: const ['worry'],
      quick: ObservationQuickPickPriority.defaultPick,
    ),
    _symptom(
      SymptomType.panicAttack,
      ObservationCategory.mood,
      aliases: const ['panic'],
    ),
    _symptom(
      SymptomType.hypersensitivity,
      ObservationCategory.mood,
      aliases: const ['unusually sensitive'],
    ),
    _symptom(
      SymptomType.overwhelm,
      ObservationCategory.mood,
      aliases: const ['overwhelmed'],
    ),
    _symptom(
      SymptomType.socialWithdrawal,
      ObservationCategory.mood,
      aliases: const ['want to be alone'],
    ),
    _symptom(
      SymptomType.paranoia,
      ObservationCategory.mood,
      aliases: const ['suspicious thoughts'],
    ),
    _symptom(SymptomType.impulsiveUrges, ObservationCategory.mood),

    _symptom(
      SymptomType.concentration,
      ObservationCategory.cognitive,
      aliases: const ['difficulty concentrating'],
      quick: ObservationQuickPickPriority.searchOnly,
    ),
    _symptom(
      SymptomType.brainFog,
      ObservationCategory.cognitive,
      quick: ObservationQuickPickPriority.defaultPick,
    ),
    _symptom(SymptomType.forgetfulness, ObservationCategory.cognitive),

    _symptom(
      SymptomType.fatigue,
      ObservationCategory.energy,
      quick: ObservationQuickPickPriority.defaultPick,
    ),
    _symptom(SymptomType.lowEnergy, ObservationCategory.energy),
    _symptom(SymptomType.sleepiness, ObservationCategory.energy),

    _symptom(
      SymptomType.insomnia,
      ObservationCategory.sleep,
      quick: ObservationQuickPickPriority.defaultPick,
    ),
    _symptom(
      SymptomType.hypersomnia,
      ObservationCategory.sleep,
      aliases: const ['sleeping much more'],
    ),
    _symptom(
      SymptomType.sleepDifficulty,
      ObservationCategory.sleep,
      quick: ObservationQuickPickPriority.searchOnly,
    ),
    _symptom(
      SymptomType.sleepDisruption,
      ObservationCategory.sleep,
      aliases: const ['broken sleep'],
    ),
  ]);

  /// Symptoms available in the new daily editor. Emotional observations use
  /// the dedicated mood check-in catalog instead of duplicating mood symptoms.
  /// Legacy mood definitions remain readable for existing reports/tests only.
  static final List<ObservationDefinition> dailySymptoms = List.unmodifiable(
    symptoms.where(
      (definition) =>
          definition.category != ObservationCategory.mood &&
          definition.symptom.availableForNewRecords,
    ),
  );

  static final Map<String, ObservationDefinition> _byId = {
    for (final definition in symptoms) definition.id: definition,
  };

  static ObservationDefinition definitionFor(SymptomType symptom) =>
      _byId[symptom.name]!;

  static ObservationDefinition? byId(String id) => _byId[id];

  static List<ObservationDefinition> search(
    String query, {
    ObservationCategory? category,
  }) => List.unmodifiable(
    symptoms.where(
      (definition) =>
          (category == null || definition.category == category) &&
          definition.matches(query),
    ),
  );

  static List<ObservationDefinition> quickPicks(ObservationCategory category) =>
      List.unmodifiable(
        symptoms.where(
          (definition) =>
              definition.category == category &&
              definition.quickPickPriority ==
                  ObservationQuickPickPriority.defaultPick,
        ),
      );

  static final List<MomentStateDefinition> momentStates = List.unmodifiable([
    _moment(
      MomentCheckInState.good,
      MomentStateTone.positive,
      defaultPick: true,
    ),
    _moment(
      MomentCheckInState.calm,
      MomentStateTone.settled,
      defaultPick: true,
      aliases: const ['peaceful'],
    ),
    _moment(
      MomentCheckInState.steady,
      MomentStateTone.settled,
      defaultPick: true,
      aliases: const ['okay'],
    ),
    _moment(
      MomentCheckInState.energized,
      MomentStateTone.positive,
      defaultPick: true,
    ),
    _moment(MomentCheckInState.hopeful, MomentStateTone.positive),
    _moment(
      MomentCheckInState.tender,
      MomentStateTone.tender,
      aliases: const ['sensitive'],
    ),
    _moment(
      MomentCheckInState.low,
      MomentStateTone.difficult,
      defaultPick: true,
      suggestsCare: true,
    ),
    _moment(
      MomentCheckInState.irritable,
      MomentStateTone.difficult,
      defaultPick: true,
      suggestsCare: true,
    ),
    _moment(
      MomentCheckInState.anxious,
      MomentStateTone.difficult,
      defaultPick: true,
      suggestsCare: true,
      aliases: const ['restless', 'worried'],
    ),
    _moment(
      MomentCheckInState.overwhelmed,
      MomentStateTone.difficult,
      suggestsCare: true,
    ),
    _moment(
      MomentCheckInState.exhausted,
      MomentStateTone.difficult,
      suggestsCare: true,
      aliases: const ['drained'],
    ),
    _moment(
      MomentCheckInState.physical,
      MomentStateTone.physical,
      defaultPick: true,
      suggestsCare: true,
      aliases: const ['physically uncomfortable', 'in pain'],
    ),
  ]);

  static List<MomentStateDefinition> searchMomentStates(String query) =>
      List.unmodifiable(
        momentStates.where((definition) => definition.matches(query)),
      );
}

ObservationDefinition _symptom(
  SymptomType symptom,
  ObservationCategory category, {
  ObservationRecordingKind recordingKind = ObservationRecordingKind.severity,
  ObservationPatternRole patternRole = ObservationPatternRole.spectrum,
  ObservationSafetyRoute safetyRoute = ObservationSafetyRoute.none,
  ObservationQuickPickPriority quick = ObservationQuickPickPriority.contextual,
  List<String> aliases = const <String>[],
}) => ObservationDefinition(
  id: symptom.name,
  symptom: symptom,
  label: symptom.label,
  category: category,
  recordingKind: recordingKind,
  patternRole: patternRole,
  safetyRoute: safetyRoute,
  quickPickPriority: quick,
  searchAliases: aliases,
);

MomentStateDefinition _moment(
  MomentCheckInState state,
  MomentStateTone tone, {
  bool defaultPick = false,
  bool suggestsCare = false,
  List<String> aliases = const <String>[],
}) => MomentStateDefinition(
  id: state.name,
  state: state,
  label: state.label,
  tone: tone,
  defaultPick: defaultPick,
  suggestsCare: suggestsCare,
  searchAliases: aliases,
);
