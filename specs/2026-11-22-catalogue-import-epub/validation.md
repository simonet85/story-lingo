# Phase 10 — Validation : API contenu & catalogue

## Definition of Done

### 1. Analyse statique

```
flutter analyze
```

Code 0, sans erreur ni avertissement.

### 2. Tests automatisés

```
flutter test
pytest server/tests
```

Tous les tests passent, y compris ceux des phases 1 à 9.

Couverture attendue :

- **API** : health, catalogue + ETag/304, manifeste avec URLs de chapitres,
  chapitre, audio avec `Range` (200/206/416), 404 livre/chapitre, traversée de
  chemin refusée, base SQLite temporaire.
- **Import** : EPUB généré, chapitres/paragraphes non vides, annotation
  référencée et unique, publication en base, réimport sans doublon, échec propre
  sur EPUB/lexique invalide, audio désactivé par défaut.
- **Catalogue Flutter** : client HTTP simulé, chargement de 2 livres, cache
  écrit, repli cache puis embarqué en cas d'erreur, chapitre distant, audio
  `url`, manifeste `asset` ou `url`, 304/JSON invalide.
- **Lecture** : ouverture d'un livre distant, progression par livre, récap
  « livre terminé » du livre courant, 360 px sans overflow.
- **Non-régression** : phase 9 (boucle, télémétrie, réglages) reste verte.

### 3. Contrat API

- `GET /v1/health` → 200.
- `GET /v1/catalogue` → 200 + `ETag` ; second appel avec `If-None-Match` → 304.
- `GET /v1/books/sleepy-hollow` → manifeste 3 chapitres avec `url`.
- `GET /v1/books/sleepy-hollow/chapters/chapter-01` → chapitre valide, audio
  `url` si présent.
- `GET /v1/books/sleepy-hollow/audio/chapter-01.mp3` avec
  `Range: bytes=0-1023` → 206, `Content-Range: bytes 0-1023/…`.
- Livre inconnu → 404 ; `../` dans un nom de fichier → 404.

### 4. Import EPUB

- Un EPUB de test produit un pack relisible par l'application (modèles Dart
  compris).
- Chaque mot annoté a `cefr`, `pos`, `ipa`, `translationFr`, `definitionEn`,
  `example`, et est référencé dans le texte.
- Le manifeste indique `packVersion`, compteurs cohérents et au moins un
  chapitre ; les identifiants de chapitre sont uniques et numérotés sans trou.
- `--audio` produit MP3 + timings alignés (test manuel, réseau requis) ; sans
  `--audio`, aucun bloc audio.

### 5. Catalogue distant dans l'application

- Sans `API_BASE_URL` : comportement phase 9 inchangé, pile de tests verte.
- Avec l'API lancée : la bibliothèque affiche le pilote et le livre importé.
- Couper l'API après un premier chargement : le livre distant reste visible et
  lisible depuis le cache ; l'audio déjà en cache local n'est pas requis.
- Premier lancement hors-ligne : repli sur le pilote embarqué, sans erreur
  bloquante.
- Le cache n'est jamais corrompu par une réponse invalide.

### 6. Runtime

Aperçu Chrome (`.tmp/screens/web-catalogue-*.png`) :

- bibliothèque avec 2 livres, l'un importé ;
- chapitre du livre importé ;
- repli hors-ligne (serveur arrêté) montrant le cache/embarqué.

Émulateur Android (`storylingo_api36`, API sur `10.0.2.2:8000`) :

- catalogue distant chargé, livre importé visible ;
- lecture du livre importé, définition au tap ;
- audio du livre importé en streaming (progression, pause) ;
- après arrêt de l'API et redémarrage : catalogue en cache, pilote lisible ;
- mode avion : pilote embarqué et chapitres déjà consultés fonctionnent ;
- captures dans `.tmp/screens/android-catalogue-*.png`.

### 7. Préférences et stockage

- Aucune donnée personnelle côté serveur ; le cache local ne contient que du
  JSON de contenu et des horodatages.
- La version de préférences (`prefs.version = 1`) reste inchangée ; les nouvelles
  clés de cache sont préfixées `content.cache.`.
- Aucun secret dans le dépôt ; l'URL de l'API passe par `--dart-define`.

### 8. CI

- Job Flutter existant inchangé et vert.
- Nouveau job API : installation des dépendances et `pytest`.

## Not Required

- Téléchargement audio hors-ligne complet.
- Authentification, entitlements payants, synchronisation.
- Import de couvertures et d'images.
- Déploiement cloud réel (l'API tourne en local pour la validation).

## Résultats (2026-11-22)

Environnement : Flutter 3.50.1 / Dart 3.14.0, Python 3.11, Chrome, émulateur
`storylingo_api36` (1080×2400), API locale sur `http://10.0.2.2:8000`.

### Analyse et tests

- `flutter analyze` : aucun problème.
- `flutter test` : 202 tests verts (187 existants + 15 phase 10).
- `python -m pytest server/tests tools/content/tests` : 35 tests verts.
- CI : job Flutter inchangé ; job `api-content-tests` ajouté
  (`.github/workflows/ci.yml`).

### Contrat API vérifié

- `GET /v1/health` → 200 `{"status":"ok"}`.
- `GET /v1/catalogue` → 200 + `ETag`, second appel `If-None-Match` → 304
  (observé dans les logs web et Android).
- `GET /v1/books/night-train` → manifeste 2 chapitres avec `url` ;
  `sleepy-hollow` → 3 chapitres.
- `GET /v1/books/night-train/chapters/chapter-01` → chapitre schéma 2, audio
  `url` relative résolue côté client.
- `GET /v1/books/night-train/audio/chapter-01.mp3` avec
  `Range: bytes=0-1023` → 206, `Content-Range: bytes 0-1023/859248` ;
  lecture native complète → 200.
- Livre inconnu → 404 JSON ; identifiant de livre invalide → 422 ; `../` dans
  un fichier audio → 404.

### Import

- EPUB de démonstration (`night-train`, 2 chapitres « Le Départ », « La
  Vallée ») importé avec `--audio` (edge-tts) : `packVersion` 1.1.0, schéma 2,
  12 mots nouveaux, timings alignés sur les tokens.
- Pilote `sleepy-hollow` republié depuis le pack embarqué.

### Runtime web (`.tmp/screens/web-catalogue-*.png`)

- `web-catalogue-library-light.png` : catalogue distant + pilote, livre importé
  en tête.
- `web-catalogue-remote-chapter-light.png` : chapitre « Le Départ » annoté.
- `web-catalogue-cached-light.png` : bandeau « Catalogue en cache » après
  revalidation 304.
- `web-catalogue-remote-audio-mode.png` / `-playing.png` : mode Lire + Écouter,
  lecture du MP3 distant (progression, surlignage karaoké).

### Runtime Android (`.tmp/screens/android-catalogue-*.png`)

- `android-catalogue-today.png`, `android-catalogue-library.png` : catalogue
  distant chargé via `10.0.2.2`, deux livres, bandeau de cache.
- `android-catalogue-remote-chapter.png` : chapitre « Le Départ », durée audio
  0:22.
- `android-catalogue-remote-audio-playing.png` : lecture native du MP3 distant
  (0:04 / 0:22, pause, surlignage).
- Correctif nécessaire : `INTERNET` dans le manifeste principal et
  `usesCleartextTraffic="true"` en debug (ExoPlayer applique la politique
  cleartext, contrairement au client HTTP Dart).

### Hors-ligne Android (`.tmp/screens/android-offline-*.png`)

- Mode avion : `android-offline-library.png` affiche le bandeau « Catalogue en
  cache » et les deux livres ; le livre distant reste ouvrable.
- `android-offline-chapter.png` : chapitre déjà consulté relu depuis le cache,
  « Reprise là où vous vous êtes arrêté. » ; l'audio signale « Audio
  indisponible. » — cohérent avec le hors-scope (pas de téléchargement audio).

### Limites connues

- Le cache audio hors-ligne n'est pas implémenté (hors périmètre).
- Android exige HTTPS hors builds debug ; le déploiement réel devra servir
  l'API en TLS et retirer l'exception cleartext.
