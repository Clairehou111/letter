import 'cycle_care_summary.dart';

abstract interface class SummaryExportRepository {
  Future<SummaryExportInput> load();
}

final class InMemorySummaryExportRepository implements SummaryExportRepository {
  const InMemorySummaryExportRepository(this.input);

  final SummaryExportInput input;

  @override
  Future<SummaryExportInput> load() async => input;
}
