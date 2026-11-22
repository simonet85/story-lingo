import 'package:shared_preferences/shared_preferences.dart';

import '../domain/billing_offer.dart';
import 'billing_gateway.dart';
import 'demo_billing_gateway.dart';

BillingGateway createBillingGateway({
  required SharedPreferences preferences,
  required String apiKey,
  required DateTime Function() now,
}) => DemoBillingGateway(preferences: preferences, now: now);

bool get billingSupportsStore => false;

List<BillingOffer> demoBillingOffers() => DemoBillingGateway.offers;
