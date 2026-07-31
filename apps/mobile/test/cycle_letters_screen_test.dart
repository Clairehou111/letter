import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/letters/presentation/cycle_letters_screen.dart';

const completedLetter = CycleLetterDisplay(
  id: 'cycle-june',
  letterNumber: 1,
  dateRange: 'Jun 12 - Jul 9, 2026',
  recordedPeriodDates: ['Jun 12', 'Jun 13', 'Jun 14', 'Jun 15'],
  careMoments: [
    CycleLetterCareMomentDisplay(
      id: 'care-racing',
      dateLabel: 'Jul 5',
      actionLabel: 'Racing thoughts',
      checkBackLabel: 'Better',
      reflectionId: 'reflection-june',
      reflectionPreview: 'Quiet helped. Try it earlier next time.',
    ),
    CycleLetterCareMomentDisplay(
      dateLabel: 'Jul 7',
      actionLabel: 'Need space',
      checkBackLabel: 'Same',
    ),
  ],
  checkBackCounts: CycleLetterCheckBackCounts(better: 1, same: 1),
  reflection: CycleLetterReflectionDisplay(
    id: 'reflection-june',
    dateLabel: 'Jul 11',
  ),
  notRecorded: ['No check-back was recorded for one Care moment.'],
);

const secondCompletedLetter = CycleLetterDisplay(
  id: 'cycle-july',
  letterNumber: 2,
  dateRange: 'Jul 10 - Aug 6, 2026',
  recordedPeriodDates: ['Jul 10', 'Jul 11', 'Jul 12'],
  careMoments: [],
  checkBackCounts: CycleLetterCheckBackCounts(),
  notRecorded: ['No Care moments recorded.', 'No reflection recorded.'],
);

const currentCycle = CycleLetterDisplay(
  id: 'cycle-current',
  dateRange: 'Aug 7 - present',
  recordedPeriodDates: ['Aug 7', 'Aug 8'],
  careMoments: [
    CycleLetterCareMomentDisplay(
      dateLabel: 'Aug 8',
      actionLabel: 'Physical comfort',
    ),
  ],
  checkBackCounts: CycleLetterCheckBackCounts(),
  notRecorded: ['Cycle end is not recorded.'],
);

const archiveModel = CycleLettersViewModel(
  status: CycleLettersStatus.ready,
  completedLetters: [secondCompletedLetter, completedLetter],
  currentCycle: currentCycle,
  unassignedCareRecords: [
    UnassignedCareDisplay(
      id: 'care-before-history',
      dateLabel: 'May 29, 2026',
      actionLabel: 'Heavy feelings',
      checkBackLabel: 'Worse',
    ),
  ],
);

Future<void> pumpArchive(
  WidgetTester tester, {
  CycleLettersViewModel viewModel = archiveModel,
  String? selectedLetterId,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool disableAnimations = false,
  ValueChanged<int>? onNavigationSelected,
  VoidCallback? onRetry,
  ValueChanged<String>? onLetterOpen,
  VoidCallback? onLetterClose,
  ValueChanged<String>? onReflectionOpen,
  ValueChanged<String>? onCareRecordReflect,
  VoidCallback? onOpenArchiveViews,
  VoidCallback? onOpenPersonalPatterns,
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
        child: CycleLettersScreen(
          viewModel: viewModel,
          selectedLetterId: selectedLetterId,
          onNavigationSelected: onNavigationSelected,
          onRetry: onRetry,
          onLetterOpen: onLetterOpen,
          onLetterClose: onLetterClose,
          onReflectionOpen: onReflectionOpen,
          onCareRecordReflect: onCareRecordReflect,
          onOpenArchiveViews: onOpenArchiveViews,
          onOpenPersonalPatterns: onOpenPersonalPatterns,
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> scrollTo(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(
    find.byKey(key),
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

void main() {
  testWidgets('keeps observed Patterns separate from Story and Clinical', (
    tester,
  ) async {
    var patternsOpened = 0;
    var archiveOpened = 0;
    await pumpArchive(
      tester,
      onOpenPersonalPatterns: () => patternsOpened += 1,
      onOpenArchiveViews: () => archiveOpened += 1,
    );

    expect(find.text('Patterns'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.textContaining('Story, Pattern, Clinical'), findsNothing);

    await tester.tap(find.text('Patterns'));
    await tester.tap(find.text('Reports'));
    expect(patternsOpened, 1);
    expect(archiveOpened, 1);
  });

  testWidgets('shows an explicit loading state without archive content', (
    tester,
  ) async {
    await pumpArchive(tester, viewModel: const CycleLettersViewModel.loading());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No cycle letters yet'), findsNothing);
    expect(find.text('Letter No. 1'), findsNothing);
  });

  testWidgets('shows a storage error and invokes retry explicitly', (
    tester,
  ) async {
    var retries = 0;
    await pumpArchive(
      tester,
      viewModel: const CycleLettersViewModel.error(),
      onRetry: () => retries += 1,
    );

    expect(
      find.text('Your private cycle letters could not be opened.'),
      findsOneWidget,
    );
    expect(find.text('Nothing has been changed.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cycle-letters-retry')));
    expect(retries, 1);
  });

  testWidgets('shows no periods without sample records or fake trends', (
    tester,
  ) async {
    await pumpArchive(
      tester,
      viewModel: const CycleLettersViewModel(status: CycleLettersStatus.ready),
    );

    expect(find.byKey(const Key('cycle-letters-no-periods')), findsOneWidget);
    expect(find.text('No cycle letters yet'), findsOneWidget);
    expect(find.textContaining('sample history'), findsOneWidget);
    expect(find.textContaining('Letter No.'), findsNothing);
    expect(find.textContaining('trend'), findsNothing);
  });

  testWidgets('keeps one current cycle separate and visibly incomplete', (
    tester,
  ) async {
    await pumpArchive(
      tester,
      viewModel: const CycleLettersViewModel(
        status: CycleLettersStatus.ready,
        currentCycle: currentCycle,
      ),
    );

    expect(find.text('Current cycle'), findsWidgets);
    expect(find.text('INCOMPLETE'), findsOneWidget);
    expect(find.text('Aug 7 - present'), findsOneWidget);
    expect(find.textContaining('Letter No.'), findsNothing);
    expect(find.text('Completed cycles'), findsNothing);
  });

  testWidgets(
    'lists completed letters using only supplied numbers and evidence',
    (tester) async {
      await pumpArchive(tester);

      expect(find.text('Letter No. 2'), findsOneWidget);
      expect(find.text('Letter No. 1'), findsOneWidget);
      expect(find.text('Letter No. 112'), findsNothing);
      expect(find.text('Jul 10 - Aug 6, 2026'), findsOneWidget);
      expect(
        find.text('3 recorded period days  •  0 Care moments'),
        findsOneWidget,
      );
      expect(
        find.text('4 recorded period days  •  2 Care moments'),
        findsOneWidget,
      );
    },
  );

  testWidgets('keeps Care outside completed cycles visible as unassigned', (
    tester,
  ) async {
    await pumpArchive(tester);
    await scrollTo(tester, const Key('unassigned-care-care-before-history'));

    expect(find.text('Not assigned to a completed cycle'), findsOneWidget);
    expect(find.text('Heavy feelings'), findsOneWidget);
    expect(find.text('May 29, 2026  •  Worse'), findsOneWidget);
  });

  testWidgets('invokes letter and bottom navigation callbacks', (tester) async {
    String? openedLetter;
    int? selectedNavigation;
    await pumpArchive(
      tester,
      onLetterOpen: (id) => openedLetter = id,
      onNavigationSelected: (index) => selectedNavigation = index,
    );

    await tester.tap(find.byKey(const Key('cycle-letter-cycle-current')));
    expect(openedLetter, 'cycle-current');

    await tester.tap(find.byKey(const Key('navigation-cycle')));
    expect(selectedNavigation, 1);
  });

  testWidgets('detail keeps reflections attached to their Care moments', (
    tester,
  ) async {
    await pumpArchive(tester, selectedLetterId: completedLetter.id);

    expect(find.text('COMPLETED CYCLE'), findsOneWidget);
    expect(find.text('Letter No. 1'), findsOneWidget);
    expect(
      find.byKey(const Key('cycle-letter-section-timing')),
      findsOneWidget,
    );
    expect(find.text('Cycle timing'), findsOneWidget);
    expect(find.text('Jun 12, Jun 13, Jun 14, Jun 15'), findsOneWidget);

    await scrollTo(tester, const Key('cycle-letter-section-care'));
    expect(find.byKey(const Key('cycle-letter-section-care')), findsOneWidget);
    expect(find.text('Care moments'), findsOneWidget);
    expect(find.text('Better 1'), findsOneWidget);
    expect(find.text('Same 1'), findsOneWidget);
    expect(find.text('Worse 0'), findsOneWidget);

    expect(
      find.byKey(const Key('cycle-letter-reflection-preview-care-racing')),
      findsOneWidget,
    );
    expect(find.text('Edit reflection'), findsOneWidget);

    await scrollTo(tester, const Key('cycle-letter-section-missing'));
    expect(
      find.byKey(const Key('cycle-letter-section-missing')),
      findsOneWidget,
    );
    expect(find.text('What is not recorded'), findsOneWidget);
  });

  testWidgets('edits a Care moment reflection and returns through callbacks', (
    tester,
  ) async {
    String? careRecordId;
    var closes = 0;
    await pumpArchive(
      tester,
      selectedLetterId: completedLetter.id,
      onLetterClose: () => closes += 1,
      onCareRecordReflect: (id) => careRecordId = id,
    );

    await tester.tap(find.byKey(const Key('cycle-letter-detail-back')));
    expect(closes, 1);

    await scrollTo(tester, const Key('cycle-letter-reflect-care-racing'));
    await tester.tap(find.byKey(const Key('cycle-letter-reflect-care-racing')));
    expect(careRecordId, 'care-racing');
  });

  testWidgets('shows missing evidence instead of inventing content', (
    tester,
  ) async {
    await pumpArchive(tester, selectedLetterId: secondCompletedLetter.id);

    await scrollTo(tester, const Key('cycle-letter-section-care'));
    expect(
      find.text('No Care moments are recorded for this cycle.'),
      findsOneWidget,
    );
    expect(
      find.text('No reflection is recorded for this cycle.'),
      findsNothing,
    );
    expect(find.text('No reflection recorded.'), findsOneWidget);
    expect(find.text('Edit reflection'), findsNothing);
  });

  testWidgets('shows an explicit state when selected source was deleted', (
    tester,
  ) async {
    var closes = 0;
    await pumpArchive(
      tester,
      selectedLetterId: 'deleted-cycle',
      onLetterClose: () => closes += 1,
    );

    expect(
      find.text('This cycle letter is no longer available.'),
      findsOneWidget,
    );
    expect(
      find.text('Its source records may have been changed or deleted.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('cycle-letter-missing-back')));
    expect(closes, 1);
  });

  testWidgets('does not expose excluded private or clinical content', (
    tester,
  ) async {
    await pumpArchive(tester, selectedLetterId: completedLetter.id);

    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('raw angry draft'), findsNothing);
    expect(find.textContaining('boundary-card text'), findsNothing);
    expect(find.textContaining('clipboard'), findsNothing);
    expect(find.textContaining('unsubmitted'), findsNothing);
    expect(find.textContaining('diagnosis'), findsNothing);
    expect(find.textContaining('DRSP'), findsNothing);
    expect(find.textContaining('treatment result'), findsNothing);
  });

  testWidgets('supports 320 pixels at 200 percent text and reduced motion', (
    tester,
  ) async {
    await pumpArchive(
      tester,
      size: const Size(320, 700),
      textScale: 2,
      disableAnimations: true,
      onLetterOpen: (_) {},
    );

    expect(tester.takeException(), isNull);
    await scrollTo(tester, const Key('cycle-letter-cycle-current'));
    final currentControl = find.byKey(const Key('cycle-letter-cycle-current'));
    expect(currentControl, findsOneWidget);
    expect(tester.getSize(currentControl).height, greaterThanOrEqualTo(44));

    await scrollTo(tester, const Key('cycle-letter-cycle-june'));
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('cycle-letter-cycle-june'))).height,
      greaterThanOrEqualTo(44),
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: LetterTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 700),
            textScaler: TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: const CycleLettersScreen(
            viewModel: archiveModel,
            selectedLetterId: 'cycle-june',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('cycle-letter-detail-back'))).height,
      greaterThanOrEqualTo(44),
    );
    await scrollTo(tester, const Key('cycle-letter-section-missing'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('matches the archive list visual baseline', (tester) async {
    await pumpArchive(tester);

    await expectLater(
      find.byType(CycleLettersScreen),
      matchesGoldenFile('goldens/cycle_letters_archive_390x844.png'),
    );
  });

  testWidgets('matches the completed letter detail visual baseline', (
    tester,
  ) async {
    await pumpArchive(tester, selectedLetterId: completedLetter.id);

    await expectLater(
      find.byType(CycleLettersScreen),
      matchesGoldenFile('goldens/cycle_letters_detail_390x844.png'),
    );
  });
}
