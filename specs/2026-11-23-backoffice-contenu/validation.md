# Phase 14 — Validation : Back-office contenu

## Résultat

Phase validée : back-office `/admin` opérationnel (liste, import ZIP, bascule
gratuit/payant), authentification admin et CSRF couverts par les tests, aucune
régression Python.

## Tests automatisés

```text
python -m pytest server/tests tools/content/tests -q
116 passed, 1 warning in 28.17s
```

Les 28 nouveaux tests se répartissent ainsi :

- `server/tests/test_admin_auth.py` (9) : activation conditionnelle (404 sans
  token), page de connexion sans fuite du token, rejet du mauvais mot de passe,
  cookie `HttpOnly`/`SameSite=Lax`/`Path=/admin`, redirection sans session,
  cookie falsifié rejeté, CSRF obligatoire à la déconnexion, effacement de
  session, absence du token dans les pages authentifiées.
- `server/tests/test_admin_books.py` (3) : liste des livres et badges,
  statut payant, échappement HTML d'un titre malveillant.
- `server/tests/test_admin_import.py` (11) : import valide (racine et dossier
  unique), manifeste absent, zip-slip, archive corrompue, extension non ZIP,
  pack invalide, conservation/écrasement du drapeau, valeur d'accès inconnue,
  dépassement de taille (413).
- `server/tests/test_admin_access.py` (5) : bascule gratuit→payant et retour,
  valeur invalide (400), livre inconnu (404), CSRF absent (403), session
  absente (303).

Les tests utilisent exclusivement `tmp_path` (base SQLite et packs temporaires),
jamais `server/data`.

## Parcours réel sur serveur scratch

Serveur `uvicorn` lancé sur `127.0.0.1:8765` avec une base et un dossier de
packs dans `.tmp/phase14-admin`, token local factice :

- `GET /admin/books` anonyme → `303 /admin/login` ;
- mauvais mot de passe → `401`, aucun cookie ;
- connexion → `303 /admin/books`, cookie de session posé ;
- import du pack réel Sleepy Hollow (ZIP de 2 103 019 octets, accès « gratuit »)
  → `303 /admin/books?notice=imported&book=sleepy-hollow` ;
- liste → livre présent, badge « Gratuit » ;
- `GET /v1/books/sleepy-hollow` → `isFree: true`, 3 chapitres servis ;
- bascule « payant » → `303`, manifeste `isFree: false`, catalogue `isFree: false` ;
- bascule avec CSRF invalide → `403` ;
- déconnexion → `303 /admin/login`, puis accès à la liste → `303 /admin/login`.

## Interface

Contrôle dans Chrome headless 158 via CDP, viewport 1280×900, sans erreur
console ni exception :

- `.tmp/screens/phase14-admin-login.png`
- `.tmp/screens/phase14-admin-books.png`
- `.tmp/screens/phase14-admin-import.png`

La page de connexion, le tableau des livres avec badge et bouton de bascule, et
le formulaire d'import (fichier + choix d'accès) s'affichent correctement. Le
favicon est neutralisé (`href="data:,"`) pour éviter une requête 404.

## Sécurité vérifiée

- Routes `/admin` montées uniquement si `STORYLINGO_ADMIN_TOKEN` est défini ;
  sinon 404.
- Token comparé en temps constant ; jamais rendu dans les pages ni les logs.
- Cookie signé HS256, 12 h, `HttpOnly`, `SameSite=Lax`, `Secure` hors HTTP local.
- CSRF vérifié sur import, bascule et déconnexion.
- ZIP : refus des chemins absolus, `..`, backslashes, liens symboliques, plus de
  2 000 entrées, taille compressée et décompressée limitée (200 Mo par défaut,
  réglable).
- Import dans un répertoire temporaire système supprimé automatiquement ;
  publication via `publish_pack` (validation et rollback existants).
- Aucun secret ajouté au dépôt : valeurs de test factices uniquement.

## Limites assumées

- Un seul administrateur (token partagé), pas de comptes multiples ni de rôles.
- Suppression de livre, édition des métadonnées et CRUD complet ajoutés ensuite :
  voir `specs/2026-11-23-backoffice-crud/`.
- Pas de gestion RevenueCat depuis l'interface.
- Audit par logs structurés (`book`, `version`, `free`), sans table dédiée.
- En production, le back-office doit être placé derrière HTTPS, un reverse proxy
  et une restriction réseau ; les endpoints de contenu restent publics (gating
  client inchangé).
