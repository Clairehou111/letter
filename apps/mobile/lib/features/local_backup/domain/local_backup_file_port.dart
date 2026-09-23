import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart';

import '../../local_export/domain/letter_local_export_store.dart';

const localBackupExportFolderName = letterLocalExportFolderName;

/// One cross-platform filter for Letter Within's encrypted package.
///
/// iOS accepts UTIs only and throws before showing its picker when a group
/// contains just an extension or MIME type. `public.data` is intentionally
/// broad because `.letter` is a private encrypted container rather than a
/// system-registered document type; package validation still happens after
/// selection, before any records can be changed.
const localBackupFileTypeGroup = XTypeGroup(
  label: 'Letter Within encrypted backup',
  extensions: ['letter'],
  mimeTypes: ['application/octet-stream'],
  uniformTypeIdentifiers: ['public.data'],
);

String localBackupExportFileName(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return 'letter-backup-${value.year}-${two(value.month)}-'
      '${two(value.day)}-${two(value.hour)}-${two(value.minute)}-'
      '${two(value.second)}-${value.millisecond.toString().padLeft(3, '0')}.letter';
}

abstract interface class LocalBackupFilePort {
  /// Hands the encrypted package to the OS share sheet so the user can save,
  /// AirDrop, or send it anywhere. Returns the filename used.
  Future<String> shareEncryptedBackup(Uint8List bytes);

  /// Saves the encrypted package to the app's local documents directory and
  /// returns the absolute file path. Useful as a predictable fallback when the
  /// share sheet is not available.
  Future<String> saveEncryptedBackupLocally(Uint8List bytes);

  /// Returns null when the user cancels the picker.
  Future<Uint8List?> pickEncryptedBackup();

  /// Describes where exported backup files end up, for user messaging.
  String get exportLocationDescription;
}

/// Native operating-system hand-off for already encrypted package bytes.
/// The filename and share metadata intentionally contain no health information.
final class SystemLocalBackupFilePort implements LocalBackupFilePort {
  SystemLocalBackupFilePort({
    DateTime Function()? clock,
    this.localStore = const LetterLocalExportStore(),
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final LetterLocalExportStore localStore;
  String? _pendingExportFileName;
  String? _pendingExportPath;

  @override
  Future<String> shareEncryptedBackup(Uint8List bytes) async {
    final fileName = _pendingExportFileName ??= localBackupExportFileName(
      _clock(),
    );
    try {
      final savedPath = _pendingExportPath;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            if (savedPath != null)
              XFile(savedPath, mimeType: 'application/octet-stream')
            else
              XFile.fromData(
                bytes,
                name: fileName,
                mimeType: 'application/octet-stream',
              ),
          ],
        ),
      );
      return fileName;
    } finally {
      _pendingExportFileName = null;
      _pendingExportPath = null;
    }
  }

  @override
  Future<String> saveEncryptedBackupLocally(Uint8List bytes) async {
    final fileName = localBackupExportFileName(_clock());
    _pendingExportFileName = fileName;
    final savedPath = await localStore.save(fileName: fileName, bytes: bytes);
    _pendingExportPath = savedPath;
    return savedPath;
  }

  @override
  Future<Uint8List?> pickEncryptedBackup() async {
    final selection = await openFile(
      acceptedTypeGroups: const [localBackupFileTypeGroup],
    );
    return selection?.readAsBytes();
  }

  @override
  String get exportLocationDescription =>
      'Letter Within saves a timestamped copy in its dedicated letter '
      'folder, then opens the system destination sheet.';
}
