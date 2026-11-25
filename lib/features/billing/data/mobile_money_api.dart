import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/mobile_money_product.dart';

class MobileMoneyException implements Exception {
  const MobileMoneyException(this.message, {this.unauthorized = false});

  final String message;
  final bool unauthorized;

  @override
  String toString() => message;
}

class MobileMoneyCheckoutRequest {
  const MobileMoneyCheckoutRequest({
    required this.token,
    required this.url,
    required this.productId,
    required this.amount,
  });

  final String token;
  final Uri url;
  final String productId;
  final int amount;
}

class MobileMoneyApi {
  MobileMoneyApi({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  String get _root => baseUrl.replaceAll(RegExp(r'/+$'), '');

  Uri get returnUrl => Uri.parse('$_root/v1/payments/moneyfusion/return');

  Uri get creationUrl => Uri.parse('$_root/v1/payments/moneyfusion');

  Future<List<MobileMoneyProduct>> fetchProducts() async {
    if (_root.isEmpty) {
      throw const MobileMoneyException('Paiement indisponible.');
    }
    final response = await _send(
      () => _client.get(
        Uri.parse('$_root/v1/payments/moneyfusion/products'),
        headers: const {'Accept': 'application/json'},
      ),
    );
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw MobileMoneyException(_failureMessage(body, response.statusCode));
    }
    final raw = body['products'];
    if (raw is! List) {
      throw const MobileMoneyException('Réponse de paiement invalide.');
    }
    final products = <MobileMoneyProduct>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final product = MobileMoneyProduct.tryParse(
        Map<String, Object?>.from(item),
      );
      if (product != null) products.add(product);
    }
    return List<MobileMoneyProduct>.unmodifiable(products);
  }

  Future<MobileMoneyCheckoutRequest> createPayment({
    required String accessToken,
    required String productId,
    required String phone,
    required String name,
  }) async {
    if (_root.isEmpty) {
      throw const MobileMoneyException('Paiement indisponible.');
    }
    final response = await _send(
      () => _client.post(
        creationUrl,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'productId': productId,
          'numeroSend': phone,
          'nomclient': name,
        }),
      ),
    );
    final body = _decode(response);
    if (response.statusCode == 401) {
      throw const MobileMoneyException(
        'Session expirée. Reconnectez-vous.',
        unauthorized: true,
      );
    }
    if (response.statusCode != 200) {
      throw MobileMoneyException(_failureMessage(body, response.statusCode));
    }
    final token = body['token'];
    final rawUrl = body['url'];
    final url = rawUrl is String ? Uri.tryParse(rawUrl) : null;
    final amount = body['amount'];
    if (token is! String || token.isEmpty || url == null || !url.hasScheme) {
      throw const MobileMoneyException('Réponse de paiement invalide.');
    }
    return MobileMoneyCheckoutRequest(
      token: token,
      url: url,
      productId: body['productId'] is String
          ? body['productId'] as String
          : productId,
      amount: amount is int ? amount : 0,
    );
  }

  String _failureMessage(Map<String, dynamic> body, int statusCode) {
    final detail = body['detail'];
    if (detail is String && detail.isNotEmpty) return detail;
    return 'Paiement indisponible ($statusCode).';
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(timeout);
    } on TimeoutException {
      throw const MobileMoneyException('Le serveur ne répond pas. Réessayez.');
    } on http.ClientException {
      throw const MobileMoneyException(
        'Paiement indisponible. Vérifiez votre réseau.',
      );
    } on MobileMoneyException {
      rethrow;
    } on Exception {
      throw const MobileMoneyException(
        'Paiement indisponible. Vérifiez votre réseau.',
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
