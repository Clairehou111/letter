import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';
import 'package:letter_mobile/features/care/data/in_memory_care_memory_repository.dart';
import 'package:letter_mobile/features/care/domain/care_memory.dart';
import 'package:letter_mobile/features/care/domain/care_mode.dart';
import 'package:letter_mobile/features/preparation/domain/preparation_plan.dart';
import 'package:letter_mobile/features/record_hub/presentation/record_preparation_screen.dart';

final _stamp = DateTime.utc(2026, 10, 9, 12);

CareRecord _support({String id = 'fictional-care', bool pinned = false}) =>
    CareRecord(
      id: id,
      mode: CareMode.physical,
      actionId: 'fictional.warmth',
      actionLabel: 'Fictional warmth',
      outcome: CareOutcome.better,
      occurredAt: _stamp,
      createdAt: _stamp,
      updatedAt: _stamp,
      pinned: pinned,
    );

PreparationPlan _plan({required String fingerprint, bool includeCare = true}) =>
    PreparationPlan(
      id: PreparationPlan.activeId,
      status: PreparationPlanStatus.current,
      evidenceFingerprint: fingerprint,
      sourceRecordIds: includeCare ? ['fictional-care'] : [],
      includeCare: includeCare,
      careActionId: includeCare ? 'fictional.warmth' : '',
      careActionLabel: includeCare ? 'Fictional warmth' : '',
      careMode: CareMode.physical,
      betterCount: includeCare ? 1 : 0,
      sameCount: 0,
      worseCount: 0,
      noteText: null,
      personalText: 'Fictional saved words',
      createdAt: _stamp,
      updatedAt: _stamp,
    );

void main() {
  Future<void> open(
    WidgetTester tester,
    _Plans plans,
    InMemoryCareMemoryRepository care, {
    VoidCallback? onChanged,
    VoidCallback? onOpenCare,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Origin Patterns'),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (routeContext) => RecordPreparationScreen(
                    repository: plans,
                    careRepository: care,
                    clock: () => _stamp,
                    onChanged: onChanged,
                    onOpenCare: () {
                      onOpenCare?.call();
                      Navigator.pop(routeContext);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Origin Patterns'));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    if (find.text(text).evaluate().isEmpty) {
      await tester.drag(find.byType(ListView), const Offset(0, 1000));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(text),
        150,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(find.text(text).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pump();
  }

  testWidgets('opening and reading a plan never rewrites its saved snapshot', (
    tester,
  ) async {
    final original = _plan(
      fingerprint: await preparationSelectionFingerprint([_support()], null),
    );
    final plans = _Plans(original);
    await open(tester, plans, InMemoryCareMemoryRepository());
    expect(
      find.textContaining('Saved reference — its source has changed'),
      findsOneWidget,
    );
    expect(find.textContaining('1 Better · 0 Same · 0 Worse'), findsOneWidget);
    expect(plans.writes, 0);
    expect(identical(plans.active, original), isTrue);
  });

  testWidgets('own words remain current without any Care source or forecast', (
    tester,
  ) async {
    final plans = _Plans(
      _plan(
        fingerprint: await preparationSelectionFingerprint([], null),
        includeCare: false,
      ),
    );
    await open(tester, plans, InMemoryCareMemoryRepository());
    expect(find.text('Your saved preparation plan'), findsOneWidget);
    expect(find.textContaining('Saved reference —'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Fictional revised words');
    await tap(tester, 'Save my plan');
    await tester.pumpAndSettle();
    expect(plans.active!.personalText, 'Fictional revised words');
    expect(plans.active!.sourceRecordIds, isEmpty);
    expect(plans.active!.includeCare, isFalse);
    expect(plans.active!.createdAt, _stamp);
  });

  testWidgets('failed durability preserves words and guards route exit', (
    tester,
  ) async {
    final plans = _Plans()..fail = true;
    await open(tester, plans, InMemoryCareMemoryRepository());
    await tester.enterText(find.byType(TextField), 'Fictional unsaved draft');
    await tap(tester, 'Save my plan');
    await tester.pumpAndSettle();
    expect(plans.active, isNull);
    expect(find.textContaining('Your draft is still here.'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Fictional unsaved draft',
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Keep editing your plan?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byType(RecordPreparationScreen), findsOneWidget);
    plans.fail = false;
    await tap(tester, 'Save my plan');
    await tester.pumpAndSettle();
    expect(plans.active!.personalText, 'Fictional unsaved draft');
  });

  testWidgets('ordinary Care requires explicit discard of an unsaved plan', (
    tester,
  ) async {
    var careOpens = 0;
    final plans = _Plans();
    await open(
      tester,
      plans,
      InMemoryCareMemoryRepository(),
      onOpenCare: () => careOpens++,
    );
    await tester.enterText(find.byType(TextField), 'Fictional unsaved draft');
    await tap(tester, 'Open ordinary Care');
    await tester.pumpAndSettle();
    expect(careOpens, 0);
    expect(find.text('Keep editing your plan?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Fictional unsaved draft',
    );
    await tap(tester, 'Open ordinary Care');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard draft'));
    await tester.pumpAndSettle();
    expect(careOpens, 1);
    expect(plans.writes, 0);
    expect(find.byType(RecordPreparationScreen), findsNothing);
  });

  testWidgets(
    'source deletion before Save preserves draft and writes no plan',
    (tester) async {
      final plans = _Plans();
      final care = InMemoryCareMemoryRepository(records: [_support()]);
      await open(tester, plans, care);
      await tap(tester, 'Fictional warmth');
      await tester.enterText(
        find.byType(TextField),
        'Fictional retained draft',
      );
      await care.deleteRecord('fictional-care');
      await tap(tester, 'Save my plan');
      await tester.pumpAndSettle();
      expect(plans.writes, 0);
      expect(find.textContaining('Your draft is still here.'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Fictional retained draft',
      );
      await tap(tester, 'Use only my own words');
      await tap(tester, 'Save my plan');
      await tester.pumpAndSettle();
      expect(plans.active!.personalText, 'Fictional retained draft');
      expect(plans.active!.sourceRecordIds, isEmpty);
    },
  );

  testWidgets('saved future-self words require explicit selection', (
    tester,
  ) async {
    final plans = _Plans();
    final care = InMemoryCareMemoryRepository(
      records: [_support()],
      clock: () => _stamp,
    );
    await care.saveReflection(
      'fictional-care',
      const CareReflectionDraft(futureSelfNote: 'Fictional selected words'),
    );
    await open(tester, plans, care);
    await tap(tester, 'Fictional warmth');
    await tap(tester, 'Save my plan');
    await tester.pumpAndSettle();
    expect(plans.active!.noteText, isNull);
    await tap(tester, 'Fictional selected words');
    await tap(tester, 'Save my plan');
    await tester.pumpAndSettle();
    expect(plans.active!.noteText, 'Fictional selected words');
    expect(plans.active!.sourceRecordIds, ['fictional-care']);
    expect(plans.active!.betterCount, 1);
  });

  testWidgets(
    'save callback and success wait for durability; exits are disabled',
    (tester) async {
      final gate = Completer<void>();
      final plans = _Plans()..gate = gate;
      var changes = 0, careOpens = 0;
      await open(
        tester,
        plans,
        InMemoryCareMemoryRepository(),
        onChanged: () => changes++,
        onOpenCare: () => careOpens++,
      );
      await tester.enterText(find.byType(TextField), 'Fictional durable words');
      await tap(tester, 'Save my plan');
      await tester.pump(const Duration(milliseconds: 50));
      expect(changes, 0);
      expect(plans.active, isNull);
      expect(find.text('Saving privately…'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Open ordinary Care'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      expect(find.byType(RecordPreparationScreen), findsOneWidget);
      expect(careOpens, 0);
      gate.complete();
      await tester.pumpAndSettle();
      expect(changes, 1);
      expect(plans.active!.personalText, 'Fictional durable words');
      expect(
        find.text('Preparation plan saved privately on this device.'),
        findsOneWidget,
      );
    },
  );
}

final class _Plans implements PreparationRepository {
  _Plans([this.active]);
  PreparationPlan? active;
  bool fail = false;
  int writes = 0;
  Completer<void>? gate;
  @override
  Future<PreparationPlan?> getActivePlan() async => active;
  @override
  Future<void> savePlan(PreparationPlan plan) async {
    writes++;
    await gate?.future;
    if (fail) throw StateError('Synthetic storage failure');
    active = plan;
  }

  @override
  Future<void> removeActivePlan() async => active = null;
  @override
  Future<List<PreparationDismissal>> getDismissals() async => [];
  @override
  Future<void> dismiss(PreparationDismissal dismissal) async {}
  @override
  Future<void> restoreDismissal(String fingerprint) async {}
}
