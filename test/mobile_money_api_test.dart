import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:storylingo/features/billing/data/mobile_money_api.dart';
import 'package:storylingo/features/billing/domain/mobile_money_product.dart';

const _base = 'http://10.0.2.2:8000';

void main() {
  test('fetchProducts keeps known products and ignores others', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode({
          'products': [
            {
              'productId': 'storylingo_pro_monthly_xof',
              'amount': 3500,
              'days': 30,
              'currency': 'XOF',
            },
            {
              'productId': 'storylingo_pro_yearly_xof',
              'amount': 30000,
              'days': 365,
              'currency': 'XOF',
            },
            {
              'productId': 'unknown_product',
              'amount': 100,
              'days': 1,
              'currency': 'XOF',
            },
            {'productId': 'storylingo_pro_monthly_xof', 'amount': 'oops'},
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = MobileMoneyApi(baseUrl: '$_base/', client: client);

    final products = await api.fetchProducts();

    expect(
      requests.single.url.toString(),
      '$_base/v1/payments/moneyfusion/products',
    );
    expect(products, hasLength(2));
    expect(products.first.productId, MobileMoneyProduct.monthlyProductId);
    expect(products.first.priceLabel, '3 500 FCFA');
    expect(products.first.periodLabel, '/ mois');
    expect(products.last.priceLabel, '30 000 FCFA');
    expect(products.last.periodLabel, '/ an');
  });

  test('fetchProducts reports the server detail on failure', () async {
    final api = MobileMoneyApi(
      baseUrl: _base,
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'detail': 'Paiement indisponible.'}),
          503,
        ),
      ),
    );

    await expectLater(
      api.fetchProducts(),
      throwsA(
        isA<MobileMoneyException>().having(
          (error) => error.message,
          'message',
          'Paiement indisponible.',
        ),
      ),
    );
  });

  test(
    'createPayment posts the backend contract with a bearer token',
    () async {
      late http.Request captured;
      final api = MobileMoneyApi(
        baseUrl: _base,
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'token': 'demo-1',
              'url': 'http://10.0.2.2:8091/pay/demo-1',
              'productId': 'storylingo_pro_yearly_xof',
              'amount': 30000,
            }),
            200,
          );
        }),
      );

      final checkout = await api.createPayment(
        accessToken: 'jwt',
        productId: 'storylingo_pro_yearly_xof',
        phone: '01010101',
        name: 'John Doe',
      );

      expect(captured.method, 'POST');
      expect(captured.url.toString(), '$_base/v1/payments/moneyfusion');
      final authorization = captured.headers.entries.firstWhere(
        (entry) => entry.key.toLowerCase() == 'authorization',
      );
      expect(authorization.value, 'Bearer jwt');
      expect(jsonDecode(captured.body), {
        'productId': 'storylingo_pro_yearly_xof',
        'numeroSend': '01010101',
        'nomclient': 'John Doe',
      });
      expect(checkout.token, 'demo-1');
      expect(checkout.url.toString(), 'http://10.0.2.2:8091/pay/demo-1');
      expect(checkout.amount, 30000);
      expect(api.returnUrl.toString(), '$_base/v1/payments/moneyfusion/return');
      expect(api.creationUrl.toString(), '$_base/v1/payments/moneyfusion');
    },
  );

  test('a 401 flags the expired session', () async {
    final api = MobileMoneyApi(
      baseUrl: _base,
      client: MockClient(
        (_) async => http.Response(jsonEncode({'detail': 'Unauthorized'}), 401),
      ),
    );

    await expectLater(
      api.createPayment(
        accessToken: 'jwt',
        productId: MobileMoneyProduct.monthlyProductId,
        phone: '01010101',
        name: 'John Doe',
      ),
      throwsA(
        isA<MobileMoneyException>()
            .having((error) => error.unauthorized, 'unauthorized', isTrue)
            .having(
              (error) => error.message,
              'message',
              'Session expirée. Reconnectez-vous.',
            ),
      ),
    );
  });

  test('an incomplete creation payload is rejected', () async {
    final api = MobileMoneyApi(
      baseUrl: _base,
      client: MockClient(
        (_) async =>
            http.Response(jsonEncode({'token': '', 'url': 'nope'}), 200),
      ),
    );

    await expectLater(
      api.createPayment(
        accessToken: 'jwt',
        productId: MobileMoneyProduct.monthlyProductId,
        phone: '01010101',
        name: 'John Doe',
      ),
      throwsA(
        isA<MobileMoneyException>().having(
          (error) => error.message,
          'message',
          'Réponse de paiement invalide.',
        ),
      ),
    );
  });

  test('network failures are reported without technical details', () async {
    final api = MobileMoneyApi(
      baseUrl: _base,
      client: MockClient((_) async => throw http.ClientException('boom')),
    );

    await expectLater(
      api.fetchProducts(),
      throwsA(
        isA<MobileMoneyException>().having(
          (error) => error.message,
          'message',
          'Paiement indisponible. Vérifiez votre réseau.',
        ),
      ),
    );
  });
}
