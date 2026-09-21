enum MomentCheckInState {
  good('Good'),
  steady('Steady'),
  calm('Calm'),
  energized('Energized'),
  hopeful('Hopeful'),
  tender('Tender'),
  low('Low'),
  irritable('Irritable'),
  anxious('Anxious'),
  overwhelmed('Overwhelmed'),
  exhausted('Exhausted'),
  physical('Physical');

  const MomentCheckInState(this.label);

  final String label;
}

final class MomentCheckIn {
  const MomentCheckIn({
    required this.id,
    required this.state,
    required this.occurredAt,
    required this.createdAt,
  });

  final String id;
  final MomentCheckInState state;
  final DateTime occurredAt;
  final DateTime createdAt;
}
