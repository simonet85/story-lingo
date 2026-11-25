# Phase 14 — Validation : Paiement mobile money (backend)

## Definition of Done

Tout ce qui suit doit être vrai avant de fusionner dans `main`.

### 1. Tests serveur

```
python -m pytest server/tests tools/content/tests
```

Code 0, suites des phases 1 à 13 toujours vertes, plus :

- création : 401 sans jeton, 400 produit/champs invalides, 503 configuration
  incomplète, 200 avec `token`/`url`/`amount`, 502 sur échec MoneyFusion ;
- webhook : 404 token inconnu, 400 corps ou montant invalide, `paid` →
  entitlement `source = "moneyfusion"` avec l'échéance du produit, rejeu
  idempotent, `failure`/`no paid` sans grant, `pending` sans mutation ;
- `Montant` net + `frais` égal au prix stocké → entitlement accordé ; frais
  incohérents ou total divergent → 400 sans grant ;
- `totalPrice` envoyé à MoneyFusion est toujours le prix serveur ;
- `/v1/entitlements` reflète l'abonnement accordé puis son expiration.

### 2. Contrat API

- `POST /v1/payments/moneyfusion` exige `Authorization: Bearer`.
- `GET /v1/payments/moneyfusion/return` renvoie du HTML sans toucher l'état.
- Routes existantes (`/v1/entitlements`, `/v1/webhooks/revenuecat`,
  `/v1/books`, sync) inchangées.

### 3. Sécurité

- Aucun secret, aucune URL MoneyFusion avec secret ni prix dans le dépôt :
  tout passe par l'environnement.
- Le webhook n'accorde rien sans revérification serveur cohérente (token connu,
  statut `paid`, montant brut cohérent avec `Montant` net + `frais`).
- Aucun téléphone, nom client ou token dans les journaux.
- Un rejeu de webhook ne prolonge pas l'échéance.

### 4. Non-régression app

```
flutter analyze
flutter test
```

Code 0, sans modification du code Dart ; `flutter build web` reste vert en CI
si exécuté localement.

### 5. Documentation

- `server/README.md` liste les nouvelles variables et leur rôle, avec
  l'avertissement « secret » sur le lien API.
- `specs/roadmap.md` contient la phase 14 et décale la phase Analytics.

## Not Required

- Interface d'achat dans l'app et dépendance à `money_fusion` : décision produit
  ultérieure (politiques stores).
- Appel réel à MoneyFusion : les tests utilisent un faux MoneyFusion en mémoire.
- Renouvellement automatique, remboursements, PAYOUT, factures, e-mails.
- Signature des webhooks : la revérification serveur en tient lieu.
- Limitation de débit sur la création de paiements.

## Résultat de validation — 2026-11-25

Exécuté avec Python 3.12.10 dans `.venv-server` (dépendances serveur épinglées)
et Flutter 3.50.1 / Dart 3.14.0.

| Vérification | Résultat |
|---|---|
| `python -m pytest server/tests tools/content/tests` | 109 tests, tous verts, dont 21 nouveaux pour les paiements |
| `flutter analyze` | `No issues found!`, code 0 |
| `flutter test` | 286 tests, `All tests passed!`, code 0 |
| Création | 401 sans jeton ; 400 produit inconnu ou téléphone vide ; 503 service non configuré ou prix nul ; 200 avec `token`/`url`/`amount` et ligne `pending` ; 502 sur refus MoneyFusion, HTTP 500 et erreur réseau |
| Prix serveur | `totalPrice` envoyé à MoneyFusion = 3 500 (mensuel) et 30 000 (annuel), jamais une valeur cliente |
| URLs | `return_url` et `webhook_url` absolus sur `public_base_url`, statut sur `https://pay.moneyfusion.net/paiementNotif/{token}` (sans `www` : le préfixe échoue en TLS sur certains hôtes) |
| Webhook payé | `paid` → entitlement `source = "moneyfusion"`, échéance à 30 / 365 jours, numéro de transaction enregistré |
| Rejeu | Deuxième webhook → `applied: false`, échéance identique, aucune nouvelle requête de statut |
| Statuts non payés | `failure` → paiement `failed` sans grant ; `pending` sans mutation ; JSON et formulaire acceptés ; JSON illisible et token manquant → 400 ; token inconnu → 404 |
| Montant net + frais | `Montant` 242,5 + `frais` 7,5 pour 250 XOF → entitlement accordé ; `Montant` seul égal au prix accepté ; frais absents, non numériques ou négatifs avec un total divergent → 400, paiement laissé `pending`, aucun grant |
| Montant divergent | `Montant` et `Montant + frais` ≠ montant stocké → 400, paiement laissé `pending`, aucun grant ; `Montant` en chaîne accepté quand il correspond |
| Page de retour | 200 HTML « Paiement terminé », aucune ligne de paiement créée |
| Non-régression | Webhook RevenueCat et entitlements existants inchangés (`_apply` avec `source` par défaut `revenuecat`) |

Notes d'environnement : le corps du webhook est parsé manuellement (JSON ou
URL-encodé), donc `python-multipart` n'est pas requis ; `.venv-server/` est
désormais ignoré par git. Aucun appel réel à MoneyFusion dans la suite de
tests : les tests injectent un faux client `httpx` (`MockTransport`). Un essai
réel Wave de 250 XOF a confirmé `Montant: 242.5`, `frais: 7.5` et la nécessité
du domaine `pay.moneyfusion.net` sans `www`.

La phase est validée : tous les points du DoD sont satisfaits.
