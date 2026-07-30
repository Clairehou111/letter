/// Auth state for the app (spec: 2026-07-28-auth-subscription-entitlement).
///
/// Local features work in every state. Authentication is required only for
/// explicitly selected server capabilities.
library;

enum AuthStatus {
  /// Not signed in. All local features work.
  anonymous,

  /// Signed in with Supabase Auth. Server capabilities available.
  authenticated,

  /// Previously authenticated but the session expired. Local features work;
  /// server operations will prompt re-auth.
  expired,
}

/// Auth state carried through the app. No health data ever in this object.
final class AuthState {
  const AuthState({
    required this.status,
    this.userId,
    this.email,
  });

  final AuthStatus status;
  final String? userId;
  final String? email;

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

/// Contract for authentication. The real implementation uses Supabase Auth;
/// the dev adapter simulates local-only flow.
abstract interface class AuthService {
  AuthState get current;

  Stream<AuthState> watch();

  /// Signs in with email+password or magic link. Throws on failure.
  Future<AuthState> signIn({String? email, String? password});

  /// Signs up a new account.
  Future<AuthState> signUp({required String email, required String password});

  /// Signs out. Local data is untouched.
  Future<void> signOut();

  /// Deletes the server account. Explains what remains on-device.
  Future<void> deleteAccount();

  Future<void> dispose();
}
