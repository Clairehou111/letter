import 'onboarding_repository.dart';
import 'onboarding_repository_factory_native.dart'
    if (dart.library.js_interop) 'onboarding_repository_factory_web.dart'
    as platform;

OnboardingRepository createDefaultOnboardingRepository() {
  return platform.createDefaultOnboardingRepository();
}
