// Fake MoneyFusion for the Android demo: creation, checkout page, status and
// webhook notification. No dependency, no network beyond our local server.
//
//   dart run tool/fake_moneyfusion/server.dart
//
// Environment:
//   FAKE_MONEYFUSION_PORT              default 8091
//   FAKE_MONEYFUSION_PUBLIC_BASE_URL   default http://10.0.2.2:8091
//   FAKE_MONEYFUSION_WEBHOOK_URL       default http://127.0.0.1:8000/v1/webhooks/moneyfusion
//   FAKE_MONEYFUSION_SITE_NAME         merchant display name (default Storylingo)
//   FAKE_MONEYFUSION_SITE_URL          optional merchant site URL shown on checkout
//   FAKE_MONEYFUSION_REDIRECT_URL      optional return page, overrides the API return_url

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _defaultPort = 8091;
const _defaultPublicBaseUrl = 'http://10.0.2.2:8091';
const _defaultWebhookUrl = 'http://127.0.0.1:8000/v1/webhooks/moneyfusion';

class _Merchant {
  const _Merchant({
    required this.name,
    required this.siteUrl,
    required this.redirectUrl,
  });

  final String name;
  final String siteUrl;
  final String redirectUrl;
}

class _DemoPayment {
  _DemoPayment({
    required this.amount,
    required this.returnUrl,
    required this.webhookUrl,
  });

  final int amount;
  final String returnUrl;
  final String webhookUrl;
  String status = 'pending';
}

final _payments = <String, _DemoPayment>{};
var _counter = 0;

String _env(String name, String fallback) {
  final value = Platform.environment[name];
  return value == null || value.trim().isEmpty ? fallback : value.trim();
}

Future<void> main() async {
  final port = int.tryParse(_env('FAKE_MONEYFUSION_PORT', '$_defaultPort'));
  final publicBaseUrl = _env(
    'FAKE_MONEYFUSION_PUBLIC_BASE_URL',
    _defaultPublicBaseUrl,
  ).replaceAll(RegExp(r'/+$'), '');
  final webhookUrl = _env('FAKE_MONEYFUSION_WEBHOOK_URL', _defaultWebhookUrl);
  final merchant = _Merchant(
    name: _env('FAKE_MONEYFUSION_SITE_NAME', 'Storylingo'),
    siteUrl: _env('FAKE_MONEYFUSION_SITE_URL', ''),
    redirectUrl: _env('FAKE_MONEYFUSION_REDIRECT_URL', ''),
  );

  final server = await HttpServer.bind(
    InternetAddress.anyIPv4,
    port ?? _defaultPort,
  );
  stdout.writeln(
    'Faux MoneyFusion sur 0.0.0.0:${server.port} '
    '(page publique : $publicBaseUrl, webhook : $webhookUrl, '
    'marchand : ${merchant.name})',
  );

  await for (final request in server) {
    unawaited(_serve(request, publicBaseUrl, webhookUrl, merchant));
  }
}

Future<void> _serve(
  HttpRequest request,
  String publicBaseUrl,
  String webhookUrl,
  _Merchant merchant,
) async {
  try {
    await _handle(request, publicBaseUrl, webhookUrl, merchant);
  } on Exception catch (error) {
    stdout.writeln('Erreur : $error');
    request.response.statusCode = HttpStatus.internalServerError;
    await request.response.close();
  }
}

Future<void> _handle(
  HttpRequest request,
  String publicBaseUrl,
  String webhookUrl,
  _Merchant merchant,
) async {
  final segments = request.uri.pathSegments;
  final method = request.method;

  if (method == 'POST' && segments.length == 1 && segments[0] == 'payments') {
    return _create(request, publicBaseUrl, webhookUrl);
  }
  if (method == 'GET' && segments.length == 2 && segments[0] == 'pay') {
    return _page(request, segments[1], merchant);
  }
  if (method == 'GET' &&
      segments.length == 3 &&
      segments[0] == 'pay' &&
      segments[2] == 'finish') {
    return _finish(request, segments[1], merchant);
  }
  if (method == 'GET' &&
      segments.length == 2 &&
      segments[0] == 'paiementNotif') {
    return _status(request, segments[1]);
  }
  if (method == 'GET' && segments.length == 1 && segments[0] == 'callback') {
    request.response
      ..headers.contentType = ContentType.html
      ..write(
        _htmlPage('Retour à ${merchant.name}', 'Revenez dans l’application.'),
      );
    return request.response.close();
  }

  request.response.statusCode = HttpStatus.notFound;
  await request.response.close();
}

Future<void> _create(
  HttpRequest request,
  String publicBaseUrl,
  String webhookUrl,
) async {
  final raw = await utf8.decoder.bind(request).join();
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    decoded = null;
  }
  final payload = decoded is Map<String, dynamic> ? decoded : null;
  final amount = payload?['totalPrice'];
  final article = payload?['article'];
  final numero = payload?['numeroSend'];
  final nom = payload?['nomclient'];
  final returnUrl = payload?['return_url'];
  final valid =
      payload != null &&
      amount is num &&
      amount > 0 &&
      article is List &&
      numero is String &&
      numero.trim().isNotEmpty &&
      nom is String &&
      nom.trim().isNotEmpty &&
      returnUrl is String &&
      Uri.tryParse(returnUrl)?.hasScheme == true;
  if (!valid) {
    request.response
      ..headers.contentType = ContentType.json
      ..write(
        jsonEncode({
          'statut': false,
          'message': 'Champs de paiement manquants.',
        }),
      );
    return request.response.close();
  }

  final token = 'demo-${DateTime.now().millisecondsSinceEpoch}-${++_counter}';
  _payments[token] = _DemoPayment(
    amount: amount.toInt(),
    returnUrl: returnUrl,
    webhookUrl: webhookUrl,
  );
  stdout.writeln('Création $token : ${amount.toInt()} FCFA');

  request.response
    ..headers.contentType = ContentType.json
    ..write(
      jsonEncode({
        'statut': true,
        'token': token,
        'message': 'paiement en cours',
        'url': '$publicBaseUrl/pay/$token',
      }),
    );
  await request.response.close();
}

Future<void> _page(
  HttpRequest request,
  String token,
  _Merchant merchant,
) async {
  final payment = _payments[token];
  if (payment == null) {
    request.response.statusCode = HttpStatus.notFound;
    return request.response.close();
  }
  request.response
    ..headers.contentType = ContentType.html
    ..write(
      _checkoutPage(
        token: token,
        amount: payment.amount,
        status: payment.status,
        merchant: merchant,
      ),
    );
  await request.response.close();
}

Future<void> _finish(
  HttpRequest request,
  String token,
  _Merchant merchant,
) async {
  final payment = _payments[token];
  if (payment == null) {
    request.response.statusCode = HttpStatus.notFound;
    return request.response.close();
  }
  final result = request.uri.queryParameters['result'];
  if (result != 'paid' && result != 'failure') {
    request.response.statusCode = HttpStatus.badRequest;
    return request.response.close();
  }
  payment.status = result == 'paid' ? 'paid' : 'failure';
  stdout.writeln('Paiement $token : ${payment.status}');

  await _notify(payment.webhookUrl, token);

  final target = merchant.redirectUrl.isEmpty
      ? payment.returnUrl
      : merchant.redirectUrl;
  request.response
    ..headers.contentType = ContentType.html
    ..write(
      _htmlPage(
        'Retour à ${merchant.name}',
        'Paiement enregistré. Redirection…',
        script: 'location.replace(${jsonEncode(target)});',
        fallbackHref: target,
      ),
    );
  await request.response.close();
}

Future<void> _notify(String webhookUrl, String token) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(Uri.parse(webhookUrl));
    request.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
    );
    request.write('token=${Uri.encodeQueryComponent(token)}');
    final response = await request.close();
    await response.drain<void>();
    stdout.writeln('Webhook $token : HTTP ${response.statusCode}');
  } on Exception catch (error) {
    stdout.writeln('Webhook indisponible : $error');
  } finally {
    client.close(force: true);
  }
}

Future<void> _status(HttpRequest request, String token) async {
  final payment = _payments[token];
  if (payment == null) {
    request.response.statusCode = HttpStatus.notFound;
    return request.response.close();
  }
  request.response
    ..headers.contentType = ContentType.json
    ..write(
      jsonEncode({
        'statut': true,
        'message': 'ok',
        'data': {
          'statut': payment.status,
          'Montant': payment.amount,
          'frais': 0,
          'moyen': 'orange',
          'numeroTransaction': 'demo-txn-$token',
        },
      }),
    );
  await request.response.close();
}

String _checkoutPage({
  required String token,
  required int amount,
  required String status,
  required _Merchant merchant,
}) {
  final site = merchant.siteUrl.isEmpty
      ? ''
      : '<p class="note">Site : ${_escape(merchant.siteUrl)}</p>';
  final body =
      '''
<h1>Paiement ${_escape(merchant.name)}</h1>
<p>Montant : <strong>$amount FCFA</strong></p>
<p>Statut actuel : $status</p>
<p>
  <a class="button" href="/pay/$token/finish?result=paid">Payer</a>
  <a class="button secondary" href="/pay/$token/finish?result=failure">Annuler</a>
</p>
$site
<p class="note">Faux backend de démonstration. Aucun paiement réel.</p>
''';
  return _htmlPage('Paiement ${merchant.name}', body, raw: true);
}

String _htmlPage(
  String title,
  String body, {
  bool raw = false,
  String? script,
  String? fallbackHref,
}) {
  final content = raw ? body : '<p>$body</p>';
  final fallback = fallbackHref == null
      ? ''
      : '<p><a href="${_escape(fallbackHref)}">Continuer</a></p>';
  final scriptTag = script == null ? '' : '<script>$script</script>';
  return '''
<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_escape(title)}</title>
<style>
body{font-family:system-ui,sans-serif;margin:0;padding:24px;color:#1b1b1f}
h1{font-size:1.4rem}
.button{display:inline-block;padding:12px 20px;border-radius:12px;background:#3b5bdb;color:#fff;text-decoration:none;margin-right:8px}
.secondary{background:#e7e9f5;color:#1b1b1f}
.note{color:#5f6368;font-size:.85rem}
</style>
</head>
<body>
$content
$fallback
</body>
$scriptTag
</html>
''';
}

String _escape(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
