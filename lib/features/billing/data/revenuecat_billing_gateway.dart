import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../domain/billing_entitlement.dart';
import '../domain/billing_offer.dart';
import 'billing_gateway.dart';

class RevenueCatBillingGateway implements BillingGateway {
  RevenueCatBillingGateway({required this.apiKey});

  static const String entitlementId = 'storylingo_pro';

  final String apiKey;
  final Map<String, Package> _packages = {};
  Future<void> _queue = Future<void>.value();
  bool _configured = false;
  String? _appUserId;

  @override
  bool get isConfigured => true;

  @override
  bool get isDemo => false;

  @override
  Future<void> configure({String? appUserId}) {
    return _enqueue(() async {
      if (!_configured) {
        final configuration = PurchasesConfiguration(apiKey);
        final requested = appUserId != null && appUserId.isNotEmpty
            ? appUserId
            : null;
        if (requested != null) configuration.appUserID = requested;
        await Purchases.configure(configuration);
        _configured = true;
        _appUserId = requested;
        return;
      }
      if (appUserId != null && appUserId != _appUserId) {
        await Purchases.logIn(appUserId);
        _appUserId = appUserId;
      }
    });
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.catchError((Object _) {});
    return result;
  }

  @override
  Future<void> logIn(String appUserId) async {
    if (!_configured) {
      await configure(appUserId: appUserId);
      return;
    }
    if (_appUserId == appUserId) return;
    await Purchases.logIn(appUserId);
    _appUserId = appUserId;
  }

  @override
  Future<void> logOut() async {
    if (!_configured || _appUserId == null) return;
    try {
      await Purchases.logOut();
    } on PlatformException {
      return;
    }
    _appUserId = null;
  }

  @override
  Future<List<BillingOffer>> loadOffers() async {
    await configure();
    final offerings = await Purchases.getOfferings();
    final current = offerings.current;
    if (current == null) return const [];
    _packages.clear();
    final offers = <BillingOffer>[];
    for (final package in current.availablePackages) {
      final kind = switch (package.packageType) {
        PackageType.monthly => BillingOfferKind.monthly,
        PackageType.annual => BillingOfferKind.yearly,
        _ => null,
      };
      if (kind == null) continue;
      final productId = package.storeProduct.identifier;
      _packages[productId] = package;
      offers.add(
        BillingOffer(
          id: productId,
          kind: kind,
          titleFr: kind == BillingOfferKind.monthly ? 'Mensuel' : 'Annuel',
          priceLabel: package.storeProduct.priceString,
          periodLabel: kind == BillingOfferKind.monthly ? '/ mois' : '/ an',
          badgeFr: kind == BillingOfferKind.yearly ? 'Le plus choisi' : null,
        ),
      );
    }
    offers.sort(
      (a, b) => a.kind == BillingOfferKind.monthly ? -1 : b.isYearly ? -1 : 1,
    );
    return offers;
  }

  @override
  Future<BillingEntitlement> refresh() async {
    await configure();
    try {
      return _fromCustomerInfo(await Purchases.getCustomerInfo());
    } on PlatformException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<BillingEntitlement> purchase(BillingOffer offer) async {
    await configure();
    final package = _packages[offer.id] ?? await _findPackage(offer.id);
    if (package == null) {
      throw const BillingException(
        'Cette offre est indisponible pour le moment.',
      );
    }
    try {
      final result = await Purchases.purchase(
        PurchaseParams.package(package),
      );
      return _fromCustomerInfo(result.customerInfo);
    } on PlatformException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<BillingEntitlement> restore() async {
    await configure();
    try {
      return _fromCustomerInfo(await Purchases.restorePurchases());
    } on PlatformException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Package?> _findPackage(String offerId) async {
    if (_packages.isEmpty) {
      try {
        await loadOffers();
      } on PlatformException catch (error) {
        throw _mapError(error);
      }
    }
    return _packages[offerId];
  }

  BillingEntitlement _fromCustomerInfo(CustomerInfo info) {
    final entitlement = info.entitlements.active[entitlementId];
    if (entitlement == null) return BillingEntitlement.inactive;
    final rawExpiry = entitlement.expirationDate;
    final expiresAt = rawExpiry == null
        ? null
        : DateTime.tryParse(rawExpiry)?.toUtc();
    return BillingEntitlement(
      active: entitlement.isActive,
      source: 'sdk',
      productId: entitlement.productIdentifier,
      expiresAt: expiresAt,
    );
  }

  BillingException _mapError(PlatformException error) {
    return switch (PurchasesErrorHelper.getErrorCode(error)) {
      PurchasesErrorCode.purchaseCancelledError => const BillingException(
        'Achat annulé.',
      ),
      PurchasesErrorCode.networkError => const BillingException(
        'Connexion impossible. Vérifiez votre réseau.',
      ),
      PurchasesErrorCode.purchaseNotAllowedError => const BillingException(
        'Les achats sont désactivés sur cet appareil.',
      ),
      PurchasesErrorCode.productAlreadyPurchasedError =>
        const BillingException(
          'Cet abonnement est déjà actif. Essayez « Restaurer mes achats ».',
        ),
      _ => const BillingException(
        'Achat impossible pour le moment. Réessayez plus tard.',
      ),
    };
  }
}
