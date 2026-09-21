import '../domain/privacy_preferences_repository.dart';
import 'privacy_preferences_repository_factory_native.dart'
    if (dart.library.js_interop) 'privacy_preferences_repository_factory_web.dart'
    as platform;

PrivacyPreferencesRepository createDefaultPrivacyPreferencesRepository() {
  return platform.createDefaultPrivacyPreferencesRepository();
}
