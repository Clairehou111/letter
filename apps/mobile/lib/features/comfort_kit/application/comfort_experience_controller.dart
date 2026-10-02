import '../../capture/domain/capture_models.dart';
import '../../care/domain/care_memory_repository.dart';
import '../../care/domain/care_memory.dart';
import '../../comfort_window/domain/comfort_reminder_preference.dart';
import '../../comfort_window/domain/comfort_window.dart';
import '../../comfort_window/domain/comfort_window_engine.dart';
import '../../cycle/domain/cycle_prediction.dart';
import '../../cycle/domain/local_date.dart';
import '../../patterns/domain/pattern_source.dart';
import '../../patterns/domain/personal_pattern_engine.dart';
import '../domain/comfort_kit.dart';
import '../domain/comfort_kit_repository.dart';

final class ComfortExperienceSnapshot {
  const ComfortExperienceSnapshot({
    required this.today,
    required this.window,
    required this.kit,
    required this.windowState,
    required this.reminder,
  });

  final LocalDate today;
  final ComfortWindowPrediction? window;
  final ComfortKitComposition kit;
  final ComfortKitWindowState windowState;
  final ComfortReminderPreference reminder;

  bool get canConfigureReminder => window?.canOfferReminder == true;
}

/// A single non-visual boundary for Today, Care, Patterns, and Settings. It
/// always rebuilds from current local records; it has no predictive cache.
final class ComfortExperienceController {
  const ComfortExperienceController({
    required this.patternSource,
    required this.careMemory,
    required this.quickNotes,
    required this.kitRepository,
    required this.reminderRepository,
    this.onReminderChanged,
    this.now,
  });

  final PatternSourceReader patternSource;
  final CareMemoryRepository careMemory;
  final CaptureNoteStore quickNotes;
  final ComfortKitRepository kitRepository;
  final ComfortReminderPreferenceRepository reminderRepository;
  final Future<void> Function()? onReminderChanged;
  final DateTime Function()? now;

  DateTime _now() => now?.call() ?? DateTime.now();

  Future<ComfortExperienceSnapshot> load() async {
    final today = LocalDate.fromDateTime(_now().toLocal());
    final source = (await patternSource.read()).through(today);
    final periodPrediction = CyclePredictionEngine.calculate(
      CyclePredictionEngine.recordsThrough(source.periods, today),
    );
    final window = const ComfortWindowEngine().calculate(
      source: source,
      periodPrediction: periodPrediction,
      today: today,
    );
    final analysis = const PersonalPatternEngine().analyze(source);
    final values = await Future.wait<Object>([
      careMemory.getCycleReflections(),
      quickNotes.getAll(),
      kitRepository.getOverrides(),
      reminderRepository.load(),
    ]);
    final kit = const ComfortKitAssembler().compose(
      supportActions: analysis.supportActions,
      careReflections: source.careReflections,
      cycleReflections: values[0] as List<CycleReflection>,
      quickNotes: values[1] as List<CaptureNote>,
      overrides: values[2] as List<ComfortKitItemOverride>,
    );
    return ComfortExperienceSnapshot(
      today: today,
      window: window,
      kit: kit,
      windowState: ComfortKitWindowState.resolve(
        kit: kit,
        today: today,
        forecastStart: window?.forecastStart,
        forecastEnd: window?.forecastEnd,
      ),
      reminder: values[3] as ComfortReminderPreference,
    );
  }

  Future<ComfortExperienceSnapshot> remove(ComfortKitItem item) async {
    await kitRepository.removeUntilChanged(item: item, updatedAt: _now());
    return load();
  }

  Future<ComfortExperienceSnapshot> dontShowAgain(ComfortKitItem item) async {
    await kitRepository.dontShowAgain(
      sourceId: item.sourceId,
      updatedAt: _now(),
    );
    return load();
  }

  Future<ComfortExperienceSnapshot> restore(String sourceId) async {
    await kitRepository.restore(sourceId);
    return load();
  }

  Future<ComfortExperienceSnapshot> saveReminder({
    required bool enabled,
    required int leadDays,
    int hour = 9,
    int minute = 0,
  }) async {
    if (leadDays < 0 || leadDays > 2) {
      throw ArgumentError.value(leadDays, 'leadDays');
    }
    await reminderRepository.save(
      ComfortReminderPreference(
        enabled: enabled,
        leadDays: leadDays,
        hour: hour,
        minute: minute,
        updatedAt: _now().toUtc(),
      ),
    );
    await onReminderChanged?.call();
    return load();
  }
}
