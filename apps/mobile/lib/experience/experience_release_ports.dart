import '../features/auth/domain/auth_service.dart';
import '../features/local_backup/domain/local_backup_models.dart';
import '../features/privacy/domain/privacy_preferences.dart';
import '../features/summary_export/domain/cycle_care_summary.dart';

/// Presentation-facing operations for report creation and native file handoff.
///
/// Implementations adapt the existing summary/PDF/CSV and dedicated Letter
/// folder services. UI code must not build files, choose paths, or infer data.
abstract interface class ReportExperiencePort {
  Future<SummaryExportInput> load();

  Future<ExperienceFileReceipt> export({
    required SummaryDateRange range,
    required Set<String> selectedNoteIds,
    required ReportExportFormat format,
  });
}

enum ReportExportFormat { pdf, csv }

enum ExperienceFileOutcome { shared, savedOnly, cancelled, failed }

final class ExperienceFileReceipt {
  const ExperienceFileReceipt({
    required this.outcome,
    this.localPath,
    this.message,
  });

  final ExperienceFileOutcome outcome;
  final String? localPath;
  final String? message;
}

/// Presentation-facing encrypted backup workflow.
///
/// The implementation owns encryption, credential storage, file picking,
/// local Letter-folder writes, native share sheets, staging, validation and
/// atomic commit. Presentation owns user choices and progress only.
abstract interface class BackupExperiencePort {
  String get localDestinationDescription;

  Future<bool> hasStoredPassphrase();

  Future<ExperienceFileReceipt> exportEncrypted({
    required String passphrase,
    required bool rememberPassphrase,
  });

  /// Returns null when the native file picker is cancelled.
  Future<LocalBackupImportPreview?> prepareImport({
    required String passphrase,
    required LocalBackupImportPolicy policy,
  });

  Future<void> commitPreparedImport();
  Future<void> discardPreparedImport();
}

/// Account and privacy operations surfaced by the You destination.
///
/// Health records never cross this boundary. Subscription purchase/restore is
/// provided separately by `EntitlementRepository`.
abstract interface class YouExperiencePort {
  AuthState get account;
  PrivacyPreferences get privacy;

  Stream<AuthState> watchAccount();
  Future<void> savePrivacy(PrivacyPreferences preferences);
  Future<void> signOut();
  Future<void> deleteServerAccount();
}
