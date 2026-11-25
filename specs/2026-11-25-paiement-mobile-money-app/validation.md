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
dart format --output=none --set-exit-if-changed .
cd server && python -m pytest
```

Code 0 partout ; `tool/fake_moneyfusion/` est couvert par l'analyse et le formatage.

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

À compléter après exécution sur l'émulateur : environnement (Flutter, Android Studio, AVD), tableau des vérifications, notes d'environnement éventuelles, et conclusion « La phase est validée » le cas échéant.
