# Phase 8 Requirements — Programme 28 jours

## Scope

Cinquième tranche : le cadre quotidien.

- **Parcours guidé de 28 jours** : chaque jour propose un chapitre + la révision des mots du jour.
- **Série protégée** : une journée manquée ne casse pas l'élan (un bouclier unique) ; deux journées manquées rompent la série.
- **Statistiques** : minutes lues, mots en révision, révisions effectuées, série courante et record.
- **Badges** dérivés de la progression.
- Écran « Aujourd'hui » recentré sur **un objectif unique**, avec minutes estimées et état d'avancement.
- Entièrement **hors-ligne**, données additives dans les préférences locales.

## Out of Scope

- Contenu complet du livre et chapitre par jour distinct (phase 9) : le pack pilote ne contient qu'un chapitre, répété d'un jour à l'autre.
- Notifications push et rappels hors application (phases ultérieures).
- Réglage de l'objectif quotidien, personnalisation du bouclier ou des badges.
- Historique calendaire détaillé au-delà des 28 jours du programme et des totaux.
- Synchronisation cloud (phase 11), comptes, classements.

## Modèle local

### Session (`ProgramSession`)

| Champ | Rôle |
|---|---|
| `date` | Jour local, sans heure |
| `minutes` | Durée de la lecture terminée, entier ≥ 1 |

- Clé additive `program.sessions` : liste de JSON `{date: "yyyy-MM-dd", minutes}`.
- Une seule entrée par jour : une nouvelle complétion le même jour conserve le **maximum** de minutes.
- Chargement tolérant : JSON illisible, date invalide ou minutes ≤ 0 ignorés ; doublons fusionnés.
- `prefs.version` reste `1` ; aucune clé existante modifiée.

### Progression

| Concept | Définition |
|---|---|
| `daysCompleted` | Nombre de jours distincts avec session, plafonné à 28 |
| `currentDay` | Jour en cours : 1 avant toute session ; `daysCompleted` si le jour est validé ; sinon `daysCompleted + 1` ; jamais > 28 |
| `doneToday` | Une session existe pour le jour local courant |
| `programComplete` | `daysCompleted == 28` |
| `totalMinutes` | Somme des minutes de toutes les sessions |
| `totalSessions` | Nombre d'entrées conservées |

### Série et bouclier

- Un **bouclier** est disponible au début de chaque série.
- Écart de 1 jour entre deux sessions consécutives : la série continue.
- Écart de 2 jours : la série continue **si** le bouclier est disponible, qui est alors consommé (une seule fois par série).
- Écart ≥ 3 jours : la série est rompue ; une nouvelle série démarre avec un bouclier neuf.
- Depuis aujourd'hui : dernier jour aujourd'hui ou hier → série vivante ; avant-dernier jour (écart de 2) → bouclier consommé mais série vivante ; au-delà → série affichée à 0.
- `record` (meilleure série) est calculé sur tout l'historique avec la même règle, bouclier inclus.
- La série affichée est la série vivante ; le record est affiché séparément.

## Comportement

### Fin de chapitre

- « Terminer le chapitre » enregistre d'abord la session du jour (temps de lecture écoulé, arrondi à la minute supérieure, minimum 1), puis introduit les mots SRS comme en phase 7.
- Re-terminer le chapitre le même jour ne crée pas de seconde session.
- Le récapitulatif de fin de chapitre reste inchangé.

### Écran « Aujourd'hui »

Carte « Programme » au-dessus de « Vos mots du jour » :

- en-tête « Jour X sur 28 » ; « Parcours terminé » après 28 jours ;
- pastille « Série : N j » avec icône bouclier (disponible) ou bouclier barré (consommé) ;
- barre de progression `daysCompleted / 28` ;
- objectif : « Chapitre N · révision de vos mots » et « ≈ 10 min de session » ;
- état : « Objectif du jour terminé » (icône validée) ou « À faire aujourd'hui » ;
- bouton principal :
  - jour validé → « Relire le chapitre N » ;
  - position de lecture enregistrée → « Reprendre le chapitre N » ;
  - sinon → « Commencer la session » ;
  - destination : `/read/bookId/chapterId` du chapitre du jour (modulo le nombre de chapitres).
- Tant que le manifeste charge, la carte affiche l'objectif sans chapitre et le bouton est désactivé.

### Écran « Progrès »

- Carte parcours : « Jour X sur 28 », progression, grille de 28 jours (validés / courant / à venir), série, bouclier, record.
- Statistiques : minutes lues (format `h min` au-delà de 60), mots en révision, révisions totales.
- Badges : six entrées, débloquées ou verrouillées avec description (« Les 28 jours » pour le parcours accompli). Les badges de série s'appuient sur le record (qui inclut déjà la série courante).
- Données issues des providers `programProgressProvider`, `srsProvider` ; aucun chargement réseau.

## Decisions

### Badges dérivés plutôt que stockés

Les badges sont une lecture de l'état (jours, série, cartes). Aucun événement à journaliser, aucune migration, et un recalcul correct si l'horloge change. Les libellés vivent dans le domaine pour rester testables.

### Bouclier unique par série

« Une journée manquée ne casse pas l'élan » se traduit par un seul jour de grâce : deux jours manqués d'affilée rompent la série. Le bouclier se recharge avec la série suivante, ce qui évite un joker permanent qui viderait la notion d'élan.

### Une session = un jour, maximum de minutes

Le programme mesure l'assiduité, pas le volume : relire deux fois le chapitre le même jour ne compte qu'un jour. Conserver le maximum évite qu'une session interrompue écrase une durée plus longue déjà enregistrée.

### Chapitre du jour par modulo

Le pack pilote n'a qu'un chapitre ; le parcours le repropose chaque jour plutôt que de bloquer la série faute de contenu. La phase 9 introduira un chapitre par jour sans changer le calcul (`currentDay - 1`).

### Progression en jours, pas en révisions

L'objectif unique est « un chapitre + la révision du jour ». Valider un jour sur la seule lecture terminée garde un critère simple et vérifiable ; la révision reste proposée mais non bloquante.

## Context

La phase 7 a fermé la boucle lire → rencontrer → réviser. La phase 8 donne le rythme : un objectif par jour, un élan visible, des preuves de progrès. Elle prépare la phase 9 (livre complet et test utilisateur de 28 jours) sans dépendre d'un nouveau contenu.

## Stakeholder Notes

- **Produit** : un seul objectif par écran, aucune culpabilisation ; le bouclier est un pardon, pas une punition.
- **Technique** : calculs purs et testés, stockage additif, provider surchargé ; aucun nouveau paquet.
- **Business** : la série et les badges sont des marqueurs de rétention naturels pour l'abonnement (phases 11–13), déjà dérivés localement.
- **Éditorial** : les libellés français restent courts et chaleureux (« Série », « Bouclier », « Record », « Parcours terminé »).
