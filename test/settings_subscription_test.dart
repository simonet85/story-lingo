import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storylingo/app.dart';
import 'package:storylingo/core/prefs/prefs_keys.dart';
import 'package:storylingo/core/prefs/prefs_repository.dart';
import 'package:storylingo/core/prefs/user_prefs_provider.dart';
import 'package:storylingo/features/account/presentation/auth_provider.dart';
import 'package:storylingo/features/billing/application/billing_providers.dart';
import 'package:storylingo/features/billing/data/demo_billing_gateway.dart';
import 'package:storylingo/features/program/data/program_repository.dart';
import 'package:storylingo/features/program/presentation/program_provider.dart';
import 'package:storylingo/features/reading/data/reading_progress_repository.dart';
import 'package:storylingo/features/reading/presentation/reading_progress_provider.dart';
import 'package:storylingo/features/telemetry/data/telemetry_repository.dart';
import 'package:storylingo/features/telemetry/presentation/telemetry_provider.dart';
import 'package:storylingo/features/vocabulary/data/saved_words_repository.dart';
import 'package:storylingo/features/vocabulary/data/srs_repository.dart';
import 'package:storylingo/features/vocabulary/presentation/saved_words_provider.dart';
import 'package:storylingo/features/vocabulary/presentation/srs_provider.dart';

import 'support/in_memory_token_store.dart';

final _now = DateTime.utc(2026, 11, 22, 10);

Future<Widget> _buildApp({DateTime? expiresAt}) async {
  final initial = <String, Object>{
    PrefsKeys.onboardingCompleted: true,
    PrefsKeys.userLevel: 'a2',
    PrefsKeys.userInterests: <String>['mystery', 'adventure'],
  };
  if (expiresAt != null) {
    initial[PrefsKeys.demoEntitlement] = jsonEncode({
      'active': true,
      'source': 'demo',
      'productId': 'storylingo_yearly',
      'expiresAt': expiresAt.toIso8601String(),
    });
  }
  SharedPreferences.setMockInitialValues(initial);
  final sharedPreferences = await SharedPreferences.getInstance();
  final prefs = PrefsRepository(sharedPreferences);
  await prefs.ensureSchemaVersion();

  return ProviderScope(
    overrides: [
      prefsRepositoryProvider.overrideWithValue(prefs),
      readingProgressRepositoryProvider.overrideWithValue(
        ReadingProgressRepository(sharedPreferences),
      ),
      savedWordsRepositoryProvider.overrideWithValue(
        SavedWordsRepository(sharedPreferences),
      ),
      srsRepositoryProvider.overrideWithValue(
        SrsRepository(sharedPreferences),
      ),
      programRepositoryProvider.overrideWithValue(
        ProgramRepository(sharedPreferences),
      ),
      telemetryRepositoryProvider.overrideWithValue(
        TelemetryRepository(sharedPreferences),
      ),
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      billingNowProvider.overrideWithValue(() => _now),
      billingGatewayProvider.overrideWithValue(
        DemoBillingGateway(
          preferences: sharedPreferences,
          now: () => _now,
          latency: Duration.zero,
        ),
      ),
    ],
    child: const StorylingoApp(),
  );
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Réglages'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('settings shows the active subscription and its expiry', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _buildApp(expiresAt: _now.add(const Duration(days: 30))),
    );
    await tester.pumpAndSettle();
    await _openSettings(tester);

    expect(find.text('Abonnement'), findsOneWidget);
    expect(find.text('Storylingo Pro'), findsOneWidget);
    expect(find.text('Actif jusqu’au 22/12/2026.'), findsOneWidget);
    expect(find.text('Restaurer mes achats'), findsOneWidget);
    expect(find.text('Découvrir l’abonnement'), findsNothing);
  });

  testWidgets('settings invites signed-out users to discover the offer', (
    tester,
  ) async {
    await tester.pumpWidget(await _buildApp());
    await tester.pumpAndSettle();
    await _openSettings(tester);

    expect(find.text('Découvrir l’abonnement'), findsOneWidget);
    expect(find.text('Restaurer mes achats'), findsOneWidget);
    expect(
      find.text(
        'Connectez-vous pour retrouver votre abonnement sur tous vos '
        'appareils.',
      ),
      findsOneWidget,
    );
    expect(find.text('Storylingo Pro'), findsNothing);

    await tester.ensureVisible(find.text('Découvrir l’abonnement'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Découvrir l’abonnement'));
    await tester.pumpAndSettle();

    expect(find.text('Toute la bibliothèque, sans limite'), findsOneWidget);
  });
}
