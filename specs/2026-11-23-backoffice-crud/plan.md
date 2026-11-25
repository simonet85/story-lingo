# Phase 14b — Plan : CRUD complet du back-office

## Objectif

Compléter le back-office (liste, import, bascule) avec trois opérations : lire
le détail d'un livre, éditer ses métadonnées et sa politique d'accès, supprimer
un livre de façon réversible. Ajouter un scénario visuel qui rejoue tout le
cycle dans Chrome.

## Décisions

- **Lecture** : page de détail rendue côté serveur à partir de la ligne `books`
  et du manifeste publié ; un manifeste illisible dégrade la page, pas la route.
- **Édition via `publish_pack`** : le pack est copié dans un répertoire
  temporaire, le manifeste y est modifié, puis `publish_pack` refait validation,
  publication atomique, mise à jour SQL et reconstruction du descripteur
  `.download.json`. Cela évite d'écrire une seconde fois toute la logique de
  publication et garantit des hashes cohérents pour le hors-ligne.
- **Suppression réversible** : archivage du dossier dans
  `<content_dir>/.deleted/` (nom horodaté + suffixe aléatoire), puis suppression
  de la ligne `books`; en cas d'échec SQL, restauration du dossier. Aucune
  commande destructive : rien n'est effacé, seulement déplacé.
- **Confirmation par identifiant** : le formulaire de suppression exige la
  saisie exacte de l'id du livre, en défense contre les clics accidentels.
- **CSRF et session** : mêmes dépendances que les mutations existantes.

## Serveur

### `server/app/packs.py`

- `archive_pack(folder, content_dir) -> Path` : crée `.deleted/`, déplace le
  dossier sous un nom `{id}-{UTC:%Y%m%dT%H%M%SZ}-{uuid8}` via le helper de
  remplacement existant et renvoie le chemin d'archive.

### `server/app/admin/routes.py`

- Helpers : `_book_or_404`, `_clean_text` (trim, non vide, longueur max),
  `_book_view`, `_render_detail`, `_render_edit`.
- `GET /admin/books/{book_id}` : métadonnées + chapitres (PackError tolérée).
- `GET /admin/books/{book_id}/edit` : formulaire prérempli.
- `POST /admin/books/{book_id}/edit` : CSRF, validation des champs, copie
  temporaire du pack, réécriture du manifeste (`title`, `titleFr`, `author`,
  `level`, `descriptionFr`), `publish_pack(..., is_free=...)`, redirection vers
  le détail avec `notice=updated`.
- `POST /admin/books/{book_id}/delete` : CSRF, `confirm` = id exact,
  `archive_pack` puis suppression SQL avec restauration en cas d'échec,
  redirection avec `notice=deleted`.
- Nouveaux avis : `updated`, `deleted` (bandeaux de confirmation).

### Templates

- `book_detail.html` : tableau de métadonnées, tableau des chapitres, carte de
  suppression avec avertissement sur l'archivage.
- `book_edit.html` : formulaire complet, boutons Enregistrer/Annuler.
- `books.html` : lien « Détails » dans la colonne d'actions.
- `base.html` : styles champs/textarea, tables compactes, zone dangereuse.

## Tests Python

- `server/tests/test_admin_books.py` — détail (métadonnées + chapitres), 404,
  présence du lien.
- `server/tests/test_admin_edit.py` (9) — formulaire prérempli ; mise à jour
  BDD + manifeste + catalogue ; reconstruction du descripteur avec vérification
  de taille et SHA-256 de chaque fichier ; titre vide ; description trop
  longue ; accès invalide ; 404 ; CSRF ; session.
- `server/tests/test_admin_delete.py` (6) — confirmation exacte exigée ; pack
  archivé + ligne supprimée + disparition du catalogue et du manifeste ;
  dossier absent ; 404 ; CSRF ; session.

## Test visuel

- `tools/visual/fixtures/visual-crud.zip` : pack déterministe (`visual-crud`,
  un chapitre, sans audio) pour ne pas dépendre du contenu réel.
- `tools/visual/admin_crud.mjs` : Node 22+ (fetch, FormData, File, WebSocket),
  Chrome CDP. Connexion HTTP, import, captures, connexion dans le navigateur,
  édition via le formulaire, vérification manifeste/catalogue/descripteur
  (taille + SHA-256), suppression via l'interface, vérification du 404 et du
  catalogue ; toute exception/erreur console ou réseau fait échouer le script.
- Captures dans `.tmp/visual/` : `01-login.png` … `06-list-after-delete.png`.

## Documentation

Section « Back-office » de `server/README.md` : détail, édition, suppression et
archivage, lancement du scénario visuel, rappel que `.deleted/` n'est jamais
purgé automatiquement.

## Limites

- Pas de restauration depuis l'interface ; une archive se restaure à la main.
- Pas d'édition des chapitres ni du contenu audio.
- Un seul administrateur, audit par logs, périmètre réseau inchangé.
