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
