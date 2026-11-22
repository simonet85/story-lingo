# Phase 5 Validation — Audio & synchronisation karaoké

## Definition of Done

Tout ce qui suit doit être vrai avant fusion.

### 1. Analyse statique

```
flutter analyze
```

Doit sortir en code 0, sans erreur ni avertissement.

### 2. Tests automatisés

```
flutter test
```

Tous les tests passent, y compris les 61 tests existants (non-régression onboarding, préférences, contenu, bibliothèque, lecture, reprise, fin de chapitre).

Tests requis :

- **Contenu v2** : parsing du bloc `audio` ; rejet d'un schéma v2 sans audio, de mots vides, de timings non monotones, d'une durée inférieure au dernier `endMs`, d'un texte de timing différent du token.
- **Pack réel** : le chapitre pilote est valide ; 392 timings pour 392 tokens ; dernier `endMs ≤ durationMs` ; asset audio présent et déclaré.
- **Tokenizer** : apostrophes internes et finales, ponctuation, chiffres ; les segments annotés conservent leurs bornes.
- **KaraokeTrack** : index actif aux bornes `startMs`/`endMs` (inclus/exclu), avant premier/après dernier mot, phrase correcte aux `.!?…` et en fin de paragraphe, mapping paragraphe → mot global.
- **Contrôleur** : play/pause ; seek ±15 s borné à 0 et à la durée ; vitesse appliquée et persistée (valeurs autorisées, repli 1.0) ; fin d'audio → « Rejouer » ; passage en Lire → pause ; aucun moteur créé en mode Lire.
- **Widget** : sélecteur de mode visible ; transport absent en Lire, présent en Lire + Écouter ; play/pause et ±15 s appellent le moteur factice ; un événement de position colore le mot attendu ; le menu vitesse applique 1.5× ; le mode Écouter masque le texte ; le mode choisi est restauré à la réouverture ; aucun overflow à 360 px.

### 3. Contenu et alignement

- Le MP3 `assets/content/sleepy-hollow-a2/audio/chapter-01.mp3` est présent et lisible par `ffprobe` (durée ~142 s).
- `schemaVersion` du chapitre passe à `2` ; `packVersion` du manifeste est incrémenté.
- `audio.words[i].text` correspond exactement au i-ème token du chapitre (vérifié par test).
- Aucun changement aux clés de préférences existantes ; seules `settings.reading_mode` et `settings.audio_speed` s'ajoutent.

### 4. Écran de lecture

- Le sélecteur Lire / Écouter / Lire + Écouter fonctionne sans débordement à 360 px.
- En Lire : comportement de la phase 4 inchangé (timer, surlignages, reprise, fin de chapitre).
- En Lire + Écouter : le mot actif et la phrase active progressent avec la position audio ; le vocabulaire reste surligné.
- En Écouter : le texte est masqué, le panneau audio affiche titre, position, durée et transport.
- La barre de transport reste accessible pendant tout le défilement.
- Les états de chargement, d'erreur (« Réessayer ») et le retour arrière restent fonctionnels.

### 5. Transport et vitesse

- Play/pause démarre et arrête réellement l'audio.
- −15 s / +15 s ne dépassent jamais 0 et la durée ; le surlignage saute au bon mot.
- Le slider permet de se déplacer ; le temps affiché suit.
- Les quatre vitesses (0.8 / 1.0 / 1.25 / 1.5) s'appliquent à l'oreille et sont mémorisées.
- La fin de l'audio met en pause et propose « Rejouer » ; aucun récapitulatif ne s'ouvre automatiquement.

### 6. Suivi et position

- En Lire + Écouter, le texte suit le mot actif tant que l'utilisateur ne défile pas.
- Un défilement manuel arrête le suivi ; play ou seek le réactive.
- Sortir après avoir écouté sauvegarde le paragraphe visible (reprise à la réouverture).
- Le timer de session et la fin de chapitre de la phase 4 sont inchangés.

### 7. Persistance et hors-ligne

- En mode avion, lecture, karaoké, transport, modes et fin de chapitre fonctionnent.
- Aucun appel réseau n'est introduit.
- `prefs.version` reste à `1` ; les préférences existantes sont intactes.

### 8. Thèmes et accessibilité

- Karaoké et transport lisibles en thème clair et sombre (contraste mot actif).
- Cibles tactiles ≥ 44 × 44 px (play, ±15 s, vitesse, sélecteur de mode).
- Libellés d'accessibilité : « Lecture audio », « Pause audio », « Reculer de 15 secondes », « Avancer de 15 secondes », « Vitesse de lecture ».
- Les boutons du transport ne captent pas la sémantique du timer.

### 9. CI

Le workflow existant reste vert : `flutter pub get`, `flutter analyze`, `flutter test`.

### 10. Aperçu visuel

Build web puis captures Chrome : mode Lire + Écouter avec transport et mot actif, feuille de vitesse, mode Écouter, thème sombre, karaoké en cours de lecture. Captures archivées dans `.tmp/screens/web-*.png`.

### 11. Runtime Android

Sur l'émulateur existant (`storylingo_api36`) :

- l'audio se lance, se met en pause et reprend ;
- le surlignage avance avec l'audio et le suivi amène le bon paragraphe ;
- ±15 s et les quatre vitesses fonctionnent ;
- le mode Écouter masque le texte, le mode Lire n'a plus de transport ;
- en mode avion, l'audio fonctionne depuis l'asset ;
- captures archivées dans `.tmp/screens/android-*.png`.

## Not Required

- Pas de tap sur un mot ni de prononciation à la demande.
- Pas de lecture arrière-plan, notification média, contrôles casque.
- Pas de saut de phrase, boucle, signet audio.
- Pas de SRS, flashcards, statistiques, streak ni parcours 28 jours.
- Pas de téléchargement, streaming, synchronisation cloud.
- Pas de sous-titres téléchargeables ni export des timings.
