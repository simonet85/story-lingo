import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/billing_entitlement.dart';

class EntitlementsException implements Exception {
  const EntitlementsException(this.message, {this.unauthorized = false});

  final String message;
  final bool unauthorized;

  @override
  String toString() => message;
}

class EntitlementsApi {
  EntitlementsApi({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  String get _root => baseUrl.replaceAll(RegExp(r'/+$'), '');

  Future<BillingEntitlement> fetch({required String token}) async {
    if (_root.isEmpty) {
      throw const EntitlementsException('Service indisponible.');
    }
    final response = await _send(
      () => _client.get(
        Uri.parse('$_root/v1/entitlements'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ),
    );
    final body = _decode(response);
    if (response.statusCode == 401) {
      throw const EntitlementsException(
        'Session expirée. Reconnectez-vous.',
        unauthorized: true,
      );
    }
    if (response.statusCode != 200) {
      final detail = body['detail'];
      throw EntitlementsException(
        detail is String && detail.isNotEmpty
            ? detail
            : 'Abonnement indisponible (${response.statusCode}).',
      );
    }
    if (body['active'] is! bool) {
      throw const EntitlementsException('Réponse d’abonnement invalide.');
    }
    return BillingEntitlement.fromJson(body);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(timeout);
    } on TimeoutException {
      throw const EntitlementsException('Le serveur ne répond pas. Réessayez.');
    } on http.ClientException {
      throw const EntitlementsException(
        'Abonnement indisponible. Vérifiez votre réseau.',
      );
    } on EntitlementsException {
      rethrow;
    } on Exception {
      throw const EntitlementsException(
        'Abonnement indisponible. Vérifiez votre réseau.',
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
}
