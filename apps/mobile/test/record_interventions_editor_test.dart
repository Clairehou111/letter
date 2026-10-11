import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/components/record_option_scale.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/health_records/domain/health_record.dart';
import 'package:letter_mobile/features/record_hub/domain/record_hub_facts.dart';
import 'package:letter_mobile/features/record_hub/domain/record_interventions.dart';
import 'package:letter_mobile/features/record_hub/presentation/record_interventions_editor.dart';

const _date = LocalDate(2026, 10, 8);

void main() {
  Future<void> open(
    WidgetTester tester,
    Widget editor, {
    TargetPlatform? platform,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ExperienceFoundation.lightTheme().copyWith(platform: platform),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<bool>(builder: (_) => editor)),
              child: const Text('Origin Record'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Origin Record'));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(text).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pump();
  }

  DateTime clock() => DateTime(2026, 10, 8, 12);

  testWidgets(
    'episode saves exact optional values only after durable success; no use',
    (tester) async {
      final repository = _Repository();
      var changes = 0;
      await open(
        tester,
        RecordProductEditor(
          date: _date,
          family: ProductFamily.medication,
          repository: repository,
          clock: clock,
          onChanged: () => changes++,
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Exact product name'),
        '  Fictional medicine  ',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Dose (optional)'),
        '1/2',
      );
      await tap(tester, 'Save medication');
      final draft = repository.episodeDraft!;
      expect(draft.startDate, _date);
      expect(draft.details.exactName, '  Fictional medicine  ');
      expect(draft.details.dose, '1/2');
      expect(draft.details.unit, isNull);
      expect(draft.details.route, isNull);
      expect(draft.details.target, isNull);
      expect(repository.useCalls, 0);
      expect(changes, 0);
      expect(find.text('Saving on this device…'), findsOneWidget);
      repository.episodeCompletion.complete(_episode(draft));
      await tester.pumpAndSettle();
      expect(changes, 1);
      expect(find.byType(RecordProductEditor), findsNothing);
    },
  );

  testWidgets(
    'action saves an exact bundle with categorical duration and no outcome',
    (tester) async {
      final repository = _Repository();
      await open(
        tester,
        RecordActionEditor(date: _date, repository: repository, clock: clock),
      );
      await tap(tester, 'Meditation');
      await tap(tester, 'Heat/warmth');
      await tap(tester, 'Completed');
      await tap(tester, '30+ min');
      await tester.enterText(
        find.widgetWithText(TextField, 'Target in your words (optional)'),
        '  Fictional target  ',
      );
      await tap(tester, 'Save action');
      final draft = repository.actionDraft!;
      expect(draft.bundle, isTrue);
      expect(draft.actions.map((value) => value.kind), [
        TriedActionKind.meditation,
        TriedActionKind.heat,
      ]);
      expect(draft.target, '  Fictional target  ');
      expect(draft.duration!.bucket, DurationBucket.care30PlusMinutes);
      expect(draft.duration!.exactMinutes, isNull);
      expect(draft.source, TriedActionSource.outsideApp);
      expect(draft.completionToken, isNull);
      expect(repository.outcomeDraft, isNull);
      repository.actionCompletion.complete(
        TriedActionRecord(
          metadata: _metadata('synthetic-action'),
          value: draft,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RecordActionEditor), findsNothing);
    },
  );

  testWidgets(
    'skipping checkback persists no outcome, completing saves one bundle result',
    (tester) async {
      final repository = _Repository();
      final action = TriedActionRecord(
        metadata: _metadata('synthetic-action'),
        value: TriedActionDraft(
          experiencedDate: _date,
          actions: [TriedActionSelection(TriedActionKind.breathing)],
          bundle: false,
          status: TriedActionStatus.completed,
          target: 'Fictional target',
        ),
      );
      await open(
        tester,
        RecordActionCheckbackEditor(
          date: _date,
          repository: repository,
          action: action,
          clock: clock,
        ),
      );
      await tap(tester, 'Skip — keep the action only');
      await tester.pumpAndSettle();
      expect(repository.outcomeDraft, isNull);
      await open(
        tester,
        RecordActionCheckbackEditor(
          date: _date,
          repository: repository,
          action: action,
          clock: clock,
        ),
      );
      await tap(tester, 'Mixed');
      final degree = find.byKey(const Key('record-checkback-degree-0'));
      await tester.ensureVisible(degree);
      await tester.tap(degree);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RecordOptionScale<int>>(find.byType(RecordOptionScale<int>))
            .selected,
        0,
      );
      await tester.tap(degree);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RecordOptionScale<int>>(find.byType(RecordOptionScale<int>))
            .selected,
        isNull,
      );
      await tester.tap(degree);
      await tester.pumpAndSettle();
      await tap(tester, 'Save check-back');
      final draft = repository.outcomeDraft!;
      expect(draft.actionId, action.id);
      expect(draft.outcome, ActionOutcome.mixed);
      expect(draft.targetDegree, 0);
      repository.outcomeCompletion.complete(
        ActionCheckbackRecord(
          metadata: _metadata('synthetic-outcome'),
          value: draft,
        ),
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets('failed product save retains exact name and guards draft exit', (
    tester,
  ) async {
    final repository = _Repository();
    await open(
      tester,
      RecordProductEditor(
        date: _date,
        family: ProductFamily.supplement,
        repository: repository,
        clock: clock,
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Exact product name'),
      'Fictional supplement',
    );
    await tap(tester, 'Save supplement');
    repository.episodeCompletion.completeError(
      const RecordHubException(RecordHubFailure.storageUnavailable),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Your private record could not be saved. Try again.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextField>(
            find.widgetWithText(TextField, 'Exact product name'),
          )
          .controller!
          .text,
      'Fictional supplement',
    );
    await tester.tap(find.byTooltip('Close editor'));
    await tester.pumpAndSettle();
    expect(find.text('Leave without saving?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(RecordProductEditor), findsOneWidget);
  });
  testWidgets('editing a bundle preserves every distinct custom action', (
    tester,
  ) async {
    final repository = _Repository();
    final initial = TriedActionRecord(
      metadata: _metadata('synthetic-custom-bundle'),
      value: TriedActionDraft(
        experiencedDate: _date,
        actions: [
          TriedActionSelection(
            TriedActionKind.other,
            customName: '  Fictional own action A  ',
          ),
          TriedActionSelection(
            TriedActionKind.other,
            customName: 'Fictional own action B',
          ),
        ],
        bundle: true,
        status: TriedActionStatus.completed,
      ),
    );
    await open(
      tester,
      RecordActionEditor(
        date: _date,
        repository: repository,
        initial: initial,
        clock: clock,
      ),
    );
    await tap(tester, 'Save action');
    expect(repository.actionDraft!.actions.map((value) => value.customName), [
      '  Fictional own action A  ',
      'Fictional own action B',
    ]);
    expect(repository.actionDraft!.bundle, isTrue);
    repository.actionCompletion.complete(
      TriedActionRecord(
        metadata: initial.metadata,
        value: repository.actionDraft!,
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets(
    'shared action duration keeps exact minutes and in-app completion source',
    (tester) async {
      final repository = _Repository();
      final initial = TriedActionRecord(
        metadata: _metadata('synthetic-in-app-action'),
        value: TriedActionDraft(
          experiencedDate: _date,
          actions: [TriedActionSelection(TriedActionKind.breathing)],
          bundle: false,
          status: TriedActionStatus.completed,
          source: TriedActionSource.inAppCare,
          completionToken: 'synthetic-completion-token',
          careSourceId: 'synthetic-care-source',
          completionOccurredAt: DateTime.utc(2026, 10, 8, 5, 37),
          completionUtcOffsetMinutes: -240,
          duration: RecordedDuration.exact(37),
        ),
      );
      await open(
        tester,
        RecordActionEditor(
          date: _date,
          repository: repository,
          initial: initial,
          clock: clock,
        ),
      );
      expect(
        tester
            .widget<RecordDurationPicker<DurationBucket>>(
              find.byType(RecordDurationPicker<DurationBucket>),
            )
            .exact,
        isTrue,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('record-action-exact-minutes')),
            )
            .controller!
            .text,
        '37',
      );
      await tap(tester, 'Save action');
      final saved = repository.actionDraft!;
      expect(repository.actionId, initial.id);
      expect(saved.duration!.exactMinutes, 37);
      expect(saved.duration!.bucket, isNull);
      expect(saved.source, initial.value.source);
      expect(saved.completionToken, initial.value.completionToken);
      expect(saved.careSourceId, initial.value.careSourceId);
      expect(saved.completionOccurredAt, initial.value.completionOccurredAt);
      expect(
        saved.completionUtcOffsetMinutes,
        initial.value.completionUtcOffsetMinutes,
      );
      expect(repository.outcomeDraft, isNull);
      repository.actionCompletion.complete(
        TriedActionRecord(metadata: initial.metadata, value: saved),
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'duration exact and category remain separate with explicit clear',
    (tester) async {
      final repository = _Repository();
      await open(
        tester,
        RecordActionEditor(date: _date, repository: repository, clock: clock),
      );
      await tap(tester, 'Rest/lower expectations');
      await tap(tester, 'Completed');
      await tap(tester, 'Enter exact');
      await tester.enterText(
        find.byKey(const Key('record-action-exact-minutes')),
        '37',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final bucket = find.byKey(
        const Key('record-action-duration-care30PlusMinutes'),
      );
      await tester.ensureVisible(bucket);
      await tester.tap(bucket);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('record-action-exact-minutes')),
        findsNothing,
      );
      expect(
        tester
            .widget<RecordDurationPicker<DurationBucket>>(
              find.byType(RecordDurationPicker<DurationBucket>),
            )
            .selected,
        DurationBucket.care30PlusMinutes,
      );
      await tester.tap(bucket);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RecordDurationPicker<DurationBucket>>(
              find.byType(RecordDurationPicker<DurationBucket>),
            )
            .selected,
        isNull,
      );
      await tap(tester, 'Save action');
      expect(repository.actionDraft!.duration, isNull);
      repository.actionCompletion.complete(
        TriedActionRecord(
          metadata: _metadata('synthetic-cleared-duration'),
          value: repository.actionDraft!,
        ),
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'native product date cancellation leaves actual dates untouched',
    (tester) async {
      final repository = _Repository();
      await open(
        tester,
        RecordProductEditor(
          date: _date,
          family: ProductFamily.medication,
          repository: repository,
          clock: clock,
        ),
        platform: TargetPlatform.iOS,
      );
      final startLabel = tester
          .widget<Text>(find.textContaining('Actual start:'))
          .data!;
      await tap(tester, startLabel);
      await tester.pumpAndSettle();
      final wheel = tester.widget<CupertinoDatePicker>(
        find.byType(CupertinoDatePicker),
      );
      expect(wheel.mode, CupertinoDatePickerMode.date);
      expect(wheel.initialDateTime, _date.asLocalDateTime);
      expect(wheel.maximumDate, clock());
      wheel.onDateTimeChanged(DateTime(2026, 10, 7));
      await tester.tap(find.widgetWithText(CupertinoButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text(startLabel), findsOneWidget);
      expect(repository.episodeDraft, isNull);
    },
  );

  for (final editorKind in ['birth-control', 'check-back', 'action']) {
    testWidgets('$editorKind form adapts at 320px with large text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _Repository();
      final action = TriedActionRecord(
        metadata: _metadata('synthetic-action'),
        value: TriedActionDraft(
          experiencedDate: _date,
          actions: [TriedActionSelection(TriedActionKind.breathing)],
          bundle: false,
          status: TriedActionStatus.completed,
          target: 'Synthetic target',
        ),
      );
      final editor = switch (editorKind) {
        'birth-control' => RecordProductEditor(
          date: _date,
          family: ProductFamily.birthControl,
          repository: repository,
          clock: clock,
        ),
        'check-back' => RecordActionCheckbackEditor(
          date: _date,
          repository: repository,
          action: action,
          clock: clock,
        ),
        _ => RecordActionEditor(
          date: _date,
          repository: repository,
          clock: clock,
        ),
      };
      await open(tester, editor, textScale: 2);
      final save = find.widgetWithText(FilledButton, switch (editorKind) {
        'birth-control' => 'Save birth control',
        'check-back' => 'Save check-back',
        _ => 'Save action',
      });
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(save).height, greaterThanOrEqualTo(44));
    });
  }
}

RecordFactMetadata _metadata(String id) => RecordFactMetadata(
  id: id,
  experiencedDate: _date,
  recordedAt: DateTime.utc(2026, 10, 8, 12),
  updatedAt: DateTime.utc(2026, 10, 8, 12),
  originalProvenance: HealthRecordProvenance.sameDay,
  provenance: HealthRecordProvenance.sameDay,
);
ProductEpisode _episode(ProductEpisodeDraft draft) => ProductEpisode(
  metadata: _metadata('synthetic-product'),
  family: draft.details.family,
  startDate: draft.startDate,
  endDate: draft.endDate,
  archived: false,
  versions: [
    ProductVersion(
      metadata: _metadata('synthetic-version'),
      episodeId: 'synthetic-product',
      effectiveFrom: draft.startDate,
      versionNumber: 1,
      details: draft.details,
    ),
  ],
);

class _Repository implements RecordInterventionsRepository {
  ProductEpisodeDraft? episodeDraft;
  TriedActionDraft? actionDraft;
  String? actionId;
  ActionCheckbackDraft? outcomeDraft;
  var useCalls = 0;
  final episodeCompletion = Completer<ProductEpisode>();
  final actionCompletion = Completer<TriedActionRecord>();
  final outcomeCompletion = Completer<ActionCheckbackRecord>();
  @override
  Future<ProductEpisode> createEpisode(ProductEpisodeDraft draft) {
    episodeDraft = draft;
    return episodeCompletion.future;
  }

  @override
  Future<TriedActionRecord> saveAction(TriedActionDraft draft, {String? id}) {
    actionDraft = draft;
    actionId = id;
    return actionCompletion.future;
  }

  @override
  Future<ActionCheckbackRecord> saveCheckback(ActionCheckbackDraft draft) {
    outcomeDraft = draft;
    return outcomeCompletion.future;
  }

  @override
  Future<ProductUseRecord> saveUse(
    ProductUseDraft draft, {
    String? id,
    bool dailyShortcut = true,
  }) {
    useCalls++;
    throw UnimplementedError();
  }

  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
