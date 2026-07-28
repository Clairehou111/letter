final class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day)
    : assert(month >= 1 && month <= 12),
      assert(day >= 1),
      assert(
        day <=
            (month == 2
                ? ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0
                      ? 29
                      : 28)
                : (month == 4 || month == 6 || month == 9 || month == 11)
                ? 30
                : 31),
      );

  factory LocalDate.fromDateTime(DateTime value) {
    return LocalDate(value.year, value.month, value.day);
  }

  factory LocalDate.fromEpochDay(int value) {
    final date = DateTime.fromMillisecondsSinceEpoch(
      value * Duration.millisecondsPerDay,
      isUtc: true,
    );
    return LocalDate(date.year, date.month, date.day);
  }

  final int year;
  final int month;
  final int day;

  int get epochDay =>
      DateTime.utc(year, month, day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  DateTime get asLocalDateTime => DateTime(year, month, day);

  LocalDate addDays(int days) => LocalDate.fromEpochDay(epochDay + days);

  @override
  int compareTo(LocalDate other) => epochDay.compareTo(other.epochDay);

  bool isBefore(LocalDate other) => compareTo(other) < 0;

  bool isAfter(LocalDate other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) {
    return other is LocalDate &&
        year == other.year &&
        month == other.month &&
        day == other.day;
  }

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() {
    final paddedMonth = month.toString().padLeft(2, '0');
    final paddedDay = day.toString().padLeft(2, '0');
    return '$year-$paddedMonth-$paddedDay';
  }
}
