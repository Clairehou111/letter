import 'package:flutter/material.dart';

import '../../features/capture/domain/capture_models.dart';
import '../../features/check_in/domain/moment_check_in_repository.dart';
import '../../features/comfort_kit/application/comfort_experience_controller.dart';
import '../../features/cycle/domain/local_date.dart';
import '../../features/cycle/domain/period_record.dart';
import '../../features/cycle/presentation/period_write_review.dart';
import '../../features/record_hub/domain/record_hub_repository.dart';
import '../../features/record_hub/presentation/record_entry_section.dart';
import '../../features/cycle/domain/period_repository.dart';
import '../../features/health_records/domain/health_record_repository.dart';
import '../../features/health_records/domain/health_record.dart';
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
    this.comfortExperienceController,
    required this.today,
    required this.onOpenCare,
    required this.onOpenCycleDayEditor,
    required this.onOpenCycleBackfill,
    required this.onCycleDataChanged,
    this.revision = 0,
    this.showHeader = true,
    this.now,
    this.onOpenRecord,
    this.onOpenRecordSection,
    this.onOpenSymptom,
    this.preparationContent,
    this.programmeContent,
    this.recordHubRepository,
    this.loadSupportActionPatterns,
    this.loadPreparationLoopKind,
    super.key,
  });

  final PeriodRepository periodRepository;
  final MomentCheckInRepository checkInRepository;
  final HealthRecordRepository healthRecordRepository;
  final CaptureNoteStore captureNoteStore;
  final ComfortExperienceController? comfortExperienceController;
  final LocalDate Function() today;
  final DateTime Function()? now;
  final VoidCallback? onOpenRecord;
  final ValueChanged<RecordEntrySection>? onOpenRecordSection;
  final ValueChanged<SymptomType>? onOpenSymptom;
  final Widget? preparationContent, programmeContent;
  final RecordHubRepository? recordHubRepository;
  final VoidCallback onOpenCare;

  /// Retained shell routes; Today no longer duplicates Cycle's history editor.
  final Future<void> Function()? onOpenCycleDayEditor;
  final VoidCallback onOpenCycleBackfill;
  final VoidCallback onCycleDataChanged;
  final int revision;
  final bool showHeader;
  final Future<List<SupportActionPattern>> Function()?
  loadSupportActionPatterns;
  final Future<PreparationLoopKind?> Function()? loadPreparationLoopKind;

  @override
  Widget build(BuildContext context) {
    final comfortController = comfortExperienceController;
    return TodayExperienceVisual(
      revision: revision,
      showHeader: showHeader,
      preparationContent: preparationContent,
      programmeContent: programmeContent,
      onStartPeriod: () async {
        final saved = await writePeriodWithReview(
          context: context,
          repository: periodRepository,
          draft: PeriodDraft(startDate: today()),
          today: today(),
        );
        if (saved != null) onCycleDataChanged();
        return saved != null;
      },
      onEndPeriod: () async {
        final open = (await periodRepository.getAll())
            .where((period) => period.isOpen)
            .firstOrNull;
        if (open == null || !context.mounted) return false;
        final saved = await writePeriodWithReview(
          context: context,
          repository: periodRepository,
          draft: PeriodDraft(startDate: open.startDate, endDate: today()),
          editingId: open.id,
          today: today(),
        );
        if (saved != null) onCycleDataChanged();
        return saved != null;
      },
      onOpenRecord: onOpenRecord,
      onOpenRecordSection: onOpenRecordSection,
      onOpenSymptom: onOpenSymptom,
      port: RepositoryTodayVisualPort(
        periodRepository: periodRepository,
        recordHubRepository: recordHubRepository,
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
        loadComfortExperience: comfortController?.load,
        saveComfortReminderPreference: comfortController == null
            ? null
            : ({required bool enabled, required int leadDays}) =>
                  comfortController.saveReminder(
                    enabled: enabled,
                    leadDays: leadDays,
                  ),
      ),
    );
  }
}
