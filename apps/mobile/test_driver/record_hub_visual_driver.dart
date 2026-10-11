import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:integration_test/integration_test_driver_extended.dart';
import 'package:path/path.dart' as path;

/// Host persistence for real native IntegrationTest captureScreenshot bytes.
/// Runs for passing and failing acceptance results and never copies the DB.
Future<void> main() async {
  final output = Directory(
    Platform.environment['RECORD_VISUAL_OUTPUT'] ??
        'validation/record-hub-build17-2026-10-10/screenshots/ios-normal',
  );
  await output.create(recursive: true);
  final captured = <Map<String, Object>>[];
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      if (!RegExp(r'^(ios|android)-[a-z0-9-]+$').hasMatch(name) ||
          bytes.length < 24) {
        return false;
      }
      final png = ByteData.sublistView(Uint8List.fromList(bytes));
      if (png.getUint32(0) != 0x89504e47 || png.getUint32(4) != 0x0d0a1a0a) {
        return false;
      }
      await File(
        path.join(output.path, '$name.png'),
      ).writeAsBytes(bytes, flush: true);
      captured.add({
        'file': '$name.png',
        'pixelWidth': png.getUint32(16),
        'pixelHeight': png.getUint32(20),
      });
      return true;
    },
    writeResponseOnFailure: true,
    responseDataCallback: (data) async {
      await File(path.join(output.path, 'manifest.json')).writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'fixture': 'entirely synthetic',
          'sourceBaseline': data?['sourceBaseline'],
          'databaseSchemaVersion': data?['databaseSchemaVersion'],
          'canvasArgb': data?['canvasArgb'],
          'platform': data?['nativePlatform'],
          'capture':
              'native integration_test captureScreenshot via host driver',
          'renderExceptionCount': data?['renderExceptionCount'],
          'nativeScreenshotCount': captured.length,
          'images': data?['nativeImages'] ?? captured,
        }),
        flush: true,
      );
      if (captured.length != data?['nativeScreenshotCount']) {
        throw StateError('Host PNG count differs from the native manifest.');
      }
    },
  );
}
