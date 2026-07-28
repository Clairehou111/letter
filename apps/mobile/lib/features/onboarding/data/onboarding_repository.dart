import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/onboarding_profile.dart';

abstract interface class OnboardingRepository {
  Future<OnboardingProfile?> load();

  Future<void> save(OnboardingProfile profile);

  Future<void> clear();
}

final class SecureOnboardingRepository implements OnboardingRepository {
  SecureOnboardingRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _profileKey = 'letter.onboarding.profile';

  final FlutterSecureStorage _storage;

  @override
  Future<OnboardingProfile?> load() async {
    final encoded = await _storage.read(key: _profileKey);
    if (encoded == null) {
      return null;
    }
    return OnboardingProfileCodec.decode(encoded);
  }

  @override
  Future<void> save(OnboardingProfile profile) {
    return _storage.write(
      key: _profileKey,
      value: OnboardingProfileCodec.encode(profile),
    );
  }

  @override
  Future<void> clear() {
    return _storage.delete(key: _profileKey);
  }
}

abstract final class OnboardingProfileCodec {
  static String encode(OnboardingProfile profile) {
    final goals = profile.selectedGoals.map((goal) => goal.storageId).toList()
      ..sort();
    return jsonEncode({
      'version': OnboardingProfile.schemaVersion,
      'cloud_tools': profile.cloudToolsPreference.storageId,
      'goals': goals,
    });
  }

  static OnboardingProfile decode(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Invalid onboarding profile');
    }
    if (decoded['version'] != OnboardingProfile.schemaVersion) {
      throw const FormatException('Unsupported onboarding profile version');
    }

    final goalValues = decoded['goals'];
    final goals = <OnboardingGoal>{};
    if (goalValues is List<Object?>) {
      for (final value in goalValues.whereType<String>()) {
        final goal = OnboardingGoal.fromStorageId(value);
        if (goal != null) {
          goals.add(goal);
        }
      }
    }

    return OnboardingProfile(
      cloudToolsPreference: CloudToolsPreference.fromStorageId(
        decoded['cloud_tools'] as String?,
      ),
      selectedGoals: goals,
    );
  }
}
