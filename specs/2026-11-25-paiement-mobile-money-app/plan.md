# Phase 15 Plan — Paiement mobile money dans l'app

## Vue d'ensemble

1. Épingler le package (`tag v0.3.0` sur `flutter-fusion-money`) et l'ajouter à `story-lingo`.
2. Exposer les produits côté serveur (endpoint public + tests).
3. Ajouter la couche app : API, flow, providers, écran, gating par flag.
4. Relier le paywall et la route.
5. Installer le faux MoneyFusion de démonstration.
6. Documenter et vérifier sur émulateur.

Aucune modification du contrat de création ni du webhook. Aucun secret dans l'app.

## Prérequis — tag du package (à confirmer)

Le dépôt `simonet85/flutter-fusion-money` est sur `main` au commit de la phase 4, sans tag.

```bash
git -C ../FlutterFusionMoney tag v0.3.0 main
git -C ../FlutterFusionMoney push origin v0.3.0
```

Puis dans `story-lingo/pubspec.yaml` :

```yaml
money_fusion:
  git:
    url: https://github.com/simonet85/flutter-fusion-money.git
    ref: v0.3.0
```

`flutter pub get` doit résoudre le paquet depuis Git (pas de `path`), et `pubspec.lock` doit contenir `ref: v0.3.0` avec le commit résolu.

## Tâches serveur

### 1. `GET /v1/payments/moneyfusion/products`

Dans `server/app/payments.py`, route publique (sans `UserDep`), avant ou après la création, sans conflit de chemin :

```python
@router.get("/payments/moneyfusion/products")
def list_products(settings: Settings = Depends(get_settings)) -> dict[str, Any]:
    products = _products(settings)
    if any(product.price <= 0 for product in products.values()):
        raise HTTPException(status_code=503, detail="Paiement indisponible.")
    return {
        "products": [
            {"productId": product_id, "amount": product.price,
             "days": product.days, "currency": "XOF"}
            for product_id, product in products.items()
        ]
    }
```

Pas de `_require_config` : l'API link et `public_base_url` ne sont pas nécessaires pour lire les prix.

### 2. Tests serveur

Dans `server/tests/test_payments.py` :

- sans authentification → `200`, deux produits, `amount` = prix configurés (défauts 3500 / 30000), `days` 30 / 365, `currency` `"XOF"` ;
- prix surchargés par l'environnement → valeurs renvoyées ;
- prix `0` → `503` ;
- la réponse ne contient ni `STORYLINGO_MONEYFUSION_API_URL` ni d'URL MoneyFusion.

### 3. Documentation serveur

`server/README.md`, section « MoneyFusion payments » : décrire l'endpoint produits (public, lecture seule).

## Tâches app

### 4. Configuration

`lib/core/config/api_config.dart` :

```dart
final mobileMoneyEnabledProvider = Provider<bool>((ref) {
  const raw = String.fromEnvironment('MOBILE_MONEY_ENABLED');
  return raw.trim().toLowerCase() == 'true';
});

/// Base lue par le package après le retour (affichage seulement).
final moneyFusionStatusBaseUrlProvider = Provider<String>((ref) {
  const raw = String.fromEnvironment(
    'MONEYFUSION_STATUS_BASE_URL',
    defaultValue: 'https://pay.moneyfusion.net',
  );
  return raw.trim();
});
```

### 5. Domaine et API

`lib/features/billing/domain/mobile_money_product.dart` :

- `MobileMoneyProduct {productId, amount, days, currency}` ;
- constantes `storylingo_pro_monthly_xof` / `storylingo_pro_yearly_xof` ;
- libellés `titleFr` (« Mensuel » / « Annuel »), `priceLabel` (« 3 500 FCFA »), `periodLabel` (« / mois », « / an ») ;
- ignore les produits inconnus côté API.

`lib/features/billing/data/mobile_money_api.dart` (modèle : `EntitlementsApi`) :

- `fetchProducts()` → `GET <root>/v1/payments/moneyfusion/products` sans auth, timeout 10 s ;
- `createPayment({required String accessToken, required String productId, required String phone, required String name})` → `POST <root>/v1/payments/moneyfusion` avec `Authorization: Bearer`, corps `{"productId", "numeroSend", "nomclient"}`, retour `MobileMoneyCheckoutRequest {token, url (Uri), productId, amount}` ;
- `MobileMoneyException` avec `unauthorized` ; messages en français ; aucune valeur de téléphone/nom dans les messages ;
- décodage et validations symétriques à `EntitlementsApi` (401 → session expirée, statut ≠ 200 → `detail`, champs manquants → « Réponse de paiement invalide. »).

### 6. Flow et providers

`lib/features/billing/application/mobile_money_providers.dart` :

- `mobileMoneyAvailableProvider` = flag && `!kIsWeb` && `defaultTargetPlatform == TargetPlatform.android` && `apiBaseUrlProvider` non vide ;
- `mobileMoneyApiProvider` (base = `apiBaseUrlProvider`) ;
- `mobileMoneyFlowProvider` construit avec `refresh: () => ref.read(entitlementControllerProvider.notifier).refresh(silent: true)` et `isEntitled: () => ref.read(isEntitledProvider)` ;
- `checkoutLauncherProvider` (lanceur injectable, défaut = implémentation par plateforme).

`lib/features/billing/application/mobile_money_flow.dart` :

```dart
class MobileMoneyFlow {
  MobileMoneyFlow({
    required this.api,
    required this.refresh,
    required this.isEntitled,
    this.interval = const Duration(seconds: 2),
    this.confirmationTimeout = const Duration(seconds: 30),
  });
  Future<MobileMoneyProduct?> loadProduct(String productId);
  Future<MobileMoneyCheckoutRequest> start({accessToken, productId, phone, name});
  Future<bool> confirm(); // boucle refresh + isEntitled, bornée
  Uri get returnUrl; // <root>/v1/payments/moneyfusion/return
}
```

`confirm()` : si actif → `true` immédiatement ; sinon `refresh()` (exceptions avalées) puis attente `interval` ; s'arrête au premier `isEntitled()` vrai ou au timeout → `false`.

### 7. Lanceur de checkout

- `lib/features/billing/data/checkout_launcher.dart` (import conditionnel) ;
- `checkout_launcher_stub.dart` : renvoie `null` (jamais atteint sur le web, l'option y est masquée) ;
- `checkout_launcher_io.dart` :

```dart
Future<PaymentResult?> launchMoneyFusionCheckout(
  BuildContext context, {
  required MobileMoneyCheckoutRequest request,
  required Uri returnUrl,
  required String statusBaseUrl,
  required Uri backendUrl,
}) async {
  final client = MoneyFusionClient(
    backendUrl: backendUrl,
    statusBaseUrl: Uri.parse(statusBaseUrl),
    timeout: const Duration(seconds: 5),
  );
  try {
    return await Navigator.of(context).push<PaymentResult>(
      MaterialPageRoute(
        builder: (_) => MoneyFusionCheckout(
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
```

`backendUrl` = `<API_BASE_URL>/v1/payments/moneyfusion` (jamais appelé par le widget, requis par le constructeur).

### 8. Écran formulaire

`lib/features/billing/presentation/mobile_money_screen.dart` (`ConsumerStatefulWidget`, produit en paramètre) :

- charge `loadProduct` dans `initState`, affiche titre + montant + durée, erreur avec « Réessayer » ;
- champs `TextFormField` téléphone (clavier téléphone, validation : non vide, ≥ 8 caractères, chiffres/espaces/`+`) et nom (non vide, ≤ 80) ;
- si non connecté : texte « Connectez-vous pour payer par mobile money. », bouton « Se connecter » (`context.push('/account')`), formulaire désactivé ;
- bouton « Payer <montant> » : désactivé pendant l'appel ; `ensureSession()` → `flow.start(...)` → `launchMoneyFusionCheckout` ;
- traitement du résultat :
  - `PaymentCompleted(paid|pending)` → état « Confirmation du paiement… », `flow.confirm()` ; succès → snackbar « Abonnement actif. Bonne lecture ! » + pop ; sinon message d'attente ;
  - `PaymentCompleted(failure|noPaid)` → « Paiement refusé ou annulé. » ;
  - `PaymentCancelled` → formulaire réactivé ;
  - `PaymentError` / `MobileMoneyException` → message, formulaire réactivé ;
- aucun log de téléphone, nom ou token.

### 9. Paywall et route

- `lib/features/billing/presentation/paywall_screen.dart` : si `mobileMoneyAvailableProvider`, après les offres, encart « Payer par mobile money (FCFA) » + bouton qui pousse `/paywall/mobile-money?productId=<mapping de l'offre sélectionnée>` (mensuel → `storylingo_pro_monthly_xof`, annuel → `storylingo_pro_yearly_xof`) ; désactivé pendant `_busy`.
- `lib/core/router/app_router.dart` : `GoRoute(path: '/paywall/mobile-money', builder: ... MobileMoneyScreen(productId))`.

## Tâches faux serveur et outillage

### 10. `tool/fake_moneyfusion/server.dart`

`dart:io` seul, `0.0.0.0:8091`, journal minimal (token, montant, statut) :

- `POST /payments` : valide les champs du contrat, `token = demo-<n>`, stocke `amount` et `return_url`, renvoie `url` sur `FAKE_MONEYFUSION_PUBLIC_BASE_URL` ;
- `GET /pay/<token>` : HTML « Payer » / « Annuler » ;
- `GET /pay/<token>/finish?result=paid|failure` : statut mis à jour, webhook `application/x-www-form-urlencoded` `token=<token>` vers `FAKE_MONEYFUSION_WEBHOOK_URL`, puis HTML `location.replace(<return_url>)` (avec lien de secours) ;
- `GET /paiementNotif/<token>` : JSON du contrat, statut courant, `frais: 0`, `moyen: "orange"`, `numeroTransaction: "demo-txn-<token>"` ;
- `GET /callback` : page de repli ; autres chemins → `404`.

### 11. Tests Flutter

- `test/mobile_money_api_test.dart` (`MockClient`) : produits (parse, produits inconnus filtrés), création (URL, Bearer, corps exact), mapping 401/400/502, champs manquants ;
- `test/mobile_money_flow_test.dart` : `confirm()` avec fake `refresh`/`isEntitled` (actif immédiat, actif après 2 refresh, timeout court par intervalle réduit), `start` délègue à l'API, `returnUrl` exact ;
- `test/mobile_money_screen_test.dart` : flag off → pas de bouton dans le paywall ; disponible → bouton visible et route ; formulaire vide → erreurs sans appel ; soumission avec lanceur injecté renvoyant `PaymentCompleted(paid)` + entitlement simulé → message de succès ; `PaymentCancelled` → formulaire réactivé ;
- mises à jour de `test/paywall_flow_test.dart` si nécessaire (aucune régression sans flag).

### 12. Documentation

`README.md` (racine) : spec de la phase (liens) ; section « Paiement mobile money (démo Android) » : tag du package, trois terminaux (serveur, faux MoneyFusion, app), commandes complètes, alias `10.0.2.2`, cleartext limité au debug, limites (iOS non vérifié, distribution hors store).

## Vérifications

```bash
# serveur
cd server && python -m pytest

# package
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Manuel (émulateur Android) :

1. serveur (`STORYLINGO_DEV_AUTH=1`, `PUBLIC_BASE_URL=http://10.0.2.2:8000`, API et statut MoneyFusion sur `127.0.0.1:8091`, écoute `0.0.0.0:8000`) ;
2. faux MoneyFusion (`dart run tool/fake_moneyfusion/server.dart`) ;
3. app avec les trois `--dart-define` ; connexion via l'écran Compte ;
4. paywall → « Payer par mobile money » → formulaire → page factice :
   - « Payer » → webhook appliqué → entitlement actif (réglages : actif, expiration +30 j ou +365 j) ;
   - « Annuler » → « Paiement refusé ou annulé. », aucun entitlement ;
   - croix (`X`) → `PaymentCancelled`, formulaire réactivé ;
   - serveur arrêté → `PaymentError` réseau dès la création ;
5. vérifier l'absence de téléphone/nom/token dans les logs serveur et du faux serveur.

## Livraison

1. Confirmer puis pousser le tag `v0.3.0` sur `flutter-fusion-money` (dépôt partagé).
2. Commiter spec + implémentation sur `feature/paiement-mobile-money-app`.
3. Remplir `validation.md` (résultats, environnement, artefacts).
4. Relecture, merge fast-forward dans `main`, push, suppression de la branche — sur accord explicite.
