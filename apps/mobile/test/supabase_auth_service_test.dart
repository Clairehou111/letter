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
}
