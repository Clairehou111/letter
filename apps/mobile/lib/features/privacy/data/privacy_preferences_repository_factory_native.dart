import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domain/privacy_preferences_repository.dart';
import 'file_privacy_preferences_repository.dart';
import 'secure_privacy_preferences_repository.dart';

PrivacyPreferencesRepository createDefaultPrivacyPreferencesRepository() {
  if (Platform.isMacOS && kDebugMode) {
    return FilePrivacyPreferencesRepository();
  }
  return SecurePrivacyPreferencesRepository();
}
