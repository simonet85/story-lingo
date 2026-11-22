import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_config.dart';
import '../../../core/prefs/user_prefs_provider.dart';
import '../data/billing_gateway.dart';
import '../data/billing_gateway_factory.dart';

/// Replaceable clock so entitlement expiry is testable.
final billingNowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final billingGatewayProvider = Provider<BillingGateway>((ref) {
  final preferences = ref.watch(prefsRepositoryProvider).preferences;
  return createBillingGateway(
    preferences: preferences,
    apiKey: ref.watch(revenueCatApiKeyProvider),
    now: ref.watch(billingNowProvider),
  );
});
