import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:money_fusion/money_fusion.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storylingo/core/config/api_config.dart';
import 'package:storylingo/core/prefs/prefs_repository.dart';
import 'package:storylingo/core/prefs/user_prefs_provider.dart';
import 'package:storylingo/features/account/domain/auth_session.dart';
import 'package:storylingo/features/account/presentation/auth_provider.dart';
import 'package:storylingo/features/billing/application/billing_providers.dart';
import 'package:storylingo/features/billing/application/mobile_money_flow.dart';
import 'package:storylingo/features/billing/application/mobile_money_providers.dart';
import 'package:storylingo/features/billing/data/demo_billing_gateway.dart';
import 'package:storylingo/features/billing/data/mobile_money_api.dart';
import 'package:storylingo/features/billing/domain/mobile_money_product.dart';
import 'package:storylingo/features/billing/presentation/mobile_money_screen.dart';
import 'package:storylingo/features/billing/presentation/paywall_screen.dart';

const _base = 'http://10.0.2.2:8000';
final _now = DateTime.utc(2026, 11, 25, 10);

final _session = AuthSession(
  userId: 'user-1',
  email: 'reader@example.com',
  mode: AuthMode.dev,
  accessToken: 'jwt',
  expiresAt: DateTime.utc(2030),
);

class _SignedInAuthController extends AuthController {
  @override
  AuthState build() =>
      AuthState(status: AuthStatus.signedIn, session: _session);

  @override
  Future<AuthSession?> ensureSession() async => _session;
}

class _SignedOutAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(status: AuthStatus.signedOut);

  @override
  Future<AuthSession?> ensureSession() async => null;
}

class _Launcher {
  _Launcher(this._result);

  final PaymentResult? Function() _result;
  int calls = 0;
  MobileMoneyCheckoutRequest? request;
  Uri? returnUrl;

  Future<PaymentResult?> call(
    BuildContext context, {
    required MobileMoneyCheckoutRequest request,
    required Uri returnUrl,
  }) async {
    calls++;
    this.request = request;
    this.returnUrl = returnUrl;
    return _result();
  }
}

Future<http.Response> _apiHandler(http.Request request) async {
  if (request.method == 'GET') {
    return http.Response(
      jsonEncode({
        'products': [
          {
            'productId': 'storylingo_pro_monthly_xaf',
            'amount': 3500,
            'days': 30,
            'currency': 'XAF',
          },
          {
            'productId': 'storylingo_pro_yearly_xaf',
            'amount': 30000,
            'days': 365,
            'currency': 'XAF',
          },
        ],
      }),
      200,
    );
  }
  return http.Response(
    jsonEncode({
      'token': 'demo-1',
      'url': 'http://10.0.2.2:8091/pay/demo-1',
      'productId': 'storylingo_pro_yearly_xaf',
      'amount': 30000,
    }),
    200,
  );
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/paywall',
    routes: [
      GoRoute(
        path: '/paywall',
        builder: (context, state) =>
            PaywallScreen(bookId: state.uri.queryParameters['bookId']),
      ),
      GoRoute(
        path: '/paywall/mobile-money',
        builder: (context, state) => MobileMoneyScreen(
          productId:
              state.uri.queryParameters['productId'] ??
              MobileMoneyProduct.monthlyProductId,
        ),
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) => const Scaffold(body: Text('Compte test')),
      ),
      GoRoute(
        path: '/library',
        builder: (context, state) =>
            const Scaffold(body: Text('Bibliothèque test')),
      ),
    ],
  );
}

Future<({Widget app, _Launcher launcher})> _buildApp({
  bool available = true,
  bool signedIn = true,
  bool entitled = true,
  PaymentResult? Function()? result,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final prefs = PrefsRepository(preferences);
  final launcher = _Launcher(
    result ?? () => const PaymentCompleted(status: PaymentStatus.paid),
  );
  final api = MobileMoneyApi(baseUrl: _base, client: MockClient(_apiHandler));
  final flow = MobileMoneyFlow(
    api: api,
    refresh: () async {},
    isEntitled: () => entitled,
    interval: const Duration(milliseconds: 1),
    confirmationTimeout: const Duration(milliseconds: 100),
  );
  final app = ProviderScope(
    overrides: [
      prefsRepositoryProvider.overrideWithValue(prefs),
      billingGatewayProvider.overrideWithValue(
        DemoBillingGateway(
          preferences: preferences,
          now: () => _now,
          latency: Duration.zero,
        ),
      ),
      billingNowProvider.overrideWithValue(() => _now),
      mobileMoneyAvailableProvider.overrideWithValue(available),
      mobileMoneyFlowProvider.overrideWithValue(flow),
      authControllerProvider.overrideWith(
        signedIn ? _SignedInAuthController.new : _SignedOutAuthController.new,
      ),
      moneyFusionCheckoutLauncherProvider.overrideWithValue(launcher.call),
    ],
    child: MaterialApp.router(routerConfig: _router()),
  );
  return (app: app, launcher: launcher);
}

Future<void> _openForm(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Payer par mobile money'),
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Payer par mobile money'));
  await tester.pumpAndSettle();
}

Future<void> _submitForm(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), '01010101');
  await tester.enterText(find.byType(TextFormField).at(1), 'John Doe');
  await tester.tap(find.widgetWithText(FilledButton, 'Payer 30 000 FCFA'));
  await tester.pumpAndSettle();
}

void main() {
  test('availability requires the flag, Android and an API base', () {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    ProviderContainer container(bool enabled, TargetPlatform platform) {
      debugDefaultTargetPlatformOverride = platform;
      final value = ProviderContainer(
        overrides: [
          if (enabled) mobileMoneyEnabledProvider.overrideWithValue(true),
          apiBaseUrlProvider.overrideWithValue(_base),
        ],
      );
      addTearDown(value.dispose);
      return value;
    }

    expect(
      container(
        true,
        TargetPlatform.android,
      ).read(mobileMoneyAvailableProvider),
      isTrue,
    );
    expect(
      container(
        false,
        TargetPlatform.android,
      ).read(mobileMoneyAvailableProvider),
      isFalse,
    );
    expect(
      container(true, TargetPlatform.iOS).read(mobileMoneyAvailableProvider),
      isFalse,
    );
  });

  testWidgets('the paywall hides mobile money when unavailable', (
    tester,
  ) async {
    final harness = await _buildApp(available: false);
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    expect(find.text('Mobile money (FCFA)'), findsNothing);
    expect(find.text('Payer par mobile money'), findsNothing);
  });

  testWidgets('the paywall opens the mobile money form', (tester) async {
    final harness = await _buildApp();
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await _openForm(tester);

    expect(find.text('Paiement mobile money'), findsOneWidget);
    expect(find.text('Abonnement annuel'), findsOneWidget);
    expect(find.text('30 000 FCFA / an'), findsOneWidget);
  });

  testWidgets('an empty form reports errors without calling the backend', (
    tester,
  ) async {
    final harness = await _buildApp();
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();
    await _openForm(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Payer 30 000 FCFA'));
    await tester.pumpAndSettle();

    expect(find.text('Indiquez le numéro de téléphone.'), findsOneWidget);
    expect(find.text('Indiquez le nom du titulaire.'), findsOneWidget);
    expect(harness.launcher.calls, 0);
  });

  testWidgets('a paid checkout activates the server entitlement', (
    tester,
  ) async {
    final harness = await _buildApp();
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();
    await _openForm(tester);

    await _submitForm(tester);

    expect(harness.launcher.calls, 1);
    expect(harness.launcher.request?.token, 'demo-1');
    expect(
      harness.launcher.returnUrl.toString(),
      '$_base/v1/payments/moneyfusion/return',
    );
    expect(find.text('Abonnement actif. Bonne lecture !'), findsOneWidget);
    expect(find.text('Paiement mobile money'), findsNothing);
    expect(find.text('Abonnement'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a cancelled checkout keeps the form', (tester) async {
    final harness = await _buildApp(result: () => const PaymentCancelled());
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();
    await _openForm(tester);

    await _submitForm(tester);

    expect(find.text('Paiement annulé.'), findsOneWidget);
    expect(find.text('Payer 30 000 FCFA'), findsOneWidget);
  });

  testWidgets('a failed payment is reported', (tester) async {
    final harness = await _buildApp(
      result: () => const PaymentCompleted(status: PaymentStatus.failure),
    );
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();
    await _openForm(tester);

    await _submitForm(tester);

    expect(find.text('Paiement refusé ou annulé.'), findsOneWidget);
    expect(find.text('Payer 30 000 FCFA'), findsOneWidget);
  });

  testWidgets('a pending server confirmation is announced', (tester) async {
    final harness = await _buildApp(
      entitled: false,
      result: () => const PaymentCompleted(status: PaymentStatus.paid),
    );
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();
    await _openForm(tester);

    await _submitForm(tester);

    expect(
      find.text(
        'Paiement en attente de confirmation. '
        'L’abonnement s’activera dès validation.',
      ),
      findsOneWidget,
    );
    expect(find.text('Payer 30 000 FCFA'), findsOneWidget);
  });

  testWidgets('a signed-out visitor cannot pay and is invited to log in', (
    tester,
  ) async {
    final harness = await _buildApp(signedIn: false);
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();
    await _openForm(tester);

    expect(
      find.text('Connectez-vous pour payer par mobile money.'),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Payer 30 000 FCFA'),
    );
    expect(button.onPressed, isNull);
    expect(harness.launcher.calls, 0);
  });
}
