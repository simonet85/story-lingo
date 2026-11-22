# Phase 8 Validation — Programme 28 jours

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

Tous les tests passent, y compris ceux des phases 1 à 7.

Tests requis :

- **Modèle** : aller-retour JSON `ProgramSession`, date normalisée au jour local, minutes bornées 1–240 ; entrées invalides ignorées, doublons fusionnés au maximum de minutes, tri chronologique ; seule `program.sessions` ajoutée, `prefs.version` reste `1`.
- **Enregistrement** : une session par jour ; re-enregistrer le même jour conserve la durée la plus longue ; temps écoulé arrondi à la minute supérieure avec minimum 1 ; persistance relue par un nouveau repository.
- **Progression** : `daysCompleted` plafonné à 28 ; `currentDay` correct avant/après validation du jour ; `doneToday` ; `programComplete` ; totaux minutes et sessions.
- **Série** : trois jours consécutifs → 3 ; jour manqué (écart de 2) → série conservée, bouclier consommé ; deux jours manqués (écart de 3) → série 0 et bouclier neuf ; dernier jour avant-hier → bouclier consommé ; record calculé avec la même règle.
- **Badges** : chaque seuil (1 jour, série 3, série 7, 14 jours, 28 jours, 10 cartes) verrouillé puis débloqué ; description et titre non vides.
- **Mapping** : `chapterForDay` renvoie le bon chapitre, boucle sur un livre à chapitre unique, borne à 28.
- **Widget** : carte Programme sur « Aujourd'hui » (jour, série, estimation, état, CTA) ; CTA vers la lecture du chapitre ; fin de chapitre → jour validé et série 1 affichée ; écran Progrès (progression, grille, statistiques, badges) ; 360 px sans overflow ; non-régression des tests existants.

### 3. Préférences et contenu

- `prefs.version` reste à `1` ; seule `program.sessions` s'ajoute.
- `packVersion` et contenu du pack pilote inchangés.
- Aucune modification du manifeste Android ni du workflow CI.

### 4. Fin de chapitre et parcours

- « Terminer le chapitre » enregistre une session datée du jour local (temps de lecture écoulé).
- Le jour est marqué validé ; « Aujourd'hui » affiche « Objectif du jour terminé » et la série.
- Re-terminer le même jour ne crée pas de doublon et ne double pas les minutes.
- Les cartes SRS sont toujours introduites comme en phase 7.

### 5. Écran « Aujourd'hui »

- Carte « Programme » : « Jour X sur 28 », pastille de série avec bouclier, barre `jours / 28`.
- Objectif unique : « Chapitre N · révision de vos mots », « ≈ 10 min de session ».
- États : « À faire aujourd'hui » / « Objectif du jour terminé » ; CTA « Commencer la session », « Reprendre le chapitre N » ou « Relire le chapitre N ».
- La carte « Vos mots du jour » reste fonctionnelle en dessous.

### 6. Écran « Progrès »

- Progression `X/28`, grille des 28 jours, série courante, bouclier (disponible/utilisé), record.
- Statistiques : minutes lues, mots en révision, révisions totales.
- Six badges : débloqués lisibles, verrouillés atténués avec description.
- Mise à jour immédiate après une fin de chapitre (navigation vers l'onglet Progrès).

### 7. Hors-ligne

- En mode avion : fin de chapitre, validation du jour, série, statistiques et badges fonctionnent.
- Aucun appel réseau introduit.

### 8. Accessibilité et ergonomie

- Cibles ≥ 44 px ; libellés « Programme », « Jour X sur 28 », « Série », « Bouclier », « Record », « Objectif du jour terminé », « Commencer la session ».
- Contraste suffisant en thème clair et sombre ; aucune overflow à 360 px.

### 9. CI

Le workflow existant reste vert : `flutter pub get`, `flutter analyze`, `flutter test`.

### 10. Aperçu visuel

Captures Chrome : « Aujourd'hui » avec carte Programme (à faire et terminé) et « Progrès » complet, thème clair et sombre. Archives `.tmp/screens/web-*.png`.

### 11. Runtime Android

Sur l'émulateur existant (`storylingo_api36`) :

- terminer le chapitre valide le jour, affiche la série et met à jour Progrès ;
- avancer la date d'un jour propose le jour suivant et conserve la série ;
- sauter un jour consomme le bouclier sans casser la série ; deux jours sautés la rompent ;
- l'état survit à un redémarrage de l'application ;
- en mode avion, le parcours et les statistiques restent disponibles ;
- captures archivées dans `.tmp/screens/android-*.png`.

## Not Required

- Un chapitre différent par jour (phase 9).
- Notifications, rappels et réengagement.
- Réglage de l'objectif, du bouclier ou des badges.
- Historique calendaire au-delà des 28 jours, graphiques temporels.
- Synchronisation cloud.
