# Phase 10 — Requirements : API contenu & catalogue

## A. Service catalogue

### Contrat HTTP (`/v1`)

- `GET /health` → `200 {"status":"ok"}`.
- `GET /catalogue` → `200` :

```json
{
  "updatedAt": "2026-11-22T10:00:00Z",
  "books": [
    {
      "id": "sleepy-hollow",
      "title": "The Legend of Sleepy Hollow",
      "titleFr": "La Légende de Sleepy Hollow",
      "author": "Washington Irving",
      "level": "a2",
      "descriptionFr": "…",
      "packVersion": "1.3.0",
      "chapterCount": 3,
      "totalMinutes": 18,
      "newWordCount": 56,
      "isFree": true,
      "manifestUrl": "/v1/books/sleepy-hollow"
    }
  ]
}
```

  L'en-tête `ETag` reflète le contenu ; `If-None-Match` renvoie `304` sans corps.
- `GET /books/{id}` → manifeste compatible schéma 1, chaque chapitre portant
  `url` (et non `asset`) : `/v1/books/{id}/chapters/{chapterId}`.
- `GET /books/{id}/chapters/{chapterId}` → chapitre schéma 1 ou 2. Si le
  chapitre a de l'audio, la source est soit `url` (servie par l'API/CDN), soit
  `asset` (pack embarqué uniquement).
- `GET /books/{id}/audio/{fichier}` → `200`/`206` avec `Content-Type:
  audio/mpeg`, `Accept-Ranges: bytes`, `Content-Range` correct pour une requête
  `Range: bytes=a-b` ; `416` si la plage est invalide.
- Livre ou chapitre inconnu → `404` JSON `{"detail": "…"}`.
- Identifiant de livre invalide → `422` (validation FastAPI).

### Données

- Une ligne `books` par pack publié ; les compteurs (`chapterCount`,
  `totalMinutes`, `newWordCount`) proviennent du manifeste.
- Le service refuse de publier un pack dont le manifeste ou un chapitre est
  invalide (JSON malformé, schéma inconnu, chapitre absent du dossier).
- Le pack pilote est publiable par script depuis `assets/content/sleepy-hollow-a2`
  sans dupliquer les fichiers dans le dépôt.

### Erreurs et robustesse

- Toute erreur inattendue renvoie `500` JSON, jamais une trace HTML.
- Les chemins de fichiers sont résolus sous `CONTENT_DIR` ; une tentative de
  traversée (`..`) renvoie `404`.
- L'API démarre sans réseau ni PostgreSQL (SQLite par défaut).

## B. Import EPUB

- Entrée : fichier `.epub` lisible par ebooklib, identifiant de livre, métadonnées
  (titre, titre FR, auteur, niveau, description FR) et lexique JSON.
- Sortie : pack conforme aux schémas existants (manifeste 1, chapitres 1 ou 2),
  écrit dans `CONTENT_DIR/<bookId>/`, et ligne catalogue publiée.
- Découpage : un document HTML du spine = un chapitre ; documents sans
  paragraphe texte (couverture, nav, colophon vide) ignorés ; numérotation
  continue à partir de 1 ; au moins un chapitre sinon échec explicite.
- Texte : paragraphes non vides uniquement ; espaces normalisés ; ponctuation
  et apostrophes typographiques conservées.
- Annotation :
  - une entrée de vocabulaire par lemme rencontré dans le lexique ;
  - `id` kebab-case stable, `cefr`, `pos`, `ipa`, `translationFr`,
    `definitionEn`, `example` (phrase du chapitre contenant le mot) ;
  - chaque entrée est référencée par au moins un segment ;
  - les formes hors lexique restent en texte simple ;
  - mots vides (≤ 2 lettres hors lexique) jamais annotés.
- Audio :
  - `--audio` génère un MP3 par chapitre et des timings token par token
    strictement croissants, vocabulaire indépendant de l'audio ;
  - sans `--audio`, le chapitre est produit en schéma 1 sans bloc audio ;
  - un échec de synthèse annule la publication du livre (pas de pack partiel).
- Idempotence : réimporter le même livre met à jour la ligne catalogue et
  remplace le dossier du pack, sans doublons.
- Tests : EPUB construit en mémoire/temporaire, import sans audio, validation du
  pack produit et de la publication ; cas d'erreur (EPUB vide, lexique absent).

## C. Application

- Sans `API_BASE_URL` (valeur vide), l'application se comporte comme en phase 9 :
  catalogue = pack embarqué, aucun appel réseau.
- Avec `API_BASE_URL`, au démarrage de la bibliothèque :
  - catalogue distant chargé, affiché avec le pilote (ordre : catalogue serveur) ;
  - chaque carte affiche niveau, auteur, titre FR, durée, mots nouveaux,
    chapitres et CTA « Lire/Continuer/Relire le chapitre N » ;
  - une panne réseau (timeout 3 s) n'empêche pas l'usage : cache, sinon pilote
    embarqué, avec message discret non bloquant.
- Cache :
  - catalogue, manifestes et chapitres distants stockés en JSON local ;
  - TTL 12 h ; au-delà, tentative réseau puis repli sur le cache périmé ;
  - une réponse invalide n'écrase jamais un cache valide.
- Lecture :
  - `/read/:bookId/:chapterId` charge le manifeste et le chapitre du livre
    demandé (assets ou réseau/cache) ;
  - progression, position et récap fonctionnent par livre/chapitre ;
  - le récap « livre terminé » se base sur les chapitres du livre courant.
- Audio distant :
  - un chapitre dont l'audio porte `url` est lu en streaming (lecteur et
    karaoké identiques) ;
  - un audio `asset` continue de fonctionner hors-ligne.
- Le programme 28 jours, la révision et les réglages restent adossés au livre
  pilote ; l'export télémétrie ne change pas de format.
- Accessibilité : cibles ≥ 44 px, libellés complets, aucun overflow à 360 px.

## D. Contraintes techniques

- Nouvelle dépendance Flutter : `http` épinglée.
- Aucune clé secrète dans le dépôt ; URLs d'API fournies par `--dart-define`.
- Le service ne stocke aucune donnée personnelle : catalogue et packs seulement.
- `flutter analyze` sans avertissement, `flutter test` vert,
  `pytest` vert, CI Flutter inchangée + job API ajouté.

## Not Required

- Authentification, comptes, synchronisation, paywall.
- Téléchargement complet d'un pack, audio hors-ligne, CDN signé.
- Import d'images ou de couvertures.
- Liste CEFR exhaustive, détection des mots non annotés.
- Jobs asynchrones (arq/Redis), observabilité serveur avancée.
