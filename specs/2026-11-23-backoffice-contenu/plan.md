# Phase 14 — Plan : Back-office contenu

## Objectif

Ajouter une interface web minimale, servie par l'API FastAPI, pour lister les
livres, importer un pack ZIP et basculer un livre entre gratuit et payant, sans
toucher aux routes publiques ni au client Flutter.

## Décisions

- **Admin unique** : `STORYLINGO_ADMIN_TOKEN` (mot de passe) et
  `STORYLINGO_ADMIN_SESSION_SECRET` (signature de session). Pas de table
  utilisateur ni de compte multiple.
- **Session** : JWT HS256 en cookie `HttpOnly`/`SameSite=Lax`, 12 h, avec un
  jeton CSRF par session. `Secure` hors HTTP local.
- **UI server-rendered** : Jinja2 + CSS inline, aucune chaîne de build.
- **Import** : upload ZIP, extraction sécurisée dans un répertoire temporaire,
  puis `publish_pack` existant (mêmes validations et backup atomique).
- **Activation** : routeur `/admin` monté uniquement si le token est configuré ;
  sinon 404 naturellement.

## Configuration

`server/app/config.py` :

- `admin_token` ← `STORYLINGO_ADMIN_TOKEN`
- `admin_session_secret` ← `STORYLINGO_ADMIN_SESSION_SECRET`
- `admin_max_upload_bytes` ← `STORYLINGO_ADMIN_MAX_UPLOAD_MB` (défaut 200 Mo)

## Serveur

Nouveau paquet `server/app/admin/` :

- `auth.py` : `AdminAuth` (`check_password`, `issue`, `read`), constantes de
  cookie/audience/issuer, `AdminSession(csrf)`.
- `routes.py` :
  - `GET /admin` → redirection vers la liste.
  - `GET /admin/login`, `POST /admin/login`, `POST /admin/logout`.
  - `GET /admin/books` : tableau + formulaires de bascule.
  - `GET /admin/import`, `POST /admin/import` : multipart, CSRF, limite de
    taille, extraction anti zip-slip, `publish_pack(..., is_free=...)`.
  - `POST /admin/books/{book_id}/access` : `free`/`paid`.
- `templates/` : `base.html`, `login.html`, `books.html`, `import.html`.
- `main.py` : instancie `AdminAuth`, monte le routeur si activé.

Sécurité import :

- extension `.zip` obligatoire, rejet des archives vides ou corrompues ;
- chemins normalisés, refus de l'absolu, de `..`, des backslashes et des liens
  symboliques ;
- plafond sur la taille compressée, décompressée et le nombre d'entrées ;
- répertoire temporaire système supprimé automatiquement.

## Tests

`server/tests/test_admin_auth.py`, `test_admin_books.py`,
`test_admin_import.py`, `test_admin_access.py` :

- activation/désactivation, mot de passe, cookie durci, redirections, CSRF ;
- liste, badges, échappement HTML ;
- import valide (racine et dossier unique), manifeste absent, zip-slip, ZIP
  corrompu, dépassement de taille, conservation/écrasement du flag ;
- bascule dans les deux sens et propagation à `/v1/catalogue` et
  `/v1/books/{id}`.

Fixtures ajoutées dans `conftest.py` : `admin_settings`, `admin_app`,
`admin_client`, `admin_login`, `admin_csrf` (token factice de test uniquement).

## Documentation

Section « Back-office » dans `server/README.md` : variables d'environnement,
lancement, limites et avertissement sur l'activation en production (HTTPS,
reverse proxy, restriction réseau).

## Dépendances

- `jinja2==3.1.6`
- `python-multipart==0.0.20`
