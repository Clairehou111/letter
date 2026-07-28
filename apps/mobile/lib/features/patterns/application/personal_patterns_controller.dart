import 'package:flutter/foundation.dart';

import '../../care/domain/care_mode.dart';
import '../../health_records/domain/health_record.dart';
import '../domain/pattern_source.dart';
import '../domain/personal_pattern.dart';
import '../domain/personal_pattern_engine.dart';

final class PersonalPatternsController extends ChangeNotifier {
  PersonalPatternsController({
    required this._source,
    this._engine = const PersonalPatternEngine(),
    this._mutations,
  });

  final PatternSourceReader _source;
  final PersonalPatternEngine _engine;
  final PatternMutationPort? _mutations;
  PersonalPatternAnalysis _analysis = PersonalPatternAnalysis.empty;
  CareMode? _selectedCareMode;
  final Set<String> _dismissedPatternIds = {};
  bool _isLoading = false;
  Object? _error;

  PersonalPatternAnalysis get analysis {
    if (_dismissedPatternIds.isEmpty) {
      return _analysis;
    }
    return _analysis.copyWith(
      symptomPatterns: _analysis.symptomPatterns
          .where((pattern) => !_dismissedPatternIds.contains(pattern.id))
          .toList(growable: false),
      supportActions: _analysis.supportActions
          .where((pattern) => !_dismissedPatternIds.contains(pattern.id))
          .toList(growable: false),
    );
  }

  CareMode? get selectedCareMode => _selectedCareMode;
  bool get isLoading => _isLoading;
  Object? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await refresh(notify: false);
    } catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh({bool notify = true}) async {
    final source = await _source.read();
    _analysis = _engine.analyze(source, selectedCareMode: _selectedCareMode);
    _error = null;
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> selectCareMode(CareMode? mode) async {
    _selectedCareMode = mode;
    await refresh();
  }

  void dismissPattern(String patternId) {
    _dismissedPatternIds.add(patternId);
    notifyListeners();
  }

  void restorePattern(String patternId) {
    if (_dismissedPatternIds.remove(patternId)) {
      notifyListeners();
    }
  }

  Future<void> setCareActionPinned(
    String careRecordId, {
    required bool pinned,
  }) async {
    final mutations = _mutations;
    if (mutations == null) {
      throw StateError('Pattern mutations are not connected.');
    }
    await mutations.setCareActionPinned(careRecordId, pinned: pinned);
    await refresh();
  }

  Future<void> deleteHealthRecord(String healthRecordId) async {
    final mutations = _mutations;
    if (mutations == null) {
      throw StateError('Pattern mutations are not connected.');
    }
    await mutations.deleteHealthRecord(healthRecordId);
    await refresh();
  }

  Future<void> updateHealthRecord(
    String healthRecordId,
    HealthRecordDraft draft,
  ) async {
    final mutations = _mutations;
    if (mutations == null) {
      throw StateError('Pattern mutations are not connected.');
    }
    await mutations.updateHealthRecord(healthRecordId, draft);
    await refresh();
  }

  Future<void> deleteCareRecord(String careRecordId) async {
    final mutations = _mutations;
    if (mutations == null) {
      throw StateError('Pattern mutations are not connected.');
    }
    await mutations.deleteCareRecord(careRecordId);
    await refresh();
  }
}
