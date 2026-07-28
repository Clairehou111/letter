import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

abstract interface class LocalBackupFilePort {
  Future<void> shareEncryptedBackup(Uint8List bytes);

  /// Returns null when the user cancels the picker.
  Future<Uint8List?> pickEncryptedBackup();
}

/// Native operating-system hand-off for already encrypted package bytes.
/// The filename and share metadata intentionally contain no health information.
final class SystemLocalBackupFilePort implements LocalBackupFilePort {
  const SystemLocalBackupFilePort();

  @override
  Future<void> shareEncryptedBackup(Uint8List bytes) async {
    await Share.shareXFiles([
      XFile.fromData(
        bytes,
        name: 'letter-backup.letter',
        mimeType: 'application/octet-stream',
      ),
    ]);
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
}
