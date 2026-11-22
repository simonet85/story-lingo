# Phase 4 Validation — Lecteur

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

Tous les tests passent, y compris les 48 tests existants (non-régression onboarding, préférences, scoring, contenu, bibliothèque/lecture).

Tests requis :

- **Dépôt de progression** : position enregistrée puis relue ; isolation entre deux chapitres ; complétion qui efface la position ; valeurs absentes ou corrompues ignorées sans exception.
- **Timer** : la pastille est visible dans l'`AppBar` ; la valeur initiale correspond à `estimatedMinutes` du chapitre ; elle décrémente après une seconde simulée ; le dépassement affiche `+m:ss`.
- **Reprise** : avec une position sauvegardée sur un paragraphe du milieu, l'ouverture du chapitre restaure ce paragraphe en haut de la zone de lecture, le premier paragraphe n'est plus visible, et le `SnackBar` de reprise apparaît.
- **Sauvegarde** : après défilement puis retour, `reading.position.<bookId>.<chapterId>` contient un id de paragraphe du chapitre.
- **Fin de chapitre** : le bouton « Terminer le chapitre » est atteignable en bas du texte ; le récapitulatif affiche le titre, un temps de lecture `m:ss` et le nombre de mots ; « Retour au parcours » mène à l'onglet Aujourd'hui ; la complétion est persistée et la position effacée.
- **Bibliothèque** : le libellé devient « Continuer le chapitre 1 » quand une position existe, « Relire le chapitre 1 » quand le chapitre est terminé, et reste « Lire le chapitre 1 » sinon.

### 3. Écran de lecture

- La barre d'en-tête reste épinglée pendant le défilement ; le timer y est toujours visible et lisible en clair comme en sombre.
- La largeur de lecture reste centrée et bornée ; aucun débordement à 360 px de large.
- Les surlignages de vocabulaire de la phase 3 sont conservés, sans régression de lisibilité.
- Les états de chargement, d'erreur (« Réessayer ») et le retour arrière restent fonctionnels.

### 4. Reprise de position

- Faire défiler jusqu'à un paragraphe du milieu, quitter par le retour système ou le bouton de l'`AppBar`, rouvrir le chapitre : le même paragraphe est en haut, la position est écrite dans `SharedPreferences`.
- La position survit à un arrêt forcé de l'application (force-stop).
- Une position pointant vers un paragraphe inexistant (asset mis à jour, test simulé) est ignorée sans crash.

### 5. Fin de chapitre

- Le récapitulatif n'apparaît que via le bouton explicite ; atteindre le bas du texte ne le déclenche pas.
- « Retour au parcours » affiche l'onglet Aujourd'hui ; « Fermer » revient à la Bibliothèque.
- Rouvrir un chapitre terminé démarre en haut du texte.

### 6. Persistance et hors-ligne

- En mode avion, le parcours complet (ouverture, reprise, fin de chapitre) fonctionne sans réseau.
- Aucun appel réseau n'est introduit.
- Les clés existantes (`prefs.version`, `onboarding.completed`, `user.level`, `user.interests`, `settings.theme_mode`) restent intactes ; la version de schéma ne change pas.

### 7. Thèmes et accessibilité

- Lecture et récapitulatif lisibles en thème clair et sombre.
- Cibles tactiles ≥ 44 × 44 px (retour, bouton de fin, boutons du récapitulatif).
- La pastille du timer expose un libellé d'accessibilité (« Temps restant »).

### 8. CI

Le workflow existant reste vert : `flutter pub get`, `flutter analyze`, `flutter test`.

### 9. Aperçu visuel

Build web puis captures Chrome : lecture avec timer (clair et sombre), récapitulatif de fin de chapitre, carte de bibliothèque avec « Continuer ». Captures archivées dans `.tmp/screens/`.

### 10. Runtime Android

Sur l'émulateur existant (`storylingo_api36`) :

- le timer est visible et décrémente pendant la lecture ;
- la position est restaurée après un retour puis une réouverture et après un force-stop ;
- le récapitulatif s'affiche, « Retour au parcours » ramène à Aujourd'hui ;
- captures archivées dans `.tmp/screens/android-*.png`.

## Not Required

- Pas d'audio, de timings ni de karaoké.
- Pas de dictionnaire au tap ni de prononciation.
- Pas de SRS, de flashcards ni de révision de fin de session.
- Pas de statistiques dans l'onglet Progrès, de streak ni de parcours 28 jours.
- Pas de réglage de typographie ni de mode sépia.
- Pas de synchronisation ni de téléchargement.
