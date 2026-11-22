# Phase 11 — Exigences : Comptes & synchronisation

## Authentification

- **FR-11.1** — En mode dev (`STORYLINGO_DEV_AUTH=1`), `POST
  /v1/auth/dev/login` accepte un email valide et renvoie un JWT
  `{accessToken, expiresIn, user:{id,email}, mode:"dev"}`. Le même email
  produit toujours le même `user.id`, sans que l'email soit stocké.
- **FR-11.2** — En mode dev désactivé, `/v1/auth/dev/login` renvoie 404 et un
  token dev n'est pas accepté.
- **FR-11.3** — Le serveur vérifie les JWT Supabase par secret HS256 ou JWKS ;
  il expose `GET /v1/auth/me` pour une session valide.
- **FR-11.4** — Sans `Authorization` ou avec un token invalide/expiré, les
  endpoints protégés renvoient 401 JSON avec `WWW-Authenticate: Bearer`.
- **FR-11.5** — L'application peut se connecter en mode Supabase (email + mot
  de passe, inscription) ou en mode dev (email seul), restaurer la session au
  démarrage, rafraîchir un token expiré et se déconnecter.
- **FR-11.6** — Les jetons sont stockés via `flutter_secure_storage` ; aucune
  donnée d'authentification n'est écrite dans les `SharedPreferences` de
  contenu.

## Synchronisation

- **FR-11.7** — `POST /v1/sync/push` accepte jusqu'à 500 enregistrements
  `{namespace, id, updatedAt, deleted, payload}` et applique un LWW par
  enregistrement (`updatedAt` strictement supérieur).
- **FR-11.8** — La réponse au push renvoie le gagnant de chaque clé demandée et
  la révision courante de l'utilisateur ; un push identique est idempotent.
- **FR-11.9** — `GET /v1/sync/pull?since=N` renvoie les enregistrements de
  révision > N et la révision courante.
- **FR-11.10** — Les enregistrements d'un utilisateur sont invisibles pour tout
  autre utilisateur.
- **FR-11.11** — Sont synchronisés : état/position de lecture, mots
  sauvegardés (ajout et suppression), cartes SRS, sessions du programme 28
  jours, profil de préférences (niveau, intérêts, onboarding, thème, mode de
  lecture, vitesse audio). La télémétrie n'est pas synchronisée.
- **FR-11.12** — Une suppression locale de mot sauvegardé est transmise sous
  forme de pierre tombale (`deleted: true`) et s'applique sur les autres
  appareils ; une ré-ajout plus récent la remplace.
- **FR-11.13** — Chaque enregistrement possède un horodatage d'édition :
  `reading.updated.*` existant, `savedAt`, dernière révision SRS, `updatedAt`
  de session (nouveau, rétrocompatible) ou `settings.updated` (nouveau).
- **FR-11.14** — Les payloads respectent un schéma JSON par domaine ; un
  payload invalide est rejeté (422) sans modifier l'état serveur.
- **FR-11.15** — Après un push, le client applique les gagnants, puis pull les
  révisions suivantes ; la synchronisation est idempotente et ne corrompt pas
  l'état local en cas de réponse réseau invalide.
- **FR-11.16** — Le client persiste le curseur de pull et la date de dernière
  synchronisation ; il expose l'état (inactif, en cours, succès, erreur).

## Migration et parcours

- **FR-11.17** — La première connexion pousse les données locales existantes
  (migration) puis applique les données distantes plus récentes.
- **FR-11.18** — Une synchronisation est tentée après connexion et au démarrage
  lorsqu'une session est restaurée ; un bouton permet de la relancer.
- **FR-11.19** — Les réglages affichent une section « Compte » : invitation si
  déconnecté ; email, dernière synchronisation, action de sync et déconnexion
  si connecté.
- **FR-11.20** — La déconnexion efface les jetons mais conserve les données
  locales ; les écrans lecture/vocabulaire/programme restent fonctionnels.
- **FR-11.21** — En cas d'échec (réseau, 401, serveur), l'utilisateur voit un
  message clair et l'état local reste intact ; la lecture hors-ligne n'est pas
  affectée.

## Contraintes techniques et sécurité

- **SEC-11.1** — Aucun secret dans le dépôt : secrets serveur par variables
  d'environnement, configuration Supabase par `--dart-define`.
- **SEC-11.2** — Aucun email ni jeton n'est journalisé côté serveur ; le mode
  dev stocke l'utilisateur comme hash d'email.
- **SEC-11.3** — CORS limité aux origines locales ; méthodes `GET`, `POST`,
  `HEAD`, `OPTIONS` ; en-têtes `Authorization`, `Content-Type`,
  `If-None-Match`, `Range`.
- **SEC-11.4** — Limites de taille et validation des entrées avant écriture.
- **SEC-11.5** — Le serveur ne stocke aucune donnée personnelle hors du
  payload synchronisé et de l'identifiant `sub`.

## Definition of Done

- `flutter analyze` sans problème, `flutter test` et `pytest` verts, phases 1 à
  10 non régressées.
- Contrat vérifié manuellement : login dev, push/pull, LWW, isolation,
  tombstones, 401/422.
- Runtime web et Android : connexion, synchronisation, réglages ; un
  aller-retour entre deux clients (web ↔ Android) montre les données
  convergentes.
- Documentation serveur mise à jour, captures dans `.tmp/screens/`.
