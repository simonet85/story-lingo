import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/prefs/prefs_keys.dart';
import '../domain/billing_entitlement.dart';
import '../domain/billing_offer.dart';
import 'billing_gateway.dart';

class DemoBillingGateway implements BillingGateway {
  DemoBillingGateway({
    required this.preferences,
    DateTime Function()? now,
    this.latency = const Duration(milliseconds: 500),
  }) : _now = now ?? DateTime.now;

  static const List<BillingOffer> offers = [
    BillingOffer(
      id: 'storylingo_monthly',
      kind: BillingOfferKind.monthly,
      titleFr: 'Mensuel',
      priceLabel: '3,99 €',
      periodLabel: '/ mois',
    ),
    BillingOffer(
      id: 'storylingo_yearly',
      kind: BillingOfferKind.yearly,
      titleFr: 'Annuel',
      priceLabel: '29,99 €',
      periodLabel: '/ an · 2 mois offerts',
      badgeFr: 'Le plus choisi',
    ),
  ];

  final SharedPreferences preferences;
  final DateTime Function() _now;
  final Duration latency;

  @override
  bool get isConfigured => true;

  @override
  bool get isDemo => true;

  @override
  Future<void> configure({String? appUserId}) async {}

  @override
  Future<void> logIn(String appUserId) async {}

  @override
  Future<void> logOut() async {}

  @override
  Future<List<BillingOffer>> loadOffers() async {
    await _delay();
    return offers;
  }

  @override
  Future<BillingEntitlement> refresh() async {
    await _delay();
    return _read();
  }

  @override
  Future<BillingEntitlement> purchase(BillingOffer offer) async {
    await _delay();
    final days = offer.isYearly ? 365 : 30;
    final entitlement = BillingEntitlement(
      active: true,
      source: 'demo',
      productId: offer.id,
      expiresAt: _now().toUtc().add(Duration(days: days)),
    );
    await preferences.setString(
      PrefsKeys.demoEntitlement,
      jsonEncode(entitlement.toJson()),
    );
    return entitlement;
  }

  @override
  Future<BillingEntitlement> restore() async {
    await _delay();
    return _read();
  }

  BillingEntitlement _read() {
    final raw = preferences.getString(PrefsKeys.demoEntitlement);
    if (raw == null) return BillingEntitlement.inactive;
    try {
      final value = jsonDecode(raw);
      if (value is Map<String, dynamic>) {
        return BillingEntitlement.fromJson(value);
      }
      if (value is Map) {
        return BillingEntitlement.fromJson(Map<String, dynamic>.from(value));
      }
    } on FormatException {
      return BillingEntitlement.inactive;
    }
    return BillingEntitlement.inactive;
  }

  Future<void> _delay() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }
}
