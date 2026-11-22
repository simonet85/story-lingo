# Phase 7 Requirements — Vocabulaire & répétition espacée

## Scope

Quatrième tranche de l'expérience d'apprentissage : la révision.

- **Détection des mots nouveaux** selon le niveau estimé de l'utilisateur, à partir du vocabulaire annoté du chapitre et de son niveau CEFR.
- **Flashcards** générées à partir des mots rencontrés en fin de chapitre, consultables recto/verso avec prononciation.
- **Planification FSRS** locale : chaque note (À revoir, Difficile, Bien, Facile) reprogramme la carte.
- **Objectif quotidien** de 10 nouveaux mots, suivi sur l'écran « Aujourd'hui ».
- **Révision de fin de session** (≈ 2–3 min) lancée depuis le récapitulatif du chapitre ou depuis « Aujourd'hui ».
- Entièrement **hors-ligne** : ordonnanceur et cartes vivent dans les préférences locales.

## Out of Scope

- Parcours 28 jours, streak, badges, statistiques avancées (phase 8).
- Liste CEFR complète et détection des mots **non annotés** (pipeline de contenu, phase 10).
- Flashcards inversées, saisie de texte, QCM, écoute seule, tests de prononciation.
- Réglage utilisateur de l'objectif quotidien (valeur pilote fixe de 10, personnalisation phase 8).
- Synchronisation cloud de l'état SRS (phase 11).
- Migration vers SQLite/drift : l'état SRS reste dans `SharedPreferences`, comme la liste de mots.

## Modèle local

### Carte (`SrsCard`)

| Champ | Rôle |
|---|---|
| `entry` | Instantané complet de la fiche (`WordEntry`), y compris le clip de prononciation |
| `card` | État FSRS du paquet `fsrs` (`state`, `step`, `stability`, `difficulty`, `due`, `lastReview`) |
| `introducedAt` | Date d'entrée dans la révision (fin de chapitre) |
| `firstReviewedAt` | Date de la première note, base de l'objectif quotidien |
| `lastReviewedAt` | Date de la dernière note |
| `reviews` | Nombre de notes reçues |

- Stockage sous la clé additive `srs.cards` : liste de chaînes JSON, ordre d'introduction conservé.
- Chargement **tolérant** : entrée malformée ou dupliquée ignorée ; une carte illisible ne bloque pas les autres.
- `prefs.version` reste `1` ; aucune clé existante n'est modifiée.

### Détection

Chaque mot annoté du chapitre porte un niveau CEFR optionnel (`cefr`). Pour un utilisateur de niveau L, un mot est **nouveau** si :

1. ce n'est pas un nom propre ;
2. il n'est pas déjà dans la révision ;
3. son niveau CEFR est ≥ L (un mot sans niveau est retenu).

Priorités : les mots enregistrés dans « Ma liste de mots » passent en premier, même en dessous du niveau. Tri : niveau décroissant, puis ordre du chapitre. Si moins de 5 mots qualifient, les mots les plus difficiles du chapitre complètent la séance (repli du livre pilote unique).

La détection ne fait que **sélectionner** : toutes les fiches produites viennent du vocabulaire annoté du pack.

### Objectif quotidien

- Objectif : **10 nouveaux mots découverts par jour**.
- Une carte « nouveau mot » compte dès sa **première note**, pas à sa création.
- Les cartes créées en fin de chapitre mais au-delà de l'objectif restent dues et sont proposées les jours suivants.
- Les cartes déjà reprogrammées par FSRS et dues aujourd'hui ne consomment pas l'objectif.

## Comportement

### Fin de chapitre

- « Terminer le chapitre » enregistre la progression (inchangé), puis introduit les mots détectés dans la révision.
- Le récapitulatif affiche : nombre de mots ajoutés, nombre de cartes prêtes, bouton « Réviser ces mots ».
- Re-terminer un chapitre ne crée aucun doublon.
- Sans carte disponible, le bouton est remplacé par un message « Vous êtes à jour. »

### Séance de révision

Ordre de la file :

1. cartes jamais révisées, dans l'ordre d'introduction, plafonnées par le reste de l'objectif ;
2. cartes déjà révisées et échues, triées par échéance.

Recto : mot, phonétique, nature traduite, bouton « Écouter ». Verso : traduction FR mise en avant, définition EN, exemple. Révéler est explicite (« Afficher la réponse »).

Notes et effet :

| Bouton | Note FSRS | Effet |
|---|---|---|
| À revoir | Again | Carte re-proposée une fois dans la séance, puis laissée à FSRS |
| Difficile | Hard | Reprogrammation courte |
| Bien | Good | Reprogrammation standard |
| Facile | Easy | Reprogrammation longue |

- Fin de séance : « Révision terminée », nombre de mots revus, retour.
- Sans carte due : état vide explicite renvoyant vers la lecture.
- La prononciation utilise le `WordPronouncer` existant (tranche du pack, repli TTS) et s'arrête à la fermeture.

### Écran « Aujourd'hui »

Carte « Vos mots du jour » :

- progression « Nouveaux mots : X/10 » (X = premières notes du jour) ;
- « N cartes à réviser » ou « Tout est à jour » ;
- bouton « Réviser mes mots » → `/review`, désactivé si la file est vide ;
- message d'amorçage si aucune carte n'existe encore.

## Decisions

### Paquet `fsrs` plutôt qu'un ordonnanceur maison

La constitution impose FSRS, pas une heuristique improvisée. Le paquet officiel (MIT, port du projet de référence) fournit l'algorithme et la sérialisation ; nous fixons la version et désactivons le fuzz pour des tests déterministes. Les paramètres par défaut sont conservés (optimisation sur données réelles hors périmètre).

### Introduire tout le chapitre, limiter la découverte

Créer seulement 10 cartes à la fin du chapitre jetterait les autres mots du pack. Toutes les cartes sont créées ; l'objectif de 10 limite le **travail du jour**, et les cartes restantes alimentent les jours suivants. Cela respecte la promesse « +10 à +20 nouveaux mots » sans séance à rallonge.

### Niveau CEFR optionnel dans le pack, avec repli

Le format de contenu n'avait pas de niveau par mot. Ajouter un champ optionnel reste rétrocompatible avec le schéma v2 ; le repli au minimum de 5 mots évite une séance vide quand un lecteur avancé ouvre un contenu A2. La comparaison à des listes CEFR complètes arrivera avec le pipeline de contenu (phase 10), sans changer ce contrat.

### Les noms propres ne deviennent pas des cartes

« Sleepy Hollow » ou « Ichabod » n'ont pas de valeur de révision. Ils restent consultables dans la fiche et la liste, mais sont exclus de la détection SRS.

### Pas d'objectif configurable en phase 7

L'objectif quotidien unique est le cœur des phases 7–8 ; le personnaliser maintenant ouvrirait des réglages sans données d'usage. La valeur 10 est la borne basse de la fourchette produit, adaptée à 7–10 minutes.

### Les cartes suivent l'utilisateur, pas le chapitre

Une carte est identifiée par `${bookId}/${vocabId}` : revoir le même mot dans un autre chapitre ne crée pas de doublon et conserve son historique FSRS.

## Context

La phase 6 a rendu les mots explorables ; la phase 7 les transforme en apprentissage mémorisé. La révision de fin de chapitre ferme la boucle « lire → rencontrer → réviser » promise par la mission, avant le parcours 28 jours (phase 8).

## Stakeholder Notes

- **Produit** : une séance de révision courte, positive, sans culpabilisation ; les compteurs restent simples (X/10, N cartes).
- **Technique** : algorithme officiel isolé derrière un provider ; horloge injectée ; stockage additif sans migration.
- **Business** : l'état SRS local est la brique premium (SRS complet) des phases 11–13 ; il est déjà synchronisable par entité.
- **Éditorial** : 20 mots annotés suffisent pour valider la boucle ; le niveau par mot (`cefr`) enrichit le pack sans réécriture.
