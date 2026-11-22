# Phase 4 Plan — Lecteur

## Group 1 — État de lecture persistant

1. Ajouter les clés de préférences : `reading.position.<bookId>.<chapterId>` (id du paragraphe ancré) et `reading.completed.<bookId>.<chapterId>` (bool). Aucun changement de `schemaVersion` : clés additives.
2. Créer `lib/features/reading/domain/chapter_reading_state.dart` : `ChapterReadingState` (`paragraphId?`, `completed`, `updatedAt?`) immuable, avec `hasPosition`.
3. Créer `lib/features/reading/data/reading_progress_repository.dart` sur `SharedPreferences` : `load(bookId, chapterId)` synchrone, `savePosition(...)`, `markCompleted(...)` (efface la position), `clearPosition(...)`. Les valeurs corrompues ou inconnues sont ignorées sans exception.
4. Créer `lib/features/reading/presentation/reading_progress_provider.dart` :
   - `readingProgressRepositoryProvider` (override au démarrage, comme `prefsRepositoryProvider`) ;
   - `readingProgressProvider` (`NotifierProvider`) exposant `stateFor(bookId, chapterId)` (cache en mémoire, repli sur le dépôt) et les mutations `savePosition` / `complete`.
5. Brancher l'override dans `main.dart` avec la même instance `SharedPreferences` que `PrefsRepository`.

## Group 2 — Timer de session

6. Compteur à rebours basé sur les tics (`Timer.periodic` d'une seconde), pas sur l'horloge murale : durée initiale = `estimatedMinutes` du chapitre, plafonnée à `AppSizes.coreSessionMinutes` (10 min), repli à 10 min si le manifeste n'est pas chargé.
7. Affichage `m:ss` dans une pastille de l'`AppBar` (icône + texte, `Semantics` « Temps restant »). Au-delà de zéro, affichage du temps supplémentaire en `+m:ss` atténué — jamais d'alerte ni de blocage.
8. Pause quand l'app passe en arrière-plan (`WidgetsBindingObserver`), reprise au retour ; minuterie annulée au `dispose`. Aucune persistance du timer entre deux ouvertures.
9. Extraire le formatage dans une fonction pure testable (`formatSessionTime`).

## Group 3 — Écran de lecture immersif

10. Convertir `ReadingScreen` en `ConsumerStatefulWidget` avec `CustomScrollView` : `AppBar` épinglée par le `Scaffold` (retour, « Lecture », pastille timer), contenu dans un `SliverToBoxAdapter` centré, largeur max `AppSizes.contentMaxWidth`.
11. Confort de lecture : conserver la typographie actuelle (`bodyLarge`, hauteur 1.7) et les surlignages, augmenter l'espacement entre paragraphes à `AppSpacing.lg`, conserver l'en-tête (titre, badges, note sur les mots surlignés).
12. Attacher une `GlobalKey` par paragraphe ; après le premier rendu du chapitre, restaurer l'ancre sauvegardée via `Scrollable.ensureVisible` (sans animation) si l'id existe encore dans le chapitre ; sinon effacer l'ancre et démarrer en haut.
13. Enregistrer l'ancre au `ScrollEndNotification` (premier paragraphe visible calculé via les `RenderBox`) et avant le pop (`PopScope`) ; ne rien écrire si l'ancre n'a pas changé. Ignorer les notifications émises pendant la restauration.
14. Afficher un `SnackBar` discret « Reprise là où vous vous êtes arrêté. » lors d'une restauration effective.
15. Conserver les états chargement / erreur (« Réessayer ») et le retour arrière existants.

## Group 4 — Fin de chapitre

16. Ajouter un bloc de fin après le dernier paragraphe : titre « Fin du chapitre » et bouton « Terminer le chapitre ».
17. Au tap : arrêter le timer, marquer le chapitre terminé (efface la position) et remplacer le contenu par le récapitulatif dans le même écran (pas de nouvelle route).
18. Récapitulatif : icône de validation, « Chapitre terminé », titre du chapitre, deux statistiques (temps de lecture `m:ss`, nombre de mots rencontrés = taille du vocabulaire), puces des mots du chapitre, bouton principal « Retour au parcours » (`context.go('/today')`) et bouton secondaire « Fermer » (pop).
19. Un chapitre terminé rouvert démarre en haut du texte.

## Group 5 — Bibliothèque

20. Rendre `PilotBookCard` réactif à `readingProgressProvider` : libellé « Continuer le chapitre N » si une position existe, « Relire le chapitre N » si le chapitre est terminé, sinon « Lire le chapitre N » inchangé.
21. L'icône du bouton reste inchangée (`play_arrow`) ; aucune modification de la navigation.

## Group 6 — Tests et CI

22. Tests du dépôt : aller-retour position, isolation entre chapitres, complétion qui efface la position, valeurs corrompues ignorées.
23. Test widget du timer : affichage initial (`5:59` ou `6:00` selon la durée du manifeste) et décrémentation après `pump(Duration(seconds: 1))` ; pause en arrière-plan non testée en widget (comportement plateforme).
24. Test widget de reprise : position sauvegardée pour un paragraphe du milieu → ouverture → paragraphe visible, premier paragraphe hors écran, `SnackBar` de reprise.
25. Test widget de sauvegarde : défilement puis retour → position écrite dans `SharedPreferences`.
26. Test widget de fin de chapitre : bouton visible en bas, récapitulatif affiché, « Retour au parcours » mène à Aujourd'hui, complétion persistée, position effacée.
27. Test widget bibliothèque : libellé « Continuer le chapitre 1 » quand une position existe.
28. Non-régression : les 48 tests existants restent verts ; CI inchangée.

## Group 7 — Vérification

29. `flutter analyze` — 0 problème ; `flutter test` — tout vert.
30. `flutter build web` + aperçu Chrome : lecture (clair/sombre), timer, récapitulatif ; captures archivées dans `.tmp/screens/`.
31. Runtime Android sur l'émulateur existant : timer visible, reprise après force-stop, sauvegarde de position, récapitulatif et retour au parcours ; captures dans `.tmp/screens/android-*.png`.
32. README : ajouter le lien de la spec phase 4.
