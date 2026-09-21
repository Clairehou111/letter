import 'package:flutter/material.dart';

import '../../features/capture/domain/capture_models.dart';
import '../../features/check_in/domain/moment_check_in_repository.dart';
import '../../features/cycle/domain/local_date.dart';
import '../../features/cycle/domain/period_repository.dart';
import '../../features/health_records/domain/health_record_repository.dart';
import '../../features/patterns/domain/personal_pattern.dart';
import '../../features/preparation/domain/preparation_loop_state.dart';
import '../theme/experience_foundation.dart';
import 'today_experience_visual_baseline.dart';
import 'today_visual_port.dart';

export 'today_experience_visual_baseline.dart' show TodayExperienceVisual;

/// Production adapter for the approved Today visual baseline.
///
/// Its only job is to turn the shell's established repositories into the
/// narrow [TodayVisualPort] that the Kimi-authored UI consumes.
class TodayExperience extends StatelessWidget {
  const TodayExperience({
    required this.periodRepository,
    required this.checkInRepository,
    required this.healthRecordRepository,
    required this.captureNoteStore,
    required this.today,
    required this.onOpenCare,
    required this.onOpenCycleDayEditor,
    required this.onOpenCycleBackfill,
    required this.onCycleDataChanged,
    this.revision = 0,
    this.now,
    this.loadSupportActionPatterns,
    this.loadPreparationLoopKind,
    super.key,
  });

  final PeriodRepository periodRepository;
  final MomentCheckInRepository checkInRepository;
  final HealthRecordRepository healthRecordRepository;
  final CaptureNoteStore captureNoteStore;
  final LocalDate Function() today;
  final DateTime Function()? now;
  final VoidCallback onOpenCare;

  /// Retained shell routes; Today no longer duplicates Cycle's history editor.
  final Future<void> Function()? onOpenCycleDayEditor;
  final VoidCallback onOpenCycleBackfill;
  final VoidCallback onCycleDataChanged;
  final int revision;
  final Future<List<SupportActionPattern>> Function()?
  loadSupportActionPatterns;
  final Future<PreparationLoopKind?> Function()? loadPreparationLoopKind;

  @override
  Widget build(BuildContext context) {
    return TodayExperienceVisual(
      revision: revision,
      port: RepositoryTodayVisualPort(
        periodRepository: periodRepository,
        checkInRepository: checkInRepository,
        healthRecordRepository: healthRecordRepository,
        captureNoteStore: captureNoteStore,
        today: today,
        now: now ?? DateTime.now,
        onCycleDataChanged: onCycleDataChanged,
        onOpenCare: onOpenCare,
        loadRememberedHelpLine: () async {
          final actions =
              await loadSupportActionPatterns?.call() ??
              const <SupportActionPattern>[];
          final loopKind = await loadPreparationLoopKind?.call();
          final verdict = ExperienceMemoryGate.gate(
            loopKind: loopKind,
            evidence: actions,
          );
          return switch (verdict) {
            MemoryEvidenceVerdict.remembered =>
              ExperienceMemoryGate.rememberedLine(actions),
            MemoryEvidenceVerdict.accumulating =>
              ExperienceMemoryGate.accumulatingLine(actions),
            _ => null,
          };
        },
      ),
    );
  }
}
