import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/capture/data/drift_capture_note_store.dart';
import 'package:letter_mobile/features/capture/domain/capture_models.dart';
import 'package:letter_mobile/features/cycle/data/letter_health_database.dart';

void main() {
  test('Drift persists text capture notes and deletes by stable id', () async {
    final database = LetterHealthDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = DriftCaptureNoteStore(database, closeDatabase: false);
    final note = CaptureNote(
      id: 'note-1',
      text: 'I need a dark and quiet room.',
      source: CaptureSource.typed,
      createdAt: DateTime.utc(2026, 7, 28, 14),
    );

    await store.save(note);

    final loaded = (await store.getAll()).single;
    expect(loaded.id, 'note-1');
    expect(loaded.text, 'I need a dark and quiet room.');
    expect(loaded.source, CaptureSource.typed);
    expect(loaded.createdAt, DateTime.utc(2026, 7, 28, 14));

    await store.delete(loaded);
    expect(await store.getAll(), isEmpty);
  });
}
