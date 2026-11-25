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
