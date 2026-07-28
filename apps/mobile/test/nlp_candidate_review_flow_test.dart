import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/nlp/application/nlp_review_controller.dart';
import 'package:letter_mobile/features/nlp/domain/local_nlp_parser.dart';
import 'package:letter_mobile/features/nlp/domain/nlp_candidate.dart';
import 'package:letter_mobile/features/nlp/presentation/nlp_candidate_review_flow.dart';

void main() {
  testWidgets(
    'review flow shows evidence and does not save before confirmation',
    (tester) async {
      const parser = LocalNlpParser();
      final candidate = parser
          .parse(
            'I had moderate cramps today.',
            referenceDate: DateTime(2026, 7, 28),
            source: const NlpSourceReference(
              source: NlpCandidateSource.typedText,
              reference: 'note-1',
            ),
          )
          .candidates
          .single;
      final controller = NlpReviewController([candidate]);
      List<dynamic>? saved;

      await tester.pumpWidget(
        MaterialApp(
          home: NlpCandidateReviewFlow(
            controller: controller,
            fallbackDate: const LocalDate(2026, 7, 28),
            onConfirmed: (drafts) => saved = drafts,
          ),
        ),
      );

      expect(find.text('“I had moderate cramps today”'), findsOneWidget);
      expect(find.text('Clear phrase · Typed text'), findsOneWidget);
      expect(saved, isNull);

      await tester.tap(find.byKey(Key('nlp-accept-${candidate.id}')));
      await tester.pump();
      expect(find.text('Accepted by you'), findsOneWidget);
      expect(saved, isNull);

      await tester.tap(find.byKey(const Key('nlp-confirm-health-records')));
      await tester.pump();
      expect(saved, hasLength(1));
    },
  );
}
