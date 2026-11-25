# Phase 14 — Exigences : Paiement mobile money (backend)

## Scope

Préparer la vente de l'abonnement Storylingo par mobile money via MoneyFusion,
côté serveur uniquement :

- Deux produits en FCFA : mensuel (30 jours) et annuel (365 jours), prix
  configurables par l'environnement, montants entiers positifs.
- Création de paiement serveur → MoneyFusion (le lien API et le secret restent
  exclusivement côté serveur).
- Endpoint authentifié qui renvoie le `token` et l'`url` de paiement à un
  client futur.
- Webhook MoneyFusion qui déclenche une **revérification serveur** du statut,
  puis accorde l'entitlement existant (`source = "moneyfusion"`) de façon
  idempotente.
- Page de retour minimale (aucune mutation d'état) pour le backend-first.
- Documentation des variables d'environnement dans `server/README.md`.

Le package Flutter `money_fusion` n'est **pas** consommé par cette phase : le
canal de vente dans l'app (contraintes Apple/Google) est une décision produit
reportée, volontairement séparée du socle serveur.

## Functional Requirements

### Produits et configuration

- **FR-14.1** — Deux produits : `storylingo_pro_monthly_xof` (30 jours) et
  `storylingo_pro_yearly_xof` (365 jours), exposés par la création.
- **FR-14.2** — Montants en FCFA entiers positifs, lus dans
  `STORYLINGO_MONEYFUSION_PRICE_MONTHLY_XOF` /
  `STORYLINGO_MONEYFUSION_PRICE_YEARLY_XOF` (défauts de développement :
  3 500 et 30 000, à confirmer par le produit avant production).
- **FR-14.3** — Le lien API MoneyFusion vient de
  `STORYLINGO_MONEYFUSION_API_URL`, la base de statut de
  `STORYLINGO_MONEYFUSION_STATUS_BASE_URL` (défaut
  `https://pay.moneyfusion.net`). Création indisponible (503) si le lien API,
  `STORYLINGO_PUBLIC_BASE_URL` ou un prix valide manque.

### Création de paiement

- **FR-14.4** — `POST /v1/payments/moneyfusion` exige un JWT (`require_user`) ;
  l'identité vient du jeton, jamais du corps.
- **FR-14.5** — Corps : `{productId, numeroSend, nomclient}`. Produit inconnu,
  champ manquant ou vide → 400.
- **FR-14.6** — Le serveur appelle MoneyFusion avec `totalPrice` (prix serveur,
  jamais le client), `article` = `[{"paiement": <montant>}]`, `numeroSend`,
  `nomclient`, `return_url` = `{public_base_url}/v1/payments/moneyfusion/return`
  et `webhook_url` = `{public_base_url}/v1/webhooks/moneyfusion`.
- **FR-14.7** — Succès MoneyFusion (`statut: true`) → 200
  `{token, url, productId, amount}` et une ligne `pending` enregistrée
  (token, user, produit, montant). Échec (`statut: false`, HTTP non 2xx,
  réponse illisible, timeout 30 s) → 502 avec message générique, sans ligne.
- **FR-14.8** — `GET /v1/payments/moneyfusion/return` renvoie une page HTML
  minimale « Retour à l'application » sans lire ni modifier aucun paiement.

### Webhook et entitlement

- **FR-14.9** — `POST /v1/webhooks/moneyfusion` accepte un corps JSON ou
  formulaire ; le `token` est obligatoire. Token inconnu → 404, corps
  illisible → 400.
- **FR-14.10** — Le webhook ne fait pas foi : le serveur appelle
  `GET {status_base}/paiementNotif/{token}` et n'utilise que la réponse
  `data` (`statut`, `Montant`, `numeroTransaction`).
- **FR-14.11** — `data.statut == "paid"` **et** `Montant` égal au montant stocké
  → entitlement accordé : `status = "active"`, `source = "moneyfusion"`,
  `product_id = storylingo_pro_*`, échéance `maintenant + 30/365 jours`,
  `last_event_type = "MONEYFUSION_PAID"`. Réponse 200 `{ok: true,
  applied: true}` ; la ligne passe à `paid` avec le numéro de transaction.
- **FR-14.12** — Idempotence : un token déjà appliqué ou un nouveau webhook sur
  un paiement payé ne prolonge jamais l'échéance → 200 `{ok: true,
  applied: false}`.
- **FR-14.13** — `data.statut` `failure` ou `no paid` → paiement marqué
  `failed`, aucun entitlement, 200 `{ok: true, applied: false,
  status: "failed"}`. `pending` → 200 `{ok: true, applied: false,
  status: "pending"}` sans mutation.
- **FR-14.14** — `Montant` différent du montant stocké → 400, aucun
  entitlement, paiement laissé `pending` pour investigation.
- **FR-14.15** — `GET /v1/entitlements` expose l'abonnement mobile money via le
  contrat inchangé (`source = "moneyfusion"`, `productId`, `expiresAt`) ;
  l'expiration est déjà gérée par le serveur.
- **FR-14.16** — `POST /v1/webhooks/revenuecat` et les routes existantes ne
  changent pas ; le helper d'écriture d'entitlement accepte une `source`
  (défaut `revenuecat`) sans modifier les tests existants.

## Out of Scope

- Interface d'achat dans l'app et dépendance à `money_fusion` : décision
  produit après cette phase (politiques Apple/Google sur les achats intégrés).
- Signature des webhooks MoneyFusion : la sécurité repose sur la revérification
  serveur, pas sur un secret partagé.
- Renouvellement automatique : le mobile money est un paiement unique par
  période ; pas de prélèvement récurrent.
- Remboursements, PAYOUT/retraits, factures, e-mails de confirmation.
- Coexistence fine RevenueCat / mobile money : `subscriptions` garde une ligne
  par utilisateur, dernier événement gagnant (limite documentée).
- Limitation de débit sur la création de paiements (abonné authentifié requis).
- Appel réel à MoneyFusion en test ou en validation.

## Decisions

### Backend d'abord

Le canal de vente dans l'app n'est pas tranché : vendre un abonnement numérique
en mobile money dans l'app viole les règles d'achat intégré d'Apple et de
Google. Cette phase livre le socle serveur (création, webhook, entitlement),
utilisable par une page web, une app distribuée hors stores ou une future
décision produit, sans exposer de secret ni verrouiller l'architecture.

### Le webhook déclenche, le serveur vérifie

MoneyFusion ne documente pas de secret de webhook signé. Le webhook est donc un
simple signal : le serveur recontrôle le statut auprès de MoneyFusion, avec le
token et le montant qu'il a lui-même enregistrés. Un appel forgé ne peut pas
accorder d'abonnement sans paiement réel correspondant.

### Produits en dur, prix par environnement

Les identifiants de produits sont des constantes de code (revus en revue) ; les
prix viennent de l'environnement pour ne pas graver un tarif dans le dépôt. Les
défauts 3 500 / 30 000 FCFA servent au développement et doivent être validés
par le produit avant mise en production.

### Ligne de paiement séparée de l'entitlement

`moneyfusion_payments` (token en clé) porte l'association token ↔ utilisateur ↔
produit ↔ montant ↔ statut. L'entitlement reste dans `subscriptions`, écrit par
le même helper que RevenueCat avec une `source` paramétrée.

## Context

Storylingo vend déjà un abonnement via RevenueCat et synchronise l'état serveur
(`GET /v1/entitlements`, webhook RevenueCat). Le package interne
`money_fusion` (v0.3.0) fournit le contrat de création et de statut MoneyFusion
et sera consommé plus tard côté app. Cette phase est la partie serveur, la
seule indispensable quel que soit le canal de vente retenu.

## Stakeholder Notes

- **Produit** : confirmer les prix FCFA et le canal de vente (web, hors stores
  ou in-app) avant toute mise en production.
- **Équipe backend** : variables d'environnement à provisionner sur
  l'hébergement ; le lien API MoneyFusion reste un secret.
- **Relecteurs** : la phase ne modifie ni l'app Flutter ni le package ; les
  tests serveur utilisent un faux MoneyFusion en mémoire.
