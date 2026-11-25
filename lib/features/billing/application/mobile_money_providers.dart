import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_fusion/money_fusion.dart' show PaymentResult;

import '../../../core/config/api_config.dart';
import '../data/checkout_launcher.dart';
import '../data/mobile_money_api.dart';
import 'entitlement_provider.dart';
import 'mobile_money_flow.dart';

/// Mobile money is Android-only: iOS and the stores forbid out-of-store
/// digital subscriptions.
final mobileMoneyAvailableProvider = Provider<bool>((ref) {
  if (!ref.watch(mobileMoneyEnabledProvider)) return false;
  if (kIsWeb) return false;
  if (defaultTargetPlatform != TargetPlatform.android) return false;
  return ref.watch(apiBaseUrlProvider).isNotEmpty;
});

final mobileMoneyApiProvider = Provider<MobileMoneyApi>((ref) {
  return MobileMoneyApi(baseUrl: ref.watch(apiBaseUrlProvider));
});

final mobileMoneyFlowProvider = Provider<MobileMoneyFlow>((ref) {
  return MobileMoneyFlow(
    api: ref.watch(mobileMoneyApiProvider),
    refresh: () =>
        ref.read(entitlementControllerProvider.notifier).refresh(silent: true),
    isEntitled: () => ref.read(isEntitledProvider),
  );
});

typedef MoneyFusionCheckoutLauncher = Future<PaymentResult?> Function(
  BuildContext context, {
  required MobileMoneyCheckoutRequest request,
  required Uri returnUrl,
});

final moneyFusionCheckoutLauncherProvider =
    Provider<MoneyFusionCheckoutLauncher>((ref) {
      final statusBaseUrl = ref.watch(moneyFusionStatusBaseUrlProvider);
      final backendUrl = ref.watch(mobileMoneyApiProvider).creationUrl;
      return (context, {required request, required returnUrl}) {
        return launchMoneyFusionCheckout(
          context,
          request: request,
          returnUrl: returnUrl,
          backendUrl: backendUrl,
          statusBaseUrl: statusBaseUrl,
        );
      };
    });

enum PendingMobileMoneyPhase { idle, waiting, active, expired }

@immutable
class PendingMobileMoneyState {
  const PendingMobileMoneyState({
    this.phase = PendingMobileMoneyPhase.idle,
    this.startedAt,
  });

  final PendingMobileMoneyPhase phase;
  final DateTime? startedAt;

  bool get isWaiting => phase == PendingMobileMoneyPhase.waiting;
}

final pendingMobileMoneyProvider =
    NotifierProvider<PendingMobileMoneyController, PendingMobileMoneyState>(
      PendingMobileMoneyController.new,
    );

/// Keeps checking the server after the checkout closes, including when the
/// Wave confirmation happens outside the app. Without it the entitlement is
/// only reloaded when a subscription screen is opened again.
class PendingMobileMoneyController extends Notifier<PendingMobileMoneyState> {
  static const _interval = Duration(seconds: 5);
  static const _timeout = Duration(minutes: 15);

  Timer? _timer;
  DateTime? _deadline;
  bool _checking = false;

  @override
  PendingMobileMoneyState build() {
    ref.onDispose(_cancel);
    return const PendingMobileMoneyState();
  }

  void start() {
    _cancel();
    final now = DateTime.now();
    _deadline = now.add(_timeout);
    state = PendingMobileMoneyState(
      phase: PendingMobileMoneyPhase.waiting,
      startedAt: now,
    );
    unawaited(_check());
    _timer = Timer.periodic(_interval, (_) => unawaited(_check()));
  }

  Future<void> checkNow() async {
    if (!state.isWaiting) return;
    await _check();
  }

  void stop() {
    _cancel();
    _deadline = null;
    state = const PendingMobileMoneyState();
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _check() async {
    if (_checking || !state.isWaiting) return;
    final deadline = _deadline;
    if (deadline == null || !DateTime.now().isBefore(deadline)) {
      _cancel();
      state = const PendingMobileMoneyState(
        phase: PendingMobileMoneyPhase.expired,
      );
      return;
    }
    _checking = true;
    try {
      final flow = ref.read(mobileMoneyFlowProvider);
      await flow.refresh();
      if (!ref.mounted || !state.isWaiting) return;
      if (flow.isEntitled()) {
        _cancel();
        state = const PendingMobileMoneyState(
          phase: PendingMobileMoneyPhase.active,
        );
      }
    } on Exception {
      // The webhook may still be in flight; the next tick retries.
    } finally {
      _checking = false;
    }
  }
}
