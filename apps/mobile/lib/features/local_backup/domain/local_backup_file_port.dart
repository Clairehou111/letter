import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const localBackupExportFolderName = 'letter';

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
  SystemLocalBackupFilePort({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  String? _pendingExportFileName;

  @override
  Future<String> shareEncryptedBackup(Uint8List bytes) async {
    final fileName = _pendingExportFileName ??= localBackupExportFileName(
      _clock(),
    );
    await Share.shareXFiles([
      XFile.fromData(
        bytes,
        name: fileName,
        mimeType: 'application/octet-stream',
      ),
    ]);
    _pendingExportFileName = null;
    return fileName;
  }

  @override
  Future<String> saveEncryptedBackupLocally(Uint8List bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final fileName = localBackupExportFileName(_clock());
    _pendingExportFileName = fileName;
    final exportDirectory = Directory(
      '${dir.path}/$localBackupExportFolderName',
    );
    await exportDirectory.create(recursive: true);
    final file = File('${exportDirectory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  @override
  Future<Uint8List?> pickEncryptedBackup() async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['letter'],
      withData: true,
    );
    if (selection == null || selection.files.length != 1) {
      return null;
    }
    return selection.files.single.bytes;
  }

  @override
  String get exportLocationDescription {
    if (Platform.isIOS) {
      return 'After tapping "Create encrypted backup", use the share sheet to '
          'save the file to Files, AirDrop it, or send it to another app. '
          'Letter also saves a timestamped copy in the letter folder.';
    }
    return 'After tapping "Create encrypted backup", use the share sheet to '
        'save the file to your device, share it, or upload it to cloud '
        'storage. Letter also saves a timestamped copy in the letter folder.';
  }
}
