import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/onboarding_profile.dart';
import 'onboarding_repository.dart';

/// File-based onboarding repository. Used when secure storage is unavailable
/// (macOS debug builds, tests). Onboarding data is preferences only — no
/// health data — so file storage is acceptable.
final class FileOnboardingRepository implements OnboardingRepository {
  FileOnboardingRepository({this._directory});

  static const _profileFileName = 'onboarding_profile.json';

  final Directory? _directory;
  String? _profilePath;

  Future<String> get _path async {
    if (_profilePath != null) return _profilePath!;
    final dir = _directory ?? await getApplicationDocumentsDirectory();
    _profilePath = '${dir.path}/$_profileFileName';
    return _profilePath!;
  }

  @override
  Future<OnboardingProfile?> load() async {
    final path = await _path;
    final file = File(path);
    if (!await file.exists()) return null;
    try {
      final encoded = await file.readAsString();
      return OnboardingProfileCodec.decode(encoded);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(OnboardingProfile profile) async {
    final path = await _path;
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(OnboardingProfileCodec.encode(profile));
  }

  @override
  Future<void> clear() async {
    final path = await _path;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
