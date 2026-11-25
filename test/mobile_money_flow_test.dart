import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:storylingo/features/billing/application/mobile_money_flow.dart';
import 'package:storylingo/features/billing/data/mobile_money_api.dart';
import 'package:storylingo/features/billing/domain/mobile_money_product.dart';

const _base = 'http://10.0.2.2:8000';

MobileMoneyApi _api() {
  return MobileMoneyApi(
    baseUrl: _base,
    client: MockClient((request) async {
      if (request.method == 'GET') {
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
            ],
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'token': 'demo-1',
          'url': 'http://10.0.2.2:8091/pay/demo-1',
          'productId': 'storylingo_pro_monthly_xof',
          'amount': 3500,
        }),
        200,
      );
    }),
  );
}

MobileMoneyFlow _flow({
  required Future<void> Function() refresh,
  required bool Function() isEntitled,
  Duration interval = const Duration(milliseconds: 1),
  Duration timeout = const Duration(seconds: 1),
}) {
  return MobileMoneyFlow(
    api: _api(),
    refresh: refresh,
    isEntitled: isEntitled,
    interval: interval,
    confirmationTimeout: timeout,
  );
}

void main() {
  test('loadProduct returns the matching offer', () async {
    final flow = _flow(refresh: () async {}, isEntitled: () => false);

    final monthly = await flow.loadProduct(MobileMoneyProduct.monthlyProductId);
    final missing = await flow.loadProduct('unknown');

    expect(monthly?.amount, 3500);
    expect(monthly?.titleFr, 'Mensuel');
    expect(missing, isNull);
  });

  test('start delegates to the backend creation', () async {
    final flow = _flow(refresh: () async {}, isEntitled: () => false);

    final checkout = await flow.start(
      accessToken: 'jwt',
      productId: MobileMoneyProduct.monthlyProductId,
      phone: '01010101',
      name: 'John Doe',
    );

    expect(checkout.token, 'demo-1');
    expect(checkout.amount, 3500);
  });

  test('returnUrl points at the static server page', () {
    final flow = _flow(refresh: () async {}, isEntitled: () => false);

    expect(flow.returnUrl.toString(), '$_base/v1/payments/moneyfusion/return');
  });

  test('confirm returns immediately when already entitled', () async {
    var refreshes = 0;
    final flow = _flow(
      refresh: () async => refreshes++,
      isEntitled: () => true,
    );

    expect(await flow.confirm(), isTrue);
    expect(refreshes, 0);
  });

  test('confirm waits for the server entitlement', () async {
    var refreshes = 0;
    final flow = _flow(
      refresh: () async => refreshes++,
      isEntitled: () => refreshes >= 2,
    );

    expect(await flow.confirm(), isTrue);
    expect(refreshes, 2);
  });

  test('confirm keeps waiting after a refresh failure', () async {
    var refreshes = 0;
    final flow = _flow(
      refresh: () async {
        refreshes++;
        if (refreshes == 1) throw Exception('offline');
      },
      isEntitled: () => refreshes >= 2,
    );

    expect(await flow.confirm(), isTrue);
    expect(refreshes, 2);
  });

  test('confirm gives up at the deadline', () async {
    var refreshes = 0;
    final flow = _flow(
      refresh: () async => refreshes++,
      isEntitled: () => false,
      timeout: const Duration(milliseconds: 20),
    );

    expect(await flow.confirm(), isFalse);
    expect(refreshes, greaterThan(0));
  });
}
