import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/cycle/domain/local_date.dart';
import 'package:letter_mobile/features/diary/data/in_memory_diary_repository.dart';
import 'package:letter_mobile/features/diary/presentation/diary_entry_screen.dart';

void main() {
  testWidgets('daily diary removes rating animation when motion is disabled', (
    tester,
  ) async {
    final repository = InMemoryDiaryEntryRepository();

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: DiaryEntryScreen(
            entryRepository: repository,
            enrollmentId: 'enrollment-1',
            experiencedDate: LocalDate.fromDateTime(DateTime.now()),
          ),
        ),
      ),
    );

    final animatedRatings = tester.widgetList<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    expect(animatedRatings, isNotEmpty);
    expect(
      animatedRatings.every((container) => container.duration == Duration.zero),
      isTrue,
    );

    await repository.close();
  });
}
