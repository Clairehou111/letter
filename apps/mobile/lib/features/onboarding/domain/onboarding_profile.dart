import 'dart:collection';

enum OnboardingGoal {
  understandCycle('understand_cycle'),
  emotionalChanges('emotional_changes'),
  physicalDiscomfort('physical_discomfort'),
  energyAndSleep('energy_and_sleep'),
  selfCarePreparation('self_care_preparation'),
  appointmentPreparation('appointment_preparation');

  const OnboardingGoal(this.storageId);

  final String storageId;

  static OnboardingGoal? fromStorageId(String value) {
    for (final goal in values) {
      if (goal.storageId == value) {
        return goal;
      }
    }
    return null;
  }
}

final class OnboardingProfile {
  OnboardingProfile({Iterable<OnboardingGoal> selectedGoals = const []})
    : selectedGoals = UnmodifiableSetView(Set.of(selectedGoals));

  static const schemaVersion = 1;

  final Set<OnboardingGoal> selectedGoals;

  OnboardingProfile copyWith({Iterable<OnboardingGoal>? selectedGoals}) {
    return OnboardingProfile(
      selectedGoals: selectedGoals ?? this.selectedGoals,
    );
  }
}
