# Phase 4 Requirements — Lecteur

## Scope

Transformer l'écran de lecture de la phase 3 en véritable lecteur de session :

- **Lecture immersive** : barre d'en-tête épinglée discrète, largeur de ligne maîtrisée, paragraphes aérés, surlignages conservés.
- **Timer de session** toujours visible : compte à rebours basé sur la durée estimée du chapitre, plafonné à 10 minutes, sans jamais bloquer la lecture.
- **Reprise à la dernière position** : ancre sur le paragraphe visible, persistée localement, restaurée à l'ouverture suivante.
- **Fin de chapitre** : bouton explicite, marquage terminé, récapitulatif (temps de lecture, mots rencontrés) et retour au parcours.
- **Bibliothèque** : le bouton de la carte reflète l'état (« Continuer » / « Relire »).

Tout reste 100 % local, sans backend ni compte.

## Out of Scope

- Audio, timings, karaoké et modes Lire / Écouter (phase 5).
- Tap sur un mot, dictionnaire, prononciation (phase 6).
- Détection des mots nouveaux selon le niveau, SRS, flashcards, révision de fin de session (phase 7).
- Parcours 28 jours, streak, statistiques de l'onglet Progrès (phase 8) — l'onglet Progrès reste inchangé.
- Réglage de la taille de police ou de la famille typographique dans les réglages.
- Mode paysage dédié, pagination par colonnes, thème sépia.
- Catalogue distant, téléchargements, synchronisation (phases 10–12).

## Comportement attendu

### Timer de session

| Règle | Détail |
|---|---|
| Durée initiale | `estimatedMinutes` du chapitre (5–8 min pour le pack pilote), plafonnée à 10 min ; repli 10 min si le manifeste est indisponible |
| Décrément | 1 seconde par tic de `Timer.periodic` ; pas de recalage sur l'horloge murale |
| Affichage | Pastille dans l'`AppBar` épinglée : icône horloge + `m:ss` ; toujours visible pendant le défilement |
| Dépassement | Après 0:00, affiche `+m:ss` en couleur atténuée ; aucune alerte, aucun blocage |
| Pause | Arrière-plan de l'app (`paused`/`inactive`) : le compteur se fige ; retour au premier plan : il reprend |
| Cycle de vie | Aucune persistance : chaque ouverture du chapitre repart de la durée estimée |
| Accessibilité | `Semantics` « Temps restant » autour de la pastille ; texte lisible dans les deux thèmes |

### Reprise de position

- L'ancre est l'**id du premier paragraphe visible** au moment où le défilement s'arrête (ou au pop de l'écran).
- Clé de stockage : `reading.position.<bookId>.<chapterId>` → id de paragraphe (chaîne).
- À l'ouverture : si l'id existe dans le chapitre, défilement instantané jusqu'à ce paragraphe (haut de la zone de lecture) et `SnackBar` « Reprise là où vous vous êtes arrêté. » ; sinon la position est effacée et le chapitre s'ouvre en haut.
- Aucune écriture si l'ancre n'a pas changé depuis la dernière sauvegarde.
- La restauration ignore les notifications de défilement qu'elle déclenche elle-même.

### Fin de chapitre

- Bloc de fin après le dernier paragraphe : « Fin du chapitre » + bouton « Terminer le chapitre ».
- Le tap fige le timer, marque le chapitre terminé (`reading.completed.<bookId>.<chapterId> = true`), efface la position et affiche le récapitulatif.
- Récapitulatif : icône de validation, « Chapitre terminé », titre du chapitre, temps de lecture (`m:ss`), nombre de mots rencontrés (`chapter.vocabulary.length`), puces des mots du chapitre, bouton « Retour au parcours » (Aujourd'hui), bouton secondaire « Fermer » (retour Bibliothèque).
- Un chapitre terminé rouvert s'ouvre en haut ; la carte de bibliothèque affiche « Relire le chapitre N ».

### Bibliothèque

| État du chapitre | Libellé du bouton |
|---|---|
| Aucun état | « Lire le chapitre N » |
| Position enregistrée | « Continuer le chapitre N » |
| Terminé | « Relire le chapitre N » |

L'état provient de `readingProgressProvider` ; les clés sont isolées par livre et par chapitre.

## Decisions

### Ancre de paragraphe plutôt qu'offset en pixels

Un offset en pixels dépend de la largeur d'écran, de la police système et du thème : il ne se rejoue pas correctement d'un appareil à l'autre. L'id de paragraphe est stable, déjà présent dans le schéma de contenu (phase 3), et suffit pour une reprise perçue comme exacte — le lecteur retombe sur le paragraphe en cours, pas au caractère près.

### Bouton explicite de fin plutôt que détection du bas de page

Détecter « l'utilisateur a atteint le bas » est fragile (tailles d'écran, momentum, lecteurs d'écran) et déclenche le récapitulatif par accident. Un bouton « Terminer le chapitre » est explicite, accessible et testable.

### Timer à tics plutôt qu'horloge murale

Un compteur piloté par `Timer.periodic` se fige naturellement en arrière-plan (aucun tic) et se teste avec `pump`. Une dérive d'une seconde est sans conséquence pour un timer de session ; le temps hors application n'est volontairement pas compté.

### Récapitulatif dans l'écran, pas de nouvelle route

Le récapitulatif remplace le contenu du même écran. Cela évite de transmettre des statistiques via `extra` (fragile sur deep link) et garde un retour arrière simple vers la Bibliothèque.

### Complétion efface la position

Un chapitre terminé doit se rouvrir au début : conserver l'ancienne ancre donnerait « Continuer » sur un chapitre déjà fini. La complétion et la position sont donc mutuellement exclusives.

### Clés préférences additives, pas de nouvelle version de schéma

`reading.*` sont de nouvelles clés indépendantes ; aucun format existant ne change. Incrémenter la version de schéma imposerait une migration sans donnée à migrer.

### Le timer ne récompense ni ne punit

Aucun avertissement, aucun son, aucun écran de fin forcé à zéro : le récapitulatif n'est déclenché que par l'utilisateur. Conforme au principe « feedback positif, jamais punitif ».

## Context

La phase 3 a prouvé le contenu et le rendu. La phase 4 transforme la lecture en **session** : on ouvre, on reprend où on s'était arrêté, on voit le temps qui reste, on termine et on retourne au parcours. C'est la première boucle complète du produit avant l'audio (phase 5) et le vocabulaire (phases 6–7).

Les données de lecture sont écrites dans `SharedPreferences`, comme les préférences. La persistance restera locale jusqu'à la phase 11 ; le dépôt `ReadingProgressRepository` isole déjà l'accès pour une future synchronisation.

## Stakeholder Notes

- **Produit** : la session doit tenir en 7–10 minutes et rester non culpabilisante ; le timer informe, il ne stresse pas.
- **Technique** : reprise robuste aux changements d'appareil (ancre de paragraphe), timer testable, aucun couplage à un backend.
- **Business** : la reprise et la fin de chapitre sont des prérequis de rétention J1/J7 et du parcours 28 jours (phase 8).
- **Éditorial** : aucun nouveau contenu ; le récapitulatif réutilise le vocabulaire du pack.
