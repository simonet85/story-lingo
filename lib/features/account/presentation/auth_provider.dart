import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_config.dart';
import '../data/auth_api.dart';
import '../data/auth_repository.dart';
import '../data/token_store.dart';
import '../domain/auth_exception.dart';
import '../domain/auth_session.dart';

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => const SecureTokenStore(),
);

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(
    apiBaseUrl: ref.watch(apiBaseUrlProvider),
    supabaseUrl: ref.watch(supabaseUrlProvider),
    supabaseAnonKey: ref.watch(supabaseAnonKeyProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    api: ref.watch(authApiProvider),
    store: ref.watch(tokenStoreProvider),
  );
});

final authModeProvider = Provider<AuthMode>((ref) {
  final api = ref.watch(authApiProvider);
  return api.supabaseEnabled ? AuthMode.supabase : AuthMode.dev;
});

enum AuthStatus { restoring, signedOut, authenticating, signedIn }

class AuthState {
  const AuthState({required this.status, this.session, this.error});

  final AuthStatus status;
  final AuthSession? session;
  final String? error;

  bool get isSignedIn => status == AuthStatus.signedIn && session != null;

  bool get isBusy =>
      status == AuthStatus.restoring || status == AuthStatus.authenticating;
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future<void>.microtask(_restore);
    return const AuthState(status: AuthStatus.restoring);
  }

  Future<void> _restore() async {
    AuthSession? session;
    try {
      session = await ref.read(authRepositoryProvider).restore();
    } on Exception {
      session = null;
    }
    if (!ref.mounted) return;
    state = session != null
        ? AuthState(status: AuthStatus.signedIn, session: session)
        : const AuthState(status: AuthStatus.signedOut);
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = AuthState(
      status: AuthStatus.authenticating,
      session: state.session,
    );
    try {
      final session = await ref.read(authRepositoryProvider).signIn(
        email: email,
        password: password,
      );
      state = AuthState(status: AuthStatus.signedIn, session: session);
      return true;
    } on AuthException catch (error) {
      state = AuthState(status: AuthStatus.signedOut, error: error.message);
      return false;
    } on Exception {
      state = const AuthState(
        status: AuthStatus.signedOut,
        error: 'Connexion impossible. Réessayez.',
      );
      return false;
    }
  }

  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  }) async {
    state = AuthState(
      status: AuthStatus.authenticating,
      session: state.session,
    );
    try {
      final outcome = await ref.read(authRepositoryProvider).signUp(
        email: email,
        password: password,
      );
      final session = outcome.session;
      state = session != null
          ? AuthState(status: AuthStatus.signedIn, session: session)
          : AuthState(status: AuthStatus.signedOut, error: outcome.message);
      return outcome;
    } on AuthException catch (error) {
      state = AuthState(status: AuthStatus.signedOut, error: error.message);
      return SignUpOutcome(message: error.message);
    } on Exception {
      const message = 'Inscription impossible. Réessayez.';
      state = const AuthState(status: AuthStatus.signedOut, error: message);
      return const SignUpOutcome(message: message);
    }
  }

  Future<AuthSession?> ensureSession() async {
    final current = state.session;
    if (current == null) return null;
    if (!current.needsRefresh(DateTime.now())) return current;
    try {
      final refreshed = await ref.read(authRepositoryProvider).refresh(current);
      state = AuthState(status: AuthStatus.signedIn, session: refreshed);
      return refreshed;
    } on AuthException catch (error) {
      await ref.read(authRepositoryProvider).signOut();
      state = AuthState(status: AuthStatus.signedOut, error: error.message);
      return null;
    }
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AuthState(status: AuthStatus.signedOut);
  }
}
