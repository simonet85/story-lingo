# Phase 7 Plan — Vocabulaire & répétition espacée

Objectif : transformer les mots rencontrés en chapitre en flashcards révisées par un ordonnanceur FSRS, avec un objectif quotidien de 10 nouveaux mots et une révision de fin de session. Tout reste local, hors-ligne et sans nouvelle donnée de contenu lourde.

## A. Contrat et données locales

1. Ajouter la dépendance `fsrs` (algorithme officiel, port Dart du paquet de référence) et créer un `Scheduler` unique par application : `desiredRetention = 0.9`, étapes d'apprentissage par défaut, `enableFuzzing = false` pour des intervalles déterministes et testables.
2. Créer `SrsCard` dans `features/vocabulary/domain/` : instantané complet de `WordEntry`, état FSRS (`Card`), `introducedAt`, `firstReviewedAt`, `lastReviewedAt`, `reviews`. Sérialisation JSON tolérante (une entrée invalide est ignorée au chargement).
3. Identité : `entry.id` = `${bookId}/${vocabId}` ; `cardId` FSRS = hash FNV-1a stable de cet identifiant.
4. Ajouter la clé additive `srs.cards` (`List<String>` de JSON) ; `prefs.version` reste `1`.
5. Créer `SrsRepository` (chargement tolérant, déduplication par `entry.id`, sauvegarde atomique de la liste) et l'exposer via `srsRepositoryProvider`, surchargé au démarrage.
6. Exposer `srsProvider` (`NotifierProvider<List<SrsCard>>`) : `introduceFromChapter(...)`, `rate(entryId, rating)` (utilise le `Scheduler` et l'horloge injectée), `contains(id)`.
7. Injecter `nowProvider` (`DateTime Function()`) pour figer le temps dans les tests ; FSRS reçoit toujours des dates UTC, les comparaisons de jours se font en heure locale.

## B. Détection des mots nouveaux

8. Ajouter un champ optionnel `cefr` aux entrées de vocabulaire du pack (schéma de chapitre inchangé, `schemaVersion` reste `2`) et annoter les 20 mots du chapitre pilote (`a2`, `b1`, `b2`). `packVersion` passe à `1.2.0` (métadonnée additive).
9. `dictionaryEntryForVocabularyId(Chapter, vocabId)` : construit l'unique fiche d'un `vocabId` (premier token annoté, tranche audio du groupe) pour alimenter les cartes.
10. `detectNewWords({chapter, level, introducedIds, savedIds, minimum: 5})` :
    - ignore les noms propres (`proper noun`) et les mots déjà introduits ;
    - retient les mots dont le `cefr` est **au niveau de l'utilisateur ou au-dessus** (un mot sans `cefr` est retenu) ;
    - priorise les mots enregistrés dans « Ma liste de mots » (intérêt explicite), même en dessous du niveau ;
    - trie par niveau décroissant puis par ordre du chapitre ;
    - si moins de 5 mots qualifient, complète avec les mots les plus difficiles restants (repli assumé du pack pilote unique).
11. L'introduction a lieu à la **fin du chapitre** (action « Terminer le chapitre »), pas à l'ajout à la liste. Tous les mots détectés deviennent des cartes dues immédiatement ; la limite quotidienne s'applique à la **découverte**, pas à la création.

## C. File de révision et objectif quotidien

12. `buildReviewQueue(cards, now, dailyNewGoal)` :
    - cartes déjà révisées et dues (`lastReview != null`, `due <= now`) triées par échéance ;
    - puis cartes jamais révisées, dans l'ordre d'introduction, plafonnées à `max(0, objectif - nouveaux étudiés aujourd'hui)`. Les nouvelles cartes passent en tête de séance ;
    - objectif quotidien = **10 nouveaux mots** (borne basse de la fourchette 10–20, session ≈ 7–10 min).
13. « Nouveaux mots étudiés aujourd'hui » = cartes dont `firstReviewedAt` est le jour local courant. Les cartes introduites mais non étudiées restent dues et seront proposées le lendemain.
14. `VocabularyStats` (Provider) : `newStudiedToday`, `dailyGoal`, `dueCount` (longueur de la file), `total`.
15. Dans une séance, une carte notée « À revoir » est replacée **une seule fois** en fin de file ; une seconde note négative la laisse échue selon FSRS.

## D. UI

16. Nouvelle route `/review` (`ReviewScreen`) : carte mot (mot, phonétique, nature, bouton « Écouter » via `WordPronouncer` existant), bouton « Afficher la réponse », verso (traduction FR, définition EN, exemple), quatre notes : « À revoir », « Difficile », « Bien », « Facile ». Progression `n / N`, état de fin (mots revus, retour), état vide engageant.
17. Récapitulatif de fin de chapitre : compte des mots ajoutés à la révision, nombre de cartes prêtes, bouton « Réviser ces mots » → `/review` (masqué si aucune carte).
18. Écran « Aujourd'hui » : carte « Vos mots du jour » avec progression `nouveaux mots : X/10`, nombre de cartes à réviser, bouton « Réviser mes mots » (désactivé à zéro), message d'amorçage si aucune carte.
19. La prononciation de la carte est arrêtée à la fermeture de l'écran ; aucune interaction ne modifie la lecture en cours au-delà de la navigation.
20. Accessibilité : libellés des notes, cibles ≥ 44 px, pas d'overflow à 360 px, thème clair et sombre.

## E. Tests et validation

21. Tests unitaires FSRS/file : ordre des échéances selon la note, file limitée par l'objectif, cartes non dues exclues, cartes nouvelles en tête, repli après « À revoir ».
22. Tests unitaires détection : nom propre exclu, filtre de niveau, complément au minimum, mots enregistrés prioritaires, déduplication.
23. Tests unitaires stockage : aller-retour JSON complet, tolérance, déduplication, persistance entre repositories, seule clé `srs.cards` ajoutée, `prefs.version` intact.
24. Tests widget : parcours de révision (verso, quatre notes, fin), séance vide, prononciation appelée avec clip, ajout à la fin de chapitre et CTA vers la révision, carte « Aujourd'hui » avec compteurs, 360 px sans overflow, non-régression.
25. `flutter analyze` + `flutter test` verts ; captures web clair/sombre (carte recto/verso, fin de révision, carte « Aujourd'hui ») archivées dans `.tmp/screens/web-*.png`.
26. Validation Android sur `storylingo_api36` : terminer le chapitre → cartes créées ; révision complète avec notes ; échéances persistées après redémarrage ; limite de 10 nouveaux mots ; mode avion ; captures archivées.
27. Mettre à jour `README.md` et `test/pilot_pack_test.dart` (`packVersion` `1.2.0`).
