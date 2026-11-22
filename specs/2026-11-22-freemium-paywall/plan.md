# Phase 13 — Plan : Freemium & paywall

## Objectif

Garder Sleepy Hollow et The Night Train gratuits, verrouiller les futurs livres
derrière un abonnement mensuel ou annuel (RevenueCat), avec restauration, état
synchronisé côté serveur et écrans de conversion sans culpabilisation.

## Décisions

- Livres gratuits : `sleepy-hollow` (pilote) et `night-train`. Les nouveaux livres
  sont payants par défaut ; la publication choisit via `--free` / `--paid`.
- Facturation : `purchases_flutter` derrière une interface `BillingGateway` ;
  sans clé RevenueCat (`REVENUECAT_API_KEY` en `--dart-define`), un gateway démo
  simule achat et restauration. Le web reste en démo (aperçu).
- Serveur « hybride léger » : `books.is_free` à la publication, table
  `subscriptions`, `GET /v1/entitlements`, webhook RevenueCat signé, dev
  grant/revoke. Les endpoints de contenu restent publics (gating client).
- Paywall dédié `/paywall?bookId=` + section « Abonnement » dans Réglages.

## Serveur

- `subscriptions` : une ligne par utilisateur (`user_id` PK, `status`, `source`,
  `product_id`, `expires_at_ms`, `last_event_ms`, `last_event_type`, `updated_at`).
- `GET /v1/entitlements` (JWT) : `{active, status, source, productId, expiresAt,
  checkedAt}`. Actif si statut actif/grâce/annulé et expiration future ou nulle.
- `POST /v1/webhooks/revenuecat` : secret partagé en header `Authorization`
  (`hmac.compare_digest`), événements INITIAL_PURCHASE/RENEWAL/UNCANCELLATION/
  PRODUCT_CHANGE → actif, BILLING_ISSUE → grâce, CANCELLATION → annulé (actif
  jusqu'à expiration), EXPIRATION → expiré, TRANSFER → des deux côtés. Écriture
  seulement si l'événement est plus récent (`last_event_ms`).
- Dev : `POST /v1/entitlements/dev-grant` et `dev-revoke`, 404 hors `dev_auth`.
- `publish_pack(..., is_free=...)` : nouveau livre payant par défaut, republication
  sans drapeau conserve le flag ; injection de `isFree` dans le manifeste servi et
  le descripteur. CLI `import_book.py --free/--paid`.

## Flutter

- `BillingGateway` (`configure`, `logIn/logOut`, `loadOffers`, `refresh`,
  `purchase`, `restore`) + démo persistée (mensuel 3,99 €/mois, annuel
  29,99 €/an) + RevenueCat (`storylingo_pro`) isolé par import conditionnel.
- `EntitlementController` : union entitlement SDK/démo et cache serveur
  (expiration respectée), cache prefs, rafraîchissement au démarrage, à la
  connexion/déconnexion, au paywall et après achat/restauration.
- `BookAccess` : installé > abonné > gratuit > verrouillé > inconnu. Un pack
  installé reste lisible après expiration ou hors-ligne.
- `BookManifest.isFree` optionnel (défaut vrai) ; `CatalogueBook.fromManifest`
  l'utilise.
- Carte payante verrouillée → `/paywall` ; `BookDownloadControl` masqué ;
  `BookAccessGate` sur les routes de lecture (deep links inclus) ; écran verrouillé.
- Paywall : bénéfices, offres mensuelle/annuelle, achat, restauration, « Plus
  tard ». Succès → retour au livre demandé.
- Réglages : section Abonnement (statut, échéance, offres, restauration, note
  connexion).

## Vérification

`flutter analyze`, `flutter test`, `python -m pytest server/tests
tools/content/tests`, `flutter build web`, puis scénario Android en mode démo
(verrou, paywall, achat, restauration, dev grant/revoke, lecture hors-ligne d'un
pack installé) et régression web. Voir `validation.md`.
