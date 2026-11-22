import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storylingo/core/prefs/prefs_keys.dart';
import 'package:storylingo/core/prefs/prefs_repository.dart';
import 'package:storylingo/core/prefs/user_prefs_provider.dart';
import 'package:storylingo/features/account/presentation/auth_provider.dart';
import 'package:storylingo/features/billing/application/billing_providers.dart';
import 'package:storylingo/features/billing/application/entitlement_provider.dart';
import 'package:storylingo/features/billing/data/demo_billing_gateway.dart';
import 'package:storylingo/features/billing/presentation/book_access_gate.dart';
import 'package:storylingo/features/billing/presentation/paywall_screen.dart';
import 'package:storylingo/features/content/data/content_repository.dart';
import 'package:storylingo/features/content/domain/book_manifest.dart';
import 'package:storylingo/features/content/domain/catalogue.dart';
import 'package:storylingo/features/onboarding/domain/user_level.dart';

import 'support/in_memory_token_store.dart';

final _now = DateTime.utc(2026, 11, 22, 10);

BookManifest _manifest(String id, {required bool isFree}) => BookManifest(
  schemaVersion: 1,
  packVersion: '1.0.0',
  id: id,
  title: id,
  titleFr: id,
  author: 'Storylingo',
  level: UserLevel.a2,
  descriptionFr: 'Description.',
  chapters: const [
    BookChapterSummary(
      id: 'chapter-01',
      number: 1,
      title: 'Chapitre',
      asset: 'chapters/chapter-01.json',
      estimatedMinutes: 1,
      newWordCount: 0,
    ),
  ],
  isFree: isFree,
);

CatalogueView _catalogue({required bool isFree}) {
  final pilot = _manifest('sleepy-hollow', isFree: true);
  final paid = _manifest('paid-book', isFree: isFree);
  return CatalogueView(
    pilot: pilot,
    books: [
      CatalogueBook.fromManifest(paid, isEmbedded: false),
      CatalogueBook.fromManifest(pilot),
    ],
    source: CatalogueSource.network,
  );
}

GoRouter _router({
  String initialLocation = '/paywall',
  bool gateReading = false,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/library',
        builder: (context, state) =>
            const Scaffold(body: Text('Bibliothèque test')),
      ),
      GoRoute(
        path: '/paywall',
        builder: (context, state) => PaywallScreen(
          bookId: state.uri.queryParameters['bookId'],
        ),
      ),
      GoRoute(
        path: '/read/:bookId/:chapterId',
        builder: (context, state) => Scaffold(
          body: Text('Lecture ${state.pathParameters['bookId']}'),
        ),
      ),
      GoRoute(
        path: '/read/:bookId',
        builder: (context, state) {
          final bookId = state.pathParameters['bookId']!;
          final page = Scaffold(body: Text('Lecture $bookId'));
          if (!gateReading) return page;
          return BookAccessGate(bookId: bookId, child: page);
        },
      ),
    ],
  );
}

Future<({Widget app, SharedPreferences preferences})> _buildApp({
  String initialLocation = '/paywall',
  bool gateReading = false,
  CatalogueView? catalogue,
  bool entitledForTest = false,
  bool overrideEntitlement = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final sharedPreferences = await SharedPreferences.getInstance();
  final prefs = PrefsRepository(sharedPreferences);
  final gateway = DemoBillingGateway(
    preferences: sharedPreferences,
    now: () => _now,
    latency: Duration.zero,
  );

  final app = ProviderScope(
    overrides: [
      prefsRepositoryProvider.overrideWithValue(prefs),
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      billingGatewayProvider.overrideWithValue(gateway),
      billingNowProvider.overrideWithValue(() => _now),
      if (catalogue != null)
        catalogueProvider.overrideWith((ref) async => catalogue),
      if (overrideEntitlement)
        isEntitledProvider.overrideWithValue(entitledForTest),
    ],
    child: MaterialApp.router(routerConfig: _router(
      initialLocation: initialLocation,
      gateReading: gateReading,
    )),
  );
  return (app: app, preferences: sharedPreferences);
}

Future<void> _scrollTo(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a demo purchase unlocks the book and opens it', (tester) async {
    final harness = await _buildApp(initialLocation: '/paywall?bookId=paid-book');
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    expect(find.text('Toute la bibliothèque, sans limite'), findsOneWidget);
    expect(
      find.text('Mode démo : l’achat est simulé sur cet appareil.'),
      findsOneWidget,
    );

    await _scrollTo(tester, 'Choisir cet abonnement');
    expect(find.text('Mensuel'), findsOneWidget);
    expect(find.text('Annuel'), findsOneWidget);

    await tester.tap(find.text('Choisir cet abonnement'));
    await tester.pumpAndSettle();

    expect(find.text('Lecture paid-book'), findsOneWidget);
    expect(
      harness.preferences.getString(PrefsKeys.demoEntitlement),
      isNotNull,
    );
  });

  testWidgets('“Plus tard” leaves the paywall without a purchase', (
    tester,
  ) async {
    final harness = await _buildApp();
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await _scrollTo(tester, 'Plus tard');
    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();

    expect(find.text('Bibliothèque test'), findsOneWidget);
    expect(harness.preferences.getString(PrefsKeys.demoEntitlement), isNull);
  });

  testWidgets('restoring without a purchase reports it', (tester) async {
    final harness = await _buildApp();
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await _scrollTo(tester, 'Restaurer mes achats');
    await tester.tap(find.text('Restaurer mes achats'));
    await tester.pumpAndSettle();

    expect(
      find.text('Aucun achat à restaurer sur ce compte.'),
      findsOneWidget,
    );
  });

  testWidgets('a locked deep link shows the subscription screen', (
    tester,
  ) async {
    final harness = await _buildApp(
      initialLocation: '/read/paid-book',
      gateReading: true,
      catalogue: _catalogue(isFree: false),
      overrideEntitlement: true,
      entitledForTest: false,
    );
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    expect(
      find.text('Ce livre fait partie de l’abonnement'),
      findsOneWidget,
    );
    expect(find.text('Voir les offres'), findsOneWidget);

    await tester.tap(find.text('Voir les offres'));
    await tester.pumpAndSettle();

    expect(find.text('Toute la bibliothèque, sans limite'), findsOneWidget);
  });
}
