import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Empty when the app must stay on the embedded pack (default build).
final apiBaseUrlProvider = Provider<String>((ref) {
  const raw = String.fromEnvironment('API_BASE_URL');
  return raw.trim();
});

/// Empty unless the build targets a Supabase project.
final supabaseUrlProvider = Provider<String>((ref) {
  const raw = String.fromEnvironment('SUPABASE_URL');
  return raw.trim().replaceAll(RegExp(r'/+$'), '');
});

final supabaseAnonKeyProvider = Provider<String>((ref) {
  const raw = String.fromEnvironment('SUPABASE_ANON_KEY');
  return raw.trim();
});

/// Empty when billing falls back to the local demo gateway.
final revenueCatApiKeyProvider = Provider<String>((ref) {
  const raw = String.fromEnvironment('REVENUECAT_API_KEY');
  return raw.trim();
});

/// Off by default: selling subscriptions outside the stores must stay opt-in.
final mobileMoneyEnabledProvider = Provider<bool>((ref) {
  const raw = String.fromEnvironment('MOBILE_MONEY_ENABLED');
  return raw.trim().toLowerCase() == 'true';
});

/// Base of `paiementNotif/{token}`, read by the checkout after the return.
///
/// Display only: the backend webhook remains the source of truth.
final moneyFusionStatusBaseUrlProvider = Provider<String>((ref) {
  const raw = String.fromEnvironment(
    'MONEYFUSION_STATUS_BASE_URL',
    defaultValue: 'https://pay.moneyfusion.net',
  );
  return raw.trim();
});
