# Phase 13 — Validation : Freemium & paywall

## Definition of Done

### 1. Analyse statique

```
flutter analyze
flutter build web
```

Code 0 ; le web compile sans référencer le SDK RevenueCat.

### 2. Tests automatisés

```
flutter test
python -m pytest server/tests tools/content/tests
```

Tous les tests passent, y compris ceux des phases 1 à 12.

Couverture attendue :
- **Serveur** : catalogue gratuit/payant, manifeste `isFree`, entitlements
  (auth, grant/revoke), webhook signé, cycle de vie, désordre/idempotence,
  transfert, publication qui conserve ou bascule le flag.
- **Client** : gateway démo (achat/restauration/expiration), precedence d'accès,
  cache serveur expiré, carte verrouillée → paywall, achat → livre demandé,
  restauration, section Réglages, deep links verrouillés.

### 3. Contrat API

- `GET /v1/entitlements` → 401 sans jeton ; inactif sans ligne ; actif après
  `dev-grant` ; inactif après `dev-revoke`.
- `POST /v1/webhooks/revenuecat` → 503 sans secret configuré, 401 mauvais
  secret, 200 avec `applied` pour un événement récent, `stale` pour un ancien.
- `/v1/books/{id}` expose `isFree` ; les endpoints de contenu restent publics et
  inchangés.

### 4. Runtime Android

Émulateur `storylingo_api36`, API locale sur une copie de `server/data` avec un
livre payant de démonstration, build démo (sans clé RevenueCat) :

- les deux livres gratuits restent lisibles ;
- le livre payant affiche le verrou ; le paywall s'ouvre ; « Plus tard » revient ;
- achat démo → retour à la lecture ; l'état persiste après relance ;
- `dev-revoke` + refresh → verrou de nouveau ; restauration → accès rendu ;
- pack payant téléchargé puis abonnement révoqué + mode avion → lecture toujours
  possible ; livre payant non téléchargé → paywall ;
- aucun crash ni exception de plugin.

### 5. Web et non-régression

- `flutter build web` ; bibliothèque avec verrou, paywall en mode démo, Réglages
  Abonnement ; zéro erreur console, aucune `MissingPluginException`.
- Parcours existants (lecture, audio, SRS, sync, téléchargements) inchangés.

## Résultats

### 1. Analyse statique

- `flutter analyze` → **No issues found!** (53,8 s).
- `flutter build web --dart-define=API_BASE_URL=http://127.0.0.1:8000` → succès,
  code 0.
- Aucun code applicatif web n'importe `purchases_flutter` (seul
  `billing_gateway_io.dart` le fait). Flutter enregistre automatiquement le pont
  web du plugin dans le registrant généré, mais il n'est ni configuré ni appelé :
  le web utilise la gateway démo. Aucune `MissingPluginException`, aucune erreur
  console (voir §5). Ce pont inerte est une conséquence de l'auto-enregistrement
  des plugins web par Flutter ; FR-13.20 (« sans initialiser le SDK natif ») est
  respecté.

### 2. Tests automatisés

- `flutter test` → **286 tests, tous verts** (1 min 30 s).
- `python -m pytest server/tests tools/content/tests -q` → **88 passed**,
  1 avertissement de dépréciation Starlette/httpx (66 s).
- Les tests des phases 1 à 12 restent verts.

### 3. Contrat API

Vérifié sur l'API locale avec la copie `.tmp/runtime-freemium/data` :

- `GET /v1/entitlements` sans jeton → **401**.
- Avec jeton, aucune ligne → `{"active": false, "status": "none", ...}`.
- `POST /v1/entitlements/dev-grant` (30 j) → `active: true`, source `dev` ;
  `GET` confirme l'échéance ; `dev-revoke` → ligne supprimée, `active: false`.
- Webhook :
  - instance sans secret (port 8001) → **503** ;
  - mauvais secret → **401** ;
  - `INITIAL_PURCHASE` récent → `{"applied": true, "active": true}` ;
  - même événement rejoué → `{"applied": false, "reason": "stale"}` ;
  - `CANCELLATION` plus ancien → `stale` (désordre ignoré) ;
  - `EXPIRATION` plus récent → `{"applied": true, "active": false,
    "status": "expired"}`.
- `/v1/catalogue` expose `night-train` avec `isFree: false` et `sleepy-hollow`
  avec `isFree: true` ; `/v1/books/night-train` expose `isFree: false` même pour
  un pack publié avant la phase (la base est désormais prioritaire sur le
  manifeste stocké). Les endpoints de contenu restent publics et inchangés.
- Les cas transfert, cycle de vie, idempotence et publication
  gratuite/payante sont couverts par `server/tests/test_billing.py`.

### 4. Runtime Android

Émulateur `storylingo_api36` (Android 16), DB de travail
`.tmp/runtime-freemium` avec `night-train` payé, APK debug construit avec
`API_BASE_URL=http://10.0.2.2:8000` et **sans clé RevenueCat** (démo).

- Les deux livres restent accessibles en lecture : Sleepy Hollow (gratuit) ouvre
  son chapitre 1.
- Night Train affiche le verrou et « Débloquer avec l'abonnement » ; le paywall
  s'ouvre (bannière démo, annuel présélectionné) ; « Plus tard » revient à la
  bibliothèque ; « Restaurer mes achats » affiche « Aucun achat à restaurer ».
- Achat démo → redirection vers la lecture de Night Train et SnackBar
  « Abonnement actif. Bonne lecture ! » ; après relance complète, l'accès
  persiste et Réglages › Abonnement affiche « Storylingo Pro · Actif jusqu'au
  22/11/2027 ».
- Parcours serveur (compte dev `reader@example.com`) : la préférence d'achat
  démo locale a été retirée pour simuler un appareil sans achat, puis la
  bibliothèque s'est verrouillée ; `dev-grant` + refresh (ouverture du paywall) →
  Réglages affiche Pro jusqu'au 22/12/2026 ; `dev-revoke` + restauration/refresh
  → état inactif et verrou ; nouveau `dev-grant` + restauration → accès rendu.
- Pack payant téléchargé (260,6 ko), puis `dev-revoke` + refresh (inactif),
  mode avion et relance : la bibliothèque montre « Téléchargé » et le chapitre 1
  se lit hors ligne. Un livre payant non téléchargé reste verrouillé et ouvre le
  paywall.
- Aucun `FATAL EXCEPTION`, aucune `MissingPluginException` dans logcat.

Captures : `.tmp/screens/phase13-android-06-library.png` (verrou),
`phase13-android-08-paywall.png`, `phase13-android-13-after-purchase.png`,
`phase13-android-14-relaunch-library.png`,
`phase13-android-23-settings-granted.png`,
`phase13-android-24-settings-revoked.png`,
`phase13-android-29-offline-library.png`,
`phase13-android-30-offline-read.png`.

### 5. Web et non-régression

- Build web servi sur `127.0.0.1:8080` avec l'API locale, stockage local réinitiée
  par le seed de test.
- Bibliothèque : verrou et CTA sur Night Train, Sleepy Hollow lisible ; paywall
  `/paywall` en mode démo ; deep link `/read/night-train` → écran
  « Ce livre fait partie de l'abonnement » ; Réglages › Abonnement inactif avec
  « Découvrir l'abonnement », restauration et note de connexion.
- **0 exception, 0 erreur console** sur les quatre captures ; aucune
  `MissingPluginException`. Le pont RevenueCat auto-enregistré n'est jamais
  configuré ni invoqué.
- Parcours existants (lecture, audio, SRS, sync, téléchargements) inchangés et
  couverts par la suite verte.

Captures : `.tmp/screens/phase13-web-library-locked.png`,
`phase13-web-paywall-demo.png`, `phase13-web-locked-deeplink.png`,
`phase13-web-settings-subscription.png`.

### Limites assumées

- Achat réel Play/App Store non testé (produits, testeurs et clés absents) ; iOS
  non compilable sous Windows.
- L'achat démo est stocké localement par conception ; la révocation serveur a
  donc été validée en retirant cette préférence sur l'émulateur (instrumentation
  de test), l'onboarding et le compte étant conservés.
- Les endpoints de contenu restent publics : le gating est une règle client,
  documentée ; l'anti-piratage complet est hors périmètre.
- Le manifeste servi superpose `isFree` depuis la base, mais les descripteurs de
  téléchargement des packs déjà publiés gardent les octets/hashes d'origine ;
  toute bascule de flag doit republier avec un `packVersion` incrémenté.
