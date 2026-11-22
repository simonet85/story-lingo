import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/auth_exception.dart';
import '../domain/auth_session.dart';

class SignUpOutcome {
  const SignUpOutcome({this.session, this.message});

  final AuthSession? session;
  final String? message;
}

class AuthApi {
  AuthApi({
    required this.apiBaseUrl,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client();

  final String apiBaseUrl;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final Duration timeout;
  final http.Client _client;

  bool get supabaseEnabled =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  bool get devEnabled => apiBaseUrl.isNotEmpty;

  Future<AuthSession> devLogin(String email) async {
    if (!devEnabled) {
      throw const AuthException('API non configurée (API_BASE_URL).');
    }
    final response = await _post(
      '$_apiRoot/v1/auth/dev/login',
      body: {'email': email.trim()},
    );
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw AuthException(
        _errorMessage(body, 'Connexion impossible. Réessayez.'),
      );
    }
    final token = body['accessToken'];
    final user = body['user'];
    if (token is! String || token.isEmpty || user is! Map) {
      throw const AuthException('Réponse d’authentification invalide.');
    }
    final userId = user['id'];
    final userEmail = user['email'];
    if (userId is! String || userId.isEmpty) {
      throw const AuthException('Réponse d’authentification invalide.');
    }
    final expiresIn = body['expiresIn'] is num
        ? (body['expiresIn'] as num).toInt()
        : 24 * 60 * 60;
    return AuthSession(
      userId: userId,
      email: userEmail is String ? userEmail : null,
      mode: AuthMode.dev,
      accessToken: token,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

  Future<AuthSession> supabaseSignIn({
    required String email,
    required String password,
  }) async {
    if (!supabaseEnabled) {
      throw const AuthException('Supabase n’est pas configuré.');
    }
    final response = await _post(
      '$supabaseUrl/auth/v1/token?grant_type=password',
      body: {'email': email.trim(), 'password': password},
      headers: {'apikey': supabaseAnonKey},
    );
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw AuthException(
        _errorMessage(body, 'Identifiants incorrects.'),
      );
    }
    return _supabaseSession(body);
  }

  Future<SignUpOutcome> supabaseSignUp({
    required String email,
    required String password,
  }) async {
    if (!supabaseEnabled) {
      throw const AuthException('Supabase n’est pas configuré.');
    }
    final response = await _post(
      '$supabaseUrl/auth/v1/signup',
      body: {'email': email.trim(), 'password': password},
      headers: {'apikey': supabaseAnonKey},
    );
    final body = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        _errorMessage(body, 'Inscription impossible. Réessayez.'),
      );
    }
    final token = body['access_token'];
    if (token is! String || token.isEmpty) {
      return const SignUpOutcome(
        message:
            'Compte créé. Vérifiez votre email pour confirmer, puis '
            'connectez-vous.',
      );
    }
    return SignUpOutcome(session: _supabaseSession(body));
  }

  Future<AuthSession> refresh(AuthSession session) async {
    final refreshToken = session.refreshToken;
    if (!supabaseEnabled || refreshToken == null) {
      throw const AuthException('Session expirée. Reconnectez-vous.');
    }
    final response = await _post(
      '$supabaseUrl/auth/v1/token?grant_type=refresh_token',
      body: {'refresh_token': refreshToken},
      headers: {'apikey': supabaseAnonKey},
    );
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw const AuthException('Session expirée. Reconnectez-vous.');
    }
    return _supabaseSession(body);
  }

  String get _apiRoot => apiBaseUrl.replaceAll(RegExp(r'/+$'), '');

  AuthSession _supabaseSession(Map<String, dynamic> body) {
    final token = body['access_token'];
    final user = body['user'];
    if (token is! String || token.isEmpty) {
      throw const AuthException('Réponse d’authentification invalide.');
    }
    final userId = user is Map ? user['id'] : null;
    if (userId is! String || userId.isEmpty) {
      throw const AuthException('Réponse d’authentification invalide.');
    }
    final email = user is Map ? user['email'] : null;
    final refreshToken = body['refresh_token'];
    final expiresIn = body['expires_in'] is num
        ? (body['expires_in'] as num).toInt()
        : 3600;
    return AuthSession(
      userId: userId,
      email: email is String && email.isNotEmpty ? email : null,
      mode: AuthMode.supabase,
      accessToken: token,
      refreshToken:
          refreshToken is String && refreshToken.isNotEmpty
              ? refreshToken
              : null,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

  Future<http.Response> _post(
    String url, {
    required Map<String, Object?> body,
    Map<String, String> headers = const {},
  }) async {
    try {
      return await _client
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json', ...headers},
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const AuthException('Le serveur ne répond pas. Réessayez.');
    } on http.ClientException {
      throw const AuthException(
        'Connexion impossible. Vérifiez votre réseau.',
      );
    } on Exception {
      throw const AuthException(
        'Connexion impossible. Vérifiez votre réseau.',
      );
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final value = jsonDecode(utf8.decode(response.bodyBytes));
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
    } on FormatException {
      return const {};
    }
    return const {};
  }

  String _errorMessage(Map<String, dynamic> body, String fallback) {
    for (final key in const ['error_description', 'msg', 'message', 'detail']) {
      final value = body[key];
      if (value is String && value.isNotEmpty) {
        if (value == 'Invalid login credentials') {
          return 'Identifiants incorrects.';
        }
        return value;
      }
    }
    return fallback;
  }
}
