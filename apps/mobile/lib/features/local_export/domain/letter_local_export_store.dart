import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

const letterLocalExportFolderName = 'letter';

/// Stores user-created exports in one predictable, app-owned folder.
///
/// Cloud hand-off is deliberately separate: callers save here first and then
/// open the operating-system destination sheet with the saved file.
final class LetterLocalExportStore {
  const LetterLocalExportStore({this.documentsDirectory});

  /// Test override. Production resolves the platform documents directory.
  final Directory? documentsDirectory;

  Future<String> save({
    required String fileName,
    required List<int> bytes,
  }) async {
    final root = documentsDirectory ?? await getApplicationDocumentsDirectory();
    final exportDirectory = Directory(
      path.join(root.path, letterLocalExportFolderName),
    );
    await exportDirectory.create(recursive: true);
    final output = File(path.join(exportDirectory.path, fileName));
    await output.writeAsBytes(bytes, flush: true);
    return output.path;
  }
}
