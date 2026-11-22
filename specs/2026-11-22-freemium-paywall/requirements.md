# Phase 13 — Exigences : Freemium & paywall

## Catalogue et publication

- **FR-13.1** — Sleepy Hollow et The Night Train restent gratuits ; tout autre
  livre publié sans drapeau est payant.
- **FR-13.2** — La publication accepte `--free` ou `--paid` ; republier sans
  drapeau conserve le statut existant.
- **FR-13.3** — Le manifeste servi (`/v1/books/{id}`) et le descripteur de
  téléchargement exposent `isFree`, y compris hors-ligne dans le pack installé.
- **FR-13.4** — Le catalogue (`/v1/catalogue`) continue d'exposer `isFree` par
  livre.

## Entitlements serveur

- **FR-13.5** — `GET /v1/entitlements` authentifié retourne l'état actif, le
  statut, la source, le produit et l'échéance ; sans abonnement, `active=false`.
- **FR-13.6** — Un abonnement annulé reste actif jusqu'à son échéance ; expiré
  au-delà. Une ligne absente est inactive.
- **FR-13.7** — `POST /v1/webhooks/revenuecat` vérifie un secret partagé et
  applique les événements d'achat, renouvellement, annulation, expiration,
  incident de facturation, changement de produit et transfert.
- **FR-13.8** — Un événement plus ancien ou rejoué n'écrase pas un état plus
  récent (`last_event_ms`).
- **FR-13.9** — Les routes dev grant/revoke ne sont disponibles que lorsque
  l'authentification de développement est activée.

## Facturation client

- **FR-13.10** — Sans clé RevenueCat, les achats et restaurations sont simulés
  localement et persistent après redémarrage ; aucune exception de plugin.
- **FR-13.11** — Avec `REVENUECAT_API_KEY` sur mobile, les offres, achats,
  restaurations et l'entitlement `storylingo_pro` passent par le SDK.
- **FR-13.12** — L'état d'abonnement combine SDK/démo et entitlement serveur en
  cache ; une échéance passée rend le cache inactif, le mode hors-ligne conserve
  le dernier état valide.
- **FR-13.13** — La connexion lie RevenueCat à l'utilisateur applicatif ; la
  déconnexion repasse en anonyme.

## Accès et UI

- **FR-13.14** — Un livre gratuit ou possédé hors-ligne (pack installé) reste
  toujours lisible, même abonnement expiré ou hors réseau.
- **FR-13.15** — Un livre payant sans abonnement ni pack installé affiche un
  verrou sur la carte, un CTA vers `/paywall` et aucun bouton de téléchargement.
- **FR-13.16** — Les routes `/read/:bookId` et `/read/:bookId/:chapterId`
  affichent l'écran verrouillé (avec accès aux offres) au lieu du contenu.
- **FR-13.17** — Le paywall présente les bénéfices, les offres mensuelle et
  annuelle, l'achat, la restauration et « Plus tard » ; après achat, l'utilisateur
  revient au livre demandé.
- **FR-13.18** — Réglages expose l'état de l'abonnement, l'échéance, l'accès aux
  offres et la restauration.
- **FR-13.19** — Les copies françaises sont chaleureuses, sans culpabilisation
  ni fausse urgence.
- **FR-13.20** — Le web compile et permet l'aperçu du paywall en mode démo,
  sans initialiser le SDK natif.

## Sécurité et limites

- **SEC-13.1** — Aucune clé ni secret dans le dépôt ; clés RevenueCat via
  `--dart-define`, secret webhook via variable d'environnement.
- **SEC-13.2** — Le webhook compare le secret en temps constant et refuse les
  requêtes non authentifiées.
- **SEC-13.3** — Les endpoints de contenu restent publics : le verrouillage est
  une règle client, documentée comme limite anti-piratage.
- **SEC-13.4** — Aucun jeton ni courriel n'est journalisé par les nouvelles
  routes.
