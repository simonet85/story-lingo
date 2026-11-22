import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/auth_session.dart';

abstract interface class TokenStore {
  Future<AuthSession?> read();

  Future<void> write(AuthSession session);

  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  const SecureTokenStore([this._storage = const FlutterSecureStorage()]);

  static const String _key = 'auth.session.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthSession?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return null;
      return AuthSession.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(AuthSession session) {
    return _storage.write(
      key: _key,
      value: jsonEncode(session.toJson()),
    );
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      // Nothing to clear when the platform store is unavailable.
    }
  }
}
