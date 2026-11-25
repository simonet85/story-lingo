# Phase 15 Requirements — Paiement mobile money dans l'app

## Scope

Brancher dans l'app Flutter le paiement mobile money livré côté serveur en phase 14, derrière un flag désactivé par défaut :

- Serveur : `GET /v1/payments/moneyfusion/products` (public) expose les deux produits, leurs montants FCFA et leurs durées.
- Package : `money_fusion` consommé en dépendance Git épinglée au tag `v0.3.0` du dépôt `simonet85/flutter-fusion-money` (tag créé sur `main`).
- App : flag `MOBILE_MONEY_ENABLED` (défaut off) ; section « Payer par mobile money » dans le paywall ; écran dédié téléphone + nom ; création via notre backend ; checkout WebView fourni par le package ; attente bornée de l'entitlement serveur ; messages d'issue.
- Faux MoneyFusion local `tool/fake_moneyfusion/server.dart` (`dart:io`, zéro dépendance) : création, page « Payer » / « Annuler », `paiementNotif`, notification webhook vers notre serveur, retour via `return_url`.
- Android : vérification manuelle sur émulateur (paiement accepté, refusé, annulé, serveur arrêté) ; README mis à jour.

## Out of Scope

- iOS : aucune vérification possible (pas de Mac) et politique Apple 3.1.1 sur les abonnements numériques.
- Web, Windows et Linux : `webview_flutter` ne les supporte pas ; l'option est masquée.
- Appels réels à MoneyFusion : aucun secret, aucun paiement réel.
- PAYOUT, réception de webhooks côté app, renouvellement automatique, remboursements, polling d'arrière-plan.
- Achat sans compte : la création exige un JWT.
- Signature du webhook (décision phase 14).
- Nouvelle version du package `money_fusion` : la phase utilise `v0.3.0` tel quel.
- CI.

## Decisions

### Flag et disponibilité

`MOBILE_MONEY_ENABLED`, lu via `String.fromEnvironment`, désactivé par défaut. L'option n'est visible que si **toutes** ces conditions sont réunies :

- flag actif ;
- plateforme Android (`!kIsWeb` et `defaultTargetPlatform == TargetPlatform.android`) ;
- `API_BASE_URL` non vide (le serveur est indispensable).

Motif : vendre un abonnement numérique hors des stores viole les politiques Apple et Google Play ; le flag permet une distribution Android hors store (FCFA) sans changer le produit des stores. Ouvrir iOS et le web demanderait des vérifications et une décision produit hors phase.

Constantes `--dart-define` :

| Nom | Défaut | Rôle |
|---|---|---|
| `MOBILE_MONEY_ENABLED` | vide (off) | Active l'option mobile money. |
| `MONEYFUSION_STATUS_BASE_URL` | `https://pay.moneyfusion.net` | Base de `paiementNotif/{token}` lue par le package après le retour (affichage seulement). |

Aucun secret : le lien API MoneyFusion et les prix restent côté serveur.

### Endpoint produits

`GET /v1/payments/moneyfusion/products`, public (les prix ne sont pas sensibles et le paywall doit s'afficher avant connexion) :

```json
{"products": [
  {"productId": "storylingo_pro_monthly_xaf", "amount": 3500,  "days": 30,  "currency": "XAF"},
  {"productId": "storylingo_pro_yearly_xaf",  "amount": 30000, "days": 365, "currency": "XAF"}
]}
```

Montants lus dans `Settings` (mêmes variables d'environnement que la création) ; `503` si un prix est `<= 0`. Aucune autre donnée serveur n'est exposée.

Motif : les prix doivent rester dans une seule source côté serveur ; le package ne les connaît pas et l'app ne doit pas les coder en dur.

### Checkout : package `v0.3.0` tel quel

L'app construit une `PaymentSession` à partir de la réponse `{token, url}` du serveur, puis pousse `MoneyFusionCheckout` avec :

- un `MoneyFusionClient` créé pour l'occasion (`backendUrl` = notre création, jamais utilisé) dont seul `checkStatus` sert, avec `statusBaseUrl` issu de `MONEYFUSION_STATUS_BASE_URL` et un timeout court (5 s) ;
- le `returnUrl` = `<API_BASE_URL>/v1/payments/moneyfusion/return` (comparaison schéma/hôte/chemin, query ignorée).

Le résultat renvoyé par le widget sert **uniquement à l'affichage** : jamais de grant côté app. La vérité reste le webhook serveur (phase 14). Si le statut est `pending`, l'app attend la confirmation serveur.

Motif : le package ne permet pas d'ouvrir un checkout sans vérifier le statut ; le faire avec un timeout court borne l'attente et n'accorde rien. Faire évoluer le package (checkout sans vérification, `0.4.0`) est reporté : cela changerait le tag choisi et ajouterait une phase inter-dépôts sans bénéfice fonctionnel ici.

`MoneyFusion.pay` n'est pas utilisable : sa création poste le corps MoneyFusion direct, alors que notre backend attend `{productId, numeroSend, nomclient}`.

### Confirmation par l'entitlement serveur

Après le retour :

1. `PaymentCompleted` avec `paid` ou `pending` → l'écran interroge `EntitlementController.refresh(silent: true)` toutes les 2 s pendant 30 s au maximum ;
2. entitlement serveur actif → succès (« Abonnement actif. Bonne lecture ! »), retour au paywall ;
3. délai dépassé → « Paiement en attente de confirmation. L'abonnement s'activera dès validation. » (l'app reste utilisable, le paywall rafraîchit l'entitlement à l'ouverture) ;
4. `failure` / `noPaid` → « Paiement refusé ou annulé. » ;
5. `PaymentCancelled` → formulaire réactivé ;
6. `PaymentError` → message d'erreur réseau, formulaire réactivé.

La logique d'attente est isolée dans `MobileMoneyFlow` (refresh et `isEntitled` injectés), testable sans WebView ni horloge réelle.

### Écrans et providers

- Paywall : sous les offres existantes, section « Payer par mobile money » avec un bouton qui ouvre `/paywall/mobile-money?productId=<produit sélectionné>`. Les offres store (RevenueCat ou démo) et les prix en euros restent inchangés.
- `MobileMoneyScreen` (nouvelle route) : récupère les produits, affiche produit et montant, formulaire téléphone + nom, bouton désactivé pendant l'appel. Si l'utilisateur n'est pas connecté : message et lien vers `/account`, formulaire désactivé.
- Nouveau dossier `lib/features/billing/` : `data/mobile_money_api.dart`, `data/checkout_launcher_io.dart` + `checkout_launcher_stub.dart` (import conditionnel pour ne pas compiler `webview_flutter` sur le web), `domain/mobile_money_product.dart`, `application/mobile_money_providers.dart`, `application/mobile_money_flow.dart`, `presentation/mobile_money_screen.dart`.
- Le lanceur de checkout est injectable via un provider pour les tests de widget (aucune WebView en test).

### Faux MoneyFusion

`tool/fake_moneyfusion/server.dart`, lancé avec `dart run tool/fake_moneyfusion/server.dart`, écoute sur `0.0.0.0:8091` :

- `POST /payments` : valide `totalPrice`, `article`, `numeroSend`, `nomclient`, `return_url`, `webhook_url` ; renvoie `{statut: true, token: "demo-<n>", message, url: "<publicBase>/pay/<token>"}` et mémorise montant et `return_url` ;
- `GET /pay/<token>` : page HTML avec le montant, « Payer » et « Annuler » ;
- `GET /pay/<token>/finish?result=paid|failure` : met à jour le statut, **puis** poste le webhook `token` vers notre serveur, puis renvoie une page qui navigue vers le `return_url` par `location.replace(...)` ;
- `GET /paiementNotif/<token>` : `{statut: true, data: {Montant, frais, statut, moyen, numeroTransaction}}` (lu par le serveur pour le webhook et par l'app pour l'affichage) ;
- `GET /callback` : page de repli.

Configuration par variables d'environnement : `FAKE_MONEYFUSION_PORT` (8091), `FAKE_MONEYFUSION_PUBLIC_BASE_URL` (`http://10.0.2.2:8091`, joignable depuis l'émulateur), `FAKE_MONEYFUSION_WEBHOOK_URL` (`http://127.0.0.1:8000/v1/webhooks/moneyfusion`, notre serveur vu du poste).

Aucune donnée personnelle journalisée : seuls token, montant et statut.

### Configuration de démonstration

- Serveur lancé en écoute `0.0.0.0:8000` (sinon l'émulateur via `10.0.2.2` ne le joint pas) avec `STORYLINGO_DEV_AUTH=1`, `STORYLINGO_PUBLIC_BASE_URL=http://10.0.2.2:8000`, `STORYLINGO_MONEYFUSION_API_URL=http://127.0.0.1:8091/payments`, `STORYLINGO_MONEYFUSION_STATUS_BASE_URL=http://127.0.0.1:8091`.
- App : `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000 --dart-define=MOBILE_MONEY_ENABLED=true --dart-define=MONEYFUSION_STATUS_BASE_URL=http://10.0.2.2:8091`.
- Cleartext : déjà autorisé dans `android/app/src/debug/AndroidManifest.xml` ; les builds release restent HTTPS.

`public_base_url` sert aussi à `webhook_url` : `http://10.0.2.2:8000` n'est pas joignable depuis le poste, d'où la configuration explicite du webhook dans le faux serveur.

### Tag du package `v0.3.0`

Le dépôt `flutter-fusion-money` n'a pas encore de tag. La livraison crée `v0.3.0` sur `main` (commit de la phase 4) et le pousse sur `origin`, puis `story-lingo` déclare :

```yaml
money_fusion:
  git:
    url: https://github.com/simonet85/flutter-fusion-money.git
    ref: v0.3.0
```

L'épinglage par tag fige le code consommé ; `pubspec.lock` conserve le commit résolu. Le push du tag est une action sur un dépôt partagé : à confirmer avant exécution.

## Context

La phase 14 a livré la création, le webhook vérifié et l'entitlement `source = "moneyfusion"`, mais rien ne les utilise dans l'app. La phase 15 apporte le parcours visible, sans changer le contrat serveur existant, et installe le faux MoneyFusion qui rejoue la page de paiement et la notification en local. La vérité d'activation reste le webhook ; le statut MoneyFusion lu par le package n'est qu'un affichage.

Rappels inchangés : aucun secret dans l'app ni dans le faux serveur ; création côté backend uniquement ; téléphone, nom et token jamais journalisés ; l'app ne parle à MoneyFusion que pour le statut public du token.

## Stakeholder Notes

- **Développeurs des apps** : parcours Android testable de bout en bout avec deux terminaux (serveur, faux MoneyFusion) et un build à trois `--dart-define`.
- **Équipe backend** : un endpoint de lecture ajouté ; création et webhook inchangés.
- **Relecteurs** : l'option est invisible par défaut ; iOS et le web restent hors périmètre ; la vérification Android est manuelle et documentée.
