import '../domain/privacy_preferences_repository.dart';
import 'secure_privacy_preferences_repository.dart';

PrivacyPreferencesRepository createDefaultPrivacyPreferencesRepository() {
  return SecurePrivacyPreferencesRepository();
}
