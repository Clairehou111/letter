import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class PersonalPatternPreviewRepository {
  Future<bool> hasViewedPreview();
  Future<void> markPreviewViewed();
}

final class SecurePersonalPatternPreviewRepository
    implements PersonalPatternPreviewRepository {
  SecurePersonalPatternPreviewRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'letter.plus.personal-pattern-preview-viewed';
  final FlutterSecureStorage _storage;

  @override
  Future<bool> hasViewedPreview() async =>
      await _storage.read(key: _key) == 'true';

  @override
  Future<void> markPreviewViewed() => _storage.write(key: _key, value: 'true');
}

final class InMemoryPersonalPatternPreviewRepository
    implements PersonalPatternPreviewRepository {
  InMemoryPersonalPatternPreviewRepository([this._viewed = false]);

  bool _viewed;

  @override
  Future<bool> hasViewedPreview() async => _viewed;

  @override
  Future<void> markPreviewViewed() async => _viewed = true;
}
