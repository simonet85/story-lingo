# Phase 5 Plan — Audio & synchronisation karaoké

Objectif : écouter le chapitre pilote avec un audio embarqué, dans trois modes (Lire / Écouter / Lire + Écouter), avec un surlignage mot et phrase piloté par un index de timings, vitesse 0.8x–1.5x et transport complet (±15 s).

## A. Contrat de contenu v2 et pipeline audio

1. Faire évoluer le chapitre vers `schemaVersion: 2` en ajoutant un bloc `audio` obligatoire en v2 : `asset`, `durationMs`, `voice`, `words[]` (`text`, `startMs`, `endMs`).
2. Garder `schemaVersion: 1` valide et sans audio pour les futurs chapitres non enregistrés ; le modèle Dart accepte v1 et v2, et rejette v2 sans audio.
3. Définir un tokenizer partagé (`dart`) : mots = suites alphanumériques avec apostrophes internes ou finales (`farmers’`), tout le reste (espaces, ponctuation) reste du texte non cliquable.
4. Créer `tools/content/generate_chapter_audio.py` : synthèse `edge-tts` (`en-US-AriaNeural`, `boundary="WordBoundary"`), collecte des fenêtres mot, alignement DP sur les tokens du chapitre, répartition proportionnelle des fenêtres fusionnées (« The road »), écriture du MP3 et injection du bloc `audio` + bump `packVersion`.
5. Générer `assets/content/sleepy-hollow-a2/audio/chapter-01.mp3` (~2 min 22) et vérifier 1:1 strict entre les 392 tokens et les timings produits.
6. Déclarer `assets/content/sleepy-hollow-a2/audio/` dans `pubspec.yaml` ; documenter que l'audio est un asset embarqué (aucun réseau au runtime).

## B. Modèle et karaoké

7. Ajouter `ChapterAudio` et `AudioWordTiming` dans `lib/features/content/domain/` avec parsing strict (`schemaVersion`, champs, monotonie des `startMs`, `durationMs ≥ dernier endMs`).
8. Valider à la frontière que le nombre de timings égale le nombre de tokens et que chaque `text` correspond au token (comparaison normalisée) ; erreur `ContentFormatException` explicite sinon.
9. Implémenter `KaraokeTrack` : index global des mots par paragraphe, ids de phrase dérivés de la ponctuation (`. ! ? …` et fin de paragraphe), recherche binaire de l'index actif à une position.
10. Exposer le paragraphe actif pour le suivi visuel et les bornes de phrase pour le rendu.
11. Couvrir les cas limites : position avant le premier mot, après le dernier, groupe fusionné, phrase à cheval sur plusieurs segments.

## C. Moteur audio et préférences

12. Ajouter `just_audio` (conforme à la tech stack) et une abstraction `AudioEngine` (position, playing, duration, setAsset, play, pause, seek, setSpeed, dispose) avec implémentation `JustAudioEngine`.
13. Fournir une factory Riverpod (`audioEngineFactoryProvider`) surchargeable dans les tests.
14. Ajouter `ReadingMode { read, listen, readListen }` et des clés additives `settings.reading_mode`, `settings.audio_speed` (pas de bump de schéma).
15. Étendre `PrefsRepository` : lecture/écriture du mode et de la vitesse (valeurs autorisées 0.8 / 1.0 / 1.25 / 1.5, repli sur 1.0).
16. Implémenter `AudioSessionController` : chargement paresseux, positions limitées à `[0, duration]`, seek ±15 s borné, pause en quittant les modes audio, état « terminé » → bouton rejouer, notifications limitées aux changements utiles (mot/phrase ou ~200 ms) pour ne pas reconstruire l'écran à chaque frame.
17. Ne jamais créer de moteur réel en mode Lire (les tests et l'écran par défaut restent sans plugin).

## D. Rendu et UI

18. Refondre `ChapterParagraphText` en spans mot par mot tout en préservant les surlignages de vocabulaire de la phase 3 (espaces et ponctuation d'un segment annoté gardent leur fond).
19. Styles karaoké : mot actif = fond `primary` + texte `onPrimary` + gras ; phrase active = soulignement `secondary` ; priorité mot actif > vocabulaire > phrase ; aucun style karaoké en mode Lire.
20. Ajouter le sélecteur `SegmentedButton<ReadingMode>` sous la barre d'en-tête (« Lire », « Écouter », « Lire + Écouter »), compact et sans débordement à 360 px.
21. Mode Lire + Écouter : barre de transport épinglée en bas (play/pause, −15 s, +15 s, vitesse, slider + temps), texte défilant avec karaoké.
22. Mode Écouter : panneau centré (titre, indicateur d'écoute, slider, temps, gros play/pause, ±15 s, vitesse) sans le texte.
23. Menu de vitesse en feuille modale avec quatre choix, persistance immédiate.
24. Suivi automatique du mot actif en Lire + Écouter (paragraphe actif amené à l'écran) tant que l'utilisateur ne fait pas défiler ; le défilement manuel désactive le suivi, play/seek le réactive.
25. Sauvegarde de la position à la sortie si l'utilisateur a défilé **ou** écouté (l'ancre audio reflète ce qui était visible).
26. Conserver le timer de session, la reprise de position, la fin de chapitre et le récapitulatif de la phase 4 ; mettre l'audio en pause à la complétion et à la sortie.
27. Gérer les erreurs de chargement audio par un message inline (« Audio indisponible ») avec possibilité de réessayer, sans bloquer la lecture.

## E. Tests et validation

28. Tests unitaires contenu : parsing v2, erreurs (audio manquant, mots vides, timings non monotones, désalignement tokens/timings), intégrité du pack réel.
29. Tests unitaires karaoké : index à une position, bornes, phrases, mapping paragraphes.
30. Tests contrôleur avec moteur factice : play/pause, seek borné, vitesse persistée, fin d'audio, pause au changement de mode.
31. Tests widget : modes et transport, karaoké visible (mot actif stylé), vitesse, 360 px sans overflow, persistance du mode à la réouverture ; non-régression des tests existants.
32. `flutter analyze` + `flutter test` verts, captures web (clair/sombre, transport, karaoké, mode Écouter, feuille vitesse) via CDP.
33. Validation Android sur `storylingo_api36` : audio réel, karaoké qui avance, ±15 s, vitesse, hors-ligne, captures archivées.
34. Mettre à jour `README.md` avec le lien vers cette spec.
