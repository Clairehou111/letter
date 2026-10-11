import 'package:flutter/foundation.dart';

import '../../cycle/domain/local_date.dart';
import '../domain/record_session.dart';

/// Guards ephemeral drafts. Durable writes remain owned by repositories.
final class RecordSessionController extends ChangeNotifier {
  RecordSessionController({
    required RecordSession initialSession,
    DateTime Function()? clock,
    String Function()? zoneProvider,
  }) : _session = initialSession,
       _clock = clock ?? DateTime.now,
       _zoneName = zoneProvider;

  RecordSession _session;
  final DateTime Function() _clock;
  final String Function()? _zoneName;
  RecordActivity _activity = RecordActivity.workspace;
  RecordActivity? _beforeSafety;
  RecordDraftState _draftState = RecordDraftState.clean;

  RecordSession get session => _session;
  RecordActivity get activity => _activity;
  RecordDraftState get draftState => _draftState;
  bool get hasUnsavedDraft =>
      _draftState == RecordDraftState.dirty ||
      _draftState == RecordDraftState.failed;
  LocalDate get today => LocalDate.fromDateTime(_clock().toLocal());
  bool get selectedDateIsEligible => !_session.selectedDate.isAfter(today);

  void markDraftDirty() {
    if (_activity == RecordActivity.closed ||
        _draftState == RecordDraftState.saving) {
      return;
    }
    _draftState = RecordDraftState.dirty;
    notifyListeners();
  }

  void setDraftDirty(bool dirty) {
    if (_activity == RecordActivity.closed ||
        _draftState == RecordDraftState.saving) {
      return;
    }
    _draftState = dirty ? RecordDraftState.dirty : RecordDraftState.clean;
    notifyListeners();
  }

  RecordTransitionResult openCalendar() {
    if (_activity != RecordActivity.workspace) {
      return RecordTransitionResult.unavailable;
    }
    if (_draftState == RecordDraftState.saving) {
      return RecordTransitionResult.saveInProgress;
    }
    _activity = RecordActivity.calendar;
    notifyListeners();
    return RecordTransitionResult.applied;
  }

  void cancelCalendar() {
    if (_activity != RecordActivity.calendar) return;
    _activity = RecordActivity.workspace;
    notifyListeners();
  }

  RecordTransitionResult requestDateChange(
    LocalDate date, {
    bool discardDraft = false,
  }) {
    if (_activity != RecordActivity.workspace &&
        _activity != RecordActivity.calendar) {
      return RecordTransitionResult.unavailable;
    }
    if (_draftState == RecordDraftState.saving) {
      return RecordTransitionResult.saveInProgress;
    }
    if (date.isAfter(today)) return RecordTransitionResult.futureDate;
    if (date != _session.selectedDate && hasUnsavedDraft && !discardDraft) {
      return RecordTransitionResult.needsDraftDecision;
    }
    if (date != _session.selectedDate) {
      _session = _session.withDate(date);
      _draftState = RecordDraftState.clean;
    }
    _activity = RecordActivity.workspace;
    notifyListeners();
    return RecordTransitionResult.applied;
  }

  RecordTransitionResult openChild() {
    if (_activity != RecordActivity.workspace) {
      return RecordTransitionResult.unavailable;
    }
    if (_draftState == RecordDraftState.saving) {
      return RecordTransitionResult.saveInProgress;
    }
    // A workspace draft must be resolved before another editor can own it.
    if (hasUnsavedDraft) return RecordTransitionResult.needsDraftDecision;
    _activity = RecordActivity.childEditor;
    notifyListeners();
    return RecordTransitionResult.applied;
  }

  RecordTransitionResult closeChild({bool discardDraft = false}) {
    if (_activity != RecordActivity.childEditor) {
      return RecordTransitionResult.unavailable;
    }
    final guard = _exitGuard(discardDraft);
    if (guard != RecordTransitionResult.applied) return guard;
    _draftState = RecordDraftState.clean;
    _activity = RecordActivity.workspace;
    notifyListeners();
    return RecordTransitionResult.applied;
  }

  void openSafety() {
    if (_activity == RecordActivity.safety ||
        _activity == RecordActivity.closed ||
        _activity == RecordActivity.calendar) {
      return;
    }
    _beforeSafety = _activity;
    _activity = RecordActivity.safety;
    notifyListeners();
  }

  void returnFromSafety() {
    if (_activity != RecordActivity.safety) return;
    _activity = _beforeSafety ?? RecordActivity.workspace;
    _beforeSafety = null;
    notifyListeners();
  }

  /// Call immediately before each fact write, including retries after travel.
  RecordTransitionResult beginSave() {
    if (_activity != RecordActivity.workspace &&
        _activity != RecordActivity.childEditor) {
      return RecordTransitionResult.unavailable;
    }
    if (_draftState == RecordDraftState.saving) {
      return RecordTransitionResult.saveInProgress;
    }
    if (!selectedDateIsEligible) return RecordTransitionResult.futureDate;
    _draftState = RecordDraftState.saving;
    notifyListeners();
    return RecordTransitionResult.applied;
  }

  RecordWriteClock captureWriteClock() {
    final now = _clock();
    return RecordWriteClock(
      recordedAt: now,
      localDay: LocalDate.fromDateTime(now.toLocal()),
      zoneName: _zoneName?.call() ?? now.timeZoneName,
    );
  }

  void saveSucceeded() {
    if (_draftState != RecordDraftState.saving) return;
    _draftState = RecordDraftState.clean;
    notifyListeners();
  }

  void saveFailed() {
    if (_draftState != RecordDraftState.saving) return;
    _draftState = RecordDraftState.failed;
    notifyListeners();
  }

  RecordTransitionResult requestClose({bool discardDraft = false}) {
    if (_activity == RecordActivity.closed) {
      return RecordTransitionResult.unavailable;
    }
    final guard = _exitGuard(discardDraft);
    if (guard != RecordTransitionResult.applied) return guard;
    _draftState = RecordDraftState.clean;
    _activity = RecordActivity.closed;
    notifyListeners();
    return RecordTransitionResult.applied;
  }

  RecordTransitionResult _exitGuard(bool discardDraft) {
    if (_draftState == RecordDraftState.saving) {
      return RecordTransitionResult.saveInProgress;
    }
    if (hasUnsavedDraft && !discardDraft) {
      return RecordTransitionResult.needsDraftDecision;
    }
    return RecordTransitionResult.applied;
  }
}
