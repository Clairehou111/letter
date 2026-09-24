/// Account state contains identity metadata only. Health records never cross
/// this boundary.
library;

enum AuthStatus {
  /// This installation has not completed its required first sign-in.
  signedOut,

  /// A valid Supabase session is available.
  authenticated,

  /// This installation signed in before, but no usable server session is
  /// currently available. Existing on-device records remain accessible.
  offlineOrExpired,

  /// A different account attempted to open health records already bound to
  /// this installation. The records stay closed until their original account
  /// signs in again.
  localDataAccountMismatch,

  /// The server account was deleted, while records that never left this
  /// installation remain available until the app itself is deleted.
  localOnlyAfterAccountDeletion,
}

final class AuthState {
  const AuthState({required this.status, this.userId, this.email});

  final AuthStatus status;
  final String? userId;
  final String? email;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get canOpenLocalData =>
      status == AuthStatus.authenticated ||
      status == AuthStatus.offlineOrExpired ||
      status == AuthStatus.localOnlyAfterAccountDeletion;
  bool get requiresServerReauthentication =>
      status == AuthStatus.offlineOrExpired;
  bool get hasLocalDataAccountMismatch =>
      status == AuthStatus.localDataAccountMismatch;
  bool get hasDeletedServerAccount =>
      status == AuthStatus.localOnlyAfterAccountDeletion;
}

abstract interface class AuthService {
  AuthState get current;

  Stream<AuthState> watch();

  /// Resolves the persisted Supabase session or the local prior-sign-in marker.
  Future<AuthState> initialize();

  /// Starts Sign in with Apple in the system browser.
  Future<void> signInWithApple();

  /// Sends a magic link. A new account is created when the address is new.
  Future<void> sendMagicLink(String email);

  /// Signs in an existing account with a password. This never creates a new
  /// account; normal customer onboarding continues to use a magic link.
  Future<void> signInWithPassword(String email, String password);

  /// Explicit sign-out closes the local-data gate but never deletes records.
  /// The installation remains bound to this account so another account cannot
  /// read the records left on the device.
  Future<void> signOut();

  /// Deletes the server account through the authenticated server function.
  /// Local records remain available offline on this installation.
  Future<void> deleteAccount();

  Future<void> dispose();
}
