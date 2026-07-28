import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/care/presentation/personal_care_kit_view.dart';

const _items = [
  PersonalCareKitItemViewModel(
    id: 'warm-stone',
    actionLabel: 'Warm stone hold',
    modeLabel: 'Physical comfort',
    betterCount: 2,
    sameCount: 1,
    worseCount: 0,
  ),
  PersonalCareKitItemViewModel(
    id: 'quiet-cocoon',
    actionLabel: 'Close the quiet curtain',
    modeLabel: 'Need space',
    betterCount: 0,
    sameCount: 1,
    worseCount: 1,
  ),
];

Future<void> pumpKit(
  WidgetTester tester, {
  List<PersonalCareKitItemViewModel> items = _items,
  Set<String> busyItemIds = const {},
  bool isLoading = false,
  bool hasError = false,
  ValueChanged<String>? onUnpin,
  ValueChanged<String>? onDelete,
  VoidCallback? onRetry,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool disableAnimations = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: LetterTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: PersonalCareKitView(
          items: items,
          busyItemIds: busyItemIds,
          isLoading: isLoading,
          hasError: hasError,
          onUnpin: onUnpin ?? (_) {},
          onDelete: onDelete ?? (_) {},
          onRetry: onRetry,
        ),
      ),
    ),
  );
  await tester.pump();
}

void expectMinimumTarget(WidgetTester tester, String key) {
  final size = tester.getSize(find.byKey(Key(key)));
  expect(size.width, greaterThanOrEqualTo(44), reason: '$key width');
  expect(size.height, greaterThanOrEqualTo(44), reason: '$key height');
}

void main() {
  testWidgets('renders immutable items and direct observed counts', (
    tester,
  ) async {
    await pumpKit(tester);

    expect(find.text('My Care Kit'), findsOneWidget);
    expect(find.text('Warm stone hold'), findsOneWidget);
    expect(find.text('Physical comfort'), findsOneWidget);
    expect(find.text('Better in 2 of 3 check-backs'), findsOneWidget);
    expect(find.text('Better 2'), findsOneWidget);
    expect(find.text('Same 1'), findsNWidgets(2));
    expect(find.text('Worse 0'), findsOneWidget);
    expect(find.text('Better in 0 of 2 check-backs'), findsOneWidget);
    expect(find.textContaining('effective'), findsNothing);
    expect(find.textContaining('worked'), findsNothing);
    expect(find.textContaining('helped'), findsNothing);
  });

  testWidgets('unpin and delete emit only the selected item id', (
    tester,
  ) async {
    final unpinned = <String>[];
    final deleted = <String>[];
    await pumpKit(tester, onUnpin: unpinned.add, onDelete: deleted.add);

    await tester.tap(
      find.byKey(const Key('personal-care-kit-unpin-warm-stone')),
    );
    await tester.tap(
      find.byKey(const Key('personal-care-kit-delete-quiet-cocoon')),
    );
    await tester.pump();

    expect(unpinned, ['warm-stone']);
    expect(deleted, ['quiet-cocoon']);
  });

  testWidgets('empty Kit explains that pinning is always explicit', (
    tester,
  ) async {
    await pumpKit(tester, items: const []);

    expect(find.byKey(const Key('personal-care-kit-empty')), findsOneWidget);
    expect(find.text('Your Care Kit is empty.'), findsOneWidget);
    expect(
      find.text('Actions appear here only after you choose to keep them.'),
      findsOneWidget,
    );
  });

  testWidgets('loading state does not expose stale item actions', (
    tester,
  ) async {
    await pumpKit(tester, isLoading: true);

    expect(find.byKey(const Key('personal-care-kit-loading')), findsOneWidget);
    expect(find.text('Warm stone hold'), findsNothing);
    expect(find.text('Unpin'), findsNothing);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('busy item preserves counts and disables its actions only', (
    tester,
  ) async {
    await pumpKit(tester, busyItemIds: const {'warm-stone'});

    expect(find.text('Better in 2 of 3 check-backs'), findsOneWidget);
    final busyUnpin = tester.widget<OutlinedButton>(
      find.byKey(const Key('personal-care-kit-unpin-warm-stone')),
    );
    final busyDelete = tester.widget<TextButton>(
      find.byKey(const Key('personal-care-kit-delete-warm-stone')),
    );
    final otherUnpin = tester.widget<OutlinedButton>(
      find.byKey(const Key('personal-care-kit-unpin-quiet-cocoon')),
    );
    expect(busyUnpin.onPressed, isNull);
    expect(busyDelete.onPressed, isNull);
    expect(otherUnpin.onPressed, isNotNull);
  });

  testWidgets('generic error preserves items and supports explicit retry', (
    tester,
  ) async {
    var retries = 0;
    final semantics = tester.ensureSemantics();
    await pumpKit(tester, hasError: true, onRetry: () => retries += 1);

    expect(find.text('Warm stone hold'), findsOneWidget);
    expect(
      find.text('Letter could not update private Care memory. Try again.'),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(find.byKey(const Key('personal-care-kit-error'))),
      isSemantics(isLiveRegion: true),
    );

    await tester.tap(find.byKey(const Key('personal-care-kit-retry')));
    await tester.pump();
    expect(retries, 1);
    semantics.dispose();
  });

  testWidgets('item semantics state all outcomes without an inferred claim', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpKit(tester);

    final data = tester
        .getSemantics(
          find.byKey(const Key('personal-care-kit-item-warm-stone')),
        )
        .getSemanticsData();
    expect(
      data.label,
      contains(
        'Warm stone hold. Physical comfort. '
        'Better 2, Same 1, Worse 0, across 3 check-backs.',
      ),
    );
    expect(
      find.bySemanticsLabel(RegExp('effective|worked|helped')),
      findsNothing,
    );
    semantics.dispose();
  });

  testWidgets('all item actions meet the 44 logical-pixel target', (
    tester,
  ) async {
    await pumpKit(tester);

    for (final key in [
      'personal-care-kit-unpin-warm-stone',
      'personal-care-kit-delete-warm-stone',
      'personal-care-kit-unpin-quiet-cocoon',
      'personal-care-kit-delete-quiet-cocoon',
    ]) {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.pump();
      expectMinimumTarget(tester, key);
    }
  });

  testWidgets('fits 320 pixels at 200 percent text with reduced motion', (
    tester,
  ) async {
    await pumpKit(
      tester,
      size: const Size(320, 700),
      textScale: 2,
      disableAnimations: true,
    );

    for (final key in [
      'personal-care-kit-unpin-warm-stone',
      'personal-care-kit-delete-warm-stone',
      'personal-care-kit-unpin-quiet-cocoon',
      'personal-care-kit-delete-quiet-cocoon',
    ]) {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.pump();
      expect(find.byKey(Key(key)).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('populated Kit matches the visual baseline', (tester) async {
    await pumpKit(tester);

    await expectLater(
      find.byType(PersonalCareKitView),
      matchesGoldenFile('goldens/personal_care_kit_populated_390x844.png'),
    );
  });
}
