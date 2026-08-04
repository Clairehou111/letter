import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/design_system/letter_theme.dart';
import 'package:letter_mobile/features/archive_views/domain/archive_repository.dart';
import 'package:letter_mobile/features/archive_views/presentation/archive_views_screen.dart';
import 'package:letter_mobile/features/health_records/data/in_memory_health_record_repository.dart';

import 'archive_views_domain_test.dart' as fixtures;

Future<void> pumpArchive(
  WidgetTester tester,
  ArchiveInput input, {
  InMemoryHealthRecordRepository? healthRecords,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: LetterTheme.light,
      home: ArchiveViewsScreen(
        repository: InMemoryArchiveRepository(input),
        healthRecordRepository: healthRecords,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('keeps incomplete cycle separate and opens Story and Clinical', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpArchive(tester, fixtures.archiveInput());

    expect(find.text('Current cycle'), findsWidgets);
    expect(find.text('INCOMPLETE'), findsOneWidget);
    expect(find.text('Letter No. 12'), findsOneWidget);

    await tester.tap(find.byKey(const Key('archive-cycle-complete-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('archive-view-tabs')), findsOneWidget);
    expect(
      find.text('The middle of this cycle needed a quieter pace.'),
      findsOneWidget,
    );
    expect(find.text('Care overview'), findsOneWidget);
    final storyScroll = find
        .descendant(
          of: find.byKey(const Key('archive-story-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Warmth and quiet'),
      160,
      scrollable: storyScroll,
    );
    await tester.drag(storyScroll, const Offset(0, -100));
    await tester.pump();
    await tester.tap(find.text('Warmth and quiet'));
    await tester.pumpAndSettle();
    expect(find.text('Saved Care note'), findsOneWidget);
    expect(
      find.textContaining('The warmth made the next hour easier.'),
      findsOneWidget,
    );

    expect(find.text('Pattern'), findsNothing);

    await tester.tap(find.byIcon(Icons.table_chart_outlined));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('archive-clinical-health-table')),
      findsOneWidget,
    );
    expect(find.textContaining('Same day'), findsOneWidget);
  });

  testWidgets('search uses only visible saved evidence', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpArchive(tester, fixtures.archiveInput());

    await tester.enterText(
      find.byKey(const Key('archive-search')),
      'not a draft',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('archive-no-search-results')), findsOneWidget);
    expect(find.text('Letter No. 12'), findsNothing);

    await tester.enterText(find.byKey(const Key('archive-search')), 'cramps');
    await tester.pumpAndSettle();
    expect(find.text('Letter No. 12'), findsOneWidget);
    expect(find.text('Current cycle'), findsNothing);
  });

  testWidgets('clinical records offer an edit entrance', (tester) async {
    final input = fixtures.archiveInput();
    final healthRecords = InMemoryHealthRecordRepository(
      seed: input.healthRecords,
    );
    await pumpArchive(tester, input, healthRecords: healthRecords);

    await tester.tap(find.byKey(const Key('archive-cycle-complete-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.table_chart_outlined));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('archive-edit-health-records')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('archive-edit-health-records')));
    await tester.pumpAndSettle();
    expect(find.text('Health record'), findsOneWidget);
  });
}
