# Phase 14 — Plan : Paiement mobile money (backend)

## Objectif

Ouvrir côté FastAPI la création de paiement MoneyFusion et l'octroi
d'abonnement par webhook vérifié, pour deux produits FCFA (mensuel 30 jours,
annuel 365 jours), sans toucher à l'app Flutter ni au package `money_fusion`.

## Décisions

- Backend-first : aucune UI d'achat ; le canal de vente sera décidé ensuite.
- `moneyfusion_payments` : `token` PK, `user_id`, `product_id`, `amount`,
  `status` (`pending` | `paid` | `failed`), `transaction_number`,
  `created_at_ms`, `applied_at_ms`.
- Produits constants `storylingo_pro_monthly_xof` / `storylingo_pro_yearly_xof`
  (30 / 365 jours) ; prix par variables d'environnement (défauts de dev
  3 500 / 30 000 FCFA).
- Webhook = déclencheur : revérification `GET paiementNotif/{token}` côté
  serveur, montant stocké comparé au montant brut reconstitué
  (`Montant` net + `frais`, ou `Montant` seul).
- `_apply` existant reçoit une `source` (défaut `revenuecat`) pour réutiliser
  l'idempotence `last_event_ms`.
- Client `httpx` injectable pour les tests (`MockTransport`), timeout 30 s.

## Serveur

1. `Settings` : `moneyfusion_api_url`, `moneyfusion_status_base_url`,
   `moneyfusion_price_monthly_xof`, `moneyfusion_price_yearly_xof`, lus depuis
   l'environnement (statut par défaut `https://pay.moneyfusion.net`, sans
   `www` : le préfixe échoue en TLS sur certains hôtes).
2. `server/app/models.py` : modèle `MoneyFusionPayment` (table
   `moneyfusion_payments`) ; `Base.metadata.create_all` suffit, comme le reste.
3. `server/app/payments.py` : constantes produits/durées, validation des prix,
   fonction de création (appel MoneyFusion), fonction de revérification du
   statut, calcul d'échéance, client `httpx` injectable.
4. `server/app/billing.py` : `_apply(..., source="revenuecat")` ; aucune
   modification de comportement pour RevenueCat.
5. `server/app/payments.py` (router monté dans `main.py`) :
   - `POST /v1/payments/moneyfusion` (JWT, `require_user`) ;
   - `POST /v1/webhooks/moneyfusion` (sans auth, JSON ou formulaire) ;
   - `GET /v1/payments/moneyfusion/return` (page HTML minimale).
6. Codes et cas : 503 config incomplète, 400 produit/champs montant, 502 échec
   MoneyFusion, 404 token inconnu, 200 pending/paid/failure/idempotent, 400
   montant brut divergent (paiement laissé `pending`).
7. Aucune journalisation du téléphone, du nom client ni du token.

## Tests serveur

8. Création : 401 sans jeton, 400 produit inconnu ou champ vide, 503 sans
   configuration, 200 avec token/url/amount et ligne `pending`, 502 sur
   `statut: false`, HTTP 500, timeout et JSON illisible, `totalPrice` toujours
   celui du serveur.
9. Webhook : JSON et formulaire, token inconnu (404), corps illisible (400),
   `paid` → échéance +30/+365 jours et `source = "moneyfusion"` visible dans
   `/v1/entitlements`, rejeu sans prolongation, `failure`/`no paid` sans grant,
   `pending` sans mutation, montant brut divergent (400, aucun grant),
   `Montant` net + `frais` égal au prix accepté, frais incohérents rejetés.
10. Non-régression : suite `server/tests` complète verte, y compris
    RevenueCat et le cycle de vie des entitlements.

## Documentation

11. `server/README.md` : nouvelles variables, exemple de session curl locale
    (dev auth + faux volumes), avertissement secret, sémantique
    `Montant` net + `frais` et hôte de statut sans `www`.
12. `README.md` (specs) : lien vers cette phase ; `specs/roadmap.md` : phase 14
    « Paiement mobile money (backend) », phase Analytics décalée en 15.

## Vérification

```
python -m pytest server/tests tools/content/tests
flutter analyze
flutter test
```

Aucune modification Dart n'est attendue : l'app reste identique, ses tests et
l'analyse servent de contrôle de non-régression du dépôt.

## Livraison

13. Commiter la spec, puis l'implémentation et ses tests sur une branche dédiée.
14. Remplir `validation.md` avec les résultats, relire, puis fusionner dans
    `main` (CI `analyze-test` et `api-content-tests` vertes).
