import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/entitlement/data/local_entitlement_repository.dart';
import 'package:letter_mobile/features/entitlement/domain/entitlement.dart';
import 'package:letter_mobile/features/entitlement/presentation/entitlement_scope.dart';

void main() {
  testWidgets('preview grants Plus capability without pretending to be paid', (
    tester,
  ) async {
    final repository = LocalEntitlementRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      EntitlementScope(
        repository: repository,
        hasPlusPreviewAccess: true,
        child: Builder(
          builder: (context) => Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '${EntitlementScope.canUse(context, LetterCapability.personalPatterns)}:'
              '${EntitlementScope.canUse(context, LetterCapability.clinicianReports)}:'
              '${EntitlementScope.canGenerateReportFiles(context)}:'
              '${EntitlementScope.stateOf(context).hasPremiumAccess}',
            ),
          ),
        ),
      ),
    );

    expect(find.text('true:false:false:false'), findsOneWidget);
  });
}
