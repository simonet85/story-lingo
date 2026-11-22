enum AuthMode { dev, supabase }

class AuthSession {
  const AuthSession({
    required this.userId,
    required this.email,
    required this.mode,
    required this.accessToken,
    required this.expiresAt,
    this.refreshToken,
  });

  final String userId;
  final String? email;
  final AuthMode mode;
  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;

  bool needsRefresh(DateTime now) {
    return expiresAt.isBefore(now.add(const Duration(seconds: 60)));
  }

  bool get canRefresh =>
      mode == AuthMode.supabase &&
      refreshToken != null &&
      refreshToken!.isNotEmpty;

  Map<String, Object?> toJson() => {
    'userId': userId,
    'email': email,
    'mode': mode.name,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toIso8601String(),
  };

  static AuthSession? fromJson(Object? source) {
    if (source is! Map) return null;
    final userId = source['userId'];
    final accessToken = source['accessToken'];
    final rawMode = source['mode'];
    final rawExpiry = source['expiresAt'];
    if (userId is! String || userId.isEmpty) return null;
    if (accessToken is! String || accessToken.isEmpty) return null;
    if (rawMode is! String || rawExpiry is! String) return null;
    final mode = AuthMode.values
        .where((value) => value.name == rawMode)
        .firstOrNull;
    if (mode == null) return null;
    final expiresAt = DateTime.tryParse(rawExpiry);
    if (expiresAt == null) return null;
    final email = source['email'];
    final refreshToken = source['refreshToken'];
    return AuthSession(
      userId: userId,
      email: email is String && email.isNotEmpty ? email : null,
      mode: mode,
      accessToken: accessToken,
      refreshToken:
          refreshToken is String && refreshToken.isNotEmpty
              ? refreshToken
              : null,
      expiresAt: expiresAt,
    );
  }
}

String authModeLabel(AuthMode mode) => switch (mode) {
  AuthMode.dev => 'Mode développement',
  AuthMode.supabase => 'Supabase',
};
