import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every Care mode bundles its selected runtime MP3 loop', () async {
    for (final mode in CareMode.values) {
      final data = await rootBundle.load(
        'assets/audio/care/prototype/${mode.name}.mp3',
      );
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      expect(bytes.length, greaterThan(100000), reason: mode.name);
      expect(bytes.sublist(0, 3), [0x49, 0x44, 0x33], reason: mode.name);
    }
  });
}
