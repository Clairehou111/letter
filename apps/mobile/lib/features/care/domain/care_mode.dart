enum CareSafetyKind { emotional, physical }

enum CareMode {
  explode(
    label: 'I want to explode',
    sceneTitle: 'Put the force somewhere safe.',
    focalAction: 'Put the force here',
    transformedLabel: 'The noise stops here.',
    protectiveLine: 'Nothing has to leave this screen.',
    handOff: 'Pause the decision for now',
    safetyKind: CareSafetyKind.emotional,
  ),
  heavy(
    label: 'I feel heavy',
    sceneTitle: 'One small response is enough.',
    focalAction: 'Wake one light',
    transformedLabel: 'One light is on.',
    protectiveLine: 'Nothing needs to be solved from this minute.',
    handOff: 'Put the phone down for a moment',
    safetyKind: CareSafetyKind.emotional,
  ),
  racing(
    label: "My mind won't stop",
    sceneTitle: 'Bring everything toward one point.',
    focalAction: 'Bring it to one point',
    transformedLabel: 'One point. Not every thought.',
    protectiveLine: 'The rest can wait outside this minute.',
    handOff: 'Choose one thing, or nothing now',
    safetyKind: CareSafetyKind.emotional,
  ),
  space(
    label: 'I need everyone away',
    sceneTitle: 'Close one boundary.',
    focalAction: 'Close the curtain',
    transformedLabel: 'The boundary is closed.',
    protectiveLine: 'You are allowed to be unavailable.',
    handOff: 'Take a quiet boundary now',
    safetyKind: CareSafetyKind.emotional,
  ),
  physical(
    label: 'My body hurts',
    sceneTitle: 'Make this moment quieter.',
    focalAction: 'Make the screen quieter',
    transformedLabel: 'Less input. More room.',
    protectiveLine: 'Comfort first. You do not need to explain it.',
    handOff: 'Get one familiar comfort',
    safetyKind: CareSafetyKind.physical,
  );

  const CareMode({
    required this.label,
    required this.sceneTitle,
    required this.focalAction,
    required this.transformedLabel,
    required this.protectiveLine,
    required this.handOff,
    required this.safetyKind,
  });

  final String label;
  final String sceneTitle;
  final String focalAction;
  final String transformedLabel;
  final String protectiveLine;
  final String handOff;
  final CareSafetyKind safetyKind;
}
