# Phase 14b — Exigences : CRUD complet du back-office

Extension de `specs/2026-11-23-backoffice-contenu` : la liste, l'import et la
bascule gratuit/payant existent déjà. Cette phase ajoute la lecture détaillée,
l'édition des métadonnées et la suppression d'un livre.

## Lecture détaillée

- **FR-14b.1** — `/admin/books/{id}` affiche les métadonnées du livre (id,
  titre, titre français, auteur, niveau, description, version de pack, nombre
  de chapitres, durée, mots nouveaux, accès, mise à jour) et la liste des
  chapitres lus depuis le manifeste publié.
- **FR-14b.2** — Chaque ligne de la liste renvoie vers cette page de détail.
- **FR-14b.3** — Un identifiant inconnu répond 404 ; un manifeste illisible
  affiche la fiche sans les chapitres plutôt qu'une erreur 500.
- **FR-14b.4** — Les valeurs du manifeste restent échappées (anti-XSS).

## Édition

- **FR-14b.5** — `/admin/books/{id}/edit` (GET) propose un formulaire prérempli :
  titre, titre français, auteur, niveau, description française et accès
  gratuit/payant.
- **FR-14b.6** — Le POST exige un jeton CSRF valide (403 sinon) et une session
  admin (303 vers la connexion sinon).
- **FR-14b.7** — Validation : titre et titre français obligatoires (≤ 300
  caractères), auteur ≤ 200, niveau ≤ 8, description ≤ 1 000, accès limité à
  `free`/`paid`. Un champ invalide réaffiche le formulaire en 400 sans rien
  modifier.
- **FR-14b.8** — Un enregistrement valide met à jour la ligne `books`, les clés
  `title`, `titleFr`, `author`, `level`, `descriptionFr` du manifeste publié et
  le drapeau `isFree`, puis redirige vers le détail avec confirmation.
- **FR-14b.9** — Le descripteur `.download.json` est reconstruit à chaque
  édition afin que tailles et SHA-256 servis restent cohérents ; le remplacement
  du pack est atomique (staging + backup de `publish_pack`).
- **FR-14b.10** — Un identifiant inconnu répond 404.

## Suppression

- **FR-14b.11** — `/admin/books/{id}/delete` n'agit que si le formulaire
  contient l'identifiant exact du livre ; sinon la fiche est réaffichée avec un
  message et rien n'est supprimé.
- **FR-14b.12** — La suppression est réversible : le dossier du pack est déplacé
  dans `<content_dir>/.deleted/<id>-<horodatage UTC>-<suffixe aléatoire>`, puis
  la ligne `books` est supprimée.
- **FR-14b.13** — Si la suppression en base échoue, le dossier archivé est
  restauré à son emplacement d'origine.
- **FR-14b.14** — Après succès, `/v1/catalogue` et `/v1/books/{id}` ne servent
  plus le livre (404) et la liste affiche une confirmation.
- **FR-14b.15** — Une suppression est possible même si le dossier de pack a déjà
  disparu (la ligne est retirée). CSRF absent → 403, session absente → 303,
  identifiant inconnu → 404.

## Tests visuels

- **FR-14b.16** — Un scénario Node/CDP rejoue le cycle complet sur un serveur
  scratch : connexion, import d'une archive de test, captures de la liste et du
  détail, édition via le formulaire, vérification du manifeste, du catalogue et
  de chaque fichier du descripteur (taille + SHA-256), suppression via
  l'interface, vérification du 404 et de la disparition dans le catalogue.
- **FR-14b.17** — Le scénario échoue si une exception, une erreur console ou une
  erreur réseau est observée dans le navigateur.

## Sécurité et données

- **SEC-14b.1** — Aucun secret ajouté au dépôt ; le token du scénario visuel est
  fourni par variable d'environnement.
- **SEC-14b.2** — Les tests et le scénario n'écrivent jamais dans `server/data` :
  base SQLite et packs vivent dans `.tmp/`.
- **SEC-14b.3** — Les routes publiques, le CORS local et l'authentification
  applicative restent inchangés.

## Hors périmètre

- Restauration d'un livre depuis l'interface (l'archive `.deleted/` se restaure
  à la main), purge automatique des archives, édition chapitre par chapitre,
  historique d'audit en base, comptes admin multiples.
