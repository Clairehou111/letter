import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:integration_test/integration_test_driver_extended.dart';
import 'package:path/path.dart' as path;

/// Host persistence for real native IntegrationTest captureScreenshot bytes.
/// Runs for passing and failing acceptance results and never copies the DB.
Future<void> main() async {
  final output = Directory('validation/ui-pilot-2026-10-10/v5/screenshots');
  await output.create(recursive: true);
  final captured = <Map<String, Object>>[];
  final motion = _NativeMotion(output);
  await motion.listen();
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
      await motion.close();
      await File(path.join(output.path, 'manifest.json')).writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'fixture': 'entirely synthetic',
          'sourceBaseline': data?['sourceBaseline'],
          'reviewDevice': data?['reviewDevice'],
          'expectedScreenshotCount': data?['expectedScreenshotCount'],
          'productionFingerprint': data?['productionFingerprint'],
          'plannedStates': data?['plannedStates'],
          'pinnedOrderAndZeroVerified':
              data?['pinnedOrderAndZeroVerified'] ?? false,
          'zeroRemovalUndoImpactVerified':
              data?['zeroRemovalUndoImpactVerified'] ?? false,
          'exactTodayReturnVerified':
              data?['exactTodayReturnVerified'] ?? false,
          'ordinaryRecordScrollVerified':
              data?['ordinaryRecordScrollVerified'] ?? false,
          'recordScrollOffset': data?['recordScrollOffset'],
          'revision': data?['revision'],
          'entryRoute': data?['entryRoute'],
          'motionEvidence': motion.metadata,
          'durableReopenVerified': data?['durableReopenVerified'] ?? false,
          'bleedingOpeningCancellationVerified':
              data?['bleedingOpeningCancellationVerified'] ?? false,
          'databaseSchemaVersion': data?['databaseSchemaVersion'],
          'expectedDatabaseSchemaVersion':
              data?['expectedDatabaseSchemaVersion'],
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
      if (data?['durableReopenVerified'] == true && !motion.verified) {
        throw StateError(
          'The native UI motion clip was not recorded and finalized.',
        );
      }
      if (captured.length != data?['nativeScreenshotCount']) {
        throw StateError('Host PNG count differs from the native manifest.');
      }
    },
  );
}

/// The simulator executes the actual fixture taps while this bounded clip runs.
/// A loopback handshake brackets Record only; it makes no timing/refresh claims.
final class _NativeMotion {
  _NativeMotion(this.output);
  final Directory output;
  static const device = '7A533533-EA45-4735-AC28-10FA095A65FF';
  HttpServer? _server;
  Process? _recorder;
  DateTime? _startedAt;
  DateTime? _stoppedAt;
  int? _exitCode;
  String? _error;
  bool verified = false;
  String get clip =>
      path.join(output.path, 'ios-symptom-shortcut-interactions.mov');
  Map<String, Object?> get metadata => {
    'file': path.basename(clip),
    'device': device,
    'source': 'xcrun simctl io recordVideo during actual native fixture taps',
    'scope':
        'Today pinned symptom/full-page save, removal, Undo, impact, normal Record return, and Bleeding entry',
    'verified': verified,
    'startedAt': _startedAt?.toUtc().toIso8601String(),
    'stoppedAt': _stoppedAt?.toUtc().toIso8601String(),
    'wallDurationMilliseconds': _startedAt == null || _stoppedAt == null
        ? null
        : _stoppedAt!.difference(_startedAt!).inMilliseconds,
    'exitCode': _exitCode,
    if (_error != null) 'error': _error,
  };
  Future<void> listen() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 54327);
    _server!.listen((request) async {
      try {
        switch (request.uri.path) {
          case '/start':
            await _start();
          case '/stop':
            await _stop();
          default:
            throw StateError('Unknown native motion command.');
        }
        request.response.statusCode = HttpStatus.ok;
      } catch (error) {
        _error = error.toString();
        request.response.statusCode = HttpStatus.internalServerError;
      } finally {
        await request.response.close();
      }
    });
  }

  Future<void> _start() async {
    if (_recorder != null) {
      throw StateError('Native recording already started.');
    }
    final file = File(clip);
    if (await file.exists()) await file.delete();
    final started = Completer<void>();
    _recorder = await Process.start('/usr/bin/xcrun', [
      'simctl',
      'io',
      device,
      'recordVideo',
      '--codec=h264',
      clip,
    ]);
    _recorder!.stdout.drain<void>();
    _recorder!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (line.contains('Recording started') && !started.isCompleted) {
            _startedAt = DateTime.now();
            started.complete();
          }
        });
    unawaited(
      _recorder!.exitCode.then((code) {
        if (!started.isCompleted) {
          started.completeError(
            StateError(
              'Native recorder exited before recording started ($code).',
            ),
          );
        }
      }),
    );
    await started.future.timeout(const Duration(seconds: 10));
  }

  Future<void> _stop() async {
    final recorder = _recorder;
    if (recorder == null || _stoppedAt != null) return;
    recorder.kill(ProcessSignal.sigint);
    _exitCode = await recorder.exitCode.timeout(const Duration(seconds: 10));
    _stoppedAt = DateTime.now();
    final file = File(clip);
    verified =
        _exitCode == 0 &&
        _startedAt != null &&
        await file.exists() &&
        await file.length() > 1024;
    if (!verified) {
      throw StateError('Actual native recording did not finalize.');
    }
  }

  Future<void> close() async {
    try {
      await _stop();
    } catch (error) {
      _error = error.toString();
    }
    await _server?.close(force: true);
  }
}
