import 'package:material_ui/material_ui.dart';
import 'package:money_fusion/money_fusion.dart';

import 'mobile_money_api.dart';

Future<PaymentResult?> launchMoneyFusionCheckout(
  BuildContext context, {
  required MobileMoneyCheckoutRequest request,
  required Uri returnUrl,
  required Uri backendUrl,
  required String statusBaseUrl,
}) async {
  final client = MoneyFusionClient(
    backendUrl: backendUrl,
    statusBaseUrl: Uri.parse(statusBaseUrl),
    timeout: const Duration(seconds: 5),
  );
  try {
    return await Navigator.of(context).push<PaymentResult>(
      MaterialPageRoute(
        builder: (context) => MoneyFusionCheckout(
          client: client,
          session: PaymentSession(
            token: request.token,
            url: request.url,
            message: '',
          ),
          returnUrl: returnUrl,
        ),
      ),
    );
  } finally {
    client.close();
  }
}
