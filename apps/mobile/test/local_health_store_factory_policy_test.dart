import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/health_data/data/local_health_store_factory_native.dart';

void main() {
  group('sandbox database-key fallback', () {
    test('is allowed for macOS debug storage', () {
      expect(
        allowsSandboxKeyFallback(
          isMacOS: true,
          isIOS: false,
          isDebug: true,
          environment: const {},
        ),
        isTrue,
      );
    });

    test('is denied for a macOS release build', () {
      expect(
        allowsSandboxKeyFallback(
          isMacOS: true,
          isIOS: false,
          isDebug: false,
          environment: const {},
        ),
        isFalse,
      );
    });

    test('is allowed for an iOS Simulator debug build', () {
      expect(
        allowsSandboxKeyFallback(
          isMacOS: false,
          isIOS: true,
          isDebug: true,
          environment: const {'SIMULATOR_UDID': 'test-simulator'},
        ),
        isTrue,
      );
    });

    test('is denied for an iOS release build', () {
      expect(
        allowsSandboxKeyFallback(
          isMacOS: false,
          isIOS: true,
          isDebug: false,
          environment: const {'SIMULATOR_UDID': 'test-simulator'},
        ),
        isFalse,
      );
    });

    test('is denied for a physical iOS debug build', () {
      expect(
        allowsSandboxKeyFallback(
          isMacOS: false,
          isIOS: true,
          isDebug: true,
          environment: const {},
        ),
        isFalse,
      );
    });

    test('is denied for Android', () {
      expect(
        allowsSandboxKeyFallback(
          isMacOS: false,
          isIOS: false,
          isDebug: true,
          environment: const {'SIMULATOR_UDID': 'not-ios'},
        ),
        isFalse,
      );
    });

    test(
      'creates and reuses a sandbox key when secure storage fails',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'letter-database-key-test-',
        );
        addTearDown(() => directory.delete(recursive: true));

        Future<String?> unavailableRead() =>
            Future<String?>.error(Exception('Keychain unavailable'));
        Future<void> unavailableWrite(String _) =>
            Future<void>.error(Exception('Keychain unavailable'));

        final first = await loadOrCreateDatabaseKey(
          directory: directory,
          readSecureKey: unavailableRead,
          writeSecureKey: unavailableWrite,
          allowSandboxFallback: true,
        );
        final second = await loadOrCreateDatabaseKey(
          directory: directory,
          readSecureKey: unavailableRead,
          writeSecureKey: unavailableWrite,
          allowSandboxFallback: true,
        );

        expect(first, matches(RegExp(r'^[0-9a-f]{64}$')));
        expect(second, first);
        expect(
          File('${directory.path}/letter.health_database.key').existsSync(),
          isTrue,
        );
      },
    );

    test('fails closed when secure storage fails without permission', () async {
      final directory = await Directory.systemTemp.createTemp(
        'letter-database-key-test-',
      );
      addTearDown(() => directory.delete(recursive: true));

      await expectLater(
        loadOrCreateDatabaseKey(
          directory: directory,
          readSecureKey: () =>
              Future<String?>.error(Exception('Keychain unavailable')),
          writeSecureKey: (_) async {},
          allowSandboxFallback: false,
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        File('${directory.path}/letter.health_database.key').existsSync(),
        isFalse,
      );
    });
  });
}
