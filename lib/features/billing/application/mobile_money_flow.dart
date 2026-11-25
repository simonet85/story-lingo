import '../data/mobile_money_api.dart';
import '../domain/mobile_money_product.dart';

/// Creates the payment, then waits for the server-side entitlement.
///
/// The MoneyFusion status shown by the checkout is display only: activation
/// always comes from the backend webhook.
class MobileMoneyFlow {
  MobileMoneyFlow({
    required this.api,
    required this.refresh,
    required this.isEntitled,
    this.interval = const Duration(seconds: 2),
    this.confirmationTimeout = const Duration(seconds: 30),
  });

  final MobileMoneyApi api;
  final Future<void> Function() refresh;
  final bool Function() isEntitled;
  final Duration interval;
  final Duration confirmationTimeout;

  Uri get returnUrl => api.returnUrl;

  Uri get creationUrl => api.creationUrl;

  Future<MobileMoneyProduct?> loadProduct(String productId) async {
    final products = await api.fetchProducts();
    for (final product in products) {
      if (product.productId == productId) return product;
    }
    return null;
  }

  Future<MobileMoneyCheckoutRequest> start({
    required String accessToken,
    required String productId,
    required String phone,
    required String name,
  }) {
    return api.createPayment(
      accessToken: accessToken,
      productId: productId,
      phone: phone,
      name: name,
    );
  }

  Future<bool> confirm() async {
    final deadline = DateTime.now().add(confirmationTimeout);
    while (true) {
      if (isEntitled()) return true;
      if (!DateTime.now().isBefore(deadline)) return false;
      try {
        await refresh();
      } on Exception {
        // The next tick retries; a webhook may still be in flight.
      }
      if (isEntitled()) return true;
      await Future<void>.delayed(interval);
    }
  }
}
