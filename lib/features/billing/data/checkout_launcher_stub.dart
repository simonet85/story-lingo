import 'package:flutter/widgets.dart';
import 'package:money_fusion/money_fusion.dart' show PaymentResult;

import 'mobile_money_api.dart';

Future<PaymentResult?> launchMoneyFusionCheckout(
  BuildContext context, {
  required MobileMoneyCheckoutRequest request,
  required Uri returnUrl,
  required Uri backendUrl,
  required String statusBaseUrl,
}) async {
  return null;
}
