# Phase 8 Plan — Programme 28 jours

Objectif : donner un cadre quotidien unique (un chapitre + la révision du jour), mesurer l'élan avec une série protégée par un bouclier, et rendre visibles statistiques et badges — sans réseau ni nouvelle dépendance.

## A. Modèle local

1. Créer `ProgramSession` dans `features/program/domain/` : date locale (jour, sans heure) et `minutes` (entier ≥ 1). JSON `{date: "yyyy-MM-dd", minutes}`.
2. Ajouter la clé additive `program.sessions` (`List<String>` de JSON) ; `prefs.version` reste `1`.
3. `ProgramRepository` : chargement tolérant (entrée invalide ignorée), déduplication par jour local en gardant le **maximum** de minutes, tri chronologique ; sauvegarde atomique. Provider surchargé au démarrage, comme SRS.
4. `ProgramController` (`NotifierProvider<List<ProgramSession>>`) : `recordSession(at, elapsedSeconds)` normalise au jour local, convertit les secondes en minutes (arrondi supérieur, borné 1–240) et ne crée jamais deux entrées pour le même jour.
5. `nowProvider` existant (phase 7) sert d'horloge commune pour figer le temps dans les tests.

## B. Progression et série

6. `computeProgramProgress(sessions, now)` (fonction pure) expose :
   - `daysCompleted` (jours distincts, plafonné à 28) ;
   - `currentDay` (jour en cours, entre 1 et 28) ;
   - `doneToday` (le jour courant figure dans les sessions) ;
   - `totalMinutes`, `totalSessions` ;
   - `programComplete` (28 jours accomplis).
7. **Série protégée** : en remontant l'historique, un écart d'un jour prolonge la série ; un écart de **deux jours** la prolonge **une seule fois** en consommant le bouclier ; un écart de trois jours ou plus la rompt. Un bouclier neuf protège la prochaine série. La série reste vivante tant que le dernier jour est aujourd'hui ou hier ; un écart de deux jours depuis le dernier jour utilise le bouclier ; au-delà, série = 0.
8. `bestStreak` : meilleure série historique, calculée avec la même règle de bouclier (parcours croissant). Aucun chevauchement de bouclier entre deux séries consécutives.
9. Mapping du parcours : `chapterForDay(manifest, day)` renvoie le chapitre `(day - 1) % chapitres.length` ; le livre pilote n'ayant qu'un chapitre, chaque jour propose le chapitre 1 (limite assumée, levée en phase 9).

## C. Badges

10. `ProgramBadge` (pur domaine) + `evaluateBadges(progress, vocabularyCards, totalReviews)` :
    - Premier pas : 1 jour terminé ;
    - Série de 3 jours / Semaine d'élan : record (incluant la série courante) ≥ 3 / ≥ 7 ;
    - Mi-parcours : 14 jours terminés ;
    - Parcours terminé : 28 jours terminés ;
    - Dix mots : ≥ 10 cartes de révision.
11. Les badges sont **dérivés** de l'état, jamais stockés : aucune migration, aucune récompense perdable. Libellés et descriptions en français dans le domaine ; icônes choisies côté présentation.

## D. UI

12. **Aujourd'hui** : remplacer la carte statique « ≈ 10 minutes » par la carte *Programme* :
    - en-tête « Jour X sur 28 » (ou « Parcours terminé »), pastille de série avec bouclier ;
    - barre de progression `jours / 28` ;
    - objectif unique : « Chapitre N · révision de vos mots », estimation `≈ 10 min` ;
    - état : « Objectif du jour terminé » ou « À faire aujourd'hui » ;
    - bouton principal vers `/read/:bookId/:chapterId` (« Commencer la session », « Reprendre le chapitre N » ou « Relire le chapitre N »).
    - La carte « Vos mots du jour » (phase 7) reste sous la carte Programme.
13. **Enregistrement** : « Terminer le chapitre » enregistre une session (horloge locale, temps de lecture écoulé) avant l'introduction SRS. Re-terminer le même jour ne crée pas de doublon.
14. **Progrès** : écran complet —
    - carte parcours : jour courant, progression `X/28`, grille des 28 jours, série courante, bouclier disponible/utilisé, record ;
    - trois statistiques : minutes lues, mots en révision, révisions totales ;
    - liste des badges (débloqués en couleur, verrouillés atténués avec description).
15. Accessibilité : cibles ≥ 44 px, 360 px sans overflow, thèmes clair et sombre, libellés français cohérents (« Série », « Bouclier », « Record »).

## E. Tests et validation

16. Tests unitaires : sérialisation/aller-retour, tolérance et déduplication du repository, enregistrement (même jour, arrondi, borne), calcul `daysCompleted/currentDay/doneToday`, série avec et sans bouclier, rupture, record, badges, mapping jour → chapitre.
17. Tests widget : carte Programme sur « Aujourd'hui » (état à faire, terminé, CTA vers la lecture), enregistrement après fin de chapitre, écran Progrès (progression, statistiques, badges verrouillés/débloqués), 360 px, non-régression des parcours existants.
18. Surcharger `programRepositoryProvider` dans `main.dart` et dans tous les harnais de test d'application complète.
19. `flutter analyze` + `flutter test` verts ; captures web (Aujourd'hui, Progrès, clair/sombre) dans `.tmp/screens/web-*.png`.
20. Validation Android sur `storylingo_api36` : terminer un chapitre → jour validé et série 1 ; avancer la date d'un jour → jour 2 proposé, série conservée ; jour manqué → bouclier consommé puis série rompue au-delà ; persistance après redémarrage ; mode avion ; captures archivées.
21. `README.md` : lien vers la spec de phase 8 ; `packVersion` et contenu du pack inchangés.
