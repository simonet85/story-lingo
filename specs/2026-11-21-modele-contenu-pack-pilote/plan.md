# Phase 3 Plan — Modèle de contenu & pack pilote

## Group 1 — Pack de contenu pilote

1. Créer l’arborescence `assets/content/sleepy-hollow-a2/` avec `manifest.json` et `chapters/chapter-01.json`.
2. Rédiger une adaptation **originale en anglais A2** du premier chapitre de *The Legend of Sleepy Hollow* (Washington Irving, domaine public) : 350 à 450 mots, 4 à 6 paragraphes, attribution de l’auteur dans le manifeste.
3. Découper chaque paragraphe en **segments de texte** : les segments annotés portent un `vocabId`, les autres du texte brut. Aucun segment vide, aucun paragraphe vide.
4. Sélectionner **15 à 20 mots ou expressions clés** au niveau A2/B1 et créer les entrées de vocabulaire correspondantes (définition EN, traduction FR, exemple, phonétique IPA, nature grammaticale).
5. Renseigner le manifeste : identité du livre, niveau `a2`, description FR, liste des chapitres avec durée estimée (5–8 min) et nombre de mots nouveaux.
6. Déclarer les assets dans `pubspec.yaml` (manifeste + dossier `chapters/`).
7. Vérifier que le nombre de mots du chapitre est cohérent avec la durée déclarée (environ 70 mots/minute en lecture assistée A2).

## Group 2 — Domaine du contenu

8. `lib/features/content/domain/book_manifest.dart` : `BookManifest` et `BookChapterSummary`, désérialisation stricte (`schemaVersion`, `packVersion` semver, ids, niveau, durées, chemins d’assets).
9. `lib/features/content/domain/chapter.dart` : `Chapter`, `ChapterParagraph`, `TextSegment`, `VocabularyEntry`.
10. Validation à la construction : `schemaVersion == 1`, ids non vides, niveau parmi A2/B1/B2 (réutiliser `UserLevel`), numéros de chapitres uniques, `vocabId` référencés existants, vocabulaire unique et effectivement utilisé au moins une fois, textes non vides.
11. Calculer `Chapter.wordCount` à partir des segments (séparateur espace), sans faire confiance à une valeur stockée.

## Group 3 — Chargement et état

12. `lib/features/content/data/content_repository.dart` : charger le manifeste et les chapitres depuis `rootBundle`, avec un `ContentFormatException` explicite en cas de JSON ou de schéma invalide.
13. Providers Riverpod : `contentRepositoryProvider`, `pilotBookProvider` (manifeste), `chapterProvider` (famille par `bookId` + `chapterId`).
14. Vérifier au chargement que l’`id` du chapitre et son `bookId` correspondent au manifeste.

## Group 4 — UI bibliothèque et lecture

15. Convertir `LibraryScreen` en `ConsumerWidget` avec trois états : chargement, erreur (bouton « Réessayer »), contenu.
16. Créer `PilotBookCard` : titre, titre FR, auteur, badge de niveau, métadonnées « ≈ N min · N mots nouveaux · 1 chapitre », bouton « Lire le chapitre 1 ».
17. Ajouter la route `/read/:bookId/:chapterId` (hors shell) et l’écran `ReadingScreen`.
18. `ReadingScreen` : titre du chapitre, badges (niveau, durée estimée), paragraphes rendus en `RichText`, note discrète « Les mots surlignés sont les mots clés du chapitre. »
19. `ChapterParagraphText` : construire les `TextSpan` à partir des segments ; les segments annotés utilisent `primaryContainer` / `onPrimaryContainer` et un poids de police renforcé, visibles en clair comme en sombre.
20. États de chargement et d’erreur du chapitre, avec retour arrière fonctionnel.

## Group 5 — Tests et CI

21. Tests unitaires du manifeste : version de schéma, semver `packVersion`, niveau invalide, durée hors bornes, chapitre dupliqué, JSON malformé.
22. Tests unitaires du chapitre : segment vide, `vocabId` inconnu, vocabulaire dupliqué, entrée non référencée, `bookId` incohérent, champs de vocabulaire manquants.
23. Test d’intégrité du pack réel : chargement des assets, 350–450 mots, 15–20 entrées, toutes référencées, chacun des ids unique, `newWordCount` du manifeste égal au nombre d’entrées, chemin du chapitre chargeable.
24. Test widget : onboarding terminé → onglet Bibliothèque → carte pilote visible → ouverture → titre du chapitre et premier paragraphe visibles.
25. Test widget : au moins un segment annoté est rendu avec un fond de surbrillance dans le paragraphe.
26. Ajouter les tests du pack au workflow CI existant (aucun changement de configuration attendu).
27. Non-régression : les 15 tests existants restent verts.

## Group 6 — Vérification

28. `flutter analyze` — 0 problème.
29. `flutter test` — tous les tests passent.
30. `flutter build web` puis aperçu Chrome : capture de la bibliothèque (clair/sombre) et du chapitre avec mots surlignés.
31. Vérifier que la lecture fonctionne hors-ligne (aucun appel réseau) et que la bibliothèque ne régresse pas l’onboarding.
