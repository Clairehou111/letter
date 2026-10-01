import '../../care/domain/care_memory.dart';
import '../../capture/domain/capture_models.dart';
import '../../cycle/domain/local_date.dart';
import '../../patterns/domain/personal_pattern.dart';

enum ComfortKitSourceKind { careAction, whatHelped, futureSelfNote, quickNote }

enum ComfortKitOverrideAction { removeUntilChanged, dontShowAgain }

final class ComfortKitItemOverride {
  const ComfortKitItemOverride({
    required this.sourceId,
    required this.action,
    required this.updatedAt,
    this.sourceVersion,
  });

  final String sourceId;
  final ComfortKitOverrideAction action;
  final String? sourceVersion;
  final DateTime updatedAt;

  bool hides(ComfortKitItem item) {
    if (item.sourceId != sourceId) return false;
    return action == ComfortKitOverrideAction.dontShowAgain ||
        sourceVersion == item.sourceVersion;
  }
}

final class ComfortKitItem {
  const ComfortKitItem({
    required this.sourceId,
    required this.sourceVersion,
    required this.kind,
    required this.title,
    required this.body,
    required this.lastChangedAt,
    required this.rankGroup,
    this.careMode,
  });

  final String sourceId;
  final String sourceVersion;
  final ComfortKitSourceKind kind;
  final String title;
  final String body;
  final DateTime lastChangedAt;

  /// Lower values are returned first. Groups are the approved free ranking:
  /// repeated Better, pinned Care, recent Better, authored reflection, Quick
  /// note.
  final int rankGroup;
  final String? careMode;
}

final class ComfortKitComposition {
  const ComfortKitComposition({required this.items});

  final List<ComfortKitItem> items;

  bool get isFormed => items.isNotEmpty;
  List<ComfortKitItem> get visibleItems => List.unmodifiable(items.take(3));
  List<ComfortKitItem> get replacementItems => List.unmodifiable(items.skip(3));
}

final class ComfortKitAssembler {
  const ComfortKitAssembler();

  ComfortKitComposition compose({
    required List<SupportActionPattern> supportActions,
    required List<CareReflection> careReflections,
    required List<CycleReflection> cycleReflections,
    required List<CaptureNote> quickNotes,
    List<ComfortKitItemOverride> overrides = const [],
  }) {
    final candidates =
        <ComfortKitItem>[
              ..._careActions(supportActions),
              ..._careWhatHelped(careReflections),
              ..._cycleWhatHelped(cycleReflections),
              ..._careFutureNotes(careReflections),
              ..._cycleFutureNotes(cycleReflections),
              ..._quickNotes(quickNotes),
            ]
            .where((item) => !overrides.any((override) => override.hides(item)))
            .toList();

    candidates.sort((left, right) {
      var order = left.rankGroup.compareTo(right.rankGroup);
      if (order != 0) return order;
      order = right.lastChangedAt.compareTo(left.lastChangedAt);
      if (order != 0) return order;
      return left.sourceId.compareTo(right.sourceId);
    });
    return ComfortKitComposition(items: List.unmodifiable(candidates));
  }

  Iterable<ComfortKitItem> _careActions(
    List<SupportActionPattern> actions,
  ) sync* {
    for (final action in actions) {
      if (!action.pinned && action.betterCount == 0) continue;
      final rank = action.betterCount >= 2
          ? 0
          : action.pinned
          ? 1
          : 2;
      final body = action.betterCount > 0
          ? 'Marked a little easier ${action.betterCount} ${action.betterCount == 1 ? 'time' : 'times'}.'
          : 'Pinned by you.';
      yield ComfortKitItem(
        sourceId: action.id,
        sourceVersion: _version([
          action.actionId,
          action.count,
          action.betterCount,
          action.pinned,
          action.lastDate.epochDay,
        ]),
        kind: ComfortKitSourceKind.careAction,
        title: action.actionLabel,
        body: body,
        lastChangedAt: action.lastDate.asLocalDateTime,
        rankGroup: rank,
        careMode: action.mode.name,
      );
    }
  }

  Iterable<ComfortKitItem> _careFutureNotes(
    List<CareReflection> reflections,
  ) sync* {
    for (final reflection in reflections) {
      final text = reflection.futureSelfNote?.trim();
      if (text == null || text.isEmpty) continue;
      yield ComfortKitItem(
        sourceId: 'care-reflection:${reflection.id}',
        sourceVersion: _version([
          reflection.updatedAt.toUtc().millisecondsSinceEpoch,
          _stableTextHash(text),
        ]),
        kind: ComfortKitSourceKind.futureSelfNote,
        title: 'A note from a past hard moment',
        body: text,
        lastChangedAt: reflection.updatedAt,
        rankGroup: 3,
        careMode: reflection.mode.name,
      );
    }
  }

  Iterable<ComfortKitItem> _careWhatHelped(
    List<CareReflection> reflections,
  ) sync* {
    for (final reflection in reflections) {
      final text = reflection.whatHelped?.trim();
      if (text == null || text.isEmpty) continue;
      yield ComfortKitItem(
        sourceId: 'care-help:${reflection.id}',
        sourceVersion: _version([
          reflection.updatedAt.toUtc().millisecondsSinceEpoch,
          _stableTextHash(text),
        ]),
        kind: ComfortKitSourceKind.whatHelped,
        title: 'What helped in a hard moment',
        body: text,
        lastChangedAt: reflection.updatedAt,
        rankGroup: 3,
        careMode: reflection.mode.name,
      );
    }
  }

  Iterable<ComfortKitItem> _cycleWhatHelped(
    List<CycleReflection> reflections,
  ) sync* {
    for (final reflection in reflections) {
      final text = reflection.whatHelped?.trim();
      if (text == null || text.isEmpty) continue;
      yield ComfortKitItem(
        sourceId: 'cycle-help:${reflection.id}',
        sourceVersion: _version([
          reflection.updatedAt.toUtc().millisecondsSinceEpoch,
          _stableTextHash(text),
        ]),
        kind: ComfortKitSourceKind.whatHelped,
        title: 'What helped in an earlier cycle',
        body: text,
        lastChangedAt: reflection.updatedAt,
        rankGroup: 3,
      );
    }
  }

  Iterable<ComfortKitItem> _cycleFutureNotes(
    List<CycleReflection> reflections,
  ) sync* {
    for (final reflection in reflections) {
      final text = reflection.futureSelfNote?.trim();
      if (text == null || text.isEmpty) continue;
      yield ComfortKitItem(
        sourceId: 'cycle-reflection:${reflection.id}',
        sourceVersion: _version([
          reflection.updatedAt.toUtc().millisecondsSinceEpoch,
          _stableTextHash(text),
        ]),
        kind: ComfortKitSourceKind.futureSelfNote,
        title: 'A note from an earlier cycle',
        body: text,
        lastChangedAt: reflection.updatedAt,
        rankGroup: 3,
      );
    }
  }

  Iterable<ComfortKitItem> _quickNotes(List<CaptureNote> notes) sync* {
    for (final note in notes.where((note) => note.keepInComfortKit)) {
      final text = note.text.trim();
      if (text.isEmpty) continue;
      yield ComfortKitItem(
        sourceId: 'quick-note:${note.id}',
        sourceVersion: _version([
          note.updatedAt.toUtc().millisecondsSinceEpoch,
          _stableTextHash(text),
        ]),
        kind: ComfortKitSourceKind.quickNote,
        title: 'A note you kept',
        body: text,
        lastChangedAt: note.updatedAt,
        rankGroup: 4,
      );
    }
  }

  String _version(List<Object> values) => values.join(':');

  /// FNV-1a is used only for a stable local change fingerprint. It is not a
  /// security primitive and the text itself never leaves local storage.
  int _stableTextHash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }
}

final class ComfortKitWindowState {
  const ComfortKitWindowState({
    required this.formed,
    required this.proactivelyVisible,
  });

  factory ComfortKitWindowState.resolve({
    required ComfortKitComposition kit,
    required LocalDate today,
    required LocalDate? forecastStart,
    required LocalDate? forecastEnd,
    int leadDays = 2,
  }) {
    final formed = kit.isFormed;
    final visible =
        formed &&
        forecastStart != null &&
        forecastEnd != null &&
        !today.isBefore(forecastStart.addDays(-leadDays)) &&
        !today.isAfter(forecastEnd);
    return ComfortKitWindowState(formed: formed, proactivelyVisible: visible);
  }

  final bool formed;
  final bool proactivelyVisible;
}
