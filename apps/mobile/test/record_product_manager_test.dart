import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/experience/theme/experience_foundation.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/record_hub/data/drift_record_interventions_repository.dart';
import 'package:letter_mobile/features/record_hub/domain/record_interventions.dart';
import 'package:letter_mobile/features/record_hub/presentation/record_interventions_editor.dart';

const _day = LocalDate(2026, 10, 5);
final _now = DateTime(2026, 10, 10, 12);

Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 25)),
  );
  await tester.pump(const Duration(milliseconds: 240));
}

Future<void> _wait(WidgetTester tester, bool Function() ready) async {
  for (var attempt = 0; attempt < 25 && !ready(); attempt++) {
    await _pump(tester);
  }
  expect(ready(), isTrue);
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  for (var attempt = 0; attempt < 4; attempt++) {
    await tester.ensureVisible(target);
    await _pump(tester);
    if (target.hitTestable().evaluate().isNotEmpty) break;
  }
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await _pump(tester);
}

ProductDetails _details(ProductFamily family, String name, String dose) =>
    ProductDetails(
      family: family,
      exactName: name,
      dose: dose,
      unit: DoseUnit.mg,
      birthControlMethod: family == ProductFamily.birthControl
          ? BirthControlMethod.combinedPill
          : null,
    );

void main() {
  late LetterHealthDatabase database;
  late DriftRecordInterventionsRepository repository;
  setUp(() {
    var next = 0;
    database = LetterHealthDatabase(NativeDatabase.memory());
    repository = DriftRecordInterventionsRepository(
      database,
      clock: () => _now,
      idGenerator: () => 'synthetic-${next++}',
    );
  });
  tearDown(() => database.close());

  Future<ProductEpisode> create(
    WidgetTester tester, {
    ProductFamily family = ProductFamily.medication,
    String name = 'Synthetic medicine',
    String dose = '1/2',
    LocalDate? end,
  }) async => (await tester.runAsync(
    () => repository.createEpisode(
      ProductEpisodeDraft(
        startDate: const LocalDate(2026, 10, 1),
        endDate: end,
        details: _details(family, name, dose),
      ),
    ),
  ))!;

  Future<void> show(
    WidgetTester tester,
    ProductFamily family, {
    LocalDate date = _day,
    double textScale = 1,
    TargetPlatform platform = TargetPlatform.android,
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
        home: RecordInterventionsManager(
          date: date,
          family: family,
          repository: repository,
          clock: () => _now,
        ),
      ),
    );
    await _wait(
      tester,
      () => find.byKey(const Key('product-add')).evaluate().isNotEmpty,
    );
  }

  Future<List<ProductUseRecord>> uses(WidgetTester tester, String id) async =>
      (await tester.runAsync(() => repository.getUses(episodeId: id)))!;
  Future<ProductEpisode> savedProduct(WidgetTester tester, String id) async =>
      (await tester.runAsync(
        () => repository.getEpisodes(includeArchived: true),
      ))!.singleWhere((product) => product.id == id);
  Finder status(ProductEpisode product, ProductUseStatus value) =>
      find.byKey(Key('product-status-${product.id}-${value.name}'));
  Future<void> details(WidgetTester tester, ProductEpisode product) =>
      _tap(tester, find.byKey(Key('product-records-toggle-${product.id}')));

  testWidgets(
    'one expanded product and daily selection use only genuine daily source',
    (tester) async {
      final first = await create(tester, name: 'First synthetic medicine');
      final second = await create(tester, name: 'Second synthetic medicine');
      final additional = (await tester.runAsync(
        () => repository.saveUse(
          ProductUseDraft(
            experiencedDate: _day,
            episodeId: first.id,
            status: ProductUseStatus.taken,
          ),
          dailyShortcut: false,
        ),
      ))!;
      await show(tester, ProductFamily.medication);
      expect(find.text('Add medication'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(status(first, ProductUseStatus.taken))
            .selected,
        isFalse,
      );
      expect(
        status(first, ProductUseStatus.taken).hitTestable(),
        findsOneWidget,
      );
      expect(
        status(second, ProductUseStatus.taken).hitTestable(),
        findsNothing,
      );
      await _tap(tester, status(first, ProductUseStatus.skipped));
      await _wait(
        tester,
        () => tester
            .widget<ChoiceChip>(status(first, ProductUseStatus.skipped))
            .selected,
      );
      final afterFirst = await uses(tester, first.id);
      final daily = afterFirst.singleWhere((use) => use.dailyShortcut);
      expect(
        afterFirst.singleWhere((use) => use.id == additional.id).dailyShortcut,
        isFalse,
      );
      await _tap(tester, status(first, ProductUseStatus.skipped));
      final repeated = await uses(tester, first.id);
      expect(repeated, hasLength(2));
      expect(repeated.singleWhere((use) => use.dailyShortcut).id, daily.id);
      expect(
        repeated.singleWhere((use) => use.dailyShortcut).metadata.recordedAt,
        daily.metadata.recordedAt,
      );
      await _tap(tester, status(first, ProductUseStatus.asNeeded));
      final changed = (await uses(
        tester,
        first.id,
      )).singleWhere((use) => use.dailyShortcut);
      expect(changed.id, daily.id);
      expect(changed.versionId, daily.versionId);
      expect(changed.value.status, ProductUseStatus.asNeeded);
      await _tap(tester, find.byKey(Key('product-row-${second.id}')));
      expect(status(first, ProductUseStatus.taken).hitTestable(), findsNothing);
      expect(
        status(second, ProductUseStatus.taken).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'additional save is explicit, distinct and keeps the daily identity',
    (tester) async {
      final product = await create(tester);
      final original = (await tester.runAsync(
        () => repository.saveUse(
          ProductUseDraft(
            experiencedDate: _day,
            episodeId: product.id,
            status: ProductUseStatus.taken,
          ),
        ),
      ))!;
      await show(tester, ProductFamily.medication);
      await details(tester, product);
      await _tap(tester, find.byKey(Key('product-additional-${product.id}')));
      expect(find.text('Already recorded on this date'), findsOneWidget);
      expect(
        find.text('Taken · Synthetic medicine\n1/2 · mg · Daily entry'),
        findsOneWidget,
      );
      await _tap(tester, find.widgetWithText(ChoiceChip, 'As needed').last);
      expect(await uses(tester, product.id), hasLength(1));
      await _tap(
        tester,
        find.widgetWithText(FilledButton, 'Save additional entry'),
      );
      await _wait(
        tester,
        () => find
            .byKey(const Key('product-add'))
            .hitTestable()
            .evaluate()
            .isNotEmpty,
      );
      final recorded = await uses(tester, product.id);
      expect(recorded, hasLength(2));
      final daily = recorded.singleWhere((use) => use.dailyShortcut);
      expect(daily.id, original.id);
      expect(daily.versionId, original.versionId);
      expect(daily.value.status, original.value.status);
      expect(daily.metadata.updatedAt, original.metadata.updatedAt);
      final extra = recorded.singleWhere((use) => !use.dailyShortcut);
      expect(extra.id, isNot(original.id));
      expect(extra.value.status, ProductUseStatus.asNeeded);
      expect(extra.value.experiencedDate, _day);
      expect(extra.value.episodeId, product.id);
    },
  );

  testWidgets(
    'additional draft cancellation and rapid opening make no extra entry',
    (tester) async {
      final product = await create(tester);
      await show(tester, ProductFamily.medication);
      await details(tester, product);
      final add = find.byKey(Key('product-additional-${product.id}'));
      await tester.ensureVisible(add);
      await _pump(tester);
      await tester.tap(add);
      await tester.tap(add, warnIfMissed: false);
      await _pump(tester);
      expect(find.text('Status of this entry'), findsOneWidget);
      await _tap(tester, find.widgetWithText(ChoiceChip, 'Taken').last);
      await tester.tap(find.byTooltip('Close editor').last);
      await _pump(tester);
      expect(find.text('Leave without saving?'), findsOneWidget);
      await tester.tap(find.text('Discard changes'));
      await _wait(
        tester,
        () => find.text('Status of this entry').evaluate().isEmpty,
      );
      expect(await uses(tester, product.id), isEmpty);
      expect(find.text('Status of this entry'), findsNothing);
    },
  );

  testWidgets(
    'stopped use remains recordable within its actual historical dates',
    (tester) async {
      final product = await create(tester, end: const LocalDate(2026, 10, 7));
      await show(tester, ProductFamily.medication);
      await _tap(tester, status(product, ProductUseStatus.taken));
      final recorded = (await uses(tester, product.id)).single;
      expect(recorded.value.experiencedDate, _day);
      expect(recorded.dailyShortcut, isTrue);
      expect(
        (await savedProduct(tester, product.id)).endDate,
        const LocalDate(2026, 10, 7),
      );
    },
  );

  testWidgets(
    'daily row retains its saved version while a new additional entry uses applicable details',
    (tester) async {
      final product = await create(
        tester,
        name: 'Original daily product',
        dose: '10',
      );
      final daily = (await tester.runAsync(
        () => repository.saveUse(
          ProductUseDraft(
            experiencedDate: _day,
            episodeId: product.id,
            status: ProductUseStatus.taken,
          ),
        ),
      ))!;
      final revised = (await tester.runAsync(
        () => repository.reviseEpisode(
          product.id,
          _details(ProductFamily.medication, 'Updated product details', '12.5'),
          effectiveFrom: _day,
        ),
      ))!;
      expect(revised.versionAt(_day).id, isNot(daily.versionId));
      await show(tester, ProductFamily.medication);
      expect(find.text('Original daily product'), findsOneWidget);
      expect(find.text('10 · mg'), findsOneWidget);
      await _tap(tester, status(product, ProductUseStatus.skipped));
      final changed = (await uses(tester, product.id)).single;
      expect(changed.id, daily.id);
      expect(changed.versionId, daily.versionId);
      await details(tester, product);
      await _tap(tester, find.byKey(Key('product-additional-${product.id}')));
      expect(find.text('Updated product details'), findsOneWidget);
      expect(find.text('12.5 · mg'), findsOneWidget);
      expect(
        find.text('Skipped · Original daily product\n10 · mg · Daily entry'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Close editor').last);
      await _wait(
        tester,
        () => find.text('Status of this entry').evaluate().isEmpty,
      );
      expect((await uses(tester, product.id)).single.id, daily.id);
    },
  );

  testWidgets(
    'end-use correction preserves records and leaves eligible historical entry available',
    (tester) async {
      final product = await create(tester);
      final original = (await tester.runAsync(
        () => repository.saveUse(
          ProductUseDraft(
            experiencedDate: _day,
            episodeId: product.id,
            status: ProductUseStatus.taken,
          ),
        ),
      ))!;
      await show(
        tester,
        ProductFamily.medication,
        platform: TargetPlatform.iOS,
      );
      await _tap(tester, find.byKey(Key('product-manage-${product.id}')));
      await _tap(tester, find.text('End use'));
      await _wait(
        tester,
        () => find.byType(CupertinoDatePicker).evaluate().isNotEmpty,
      );
      tester
          .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
          .onDateTimeChanged(DateTime(2026, 10, 7));
      await tester.tap(find.widgetWithText(CupertinoButton, 'Done'));
      await _wait(
        tester,
        () => find.text('Save end date').evaluate().isNotEmpty,
      );
      await tester.tap(find.text('Save end date'));
      await _pump(tester);
      final saved = await savedProduct(tester, product.id);
      expect(saved.startDate, product.startDate);
      expect(saved.endDate, const LocalDate(2026, 10, 7));
      expect(saved.archived, isFalse);
      final retained = (await uses(tester, product.id)).single;
      expect(retained.id, original.id);
      expect(retained.versionId, original.versionId);
      expect(retained.metadata.updatedAt, original.metadata.updatedAt);
      expect(
        status(product, ProductUseStatus.taken).hitTestable(),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'archive leaves dates and all version snapshots unchanged, with read-only history',
    (tester) async {
      final product = await create(
        tester,
        name: 'Original synthetic name',
        dose: '1/2',
      );
      final oldUse = (await tester.runAsync(
        () => repository.saveUse(
          ProductUseDraft(
            experiencedDate: _day,
            episodeId: product.id,
            status: ProductUseStatus.taken,
          ),
        ),
      ))!;
      final revised = (await tester.runAsync(
        () => repository.reviseEpisode(
          product.id,
          _details(ProductFamily.medication, 'New synthetic name', '0.25'),
          effectiveFrom: const LocalDate(2026, 10, 6),
        ),
      ))!;
      final newUse = (await tester.runAsync(
        () => repository.saveUse(
          ProductUseDraft(
            experiencedDate: const LocalDate(2026, 10, 8),
            episodeId: product.id,
            status: ProductUseStatus.skipped,
          ),
          dailyShortcut: false,
        ),
      ))!;
      await show(tester, ProductFamily.medication);
      expect(find.text('Original synthetic name'), findsOneWidget);
      expect(find.text('1/2 · mg'), findsOneWidget);
      await _tap(tester, find.byKey(Key('product-manage-${product.id}')));
      expect(find.text('Edit details'), findsOneWidget);
      await _tap(tester, find.text('Archive use period'));
      await _wait(
        tester,
        () => find.text('Archive this use period?').evaluate().isNotEmpty,
      );
      expect(
        find.textContaining('actual start and end dates stay unchanged'),
        findsOneWidget,
      );
      await tester.tap(find.text('Archive use period').last);
      await _pump(tester);
      final archived = await savedProduct(tester, product.id);
      expect(archived.archived, isTrue);
      expect(archived.startDate, revised.startDate);
      expect(archived.endDate, isNull);
      expect(
        archived.versions.map((version) => version.id),
        revised.versions.map((version) => version.id),
      );
      final retained = await uses(tester, product.id);
      expect(retained.map((use) => use.id).toSet(), {oldUse.id, newUse.id});
      for (final source in [oldUse, newUse]) {
        final saved = retained.singleWhere((use) => use.id == source.id);
        expect(saved.versionId, source.versionId);
        expect(saved.metadata.updatedAt, source.metadata.updatedAt);
        expect(saved.value.experiencedDate, source.value.experiencedDate);
        expect(saved.dailyShortcut, source.dailyShortcut);
      }
      await _tap(tester, find.byKey(const Key('product-past-toggle')));
      await _tap(tester, find.byKey(Key('product-row-${product.id}')));
      expect(find.textContaining('No end date · Archived'), findsOneWidget);
      expect(find.byKey(Key('product-manage-${product.id}')), findsNothing);
      expect(status(product, ProductUseStatus.taken), findsNothing);
      await details(tester, product);
      expect(find.byKey(Key('product-additional-${product.id}')), findsNothing);
      expect(find.byKey(Key('product-use-${oldUse.id}')), findsOneWidget);
      expect(find.byKey(Key('product-use-${newUse.id}')), findsOneWidget);
      expect(find.text('Taken · Original synthetic name'), findsOneWidget);
      expect(find.text('Skipped · New synthetic name'), findsOneWidget);
      await _tap(
        tester,
        find.descendant(
          of: find.byKey(Key('product-use-${oldUse.id}')),
          matching: find.byTooltip('Delete use record'),
        ),
      );
      await tester.tap(find.text('Cancel').last);
      await _pump(tester);
      expect(await uses(tester, product.id), hasLength(2));
      await _tap(tester, find.byKey(Key('product-versions-${product.id}')));
      for (final version in revised.versions) {
        expect(
          find.byKey(Key('product-version-${version.id}')),
          findsOneWidget,
        );
      }
      await _tap(
        tester,
        find.descendant(
          of: find.byKey(Key('product-use-${oldUse.id}')),
          matching: find.byTooltip('Delete use record'),
        ),
      );
      await tester.tap(find.text('Delete').last);
      await _pump(tester);
      expect((await uses(tester, product.id)).single.id, newUse.id);
      final afterDeletion = await savedProduct(tester, product.id);
      expect(afterDeletion.archived, isTrue);
      expect(afterDeletion.startDate, archived.startDate);
      expect(afterDeletion.endDate, archived.endDate);
      expect(
        afterDeletion.versions.map((version) => version.id),
        archived.versions.map((version) => version.id),
      );
    },
  );

  testWidgets(
    'birth-control emergency remains an additional source and own statuses stay distinct',
    (tester) async {
      final product = await create(tester, family: ProductFamily.birthControl);
      await show(tester, ProductFamily.birthControl);
      expect(status(product, ProductUseStatus.skipped), findsNothing);
      expect(status(product, ProductUseStatus.missed), findsOneWidget);
      await _tap(tester, status(product, ProductUseStatus.emergency));
      final emergency = (await uses(tester, product.id)).single;
      expect(emergency.dailyShortcut, isFalse);
      expect(emergency.value.status, ProductUseStatus.emergency);
      expect(
        tester
            .widget<ChoiceChip>(status(product, ProductUseStatus.emergency))
            .selected,
        isFalse,
      );
      await _tap(tester, status(product, ProductUseStatus.late));
      final recorded = await uses(tester, product.id);
      expect(recorded, hasLength(2));
      expect(
        recorded.singleWhere((use) => use.dailyShortcut).value.status,
        ProductUseStatus.late,
      );
      expect(
        recorded.singleWhere((use) => !use.dailyShortcut).id,
        emergency.id,
      );
    },
  );

  for (final family in ProductFamily.values) {
    testWidgets('${family.name} multiple long-name rows adapt at 320px / 2x', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final product = await create(
        tester,
        family: family,
        name:
            'Synthetic long product name retained completely for accessible history',
        dose: '0.125',
      );
      await create(
        tester,
        family: family,
        name: 'Another synthetic product with an equally detailed name',
        dose: '1/2',
      );
      await show(tester, family, textScale: 2);
      expect(
        find.text(
          'Add ${family == ProductFamily.birthControl ? 'birth control' : family.name}',
        ),
        findsOneWidget,
      );
      await details(tester, product);
      expect(tester.takeException(), isNull);
      await _tap(tester, find.byKey(Key('product-manage-${product.id}')));
      expect(find.text('Archive use period'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
