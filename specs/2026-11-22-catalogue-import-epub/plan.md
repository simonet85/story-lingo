# Phase 10 — Plan : API contenu & catalogue

Objectif : sortir le contenu du seul pack embarqué. Un service FastAPI publie un
catalogue et des packs, un CLI importe un EPUB annoté, et l'application Flutter
charge le catalogue distant avec cache local et repli sur l'embarqué.

Tranche livrée : API + import EPUB + catalogue distant côté app. Sans comptes,
paiements, téléchargement hors-ligne complet ni file de jobs asynchrone.

## A. Service FastAPI

- Nouveau paquet `server/` : FastAPI + Pydantic v2 + SQLAlchemy 2.
  - `DATABASE_URL` : SQLite par défaut en dev/tests ; PostgreSQL possible via
    l'URL (psycopg non requis pour les tests).
  - `CONTENT_DIR` : racine des packs publiés (défaut `server/data/packs`).
  - `PUBLIC_BASE_URL` : base des URLs d'audio si un CDN remplace l'API.
- Table `books` minimale : identité, niveau, description FR, `packVersion`,
  compteurs, dossier du pack, `isFree`, `updatedAt`.
- Endpoints `/v1` :
  - `GET /health` ;
  - `GET /catalogue` (liste + ETag/304) ;
  - `GET /books/{id}` (manifeste schéma 1, chapitres avec `url`) ;
  - `GET /books/{id}/chapters/{chapterId}` (chapitre schéma 1/2, audio avec
    `url` ou `asset`) ;
  - `GET /books/{id}/audio/{file}` (MP3, requêtes Range) ;
  - CORS limité aux origines locales de développement.
- Script de publication du pack pilote existant (`server/scripts/publish_pack.py`)
  pour amorcer la base et le store.
- Tests `pytest` + `TestClient` sur base SQLite temporaire et pack fixture :
  catalogue, ETag, manifeste, chapitre, audio Range, 404/422.

## B. Import EPUB

- `tools/content/import_book.py` (ebooklib + BeautifulSoup) :
  - parcourt le spine HTML, ignore couverture/nav, déduit les titres (TOC ou
    premier `h1/h2`), découpe les paragraphes ;
  - annote via un lexique versionné `tools/content/lexicon/a2.json` (formes
    surface → lemme, CEFR, POS, IPA, traduction FR, définition EN) ; les mots
    hors lexique restent du texte ;
  - génère des identifiants de vocabulaire stables par lemme, référence chaque
    entrée dans les segments, ignore les doublons ;
  - audio optionnel (`--audio`) via un module partagé avec
    `generate_chapter_audio.py` (edge-tts, timings alignés token par token) ;
  - écrit le pack (manifeste + chapitres + audio) dans `CONTENT_DIR` et publie
    la ligne catalogue (même base que le service).
- Lexique initial dérivé du pack pilote (56 entrées A2/B1), extensible.
- Tests : EPUB généré à la volée, sortie valide (paragraphes, vocabulaire
  référencé, identifiants uniques), publication en base, dry-run sans audio.

## C. Application Flutter

- Dépendance `http` ; `API_BASE_URL` injectée par `--dart-define` (vide =
  embarqué uniquement).
- `CatalogueRepository` :
  - charge `/catalogue`, les manifestes et les chapitres distants ;
  - cache JSON dans `SharedPreferences` (clé par livre/chapitre + horodatage,
    TTL 12 h) et cache mémoire ;
  - en cas d'échec réseau (timeout 3 s, JSON invalide), utilise le cache même
    périmé, sinon le pack embarqué ; le pilote reste toujours disponible.
- Modèles : un chapitre du manifeste porte `asset` **ou** `url` ; l'audio porte
  `asset` **ou** `url` (un seul des deux, validation stricte).
- Lecture de n'importe quel livre : `chapterProvider` résout le manifeste par
  `bookId` ; le récap « livre terminé » porte sur le livre courant.
- Bibliothèque : liste des livres du catalogue (pilote + livres importés),
  états chargement/erreur, carte réutilisable, CTA premier chapitre.
- Audio distant : `AudioEngine.loadUrl`, streaming via l'API/CDN.
- Le programme 28 jours reste adossé au livre pilote ; les livres du catalogue
  sont lisibles hors parcours (un parcours multi-livres viendra plus tard).
- Tests : repository HTTP simulé, cache et repli hors-ligne, bibliothèque à
  2 livres, chapitre/audio distants, 360 px sans overflow.

## D. Outillage et CI

- `server/requirements.txt` (fastapi, uvicorn, sqlalchemy, pydantic, httpx,
  ebooklib, beautifulsoup4, edge-tts) et `server/requirements-dev.txt` (pytest).
- `server/README.md` : démarrage local, publication du pilote, import d'un EPUB,
  variables d'environnement.
- CI : job Python (`pip install`, `pytest`) à côté du job Flutter.

## Décisions

- **SQLite par défaut**, PostgreSQL via `DATABASE_URL` : le schéma reste
  portable, les tests ne dépendent pas de Docker.
- **Cache JSON TTL 12 h avec repli périmé** : lecture immédiate et tolérance
  hors-ligne ; l'audio n'est pas téléchargé (phase 12).
- **Annotation par lexique versionné** : reproductible et testable ; la liste
  CEFR complète et la détection de mots non annotés arriveront avec le pipeline
  éditorial élargi.
- **Entitlement minimal** (`isFree`) sans auth : l'application n'applique aucun
  verrou avant la phase 13.
- **Pas de file arq/Redis** : l'import est un CLI synchrone pour cette tranche.

## Not Required

- Comptes, JWT, synchronisation, entitlements premium.
- Téléchargement/lecture audio hors-ligne, intégrité et mise à jour atomique.
- CDN signé, observabilité Sentry, analytics distants.
- Import d'images, pagination complexe, liste CEFR complète.
- Administration web du catalogue.
