import 'privacy_preferences.dart';

abstract interface class PrivacyPreferencesRepository {
  Future<PrivacyPreferences> load();

  Future<void> save(PrivacyPreferences preferences);
}

final class InMemoryPrivacyPreferencesRepository
    implements PrivacyPreferencesRepository {
  InMemoryPrivacyPreferencesRepository([
    this._preferences = const PrivacyPreferences(),
  ]);

  PrivacyPreferences _preferences;

  @override
  Future<PrivacyPreferences> load() async => _preferences;

  @override
  Future<void> save(PrivacyPreferences preferences) async {
    _preferences = preferences;
  }
}
