import '../../cycle/domain/local_date.dart';

/// Calendar geometry uses calendar dates, never elapsed local-time hours.
final class RecordCalendarMonth {
  const RecordCalendarMonth(this.year, this.month)
    : assert(year >= 1 && year <= 9999),
      assert(month >= 1 && month <= 12);

  factory RecordCalendarMonth.of(LocalDate date) =>
      RecordCalendarMonth(date.year, date.month);

  final int year;
  final int month;

  LocalDate get firstDay => LocalDate(year, month, 1);

  int get daysInMonth => DateTime.utc(year, month + 1, 0).day;

  LocalDate get lastDay => LocalDate(year, month, daysInMonth);

  RecordCalendarMonth shift(int months) {
    final index = (year - 1) * 12 + month - 1 + months;
    if (index < 0 || index >= 9999 * 12) {
      throw RangeError('Calendar month is outside the supported years.');
    }
    return RecordCalendarMonth(index ~/ 12 + 1, index % 12 + 1);
  }

  /// [firstDayOfWeek] follows MaterialLocalizations: Sunday is zero.
  List<LocalDate?> cells({int firstDayOfWeek = 0}) {
    if (firstDayOfWeek < 0 || firstDayOfWeek > 6) {
      throw RangeError.range(firstDayOfWeek, 0, 6, 'firstDayOfWeek');
    }
    final leading = (firstDay.asLocalDateTime.weekday % 7 - firstDayOfWeek) % 7;
    final length = ((leading + daysInMonth + 6) ~/ 7) * 7;
    return List<LocalDate?>.unmodifiable([
      for (var index = 0; index < length; index++)
        index < leading || index >= leading + daysInMonth
            ? null
            : LocalDate(year, month, index - leading + 1),
    ]);
  }

  bool intersects({
    required LocalDate firstDate,
    required LocalDate lastDate,
  }) => !lastDay.isBefore(firstDate) && !firstDay.isAfter(lastDate);
}
