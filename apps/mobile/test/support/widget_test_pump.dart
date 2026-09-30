import 'package:flutter_test/flutter_test.dart';

/// Advances a widget test until [finder] appears without requiring the whole
/// tree to become idle. Letter Within intentionally has low-frequency ambient
/// motion, so app-level tests must wait for the state they care about instead
/// of using `pumpAndSettle`.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 50,
  Duration step = const Duration(milliseconds: 100),
}) async {
  for (var index = 0; index < maxPumps; index += 1) {
    await tester.pump(step);
    final exception = tester.takeException();
    if (exception != null) {
      throw TestFailure('Unexpected exception while waiting: $exception');
    }
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure(
    'Timed out waiting for ${finder.describeMatch(Plurality.one)} '
    'after $maxPumps pumps.',
  );
}
