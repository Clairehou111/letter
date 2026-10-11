import 'package:flutter/material.dart';
import 'package:letter_mobile/app/letter_app.dart';
import 'package:letter_mobile/features/onboarding/data/onboarding_repository.dart';
import 'package:letter_mobile/features/onboarding/domain/onboarding_profile.dart';

/// Local simulator review of the actual Build17 application and native store.
/// Starts at Today without an account, purchase or onboarding setup step.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(LetterApp(onboardingRepository: _PreviewOnboardingRepository()));
}

final class _PreviewOnboardingRepository implements OnboardingRepository {
  OnboardingProfile? _profile = OnboardingProfile();

  @override
  Future<OnboardingProfile?> load() async => _profile;

  @override
  Future<void> save(OnboardingProfile profile) async => _profile = profile;

  @override
  Future<void> clear() async => _profile = null;
}
