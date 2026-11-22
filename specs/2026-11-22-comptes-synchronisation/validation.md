# Phase 11 — Validation : Comptes & synchronisation

## Definition of Done

### 1. Analyse statique

```
flutter analyze
```

Code 0, sans erreur ni avertissement.

### 2. Tests automatisés

```
flutter test
python -m pytest server/tests tools/content/tests
```

Tous les tests passent, y compris ceux des phases 1 à 10.

Couverture attendue :

- **Auth serveur** : login dev (nominal, email invalide), mode dev désactivé,
  token absent/invalide/expiré, `me`, stabilité de l'id, claim utilisateur.
- **Sync serveur** : push initial, LWW (plus récent gagne, plus ancien
  ignoré), idempotence, révisions et pull `since`, tombstones, isolation entre
  utilisateurs, validations (namespace, payload, taille, lot), 401.
- **CORS** : préflight `POST` avec `Authorization` accepté pour les origines
  locales.
- **Auth Flutter** : login dev via HTTP simulé, stockage sécurisé (doublure),
  restauration, déconnexion, refresh Supabase, inscription Supabase,
  erreurs.
- **Sync Flutter** : collecte des cinq domaines, timestamps (dont
  `settings.updated` et sessions), application des gagnants, tombstones,
  curseur, migration à la connexion, réponse invalide sans corruption.
- **UI** : réglages déconnecté/connecté, écran compte (dev et Supabase),
  sync manuelle, déconnexion, messages d'erreur ; 360 px sans overflow.
- **Non-régression** : boucle pilote, catalogue, audio, SRS, programme.

### 3. Contrat API

- `POST /v1/auth/dev/login` → 200 + JWT ; mode désactivé → 404.
- `GET /v1/auth/me` avec Bearer → 200 ; sans token → 401.
- `POST /v1/sync/push` sans token → 401 ; avec token → gagnants + révision.
- Deux pushes successifs sur la même clé : le plus récent `updatedAt` gagne,
  l'ancien renvoie l'état stocké sans nouvelle révision.
- `GET /v1/sync/pull?since=0` → tous les enregistrements ; un second pull avec
  la révision renvoyée → liste vide.
- Un enregistrement `deleted: true` est propagé et une ré-ajout plus récente
  le remplace.
- Utilisateur B ne voit jamais les enregistrements de A.

### 4. Synchro multi-appareils

- Connecter les deux clients (web et Android) au même compte dev.
- Créer une donnée sur Android (mot sauvegardé ou chapitre terminé),
  synchroniser, puis synchroniser côté web : la donnée apparaît.
- Inversement, modifier une préférence ou une position sur web et la retrouver
  sur Android.

### 5. Runtime

Aperçu Chrome (`.tmp/screens/web-account-*.png`, `.tmp/screens/web-sync-*.png`)
et émulateur Android `storylingo_api36`
(`.tmp/screens/android-account-*.png`, `.tmp/screens/android-sync-*.png`) :

- réglages déconnecté avec section Compte ;
- écran de connexion dev (et Supabase si configuré) ;
- réglages connecté avec email et dernière synchronisation ;
- état de synchronisation et propagation entre les deux clients.

### 6. Sécurité et confidentialité

- Aucun secret ni jeton dans le dépôt ou les logs.
- Jetons uniquement dans le stockage sécurisé.
- Emails absents de la base serveur en mode dev (hash uniquement).
- CORS restreint ; entrées validées et bornées.

### 7. CI et documentation

- Job Flutter existant inchangé et vert.
- Job API existant exécute les nouveaux tests.
- `server/README.md` décrit le mode dev, les variables Supabase et les
  endpoints `auth`/`sync`.

## Not Required

- Fournisseurs sociaux, vérification d'email dans l'UI, mot de passe oublié.
- Multi-comptes sur un même appareil, fusion interactive de conflits.
- Sync en arrière-plan, téléchargement hors-ligne, entitlements, paiement.
- Synchronisation de la télémétrie.

## Résultats (2026-11-22)

### Analyse et tests automatisés

- `flutter analyze` : **No issues found** (50,1 s).
- `flutter test` : **242 tests passés**, dont les 40 nouveaux tests
  `auth_sync_test.dart` (33) et `account_flow_test.dart` (7).
- `python -m pytest server/tests tools/content/tests` : **65 tests passés**
  (53 côté serveur, 12 côté outils de contenu).

### Contrat API et sécurité

Vérifiés par les tests serveur et en runtime avec l'API locale :

- login dev → 200 + JWT ; `me` → 200 avec Bearer, 401 sans token ;
- push/pull, LWW, idempotence, tombstones, isolation entre utilisateurs,
  validations de taille et 401 couverts par les tests ;
- CORS préflight local accepté.

Inspection de `server/data/storylingo.db` après le scénario multi-appareils :

- aucune occurrence d'email ni de `@` dans le dump ;
- un seul identifiant utilisateur, haché :
  `dev_f7d54c22dda5b1780276601cd005909b` ;
- tombstone `words/sleepy-hollow/mist` (`deleted=1`, révision 4) ;
- aucun jeton stocké côté serveur.

### Runtime multi-appareils

Scénario réalisé avec Chrome (`127.0.0.1:8080`) et l'émulateur
`storylingo_api36`, tous deux connectés en mode dev avec
`anna@example.com` :

1. Web : connexion, puis synchronisation d'un mot (`mist`), du programme et
   du niveau préféré B2.
2. Android : connexion avec le même email ; la synchronisation automatique
   récupère le niveau B2 et le mot `mist`.
3. Android : suppression de `mist` ; le tombstone est poussé (révision 4).
4. Web : synchronisation manuelle ; le mot disparaît de la liste.
5. Web : rechargement complet de l'application ; la session est restaurée
   depuis le stockage sécurisé et une synchronisation automatique se déclenche
   (capture `web-account-restored-light.png`).

Captures : `web-account-*.png`, `web-sync-*.png`,
`android-account-*.png`, `android-sync-*.png`.

### Supabase réel (complément)

Test effectué ensuite contre un vrai projet Supabase
(`jxmbuxqtxlylrumcxylb`), avec confirmation d'email désactivée :

- API démarrée avec `STORYLINGO_SUPABASE_JWKS_URL` (clé ES256) et
  `STORYLINGO_SUPABASE_ISSUER` ; login dev renvoie bien 404.
- App web compilée avec `SUPABASE_URL` et la publishable key ; inscription
  réelle depuis l'UI (`Créer un compte`), puis synchronisation automatique.
- L'API identifie l'utilisateur par l'UUID Supabase (`sub`) : `/v1/auth/me`
  renvoie `mode: supabase` et l'UUID attendu ; les lignes de sync sont
  stockées sous cet UUID, sans email.
- Second appareil simulé (stockage local vidé) : connexion avec le même
  compte, récupération du niveau B2 et du mot `mist` sans action manuelle.
- Audit du stockage navigateur : aucun JWT en clair ni clé `access_token` ;
  audit des logs API : aucun jeton, email ou mot de passe.

Captures : `web-supabase-*.png`.

### Limites connues

- Le compte de test Supabase créé pour cette validation
  (`phase11.<timestamp>@example.com`) reste enregistré dans le projet et peut
  être supprimé depuis le dashboard.
- La synchronisation reste manuelle ou déclenchée à la connexion : pas de sync
  en arrière-plan ni de résolution interactive de conflits (hors périmètre).
