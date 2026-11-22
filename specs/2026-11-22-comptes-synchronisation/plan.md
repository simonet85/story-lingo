# Phase 11 — Plan : Comptes & synchronisation

Objectif : permettre à un utilisateur de se connecter et de retrouver sa
progression sur plusieurs appareils. L'authentification passe par Supabase Auth
en production, avec un mode dev local pour les tests et la démo ; le serveur
FastAPI vérifie les JWT et expose un push/pull différentiel en
last-write-wins.

Tranche livrée : connexion (Supabase + dev), jetons en stockage sécurisé,
synchronisation de progression, positions, mots sauvegardés, SRS, programme et
préférences. Sans téléchargement hors-ligne, sans paiement, sans télémétrie
distante.

## A. Authentification serveur

- `server/app/auth.py` : vérification des JWT, `AuthContext` (user id, email,
  mode), dépendance `require_user` (401 JSON + `WWW-Authenticate: Bearer`).
  - Supabase : secret HS256 (`STORYLINGO_SUPABASE_JWT_SECRET`) ou JWKS
    (`STORYLINGO_SUPABASE_JWKS_URL`, RS256/ES256 via PyJWT) ; `iss`/`aud`
    optionnels (`STORYLINGO_SUPABASE_ISSUER`, audience par défaut
    `authenticated`).
  - Mode dev : activé par `STORYLINGO_DEV_AUTH=1` ; secret
    `STORYLINGO_DEV_AUTH_SECRET` ou généré au démarrage.
- `POST /v1/auth/dev/login` (mode dev uniquement) : email → JWT HS256 24 h.
  L'identifiant est le hash SHA-256 de l'email normalisé : **aucun email n'est
  stocké côté serveur**. Endpoint absent (404) si le mode dev est désactivé.
- `GET /v1/auth/me` : renvoie l'identité issue des claims.
- CORS : ajout de `POST` et des en-têtes `Authorization`, `Content-Type`.

## B. Synchronisation serveur

- Tables `sync_records` et `sync_states` (créées par `create_all`, sans
  migration) :
  - `sync_records(user_id, namespace, record_id, updated_at_ms, deleted,
    payload, revision, server_updated_at)`, PK composite ;
  - `sync_states(user_id, revision)` pour un curseur monotone par utilisateur.
- `POST /v1/sync/push` : jusqu'à 500 enregistrements
  `{namespace, id, updatedAt, deleted, payload}` ; namespaces
  `reading|words|srs|program|prefs`.
  - LWW : l'enregistrement entrant remplace le stocké si
    `updatedAt > updated_at_ms` ; sinon le stocké gagne.
  - Une révision est allouée par lot accepté ; la réponse renvoie le gagnant
    de **chaque** clé demandée, plus `serverRevision`.
- `GET /v1/sync/pull?since=<révision>` : enregistrements de révision
  strictement supérieure, plus la révision courante.
- Validations : namespace inconnu, id vide, payload non-objet (hors
  suppression), JSON > 64 Ko, lot > 500 → 422. Isolation stricte par `sub`.
- Aucune donnée personnelle n'est journalisée ni stockée au-delà de `user_id`
  (et du payload de contenu utilisateur).

## C. Client Flutter

- Dépendance `flutter_secure_storage` pour les jetons ; abstraction
  `TokenStore` (implémentation sécurisée + mémoire pour les tests).
- `features/account/` :
  - `AuthApi` : login dev (`/v1/auth/dev/login`), Supabase GoTrue
    (`/auth/v1/token?grant_type=password`, `/auth/v1/signup`, refresh token),
    `GET /v1/auth/me` ;
  - `AuthRepository` : connexion, inscription (Supabase), restauration,
    déconnexion, refresh à l'expiration ;
  - `authControllerProvider` : état `signedOut|signedIn|loading`, session
    persistée (access/refresh token, email, expiration, mode).
- Configuration par `--dart-define` : `SUPABASE_URL` + `SUPABASE_ANON_KEY`
  (prod) ; sinon mode dev adossé à `API_BASE_URL`.
- `features/sync/` :
  - `SyncRecord` + `SyncApi` (`push`, `pull`) ;
  - collecte locale : progression/positions, mots (avec pierres tombales
    `sync.tombstones.words`), cartes SRS, sessions du programme, profil de
    préférences ;
  - application des gagnants aux Prefs, puis invalidation des providers
    (lecture, mots, SRS, programme, préférences) ;
  - curseur `sync.cursor` et date `sync.last_at` persistés.
- Horodatages LWW : `reading.updated.*` existant ; `savedAt` des mots ;
  `lastReviewedAt`/`introducedAt` des cartes ; nouveau champ `updatedAt` des
  sessions du programme ; nouvelle clé `settings.updated` pour les
  préférences.
- UI :
  - section « Compte » dans les réglages (état, email, dernière sync,
    synchroniser, se déconnecter) ;
  - écran `/account` : formulaire (email/mot de passe Supabase, email seul en
    dev), erreurs lisibles, chargement ;
  - synchronisation automatique après connexion et au démarrage si une
    session est restaurée ; bouton manuel ensuite ;
  - migration : la première synchronisation pousse les données locales puis
    applique les gagnants distants.
- Déconnexion : jetons effacés, données locales conservées, sync arrêtée.

## D. Tests, CI et documentation

- `pytest` : auth dev (activée/désactivée, token invalide, `me`), isolation
  utilisateurs, LWW (plus récent gagne, ancien ignoré), révisions/pull,
  tombstones, validations 422, CORS.
- `flutter test` : AuthRepository (dev + Supabase simulé, refresh), collecte et
  application des enregistrements, LWW, curseur, migration à la connexion,
  écran compte/réglages, non-régression complète.
- CI : jobs existants inchangés, les nouveaux tests passent avec eux.
- `server/README.md` : variables d'auth, mode dev, exemples `curl` push/pull.

## Décisions

- **JWKS + secret HS256** : Supabase peut tourner avec les deux générations de
  clés ; le mode dev n'ajoute aucune dépendance externe.
- **LWW par enregistrement** : granularité utile (un chapitre, un mot, une
  carte), suffisante pour un usage mono-utilisateur multi-appareils.
- **Révisions serveur pour le pull** : évite les trous liés aux horloges
  client ; le LWW, lui, reste fondé sur l'horodatage d'édition.
- **Pierres tombales limitées aux mots** : seule entité supprimable
  localement ; les autres domaines ne font que progresser.
- **Profil de préférences en un enregistrement** : les réglages sont modifiés
  en bloc, un seul horodatage suffit.
- **Télémétrie non synchronisée** : elle reste locale jusqu'à la phase 14.

## Not Required

- Fournisseurs sociaux, vérification d'email gérée par l'UI, réinitialisation
  de mot de passe.
- Multi-comptes sur un même appareil, fusion interactive de conflits.
- Synchronisation automatique en arrière-plan (background jobs).
- Téléchargement hors-ligne, entitlements, paiement.
- Chiffrement de bout en bout des payloads.
