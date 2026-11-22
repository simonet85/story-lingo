# Phase 12 — Plan : Hors-ligne complet

## Objectif

Permettre de télécharger un livre et son audio, vérifier l'intégrité du pack,
le mettre à jour atomiquement, puis lire, écouter et réviser sans réseau.
Le web reste un aperçu : cache JSON existant et mention « disponible sur mobile ».

## Périmètre

Livré : descripteur de téléchargement (taille + SHA-256 par fichier), publication
serveur atomique, stockage local natif, téléchargement avec progression et
annulation, vérification d'intégrité, badge de mise à jour, lecture/audio hors
ligne, espace utilisé et suppression.

Hors périmètre : téléchargement web, ZIP, reprise partielle, téléchargement en
arrière-plan, mises à jour automatiques, quota imposé, clips de mots depuis
l'audio téléchargé (TTS conservé), re-hachage complet au démarrage.

## A. Contrat serveur

### Descripteur

`GET /v1/books/{book_id}/download` — JSON, ETag :

```json
{
  "schemaVersion": 1,
  "bookId": "sleepy-hollow",
  "packVersion": "1.3.0",
  "totalBytes": 2541123,
  "files": [
    {"kind": "manifest", "path": "manifest.json",
     "url": "/v1/books/sleepy-hollow",
     "downloadUrl": "/v1/books/sleepy-hollow/files/manifest.json",
     "sizeBytes": 812, "sha256": "<64 hex>"},
    {"kind": "chapter", "chapterId": "chapter-01",
     "path": "chapters/chapter-01.json",
     "url": "/v1/books/sleepy-hollow/chapters/chapter-01",
     "downloadUrl": "/v1/books/sleepy-hollow/files/chapters/chapter-01.json",
     "sizeBytes": 9210, "sha256": "<64 hex>"},
    {"kind": "audio", "path": "audio/chapter-01.mp3",
     "url": "/v1/books/sleepy-hollow/audio/chapter-01.mp3",
     "downloadUrl": "/v1/books/sleepy-hollow/audio/chapter-01.mp3",
     "sizeBytes": 612345, "sha256": "<64 hex>"}
  ]
}
```

- `url` reproduit l'URL utilisée dans les JSON consommés (association audio local).
- `downloadUrl` sert au téléchargement effectif.
- Ordre déterministe : manifeste, chapitres, audio triés et dédupliqués.

`GET /v1/books/{id}/files/{rel_path}` sert les octets **exactement hachés** :
manifeste/chapitres sérialisés canoniquement (`ensure_ascii=False`, séparateurs
`,`/`:`) avec URLs relatives. L'audio réutilise `/audio/{file}` (Range/ETag).
Refus des chemins absolus, `..`, `\`, NUL et noms inconnus.

### Implémentation

- `server/app/packs.py` : payloads purs (`manifest_payload_from`,
  `chapter_payload_from`), `canonical_json`, `build_download_descriptor`,
  sidecar `<pack>/.download.json` écrit à la publication et reconstruit si
  `packVersion` diffère.
- Publication atomique : staging `.staging/<book>-<uuid>` sur le même volume,
  backup `.backup/<book>-<uuid>`, `os.replace` avec rollback, commit DB après
  swap, retries Windows, nettoyage des résidus > 24 h.
- Tests : `server/tests/test_downloads.py`, extension de
  `server/tests/test_publish.py` et `tools/content/tests/test_publish_integration.py`.
- Documentation : `server/README.md`.

## B. Stockage Flutter

Dépendances directes : `path_provider`, `crypto`, `path` (versions du lock).

```
<appSupport>/storylingo/downloads.json
<appSupport>/storylingo/packs/<bookId>/{manifest.json,chapters/,audio/,pack.json}
<appSupport>/storylingo/staging/<bookId>-<token>/
<appSupport>/storylingo/trash/<bookId>-<token>/
```

- `PackStore` sans `dart:io` : implémentations `pack_store_io.dart` et
  `pack_store_stub.dart` via import conditionnel ; aucun `dart:io` dans le web.
- Index `downloads.json` : version, date, taille, nombre de fichiers par livre.
- Réconciliation au démarrage : nettoyage staging/trash, entrées incohérentes
  retirées.
- Suppression : pack vers trash puis effacement, index mis à jour.

## C. Téléchargement

- `PackDownloader` : descripteur, validation (bookId, SHA 64 hex, tailles,
  chemins sûrs), stream vers staging avec hachage incrémental, vérification
  SHA/taille, progression, annulation.
- Échec avant commit : staging supprimé, pack précédent intact.
- Commit : `pack → trash`, `staging → pack`, rollback si échec, suppression du
  trash, puis écriture de l'index.
- Un seul téléchargement actif, pas de reprise partielle.
- Exceptions typées : réseau, HTTP, intégrité, stockage, annulation, non supporté,
  base URL absente.

## D. Contenu et audio hors ligne

- `LocalPackContent` lit manifeste/chapitres installés avec les modèles existants.
- Priorité : pack installé > asset embarqué > cache > réseau, pour le manifeste
  et les chapitres ; le pilote accepte aussi les mises à jour.
- `catalogueProvider` fusionne les packs installés (bibliothèque hors ligne).
- Erreur dédiée : « Ce chapitre n'est pas téléchargé. Connectez-vous ou
  téléchargez le livre. »
- `ChapterAudio.localFile` + résolution `audio.url → downloadUrl → chemin local`.
- `AudioEngine.loadFile` (`setFilePath`), fake de test étendu ; le contrôleur
  choisit `localFile > url > asset`.

## E. UI

- `BookDownloadControl` sous le CTA des cartes livre :
  web (mention mobile), non installé, progression + annuler, téléchargé + taille,
  mise à jour + bouton, échec + réessayer, base URL absente.
- `DownloadsSection` dans Réglages : total, liste, suppression avec confirmation,
  état vide, mention web.
- Format FR `formatBytes`, sémantique avec pourcentage, 360 px sans overflow.

## F. Ordre d'implémentation

1. Specs + README.
2. Serveur (descripteur, `/files`, sidecar, publication atomique, tests).
3. Socle Flutter (dépendances, `PackStore`, plateforme, index).
4. Téléchargeur + repository + providers + tests.
5. Contenu (`LocalPackContent`, priorités, catalogue) et audio local.
6. UI cartes + Réglages.
7. Validation complète, build web, runtime Android, résultats.
