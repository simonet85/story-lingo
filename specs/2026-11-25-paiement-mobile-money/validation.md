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
  statut `paid`, montant identique).
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

## Résultat de validation

À remplir après l'implémentation.
