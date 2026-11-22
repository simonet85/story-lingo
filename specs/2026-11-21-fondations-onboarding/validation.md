# Phase 1–2 Validation — Fondations & Onboarding

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

Tous les tests passent. Tests requis :

- **Scoring** : 4 réponses A2 correctes seules → A2 ; A2 + B1 correctes (10 points) → B1 ; 13 points ou plus → B2 ; aucune bonne réponse → A2.
- **Asset** : `level_test_fr.json` contient exactement 10 questions, 4 A2 / 3 B1 / 3 B2, 4 options par question, `answerIndex` dans les bornes.
- **Préférences** : valeurs par défaut quand les clés manquent ; écriture puis relecture identique ; donnée corrompue → défaut, sans exception.
- **Widget — premier lancement** : préférences vierges → écran d'accueil de l'onboarding, pas de shell.
- **Widget — parcours heureux** : 10 réponses, 2 intérêts, continuité → `/today`.
- **Widget — validation des intérêts** : moins de 2 sélections → bouton « Continuer » désactivé, texte d'aide visible.
- **Widget — relance** : `onboarding.completed = true` → démarrage direct sur le shell.

### 3. Premier lancement sur installation vierge

Effacer les données de l'application, puis `flutter run` :

- L'écran d'accueil affiche « Storylingo » et la promesse « Améliore ton anglais en 28 jours avec des livres adaptés ».
- Le test de niveau affiche 10 questions, une à la fois, avec la progression `n/10`.
- Un jeu de réponses à 13 points ou plus affiche le résultat **B2** ; un jeu à 4 points affiche **A2**.
- L'écran des intérêts exige au moins 2 sélections.
- La fin de l'onboarding ouvre **Aujourd'hui**.
- Durée totale constatée ≤ 3 minutes.

### 4. Relance

Fermer puis relancer l'application : elle ouvre directement **Aujourd'hui**, sans onboarding.

### 5. Niveau modifiable dans les réglages

- Les réglages s'ouvrent depuis l'icône de l'`AppBar` et affichent le niveau courant.
- Passer de A2 à B1 puis B2 s'applique immédiatement.
- Après redémarrage, le dernier niveau choisi est conservé.
- Le changement de niveau ne déclenche pas l'onboarding.

### 6. Thème

- Les trois modes (Système, Clair, Sombre) sont proposés ; **Système** est le défaut.
- Chaque mode s'applique à l'onboarding, au shell et aux réglages.
- Le choix survit à un redémarrage.
- En mode sombre, tous les textes restent lisibles (contraste visuel vérifié à l'œil sur les écrans clés).

### 7. Navigation

- Les trois onglets (Aujourd'hui, Bibliothèque, Progrès) s'ouvrent sans erreur et conservent leur état.
- Les réglages ne forment pas un quatrième onglet et reviennent correctement au shell.
- Un lien profond vers `/today` avec un onboarding incomplet redirige vers `/onboarding`.

### 8. Hors-ligne

En mode avion, depuis une installation vierge, les points 3 à 6 passent intégralement. Aucune requête réseau n'est nécessaire à l'onboarding ni au shell.

### 9. CI

Le workflow GitHub Actions est vert : `flutter pub get`, `flutter analyze`, `flutter test`.

### 10. Accessibilité de base

- Toutes les cibles tactiles font au moins 44 × 44 px.
- Les trois onglets et les options du test ont des libellés lus par TalkBack/VoiceOver.
- Aucun texte français tronqué à l'échelle de texte par défaut.

## Not Required

- Pas de contenu de livre, de lecteur, d'audio ni de catalogue.
- Pas de base de données locale (`drift`) ni de couche réseau.
- Pas de comptes, d'analytics, de notifications ni de paiements.
- Pas de builds de production ni de soumission aux stores.
- Pas d'exécution sur simulateur iOS sous Windows : vérifiée sur macOS/CI ; l'émulateur Android suffit pour valider cette phase.
- Pas de golden tests (reportés à la phase 4, avec le lecteur).
- Pas de mise en page spécifique tablette.
