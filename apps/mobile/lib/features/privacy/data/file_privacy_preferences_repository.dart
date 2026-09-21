import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../domain/privacy_preferences.dart';
import '../domain/privacy_preferences_repository.dart';
import 'secure_privacy_preferences_repository.dart';

/// File-backed preferences for ad-hoc macOS debug builds without Keychain
/// entitlements. These values are app settings, not health records.
final class FilePrivacyPreferencesRepository
    implements PrivacyPreferencesRepository {
  FilePrivacyPreferencesRepository([this._directory]);

  static const _fileName = 'privacy_preferences.json';
  final Directory? _directory;

  Future<File> get _file async {
    final directory = _directory ?? await getApplicationSupportDirectory();
    return File(path.join(directory.path, _fileName));
  }

  @override
  Future<PrivacyPreferences> load() async {
    final file = await _file;
    if (!await file.exists()) return const PrivacyPreferences();
    try {
      return PrivacyPreferencesCodec.decode(await file.readAsString());
    } on Object {
      return const PrivacyPreferences();
    }
  }

  @override
  Future<void> save(PrivacyPreferences preferences) async {
    final file = await _file;
    await file.parent.create(recursive: true);
    await file.writeAsString(
      PrivacyPreferencesCodec.encode(preferences),
      flush: true,
    );
  }
}
