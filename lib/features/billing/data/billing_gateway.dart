import '../domain/billing_entitlement.dart';
import '../domain/billing_offer.dart';

abstract interface class BillingGateway {
  bool get isConfigured;

  bool get isDemo;

  Future<void> configure({String? appUserId});

  Future<void> logIn(String appUserId);

  Future<void> logOut();

  Future<List<BillingOffer>> loadOffers();

  Future<BillingEntitlement> refresh();

  Future<BillingEntitlement> purchase(BillingOffer offer);

  Future<BillingEntitlement> restore();
}
