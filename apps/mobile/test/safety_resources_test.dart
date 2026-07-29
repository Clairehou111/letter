import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/care/domain/safety_resources.dart';

void main() {
  group('crisisRegionForCode', () {
    test('maps US and CA explicitly', () {
      expect(crisisRegionForCode('US'), CrisisRegion.unitedStates);
      expect(crisisRegionForCode('us'), CrisisRegion.unitedStates);
      expect(crisisRegionForCode('CA'), CrisisRegion.canada);
      expect(crisisRegionForCode('ca'), CrisisRegion.canada);
    });

    test('falls back for other, missing, or malformed codes', () {
      expect(crisisRegionForCode('GB'), CrisisRegion.other);
      expect(crisisRegionForCode('CN'), CrisisRegion.other);
      expect(crisisRegionForCode(null), CrisisRegion.other);
      expect(crisisRegionForCode(''), CrisisRegion.other);
      expect(crisisRegionForCode('usa'), CrisisRegion.other);
    });
  });

  group('crisisSafetyContentForCode', () {
    test('US content offers 988 call/text and 911', () {
      final content = crisisSafetyContentForCode('US');
      expect(content.contacts, hasLength(2));
      expect(content.contacts.first.number, '988');
      expect(content.contacts.first.label, contains('988'));
      expect(content.contacts.first.label.toLowerCase(), contains('text'));
      expect(content.contacts.last.number, '911');
      expect(content.fallbackLine, isNull);
    });

    test('CA content offers 9-8-8 call/text and 911', () {
      final content = crisisSafetyContentForCode('CA');
      expect(content.contacts, hasLength(2));
      expect(content.contacts.first.number, '988');
      expect(content.contacts.first.label, contains('9-8-8'));
      expect(content.contacts.last.number, '911');
      expect(content.fallbackLine, isNull);
    });

    test('fallback content invents no numbers', () {
      for (final code in ['GB', 'CN', null, '']) {
        final content = crisisSafetyContentForCode(code);
        expect(content.region, CrisisRegion.other);
        expect(content.contacts, isEmpty);
        expect(content.fallbackLine, isNotNull);
        expect(content.fallbackLine, isNot(contains(RegExp(r'\d{3}'))));
      }
    });
  });

  group('medicalBoundaryContent', () {
    test('defines urgent and non-urgent tiers without treatment advice', () {
      expect(medicalBoundaryContent.urgent, isNotEmpty);
      expect(medicalBoundaryContent.nonUrgent, isNotEmpty);
      final all = [
        ...medicalBoundaryContent.urgent,
        ...medicalBoundaryContent.nonUrgent,
      ].join(' ').toLowerCase();
      for (final banned in [
        'mg',
        'dose',
        'ibuprofen',
        'naproxen',
        'ssri',
        'pill',
        'supplement',
        'diagnos',
      ]) {
        expect(all, isNot(contains(banned)), reason: 'banned term: $banned');
      }
    });

    test('urgent tier matches batch-004 emergency categories', () {
      final urgent = medicalBoundaryContent.urgent.join(' ').toLowerCase();
      expect(urgent, contains('faint'));
      expect(urgent, contains('palpitations'));
      expect(urgent, contains('severe'));
      expect(urgent, contains('bleeding'));
    });
  });
}
