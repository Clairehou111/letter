import 'package:flutter/foundation.dart';

import '../../cycle/domain/cycle_prediction.dart';
import '../today_cycle_context.dart';

/// One short line, written in the body's voice, shown at the top of Today.
///
/// Rules for this copy:
/// - It never names a condition, syndrome, or diagnosis, and never explains a
///   feeling as a symptom of anything.
/// - It never asks for input, and never asks the person to come back.
/// - Cycle position may decide which line appears. The line itself never
///   asserts a cause for how someone feels.
@immutable
final class BodyLetterLine {
  const BodyLetterLine({required this.stamp, required this.body});

  /// Small line above the letter, e.g. `Day 26`.
  final String stamp;

  /// The letter itself. One or two sentences, never a question.
  final String body;
}

@immutable
final class BodyLetterReply {
  const BodyLetterReply({
    required this.id,
    required this.label,
    required this.reply,
  });

  final String id;
  final String label;

  /// What the app answers, in the body's voice. No follow-up question.
  final String reply;
}

abstract final class BodyLetter {
  /// Chooses the line for the current cycle position.
  static BodyLetterLine forContext(
    TodayCycleContext context, {
    CyclePrediction? prediction,
  }) {
    final day = context.dayNumber;
    switch (context.kind) {
      case TodayCycleKind.noHistory:
        return const BodyLetterLine(
          stamp: 'A letter from your body',
          body:
              'Nothing is logged yet, and nothing has to be. Your body is '
              'already doing all of it without being asked.',
        );
      case TodayCycleKind.periodInProgress:
        return BodyLetterLine(
          stamp: day == null ? 'Bleeding' : 'Day $day of bleeding',
          body:
              'Your body is doing heavy, invisible work today. No one is '
              'applauding, and it is still happening.',
        );
      case TodayCycleKind.betweenPeriods:
        return _betweenPeriods(context, day, prediction ?? context.prediction);
    }
  }

  static BodyLetterLine _betweenPeriods(
    TodayCycleContext context,
    int? day,
    CyclePrediction? prediction,
  ) {
    final daysUntil = _daysUntilNextStart(context, prediction);
    final stamp = day == null ? 'A letter from your body' : 'Day $day';
    if (daysUntil != null && daysUntil <= 5) {
      return BodyLetterLine(
        stamp: stamp,
        body:
            'Some days the volume is turned up on everything. You are not '
            'being dramatic, and you do not owe anyone an explanation.',
      );
    }
    if (daysUntil != null && daysUntil <= 12) {
      return BodyLetterLine(
        stamp: stamp,
        body:
            'Whatever today costs you, it is being spent quietly. It counts '
            'even if nobody sees it.',
      );
    }
    return BodyLetterLine(
      stamp: stamp,
      body:
          'Your body has kept going through every version of you this month. '
          'Nothing more is needed from you right now.',
    );
  }

  static int? _daysUntilNextStart(
    TodayCycleContext context,
    CyclePrediction? prediction,
  ) {
    if (prediction == null) {
      return null;
    }
    return prediction.predictedMensesStart.epochDay - context.today.epochDay;
  }

  /// Low-effort replies. One tap, stored locally, nothing follows.
  static const acknowledgements = <BodyLetterReply>[
    BodyLetterReply(
      id: 'read',
      label: 'read it',
      reply: 'Noted. Nothing else needed today.',
    ),
    BodyLetterReply(
      id: 'true-today',
      label: "that's true today",
      reply: 'Noted. It stays on this device, and it stays true.',
    ),
    BodyLetterReply(
      id: 'worse',
      label: 'worse than that',
      reply: 'Noted, and taken seriously. You do not have to explain it.',
    ),
  ];
}
