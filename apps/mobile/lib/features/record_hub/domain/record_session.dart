import '../../cycle/domain/local_date.dart';

enum RecordOrigin { today, cycle, care, patterns }

/// Navigation evidence only. The origin route stays mounted beneath Record.
final class RecordReturnContext {
  const RecordReturnContext({
    required this.origin,
    this.cycleId,
    this.sourceId,
    this.focusId,
  });

  final RecordOrigin origin;
  final String? cycleId;
  final String? sourceId;
  final String? focusId;
}

/// Ephemeral workspace state; this is never a stored Today selection.
final class RecordSession {
  const RecordSession({
    required this.selectedDate,
    required this.returnContext,
    this.sectionFocus,
  });

  final LocalDate selectedDate;
  final RecordReturnContext returnContext;
  final String? sectionFocus;

  RecordOrigin get origin => returnContext.origin;

  RecordSession withDate(LocalDate date) => RecordSession(
    selectedDate: date,
    returnContext: returnContext,
    sectionFocus: sectionFocus,
  );
}

enum RecordActivity { workspace, calendar, childEditor, safety, closed }

enum RecordDraftState { clean, dirty, saving, failed }

enum RecordTransitionResult {
  applied,
  needsDraftDecision,
  futureDate,
  saveInProgress,
  unavailable,
}

/// Captured at a write boundary, independently from the experienced date.
final class RecordWriteClock {
  const RecordWriteClock({
    required this.recordedAt,
    required this.localDay,
    required this.zoneName,
  });

  final DateTime recordedAt;
  final LocalDate localDay;
  final String zoneName;
}
