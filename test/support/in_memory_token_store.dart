import 'package:storylingo/features/account/data/token_store.dart';
import 'package:storylingo/features/account/domain/auth_session.dart';

class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore([this.session]);

  AuthSession? session;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> write(AuthSession session) async {
    this.session = session;
  }

  @override
  Future<void> clear() async {
    session = null;
  }
}
