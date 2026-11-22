# Phase 12 — Validation : Hors-ligne complet

## Definition of Done

### 1. Analyse statique

```
flutter analyze
flutter build web
```

Code 0, sans erreur ni avertissement ; le build web ne référence aucun `dart:io`.

### 2. Tests automatisés

```
flutter test
python -m pytest server/tests tools/content/tests
```

Tous les tests passent, y compris ceux des phases 1 à 11.

Couverture attendue :

- **Serveur** : descripteur (schéma, ordre, total), octets servis == hashes et
  tailles, URLs relatives puis préfixées, ETag/304, chemins dangereux refusés,
  publication atomique avec rollback, sidecar présent.
- **Client** : parsing du descripteur, validation des chemins, hachage incrémental,
  progression, annulation, intégrité en échec, staging nettoyé, swap/rollback,
  réconciliation, suppression.
- **Contenu** : pack installé prioritaire, manifeste/chapitre locaux, audio local,
  fusion catalogue hors ligne, invalidation après suppression.
- **UI** : cinq états de carte, section Réglages, suppression confirmée, mention
  web, 360 px sans overflow, non-régression.

### 3. Contrat API

- `GET /v1/books/{id}/download` → 200, `totalBytes` = somme des tailles.
- Chaque `downloadUrl` renvoie des octets dont taille et SHA-256 correspondent.
- `GET /v1/books/{id}/files/manifest.json` et `chapters/*.json` → JSON canonique,
  URLs relatives, pas de champ `asset`.
- `../`, chemin absolu, `\`, NUL, fichier inconnu → 404.
- Les endpoints existants (catalogue, manifeste, chapitre, audio) sont inchangés.

### 4. Runtime Android

Émulateur `storylingo_api36`, API locale sur une copie de `server/data` :

- télécharger un livre depuis la carte, vérifier progression puis espace Réglages ;
- mode avion, tuer/relancer l'app : bibliothèque, lecture, écoute karaoké et
  révision SRS fonctionnent ;
- republier une version supérieure : badge « Mise à jour disponible », mise à jour,
  puis contenu/audio neufs hors ligne ;
- supprimer le pack : retour au streaming en ligne, message clair hors ligne ;
- corrompre un fichier local : erreur contrôlée, pas de crash, retéléchargement
  possible.

Captures : `.tmp/screens/android-offline-*.png`.

### 5. Régression web

`flutter build web` puis aperçu Chrome : cache JSON existant, mention
« téléchargement disponible sur mobile », aucun crash lié à `path_provider`.

### 6. Sécurité et documentation

- Chemins serveur validés ; aucun accès hors du pack.
- Hashes vérifiés ; aucun secret introduit.
- `server/README.md` décrit le descripteur et `/files/`.

## Not Required

- Téléchargement sur web, ZIP, reprise partielle, arrière-plan.
- Mises à jour automatiques, quota imposé, re-hachage complet au démarrage.
- Clips de mots depuis l'audio téléchargé (TTS conservé).

## Résultats

### Environnement

- Flutter 3.50.1 / Dart 3.14.0, Riverpod 3.5.0.
- Émulateur Android `emulator-5554` (API 36, 1080×2400), app en build debug
  pointant sur l'API locale via `--dart-define=API_BASE_URL=http://10.0.2.2:8000`.
- API FastAPI locale sur une copie de `server/data`
  (`.tmp/runtime/data`, journal `.tmp/runtime/api.log`).
- Web : build par défaut (sans `API_BASE_URL`), aperçu Chrome headless via CDP
  sur `http://127.0.0.1:8080`.

### 1. Analyse statique

- `flutter analyze` → **No issues found!** (87,9 s).
- `flutter build web` → **succès** (294 s). Le graphe web compile sans `dart:io`
  (PackStore stub / import conditionnel), aucun crash `path_provider`.

### 2. Tests automatisés

- `flutter test` → **269 tests passés**, dont les phases 1 à 11.
- `python -m pytest server/tests tools/content/tests` → **74 passés**.

Deux tests de régression ont été ajoutés pendant cette validation :

- `test/catalogue_repository_test.dart` : un chapitre non caché hors ligne lève
  une `CatalogueException` (« Network error ») au lieu de laisser fuir
  `ClientException`/`TimeoutException`.
- `test/offline_content_providers_test.dart` : `chapterProvider` d'un chapitre
  non installé hors ligne lève `ContentOfflineException` avec le message
  « Ce chapitre n'est pas téléchargé… » (via un faux client réseau).

Couverture existante confirmée : descripteur (schéma, ordre, total), octets
servis == hashes, ETag/304, chemins dangereux, publication atomique + rollback,
sidecar, parsing/validation client, hachage incrémental, progression,
annulation, staging nettoyé, swap/rollback, réconciliation, suppression,
priorité du pack, audio local, fusion catalogue, états de carte, section
Réglages, 360 px, mention web.

### 3. Contrat API (vérifié sur l'API locale)

- `GET /v1/books/night-train/download` → 200, `packVersion` 1.2.0,
  `totalBytes` 260 642 = somme exacte des 5 fichiers, ordre manifeste →
  chapitres → audio, ETag présent, `If-None-Match` → 304.
- Chaque `downloadUrl` renvoie des octets dont taille et SHA-256 correspondent
  (manifeste, 2 chapitres, 2 audios). JSON canonique, URLs relatives, sans
  champ `asset`.
- `../`, chemin absolu, `\`, NUL, fichier inconnu → 404.
- Endpoints existants (catalogue, manifeste, chapitre, audio) inchangés.

### 4. Runtime Android (captures `.tmp/screens/android-offline-*.png`)

| Scénario | Preuve |
| --- | --- |
| Téléchargement depuis la carte, progression, annulation | `04`, `05`, `44`, `45` |
| Espace/version/taille dans Réglages | `06` |
| Mode avion + relance : bibliothèque (cache), lecture, écoute karaoké, SRS | `07` → `13` |
| Republication 1.2.0 : badge, mise à jour, contenu neuf hors ligne | `19` → `22` |
| Fichier corrompu : erreur contrôlée, pas de crash | `24` |
| Suppression : confirmation, état vide, retour au streaming en ligne | `25` → `29` |
| Chapitre non téléchargé hors ligne : message dédié immédiat | `41` |
| « Réessayer » une fois en ligne : streaming rétabli | `42`, `43` |
| Re-téléchargement après suppression : « Téléchargé · 260.6 ko » | `46` |

Vérifications complémentaires : pack sur disque
`files/storylingo/packs/night-train/{manifest,chapters,audio,pack.json}` et
index `downloads.json` (packVersion 1.2.0, 260 642 octets, 5 fichiers,
`baseUrl`). Le streaming après suppression a été confirmé par les requêtes
`/v1/books/night-train/chapters/chapter-01` et `/audio/chapter-01.mp3` dans
`.tmp/runtime/api.log`.

### Défauts trouvés et corrigés pendant la validation

1. **Badge de mise à jour invisible** — la fusion du catalogue remplaçait
   l'entrée réseau par le manifeste installé (packVersion 1.1.0), masquant la
   version distante. Corrigé : l'entrée réseau (et son `packVersion`) est
   conservée, la priorité du contenu reste assurée par `bookManifestProvider`.
2. **Message hors ligne non spécifique et lent** — les erreurs de transport
   n'étaient pas converties en `CatalogueException`, donc l'écran de lecture
   affichait « Impossible de charger le chapitre. » après le backoff Riverpod
   (~100 s). Corrigé : `_getJson` enveloppe les échecs réseau et les trois
   providers de contenu utilisent `retry: _noRetry` → message dédié en ~2 s.
   Les deux tests de régression ci-dessus couvrent ces cas.

### 5. Régression web (captures `.tmp/screens/web-*-phase12.png`)

- `#/library` et `#/settings` rendus dans Chrome headless : **0 exception,
  0 erreur console**, aucune trace `path_provider`.
- Carte pilote : mention « Téléchargement hors-ligne disponible sur
  l'application mobile. » ; Réglages : section Téléchargements avec mention
  mobile / streaming.
- Le build web par défaut n'a pas d'`API_BASE_URL` : le catalogue embarqué est
  affiché (pas de bannière de cache attendue sur ce build). Les chemins du
  cache JSON (TTL 12 h, revalidation ETag, repli sur cache périmé) restent
  couverts par `test/catalogue_repository_test.dart`.

### 6. Sécurité et documentation

- Chemins refusés côté serveur et revérifiés côté client (relatifs, sans
  `..`, `\`, NUL) ; hashes vérifiés à la volée, staging supprimé en cas
  d'échec.
- Aucun secret ajouté au dépôt ; l'URL d'API reste injectée par
  `--dart-define`.
- `server/README.md` documente le descripteur, `/files/`, le sidecar et la
  publication atomique.

### Limites connues

- Web : téléchargement indisponible (choix validé) ; streaming et cache JSON
  conservés.
- Pas de reprise partielle, de téléchargement en arrière-plan, de mise à jour
  automatique ni de quota imposé.
- Les clips de mots reposent toujours sur le TTS hors ligne, pas sur l'audio
  téléchargé.
- Le scénario « chapitre non téléchargé hors ligne » a été reproduit en
  supprimant l'entrée de cache du chapitre 1 (le routeur n'expose pas de
  navigation directe vers le chapitre 2) ; le code parcouru est identique.

