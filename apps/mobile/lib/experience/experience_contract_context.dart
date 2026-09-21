/// Exact existing contracts available to Kimi's presentation implementation.
///
/// These exports provide compatibility and data semantics only. They are not
/// UI templates and must not be rewritten by Kimi.
library;

export '../features/care/domain/care_memory.dart';
export '../features/care/domain/care_memory_repository.dart';
export '../features/care/domain/care_mode.dart';
export '../features/care/domain/safety_resources.dart';
export '../features/capture/domain/capture_models.dart';
export '../features/check_in/domain/moment_check_in.dart';
export '../features/check_in/domain/moment_check_in_repository.dart';
export '../features/clinical/presentation/twin_matrix_view_model.dart';
export '../features/cycle/domain/bleeding_flow.dart';
export '../features/cycle/domain/cycle_prediction.dart';
export '../features/cycle/domain/local_date.dart';
export '../features/cycle/domain/period_record.dart';
export '../features/cycle/domain/period_repository.dart';
export '../features/entitlement/domain/entitlement.dart';
export '../features/entitlement/domain/entitlement_repository.dart';
export '../features/health_records/domain/health_record.dart';
export '../features/health_records/domain/observation_catalog.dart';
export '../features/health_records/domain/health_record_repository.dart';
export '../features/insights/presentation/gravity_horizon_view_model.dart';
export '../features/insights/presentation/spectrum_log_view_model.dart';
export '../features/letters/domain/cycle_letter.dart';
export '../features/letters/domain/cycle_letters_aggregator.dart';
export '../features/patterns/domain/pattern_source.dart';
export '../features/patterns/domain/personal_pattern.dart';
export '../features/patterns/domain/personal_pattern_engine.dart';
export '../features/preparation/domain/preparation_loop_state.dart';
export '../features/preparation/domain/preparation_plan.dart';
export '../features/preparation/domain/preparation_snapshot.dart';
export '../features/preparation/domain/preparation_snapshot_composer.dart';
export '../features/recovery_receipt/domain/recovery_receipt.dart';
export '../features/summary_export/domain/cycle_care_summary.dart';
export '../features/summary_export/domain/summary_export_repository.dart';
export '../features/today/today_cycle_context.dart';
export '../features/today/today_cycle_ring_model.dart';
export 'care/care_animation_port.dart';
export 'experience_release_ports.dart';
