import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/billing_offer.dart';
import 'billing_gateway.dart';
import 'demo_billing_gateway.dart';
import 'revenuecat_billing_gateway.dart';

BillingGateway createBillingGateway({
  required SharedPreferences preferences,
  required String apiKey,
  required DateTime Function() now,
}) {
  final supported =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  final hostTest = Platform.environment['FLUTTER_TEST'] == 'true';
  if (hostTest) {
    return DemoBillingGateway(
      preferences: preferences,
      now: now,
      latency: Duration.zero,
    );
  }
  if (apiKey.isEmpty || !supported) {
    return DemoBillingGateway(preferences: preferences, now: now);
  }
  return RevenueCatBillingGateway(apiKey: apiKey);
}

bool get billingSupportsStore => true;

List<BillingOffer> demoBillingOffers() => DemoBillingGateway.offers;
