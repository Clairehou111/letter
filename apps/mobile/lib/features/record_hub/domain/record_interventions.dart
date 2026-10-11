import '../../cycle/domain/local_date.dart';
import 'record_hub_facts.dart';

/// Bounded new action check-back text; legacy Care reflections are unchanged.
const actionCheckbackReflectionMaximumCharacters = 280;

void _require(bool condition) {
  if (!condition) throw const RecordHubException(RecordHubFailure.invalidValue);
}

enum ProductFamily { medication, supplement, birthControl }

enum MedicationType {
  antidepressant('SSRI / antidepressant'),
  painRelief('Pain relief / NSAID'),
  hormonal('Hormonal medication'),
  sleep('Sleep medication'),
  other('Other');

  const MedicationType(this.label);
  final String label;
}

enum SupplementType {
  magnesium('Magnesium'),
  calcium('Calcium'),
  vitaminB6('Vitamin B6'),
  vitaminD('Vitamin D'),
  iron('Iron'),
  omega3('Omega-3'),
  other('Other');

  const SupplementType(this.label);
  final String label;
}

enum BirthControlMethod {
  combinedPill('Combined pill'),
  progestinOnlyPill('Progestin-only pill'),
  patch('Patch'),
  ring('Ring'),
  hormonalIud('Hormonal IUD'),
  copperIud('Copper IUD'),
  implant('Implant'),
  injection('Injection'),
  other('Other');

  const BirthControlMethod(this.label);
  final String label;
}

enum DoseUnit {
  mg('mg'),
  mcg('mcg'),
  g('g'),
  ml('mL'),
  tablet('tablet'),
  capsule('capsule'),
  other('Other');

  const DoseUnit(this.label);
  final String label;
}

enum ProductRoute {
  oral('Oral'),
  topical('Topical'),
  injection('Injection'),
  other('Other');

  const ProductRoute(this.label);
  final String label;
}

/// Exact optional dose/name fields, with no recommended product or adherence.
final class ProductDetails {
  ProductDetails({
    required this.family,
    this.exactName,
    this.medicationType,
    this.supplementType,
    this.birthControlMethod,
    this.dose,
    this.unit,
    this.customUnit,
    this.route,
    this.customRoute,
    this.target,
  }) {
    _require(
      family == ProductFamily.birthControl
          ? birthControlMethod != null
          : exactName != null && exactName!.trim().isNotEmpty,
    );
    _require(family == ProductFamily.medication || medicationType == null);
    _require(family == ProductFamily.supplement || supplementType == null);
    _require(
      family == ProductFamily.birthControl || birthControlMethod == null,
    );
    _require(exactName == null || exactName!.trim().isNotEmpty);
    _require(dose == null || dose!.trim().isNotEmpty);
    _require(
      unit != DoseUnit.other ||
          customUnit != null && customUnit!.trim().isNotEmpty,
    );
    _require(
      route != ProductRoute.other ||
          customRoute != null && customRoute!.trim().isNotEmpty,
    );
    _require(
      birthControlMethod != BirthControlMethod.other ||
          exactName != null && exactName!.trim().isNotEmpty,
    );
  }
  final ProductFamily family;
  final String? exactName;
  final MedicationType? medicationType;
  final SupplementType? supplementType;
  final BirthControlMethod? birthControlMethod;
  final String? dose;
  final DoseUnit? unit;
  final String? customUnit;
  final ProductRoute? route;
  final String? customRoute;
  final String? target;
  String get displayName => exactName ?? birthControlMethod!.label;
}

final class ProductEpisodeDraft {
  ProductEpisodeDraft({
    required this.startDate,
    required this.details,
    this.endDate,
  }) {
    _require(endDate == null || !endDate!.isBefore(startDate));
  }
  final LocalDate startDate;
  final LocalDate? endDate;
  final ProductDetails details;
}

final class ProductVersion {
  const ProductVersion({
    required this.metadata,
    required this.episodeId,
    required this.effectiveFrom,
    required this.versionNumber,
    required this.details,
  });
  final RecordFactMetadata metadata;
  String get id => metadata.id;
  final String episodeId;
  final LocalDate effectiveFrom;
  final int versionNumber;
  final ProductDetails details;
  DateTime get recordedAt => metadata.recordedAt;
}

final class ProductEpisode {
  ProductEpisode({
    required this.metadata,
    required this.family,
    required this.startDate,
    required this.endDate,
    required this.archived,
    required Iterable<ProductVersion> versions,
  }) : versions = List.unmodifiable(versions) {
    _require(id.isNotEmpty && this.versions.isNotEmpty);
    _require(endDate == null || !endDate!.isBefore(startDate));
    _require(!updatedAt.isBefore(recordedAt));
    _require(
      this.versions.every(
        (value) => value.episodeId == id && value.details.family == family,
      ),
    );
    _require(this.versions.first.effectiveFrom == startDate);
    for (var index = 1; index < this.versions.length; index++) {
      _require(
        !this.versions[index].effectiveFrom.isBefore(
              this.versions[index - 1].effectiveFrom,
            ) &&
            this.versions[index].versionNumber ==
                this.versions[index - 1].versionNumber + 1,
      );
    }
    _require(this.versions.first.versionNumber == 1);
  }
  final RecordFactMetadata metadata;
  String get id => metadata.id;
  final ProductFamily family;
  final LocalDate startDate;
  final LocalDate? endDate;
  final bool archived;
  DateTime get recordedAt => metadata.recordedAt;
  DateTime get updatedAt => metadata.updatedAt;
  final List<ProductVersion> versions;
  ProductDetails get currentDetails => versions.last.details;
  bool includes(LocalDate date) =>
      !date.isBefore(startDate) && (endDate == null || !date.isAfter(endDate!));
  ProductVersion versionAt(LocalDate date) {
    _require(includes(date));
    return versions.lastWhere(
      (version) => !version.effectiveFrom.isAfter(date),
    );
  }
}

enum ProductUseStatus {
  taken('Taken'),
  skipped('Skipped'),
  asNeeded('As needed'),
  missed('Missed'),
  late('Late'),
  emergency('Emergency contraception');

  const ProductUseStatus(this.label);
  final String label;
}

final class ProductUseDraft implements DatedRecordDraft {
  ProductUseDraft({
    required this.experiencedDate,
    required this.episodeId,
    required this.status,
  }) {
    _require(episodeId.trim().isNotEmpty);
  }
  @override
  final LocalDate experiencedDate;
  final String episodeId;
  final ProductUseStatus status;
}

final class ProductUseRecord {
  const ProductUseRecord({
    required this.metadata,
    required this.value,
    required this.versionId,
    required this.dailyShortcut,
  });
  final RecordFactMetadata metadata;
  final ProductUseDraft value;

  /// Immutable dose/name version used when this event was first saved.
  final String versionId;
  final bool dailyShortcut;
  String get id => metadata.id;
}

enum TriedActionKind {
  meditation('Meditation'),
  breathing('Breathing'),
  heat('Heat/warmth'),
  gentleMovement('Gentle movement'),
  rest('Rest/lower expectations'),
  comfortSetup('Comfort setup'),
  trustedPerson('Talk to someone trusted'),
  other('Other');

  const TriedActionKind(this.label);
  final String label;
}

final class TriedActionSelection {
  TriedActionSelection(this.kind, {this.customName}) {
    _require(
      kind != TriedActionKind.other ||
          customName != null && customName!.trim().isNotEmpty,
    );
    _require(kind == TriedActionKind.other || customName == null);
  }
  final TriedActionKind kind;
  final String? customName;
  String get label => customName ?? kind.label;
  String get identity =>
      '${kind.name}:${customName?.length ?? 0}:${customName ?? ''}';
}

enum TriedActionStatus { completed, couldntTry }

enum TriedActionSource { outsideApp, inAppCare }

final class TriedActionDraft implements DatedRecordDraft {
  TriedActionDraft({
    required this.experiencedDate,
    required Iterable<TriedActionSelection> actions,
    required this.bundle,
    required this.status,
    this.target,
    this.duration,
    this.source = TriedActionSource.outsideApp,
    this.completionToken,
    this.careSourceId,
    this.completionOccurredAt,
    int? completionUtcOffsetMinutes,
  }) : completionUtcOffsetMinutes = completionOccurredAt == null
           ? null
           : completionUtcOffsetMinutes ??
                 completionOccurredAt.timeZoneOffset.inMinutes,
       actions = List.unmodifiable(actions) {
    _require(this.actions.isNotEmpty);
    _require(
      this.actions.map((value) => value.identity).toSet().length ==
          this.actions.length,
    );
    _require(bundle || this.actions.length == 1);
    _require(target == null || target!.trim().isNotEmpty);
    duration?.requireFamily(DurationFamily.careAction);
    _require(
      source != TriedActionSource.inAppCare ||
          status == TriedActionStatus.completed &&
              completionToken != null &&
              completionToken!.trim().isNotEmpty &&
              completionOccurredAt != null,
    );
    _require(
      source != TriedActionSource.outsideApp ||
          completionToken == null &&
              careSourceId == null &&
              completionOccurredAt == null,
    );
    _require(
      completionOccurredAt != null || completionUtcOffsetMinutes == null,
    );
    if (completionOccurredAt != null) {
      _require(
        this.completionUtcOffsetMinutes! >= -840 &&
            this.completionUtcOffsetMinutes! <= 840,
      );
      final capturedDay = LocalDate.fromDateTime(
        completionOccurredAt!.toUtc().add(
          Duration(minutes: this.completionUtcOffsetMinutes!),
        ),
      );
      _require(capturedDay == experiencedDate);
    }
  }
  @override
  final LocalDate experiencedDate;
  final List<TriedActionSelection> actions;
  final bool bundle;
  final TriedActionStatus status;
  final String? target;
  final RecordedDuration? duration;
  final TriedActionSource source;
  final String? completionToken;
  final String? careSourceId;
  final DateTime? completionOccurredAt;
  final int? completionUtcOffsetMinutes;
  String get groupingIdentity {
    final set = actions.map((value) => value.identity).toList()..sort();
    final setKey = set.map((value) => '${value.length}:$value').join();
    return '${bundle ? 'bundle' : 'single'}:$setKey:target:${target?.length ?? -1}:${target ?? ''}';
  }
}

typedef TriedActionRecord = RecordHubFact<TriedActionDraft>;

enum ActionOutcome {
  better('Better'),
  same('Same'),
  worse('Worse'),
  mixed('Mixed'),
  couldntTry('Couldn’t try');

  const ActionOutcome(this.label);
  final String label;
}

enum UnexpectedObservation { no, yes, notSure }

final class ActionCheckbackDraft implements DatedRecordDraft {
  ActionCheckbackDraft({
    required this.experiencedDate,
    required this.actionId,
    required this.outcome,
    this.targetDegree,
    this.unexpected,
    this.reflection,
  }) {
    _require(actionId.trim().isNotEmpty);
    _require(targetDegree == null || targetDegree! >= 0 && targetDegree! <= 5);
    _require(
      reflection == null ||
          reflection!.length <= actionCheckbackReflectionMaximumCharacters,
    );
  }
  @override
  final LocalDate experiencedDate;
  final String actionId;
  final ActionOutcome outcome;
  final int? targetDegree;
  final UnexpectedObservation? unexpected;
  final String? reflection;
}

typedef ActionCheckbackRecord = RecordHubFact<ActionCheckbackDraft>;

/// Factual reuse counts for an exact action set and exact target. A bundle's
/// outcome is counted once, never allocated to its individual components.
final class TriedActionMemoryGroup {
  TriedActionMemoryGroup({
    required this.identity,
    required Iterable<TriedActionSelection> actions,
    required this.bundle,
    required this.target,
    required Iterable<String> sourceIds,
    required Map<ActionOutcome, int> outcomes,
  }) : actions = List.unmodifiable(actions),
       sourceIds = List.unmodifiable(sourceIds),
       outcomes = Map.unmodifiable(outcomes);
  final String identity;
  final List<TriedActionSelection> actions;
  final bool bundle;
  final String? target;
  final List<String> sourceIds;
  final Map<ActionOutcome, int> outcomes;
  int get total => sourceIds.length;
  int get uncheckedCount =>
      total - outcomes.values.fold(0, (sum, count) => sum + count);
}

List<TriedActionMemoryGroup> factualTriedActionMemory(
  Iterable<TriedActionRecord> actions,
  Iterable<ActionCheckbackRecord> checkbacks,
) {
  final latest = <String, ActionCheckbackRecord>{};
  for (final checkback in checkbacks) {
    final previous = latest[checkback.value.actionId];
    if (previous == null ||
        checkback.metadata.updatedAt.isAfter(previous.metadata.updatedAt) ||
        checkback.metadata.updatedAt == previous.metadata.updatedAt &&
            checkback.id.compareTo(previous.id) > 0) {
      latest[checkback.value.actionId] = checkback;
    }
  }
  final groups = <String, List<TriedActionRecord>>{};
  final seen = <String>{};
  for (final action in actions) {
    _require(seen.add(action.id));
    (groups[action.value.groupingIdentity] ??= []).add(action);
  }
  final keys = groups.keys.toList()..sort();
  return List.unmodifiable([
    for (final key in keys)
      TriedActionMemoryGroup(
        identity: key,
        actions: groups[key]!.first.value.actions,
        bundle: groups[key]!.first.value.bundle,
        target: groups[key]!.first.value.target,
        sourceIds: groups[key]!.map((value) => value.id),
        outcomes: {
          for (final outcome in ActionOutcome.values)
            outcome: groups[key]!
                .where((action) => latest[action.id]?.value.outcome == outcome)
                .length,
        },
      ),
  ]);
}

abstract interface class RecordInterventionsRepository {
  Future<List<ProductEpisode>> getEpisodes({bool includeArchived = false});
  Future<ProductEpisode> createEpisode(ProductEpisodeDraft draft);
  Future<ProductEpisode> reviseEpisode(
    String id,
    ProductDetails details, {
    required LocalDate effectiveFrom,
  });
  Future<ProductEpisode> stopEpisode(String id, LocalDate endDate);

  /// Removal archives the episode and preserves all version/use history.
  Future<void> archiveEpisode(String id);
  Future<List<ProductUseRecord>> getUses({LocalDate? date, String? episodeId});
  Future<ProductUseRecord> saveUse(
    ProductUseDraft draft, {
    String? id,
    bool dailyShortcut = true,
  });
  Future<void> deleteUse(String id);
  Future<List<TriedActionRecord>> getActions({LocalDate? date});
  Future<TriedActionRecord> saveAction(TriedActionDraft draft, {String? id});
  Future<void> deleteAction(String id);
  Future<List<ActionCheckbackRecord>> getCheckbacks();

  /// One outcome for the entire action or bundle. Skipping calls no write.
  Future<ActionCheckbackRecord> saveCheckback(ActionCheckbackDraft draft);
  Future<void> deleteCheckback(String actionId);
}
