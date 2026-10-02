import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/auth/data/supabase_auth_service.dart';
import 'package:letter_mobile/features/auth/domain/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'ownership marker read failure keeps local health data closed',
    () async {
      const channel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method != 'read') return null;
            final arguments = call.arguments as Map<Object?, Object?>;
            final key = arguments['key'];
            if (key == 'letter.auth.prior-sign-in') return 'true';
            if (key == 'letter.auth.prior-user-id') {
              throw PlatformException(code: 'storage_unavailable');
            }
            return null;
          });

      final client = supabase.SupabaseClient(
        'https://letter-within.test',
        'test-anon-key',
      );
      final service = SupabaseAuthService(
        client: client,
        redirectUrl: 'app.letterwithin://auth-callback',
      );
      addTearDown(() async {
        await service.dispose();
        await client.dispose();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final state = await service.initialize();

      expect(state.status, AuthStatus.signedOut);
      expect(state.canOpenLocalData, isFalse);
    },
  );

  test(
    'replacement account requires an explicit local-record connection',
    () async {
      const channel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      final stored = <String, String>{
        'letter.auth.account-deleted': 'true',
        'letter.auth.prior-user-id': 'old-account',
        'letter.auth.prior-sign-in': 'true',
      };
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final arguments = call.arguments as Map<Object?, Object?>;
            final key = arguments['key'] as String;
            if (call.method == 'read') return stored[key];
            if (call.method == 'write') {
              stored[key] = arguments['value'] as String;
            } else if (call.method == 'delete') {
              stored.remove(key);
            }
            return null;
          });
      final client = supabase.SupabaseClient(
        'https://letter-within.test',
        'test-anon-key',
      );
      final service = SupabaseAuthService(
        client: client,
        redirectUrl: 'app.letterwithin://auth-callback',
      );
      addTearDown(() async {
        await service.dispose();
        await client.dispose();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      expect((await service.initialize()).hasDeletedServerAccount, isTrue);
      await client.auth.recoverSession(
        jsonEncode({
          'access_token': 'new-session-token',
          'token_type': 'bearer',
          'user': {'id': 'new-account'},
        }),
      );
      expect((await service.initialize()).hasDeletedServerAccount, isTrue);
      expect(stored['letter.auth.prior-user-id'], 'old-account');

      await service.beginAccountConnectionAfterDeletion();
      await client.auth.recoverSession(
        jsonEncode({
          'access_token': 'replacement-session-token',
          'token_type': 'bearer',
          'user': {'id': 'new-account'},
        }),
      );
      expect((await service.initialize()).status, AuthStatus.authenticated);
      expect(stored['letter.auth.prior-user-id'], 'new-account');
      expect(stored.containsKey('letter.auth.account-deleted'), isFalse);
    },
  );

  test('cancel during binding keeps the previous local-record owner', () async {
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    final stored = <String, String>{
      'letter.auth.account-deleted': 'true',
      'letter.auth.prior-user-id': 'old-account',
      'letter.auth.prior-sign-in': 'true',
    };
    final ownerWriteStarted = Completer<void>();
    final releaseOwnerWrite = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final arguments = call.arguments as Map<Object?, Object?>;
          final key = arguments['key'] as String;
          if (call.method == 'read') return stored[key];
          if (call.method == 'write') {
            final value = arguments['value'] as String;
            if (key == 'letter.auth.prior-user-id' && value == 'new-account') {
              ownerWriteStarted.complete();
              await releaseOwnerWrite.future;
            }
            stored[key] = value;
          } else if (call.method == 'delete') {
            stored.remove(key);
          }
          return null;
        });
    final client = supabase.SupabaseClient(
      'https://letter-within.test',
      'test-anon-key',
    );
    final service = SupabaseAuthService(
      client: client,
      redirectUrl: 'app.letterwithin://auth-callback',
    );
    addTearDown(() async {
      await service.dispose();
      await client.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    expect((await service.initialize()).hasDeletedServerAccount, isTrue);
    await service.beginAccountConnectionAfterDeletion();
    await client.auth.recoverSession(
      jsonEncode({
        'access_token': 'new-session-token',
        'token_type': 'bearer',
        'user': {'id': 'new-account'},
      }),
    );
    await ownerWriteStarted.future;
    await service.cancelAccountConnectionAfterDeletion();
    releaseOwnerWrite.complete();
    expect((await service.initialize()).hasDeletedServerAccount, isTrue);
    expect(stored['letter.auth.prior-user-id'], 'old-account');
    expect(stored['letter.auth.account-deleted'], 'true');
  });
}
