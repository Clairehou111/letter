import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';

void main() {
  test('defines the five approved experiential entrances', () {
    expect(CareMode.values.map((mode) => mode.label), [
      'I want to explode',
      'I feel heavy',
      "My mind won't stop",
      'I need everyone away',
      'My body needs care',
    ]);
  });

  test('only physical Care uses the physical safety boundary', () {
    expect(
      CareMode.values
          .where((mode) => mode.safetyKind == CareSafetyKind.physical)
          .toList(),
      [CareMode.physical],
    );
  });
}
