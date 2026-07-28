import 'dart:collection';

enum CloudToolsPreference {
  off('off'),
  askEachTime('ask_each_time');

  const CloudToolsPreference(this.storageId);

  final String storageId;

  static CloudToolsPreference fromStorageId(String? value) {
    return values.firstWhere(
      (preference) => preference.storageId == value,
      orElse: () => CloudToolsPreference.off,
    );
  }
}

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
  OnboardingProfile({
    required this.cloudToolsPreference,
    Iterable<OnboardingGoal> selectedGoals = const [],
  }) : selectedGoals = UnmodifiableSetView(Set.of(selectedGoals));

  static const schemaVersion = 1;

  final CloudToolsPreference cloudToolsPreference;
  final Set<OnboardingGoal> selectedGoals;

  OnboardingProfile copyWith({
    CloudToolsPreference? cloudToolsPreference,
    Iterable<OnboardingGoal>? selectedGoals,
  }) {
    return OnboardingProfile(
      cloudToolsPreference: cloudToolsPreference ?? this.cloudToolsPreference,
      selectedGoals: selectedGoals ?? this.selectedGoals,
    );
  }
}
