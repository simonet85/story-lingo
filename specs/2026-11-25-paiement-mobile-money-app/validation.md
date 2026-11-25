# Phase 15 Validation — Paiement mobile money dans l'app

## Definition of Done

Tout ce qui suit doit être vrai avant de fusionner la branche dans `main`.

### 1. Le package est consommé depuis le tag

- `flutter pub get` résout `money_fusion` depuis Git, `ref: v0.3.0` (aucun `path`) ;
- le tag `v0.3.0` du dépôt `flutter-fusion-money` pointe sur le commit de la phase 4 de `main` ;
- `pubspec.lock` contient la source Git et le commit résolu.

### 2. L'analyse et le formatage sont propres

```
flutter analyze
dart format --output=none --set-exit-if-changed lib/features/billing/domain/mobile_money_product.dart lib/features/billing/data/mobile_money_api.dart lib/features/billing/data/checkout_launcher.dart lib/features/billing/data/checkout_launcher_stub.dart lib/features/billing/data/checkout_launcher_io.dart lib/features/billing/application/mobile_money_flow.dart lib/features/billing/application/mobile_money_providers.dart lib/features/billing/presentation/mobile_money_screen.dart lib/features/billing/presentation/paywall_screen.dart lib/core/config/api_config.dart lib/core/router/app_router.dart tool/fake_moneyfusion test/mobile_money_api_test.dart test/mobile_money_flow_test.dart test/mobile_money_screen_test.dart
cd server && python -m pytest
```

Code 0 partout ; `tool/fake_moneyfusion/` est couvert par l'analyse et le formatage.

> Note : le formatage porte sur les fichiers de la phase. Le dépôt contient
> 46 fichiers antérieurs non formatés selon Dart 3.14 ; les reformater dans
> cette phase brouillerait la revue.

### 3. Les tests passent

- `flutter test` : code 0, tests existants toujours verts, plus les tests mobile money (API, flow, écran, gating) ;
- `pytest` : code 0, tests de la phase 14 toujours verts, plus l'endpoint produits.

### 4. L'endpoint produits respecte le contrat

- `GET /v1/payments/moneyfusion/products` sans jeton → `200` ;
- deux produits `storylingo_pro_monthly_xaf` (3500, 30 j) et `storylingo_pro_yearly_xaf` (30000, 365 j), `currency: "XAF"` ;
- montants issus de `STORYLINGO_MONEYFUSION_PRICE_*` ;
- prix `0` → `503` ;
- aucune URL MoneyFusion ni secret dans la réponse.

### 5. La création et le webhook sont inchangés

- `POST /v1/payments/moneyfusion` et `POST /v1/webhooks/moneyfusion` : mêmes contrats, mêmes tests qu'en phase 14 (aucune régression) ;
- l'app n'envoie jamais de secret ; le lien API reste côté serveur.

### 6. Le flag masque tout par défaut

- sans `MOBILE_MONEY_ENABLED`, aucune section mobile money dans le paywall, aucune route accessible depuis l'UI ;
- flag actif mais `API_BASE_URL` vide → option absente ;
- flag actif sur le web → option absente (`kIsWeb`) ;
- builds release sans cleartext (déjà le cas : `usesCleartextTraffic` uniquement en debug).

### 7. Le faux MoneyFusion se comporte comme le contrat

Vérifié à la main (curl) :

- `POST /payments` incomplet → `statut: false` ; complet → `statut: true`, `token`, `url` pointant sur `FAKE_MONEYFUSION_PUBLIC_BASE_URL` ;
- `GET /pay/<token>` : montant, « Payer », « Annuler » ;
- `GET /pay/<token>/finish?result=paid` → webhook reçu par le serveur, entrée `moneyfusion_payments` passée à `paid`, entitlement appliqué ;
- `result=failure` → statut `failed`, aucun grant ;
- `GET /paiementNotif/<token>` → `data` avec `Montant`, `frais`, `statut`, `moyen`, `numeroTransaction` ;
- navigation de retour par JavaScript (pas de 302), détectée par la WebView.

### 8. La démo fonctionne sur émulateur Android

Serveur (écoute `0.0.0.0:8000`, `PUBLIC_BASE_URL=http://10.0.2.2:8000`), faux MoneyFusion (`0.0.0.0:8091`), app avec `API_BASE_URL=http://10.0.2.2:8000`, `MOBILE_MONEY_ENABLED=true`, `MONEYFUSION_STATUS_BASE_URL=http://10.0.2.2:8091`.

- « Payer » → page de retours, « Confirmation du paiement… », entitlement actif dans les réglages, expiration cohérente (30 j mensuel, 365 j annuel) ;
- « Annuler » → « Paiement refusé ou annulé. », aucun entitlement ;
- croix de fermeture → `PaymentCancelled`, formulaire réactivé ;
- serveur arrêté → `PaymentError` réseau à la création, message affiché ;
- utilisateur déconnecté → formulaire désactivé avec lien de connexion ;
- aucun téléphone, nom ou token dans les logs serveur/app.

### 9. Le README permet de rejouer la démo

Section « Paiement mobile money (démo Android) » : tag du package, commandes serveur, faux MoneyFusion et app, alias `10.0.2.2`, cleartext debug, limites (iOS non vérifié, distribution hors store). Prérequis mis à jour.

### 10. Aucun appel réel à MoneyFusion

Aucun secret, aucun paiement réel ; l'app ne contacte le statut MoneyFusion que via le faux serveur en démo. Les tests utilisent `MockClient` et `TestClient`, sans réseau.

## Not Required

- Vérification iOS : aucun Mac ; politique Apple sur les abonnements numériques
- Support web, Windows, Linux
- Appels réels MoneyFusion, PAYOUT, webhooks côté app, renouvellement, remboursement
- Achat sans compte, polling d'arrière-plan
- Évolution du package au-delà de `v0.3.0`
- CI

## Résultat de validation

### Environnement

- Flutter 3.50.1 (stable, révision `ae9b586f34`), Dart 3.14.0
- Android SDK `C:/dev/android-sdk`, émulateur `demo36` (Android 16, API 36)
- Serveur : FastAPI local sur `0.0.0.0:8000`, base SQLite temporaire de démo
- Faux MoneyFusion : `dart run tool/fake_moneyfusion/server.dart` sur `0.0.0.0:8091`

### Vérifications automatisées

| Commande | Résultat |
| --- | --- |
| `flutter pub get` + `pubspec.lock` | `money_fusion` résolu depuis Git, `ref: v0.3.0`, commit `66c5eebbbbe9b386133542ade9d4a8c044c34b3e` |
| `flutter analyze` | 0 problème |
| `dart format --set-exit-if-changed` (fichiers de la phase) | 0 fichier modifié |
| `flutter test` | 308 tests verts (286 existants + 22 mobile money) |
| `pytest` (serveur) | 113 tests verts (109 existants + 4 produits) |

### Contrat HTTP vérifié à la main (curl)

- `GET /v1/payments/moneyfusion/products` → `200`, deux produits, montants et
  durées issus de la configuration, aucune URL MoneyFusion ;
- `POST /v1/payments/moneyfusion` → `200`, `token`, `url` sur
  `http://10.0.2.2:8091/pay/<token>` ;
- `finish?result=paid` → webhook `HTTP 200`, entitlement `source:
  "moneyfusion"`, expiration +30 jours (mensuel) ;
- `finish?result=failure` → webhook `HTTP 200`, entitlement `active: false` ;
- `GET /paiementNotif/<token>` → `statut`, `Montant`, `frais`, `moyen`,
  `numeroTransaction` conformes.

Note d'implémentation : le faux serveur sert les requêtes en concurrence
(sinon le webhook attend `finish`, qui attend le webhook → blocage), et ses
tokens incluent un horodatage pour rester uniques entre deux redémarrages.

### Vérifications sur émulateur Android

APK debug construit avec `--dart-define=API_BASE_URL=http://10.0.2.2:8000`,
`MOBILE_MONEY_ENABLED=true`, `MONEYFUSION_STATUS_BASE_URL=http://10.0.2.2:8091`,
installé sur `demo36` et parcouru par taps (`adb`).

| Scénario | Attendu | Constaté |
| --- | --- | --- |
| Flag actif, paywall ouvert | section « Mobile money (FCFA) » visible | conforme |
| Achat annuel, « Payer » | retour JS détecté, polling, abonnement actif | « Storylingo Pro — Actif jusqu’au 25/11/2027 » (365 j), webhook `HTTP 200` |
| « Annuler » sur la page de paiement | message d’échec, formulaire réactivé | « Paiement refusé ou annulé. », champs conservés |
| Croix de fermeture du checkout | `PaymentCancelled`, formulaire réactivé | « Paiement annulé. » |
| Serveur arrêté avant « Payer » | erreur réseau à la création | « Le serveur ne répond pas. Réessayez. » |
| Utilisateur déconnecté | formulaire désactivé + lien de connexion | carte « Connectez-vous pour payer par mobile money. » + bouton, champs grisés |
| Journaux | aucun téléphone, nom ou token | `logcat` : 0 occurrence ; journaux du backend : ni téléphone ni nom (le faux serveur local trace son propre token de démo) |

Note : le premier build a échoué faute de `platforms;android-35` dans le SDK ;
installation via `sdkmanager`, puis build nominal.

### Conclusion

La phase est validée sur les 10 points du DoD, dans la limite du « Not
Required » ci-dessus.


