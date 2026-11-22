import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storylingo/core/prefs/prefs_keys.dart';
import 'package:storylingo/features/billing/data/billing_gateway_factory.dart';
import 'package:storylingo/features/billing/data/demo_billing_gateway.dart';
import 'package:storylingo/features/billing/domain/billing_offer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  test('demo gateway exposes monthly and yearly offers', () async {
    final gateway = DemoBillingGateway(
      preferences: preferences,
      latency: Duration.zero,
    );
    final offers = await gateway.loadOffers();
    expect(offers.map((offer) => offer.kind), [
      BillingOfferKind.monthly,
      BillingOfferKind.yearly,
    ]);
    expect(offers.last.badgeFr, 'Le plus choisi');
    expect(offers.last.periodLabel, contains('2 mois offerts'));
    expect(gateway.isDemo, isTrue);
  });

  test('purchase persists a yearly entitlement and restore finds it', () async {
    final now = DateTime.utc(2026, 11, 22, 10);
    final gateway = DemoBillingGateway(
      preferences: preferences,
      now: () => now,
      latency: Duration.zero,
    );
    final yearly = (await gateway.loadOffers()).firstWhere(
      (offer) => offer.isYearly,
    );

    final purchased = await gateway.purchase(yearly);
    expect(purchased.active, isTrue);
    expect(purchased.source, 'demo');
    expect(purchased.productId, yearly.id);
    expect(purchased.expiresAt, now.add(const Duration(days: 365)));
    expect(preferences.getString(PrefsKeys.demoEntitlement), isNotNull);

    final restored = await gateway.restore();
    expect(restored.isActiveAt(now), isTrue);
    expect(restored.expiresAt, purchased.expiresAt);
  });

  test('an expired demo entitlement is not active', () async {
    var now = DateTime.utc(2026, 11, 22, 10);
    final gateway = DemoBillingGateway(
      preferences: preferences,
      now: () => now,
      latency: Duration.zero,
    );
    final monthly = (await gateway.loadOffers()).first;
    await gateway.purchase(monthly);

    now = now.add(const Duration(days: 31));
    final restored = await gateway.restore();
    expect(restored.active, isTrue);
    expect(restored.isActiveAt(now), isFalse);
  });

  test('corrupt stored entitlement is ignored', () async {
    await preferences.setString(PrefsKeys.demoEntitlement, 'not-json');
    final gateway = DemoBillingGateway(
      preferences: preferences,
      latency: Duration.zero,
    );
    final restored = await gateway.refresh();
    expect(restored.active, isFalse);
    expect(restored.source, 'none');
  });

  test('host tests always get the demo gateway, never the plugin', () {
    final gateway = createBillingGateway(
      preferences: preferences,
      apiKey: 'rc_public_key',
      now: DateTime.now,
    );
    expect(gateway, isA<DemoBillingGateway>());
    expect(gateway.isDemo, isTrue);
  });
}
