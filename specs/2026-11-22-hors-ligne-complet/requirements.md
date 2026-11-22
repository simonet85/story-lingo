# Phase 12 — Exigences : Hors-ligne complet

## Téléchargement et intégrité

- **FR-12.1** — L'API expose `GET /v1/books/{id}/download` avec `schemaVersion`,
  `bookId`, `packVersion`, `totalBytes` et, pour chaque fichier, `kind`, `path`,
  `url`, `downloadUrl`, `sizeBytes` et `sha256`.
- **FR-12.2** — `GET /v1/books/{id}/files/{rel_path}` sert exactement les octets
  dont le SHA-256 figure dans le descripteur ; les URLs internes sont relatives.
- **FR-12.3** — Le client refuse un descripteur incohérent (bookId, hash, taille,
  chemin non relatif) et tout fichier dont le SHA-256 ou la taille diffère.
- **FR-12.4** — Le téléchargement affiche une progression, peut être annulé et ne
  laisse aucun fichier partiel en cas d'échec.

## Stockage et mise à jour atomique

- **FR-12.5** — Les fichiers sont stockés dans le dossier support de l'application,
  avec un index persistant (version, date, taille, nombre de fichiers).
- **FR-12.6** — Une mise à jour télécharge dans un staging, vérifie l'intégrité,
  puis remplace l'ancien pack ; en cas d'échec, l'ancien pack reste utilisable.
- **FR-12.7** — La publication serveur est atomique (staging + swap + rollback)
  et laisse l'ancien pack intact si une étape échoue.
- **FR-12.8** — Au démarrage, les staging/trash résiduels et les entrées
  incohérentes sont nettoyés sans supprimer un pack valide.
- **FR-12.9** — L'utilisateur voit l'espace utilisé, la liste des livres
  téléchargés et peut supprimer un pack après confirmation.

## Lecture et révision hors réseau

- **FR-12.10** — Un pack installé est prioritaire sur l'asset, le cache et le
  réseau pour le manifeste et les chapitres, y compris pour le livre pilote.
- **FR-12.11** — La bibliothèque liste les livres téléchargés même si le cache
  réseau est absent.
- **FR-12.12** — Un chapitre téléchargé se lit sans réseau ; l'audio téléchargé
  est joué depuis le fichier local (karaoké inclus).
- **FR-12.13** — La révision SRS reste entièrement locale ; la prononciation de
  mot utilise le TTS hors ligne lorsque le clip du pack n'est pas disponible.
- **FR-12.14** — Si un chapitre n'est ni téléchargé ni disponible en cache, le
  message explique comment le rendre disponible hors ligne.

## Mises à jour et UI

- **FR-12.15** — Une `packVersion` distante supérieure affiche « Mise à jour
  disponible » ; la mise à jour est manuelle et utilise le descripteur courant.
- **FR-12.16** — Le web affiche que le téléchargement est réservé au mobile ;
  le build web compile sans `dart:io` et conserve le cache JSON existant.
- **FR-12.17** — Les états de la carte (non téléchargé, en cours, téléchargé,
  mise à jour, erreur) sont accessibles et lisibles à 360 px.

## Sécurité et contraintes

- **SEC-12.1** — Aucun chemin fourni par le serveur n'est écrit sans validation :
  refus des chemins absolus, `..`, `\` et NUL.
- **SEC-12.2** — Les SHA-256 couvrent exactement les octets servis ; l'audio est
  haché sur le fichier brut.
- **SEC-12.3** — Aucun secret ni jeton n'est introduit ; les endpoints de contenu
  restent publics et l'authentification inchangée.
- **SEC-12.4** — Les erreurs disque/réseau ne corrompent ni l'index ni le pack
  installé.

## Definition of Done

- `flutter analyze` sans problème, `flutter test` et `pytest` verts.
- `flutter build web` réussi (aucune fuite de `dart:io`).
- Contrat API vérifié (descripteur, fichiers, tailles/hashes, 404 chemins).
- Scénario Android : télécharger, mode avion, relance, lecture/écoute/révision,
  mise à jour, suppression.
- Documentation serveur et specs à jour ; captures runtime disponibles.
