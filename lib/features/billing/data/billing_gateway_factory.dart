import 'package:shared_preferences/shared_preferences.dart';

import '../domain/billing_offer.dart';
import 'billing_gateway.dart';
import 'billing_gateway_stub.dart'
    if (dart.library.io) 'billing_gateway_io.dart'
    as platform;

BillingGateway createBillingGateway({
  required SharedPreferences preferences,
  required String apiKey,
  required DateTime Function() now,
}) => platform.createBillingGateway(
  preferences: preferences,
  apiKey: apiKey,
  now: now,
);

bool get billingSupportsStore => platform.billingSupportsStore;

List<BillingOffer> demoBillingOffers() => platform.demoBillingOffers();
