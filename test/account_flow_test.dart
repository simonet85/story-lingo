import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storylingo/app.dart';
import 'package:storylingo/core/prefs/prefs_keys.dart';
import 'package:storylingo/core/prefs/prefs_repository.dart';
import 'package:storylingo/core/prefs/user_prefs_provider.dart';
import 'package:storylingo/features/account/data/auth_api.dart';
import 'package:storylingo/features/account/domain/auth_session.dart';
import 'package:storylingo/features/account/presentation/auth_provider.dart';
import 'package:storylingo/features/program/data/program_repository.dart';
import 'package:storylingo/features/program/presentation/program_provider.dart';
import 'package:storylingo/features/reading/data/reading_progress_repository.dart';
import 'package:storylingo/features/reading/presentation/reading_progress_provider.dart';
import 'package:storylingo/features/sync/data/sync_api.dart';
import 'package:storylingo/features/sync/presentation/sync_provider.dart';
import 'package:storylingo/features/telemetry/data/telemetry_repository.dart';
import 'package:storylingo/features/telemetry/presentation/telemetry_provider.dart';
import 'package:storylingo/features/vocabulary/data/saved_words_repository.dart';
import 'package:storylingo/features/vocabulary/data/srs_repository.dart';
import 'package:storylingo/features/vocabulary/presentation/saved_words_provider.dart';
import 'package:storylingo/features/vocabulary/presentation/srs_provider.dart';

import 'support/in_memory_token_store.dart';

final _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

Future<http.Response> _authHandler(http.Request request) async {
  if (request.method == 'POST' && request.url.path == '/v1/auth/dev/login') {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    return http.Response(
      jsonEncode({
        'accessToken': 'dev-token',
        'tokenType': 'bearer',
        'expiresIn': 86400,
        'mode': 'dev',
        'user': {'id': 'dev_anna', 'email': body['email']},
      }),
      200,
      headers: _jsonHeaders,
    );
  }
  return http.Response('{"detail":"not found"}', 404);
}

Future<http.Response> _syncHandler(http.Request request) async {
  if (request.method == 'POST' && request.url.path == '/v1/sync/push') {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    return http.Response(
      jsonEncode({'serverRevision': 1, 'records': body['records']}),
      200,
      headers: _jsonHeaders,
    );
  }
  return http.Response(
    jsonEncode({'revision': 1, 'records': <Object>[]}),
    200,
    headers: _jsonHeaders,
  );
}

Future<http.Response> _failingSyncHandler(http.Request request) async {
  return http.Response(
    jsonEncode({'detail': 'Serveur indisponible.'}),
    500,
    headers: _jsonHeaders,
  );
}

AuthSession _storedSession() => AuthSession(
  userId: 'dev_anna',
  email: 'anna@example.com',
  mode: AuthMode.dev,
  accessToken: 'dev-token',
  expiresAt: DateTime.now().add(const Duration(days: 7)),
);

typedef _TestApp = ({
  Widget app,
  InMemoryTokenStore tokenStore,
  PrefsRepository prefs,
});

Future<_TestApp> _buildApp({
  AuthSession? storedSession,
  bool configured = true,
  bool supabase = false,
  bool syncFails = false,
}) async {
  SharedPreferences.setMockInitialValues({
    PrefsKeys.onboardingCompleted: true,
    PrefsKeys.userLevel: 'a2',
    PrefsKeys.userInterests: <String>['mystery', 'adventure'],
  });
  final sharedPreferences = await SharedPreferences.getInstance();
  final prefs = PrefsRepository(sharedPreferences);
  await prefs.ensureSchemaVersion();
  final tokenStore = InMemoryTokenStore(storedSession);

  final app = ProviderScope(
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
      tokenStoreProvider.overrideWithValue(tokenStore),
      authApiProvider.overrideWithValue(
        AuthApi(
          apiBaseUrl: configured ? 'http://localhost:8000' : '',
          supabaseUrl: supabase ? 'https://demo.supabase.co' : '',
          supabaseAnonKey: supabase ? 'anon-key' : '',
          client: MockClient(_authHandler),
        ),
      ),
      syncApiProvider.overrideWithValue(
        SyncApi(
          baseUrl: 'http://localhost:8000',
          client: MockClient(syncFails ? _failingSyncHandler : _syncHandler),
        ),
      ),
    ],
    child: const StorylingoApp(),
  );

  return (app: app, tokenStore: tokenStore, prefs: prefs);
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Réglages'));
  await tester.pumpAndSettle();
}

Future<void> _signIn(WidgetTester tester) async {
  await _openSettings(tester);
  await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField), 'anna@example.com');
  await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('settings signs in, syncs, then signs out', (tester) async {
    final harness = await _buildApp();
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await _openSettings(tester);
    expect(find.widgetWithText(FilledButton, 'Se connecter'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
    await tester.pumpAndSettle();
    expect(find.text('Mode développement'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
    await tester.pumpAndSettle();
    expect(find.text('Adresse email invalide.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'anna@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('anna@example.com'), findsOneWidget);
    expect(find.text('Mode développement'), findsOneWidget);
    expect(find.textContaining('Dernière synchronisation'), findsOneWidget);
    expect(harness.tokenStore.session?.email, 'anna@example.com');
    expect(harness.prefs.loadSyncCursor(), 1);
    expect(harness.prefs.loadLastSyncAt(), isNotNull);

    await tester.tap(find.text('Se déconnecter'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Se déconnecter'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Se connecter'), findsOneWidget);
    expect(harness.tokenStore.session, isNull);
  });

  testWidgets('a stored session restores and syncs automatically', (
    tester,
  ) async {
    final harness = await _buildApp(storedSession: _storedSession());
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    expect(harness.prefs.loadSyncCursor(), 1);
    expect(harness.prefs.loadLastSyncAt(), isNotNull);

    await _openSettings(tester);
    expect(find.text('anna@example.com'), findsOneWidget);
    expect(find.text('Mode développement'), findsOneWidget);
    expect(find.textContaining('Dernière synchronisation'), findsOneWidget);
  });

  testWidgets('missing API configuration disables the dev sign-in', (
    tester,
  ) async {
    final harness = await _buildApp(configured: false);
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await _openSettings(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
    await tester.pumpAndSettle();

    expect(
      find.text('Renseignez API_BASE_URL au lancement pour utiliser le mode dev.'),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Se connecter'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('manual sync confirms success', (tester) async {
    final harness = await _buildApp();
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await _signIn(tester);
    // Let the sign-in snackbar expire before checking the manual sync one.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Synchroniser maintenant'));
    await tester.pumpAndSettle();

    expect(find.text('Synchronisation terminée.'), findsOneWidget);
    expect(find.textContaining('Dernière synchronisation'), findsOneWidget);
  });

  testWidgets('sync failures are surfaced in settings', (tester) async {
    final harness = await _buildApp(syncFails: true);
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await _signIn(tester);

    expect(find.text('Serveur indisponible.'), findsOneWidget);
    expect(find.text('anna@example.com'), findsOneWidget);
  });

  testWidgets('Supabase mode asks for a password and offers sign-up', (
    tester,
  ) async {
    final harness = await _buildApp(supabase: true);
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await _openSettings(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
    await tester.pumpAndSettle();

    expect(find.text('Se connecter à Storylingo'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
  });

  testWidgets('settings and account fit a 360 px screen', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await _buildApp();
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await _openSettings(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Compte'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Mode développement'), findsOneWidget);
  });
}
