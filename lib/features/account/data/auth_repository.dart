import '../domain/auth_exception.dart';
import '../domain/auth_session.dart';
import 'auth_api.dart';
import 'token_store.dart';

class AuthRepository {
  AuthRepository({required this.api, required this.store});

  final AuthApi api;
  final TokenStore store;

  Future<AuthSession?> restore() async {
    var session = await store.read();
    if (session == null) return null;
    if (!session.needsRefresh(DateTime.now())) return session;
    if (!session.canRefresh) {
      await store.clear();
      return null;
    }
    try {
      session = await api.refresh(session);
      await store.write(session);
      return session;
    } on AuthException {
      await store.clear();
      return null;
    }
  }

  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final session = api.supabaseEnabled
        ? await api.supabaseSignIn(email: email, password: password)
        : await api.devLogin(email);
    await store.write(session);
    return session;
  }

  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  }) async {
    if (!api.supabaseEnabled) {
      throw const AuthException(
        'L’inscription nécessite une configuration Supabase.',
      );
    }
    final outcome = await api.supabaseSignUp(email: email, password: password);
    final session = outcome.session;
    if (session != null) {
      await store.write(session);
    }
    return outcome;
  }

  Future<AuthSession> refresh(AuthSession session) async {
    final refreshed = await api.refresh(session);
    await store.write(refreshed);
    return refreshed;
  }

  Future<void> signOut() => store.clear();
}
