# Phase 9 — Validation : boucle pilote complète

## Definition of Done

### 1. Analyse statique

```
flutter analyze
```

Code 0, sans erreur ni avertissement.

### 2. Tests automatisés

```
flutter test
```

Tous les tests passent, y compris ceux des phases 1 à 8.

Tests requis :

- **Contenu** : manifeste 3 chapitres (numéros 1–3), `packVersion` 1.3.0 ;
  chaque chapitre respecte 4–6 paragraphes, 350–450 mots, 15–20 mots annotés ;
  identifiants uniques dans le livre ; chaque entrée annotée, référencée et
  complète ; timings audio alignés token par token ; MP3 présents.
- **Télémétrie** : aller-retour JSON, entrées invalides ignorées, plafond de
  500, contrôleur horodaté par `nowProvider`, persistance relue par un nouveau
  repository.
- **Export** : objet complet (participant, contenu, programme, vocabulaire,
  événements), sessions incluses, aucune clé nominative ni identifiant
  d'appareil, JSON valide.
- **Boucle** : fin de chapitre → récap avec « Jour X validé »/série et révision ;
  fin de révision → « Belle session ! », compteurs, encouragement, retour à
  « Aujourd'hui » ; dernier chapitre terminé → mention du livre terminé.
- **Réglages** : compteur d'événements, copie de l'export dans le presse-papiers
  avec confirmation, effacement confirmé.
- **Widget** : 360 px sans overflow pour le récap de révision, le récap de
  chapitre et les réglages ; non-régression des tests existants.

### 3. Préférences et contenu

- `prefs.version` reste `1` ; seule `telemetry.events` s'ajoute.
- `packVersion` = 1.3.0 ; ancien packVersion remplacé, pas dupliqué.
- Aucune modification du manifeste Android ni du workflow CI.

### 4. Lecture des nouveaux chapitres

- Les chapitres 2 et 3 se chargent depuis les assets, texte et audio.
- Les 3 modes de lecture fonctionnent sur les nouveaux chapitres.
- Les mots annotés ouvrent la fiche et alimentent le SRS à la fin du chapitre.
- Un chapitre déjà terminé repart du début lors d'une relecture.

### 5. Boucle de session

- Fin de chapitre : « Jour X validé », série, révision du jour.
- Fin de révision : encouragement positif, compteurs exacts, retour à
  « Aujourd'hui ».
- Une file vide affiche « Rien à réviser pour le moment » sans reproche.
- Après le dernier chapitre du livre : « Vous avez terminé le livre pilote ! ».

### 6. Estimation de session

- « Aujourd'hui » affiche `minutes estimées du chapitre + 3` (6 + 3 = 9 min
  pour les chapitres du pilote).
- Le chronomètre de lecture reste plafonné à 10 minutes.

### 7. Télémétrie et export

- Les cinq événements sont enregistrés aux moments attendus.
- L'export est copiable depuis les réglages et contient un JSON valide.
- La télémétrie survit à un redémarrage.
- L'effacement vide la liste sans toucher aux autres données.

### 8. Hors-ligne

- En mode avion : lecture, audio, révision, encouragement, statistiques,
  réglages et export fonctionnent.
- Aucun appel réseau introduit.

### 9. Accessibilité et ergonomie

- Cibles ≥ 44 px ; libellés « Belle session ! », « Terminer la session »,
  « Votre révision du jour », « Données de test », « Copier l'export JSON ».
- Contraste suffisant en clair et sombre ; aucune overflow à 360 px.

### 10. CI

Le workflow existant reste vert : `flutter pub get`, `flutter analyze`,
`flutter test`.

### 11. Aperçu visuel et runtime

Captures Chrome : bibliothèque avec 3 chapitres, chapitre 2/3, récap de fin de
chapitre, révision encouragée, réglages/export, thèmes clair et sombre
(`.tmp/screens/web-pilot-*.png`).

Sur l'émulateur existant (`storylingo_api36`) :

- les chapitres 2 et 3 se lisent avec audio et dictionnaire ;
- la boucle chapitre → révision → encouragement → « Aujourd'hui » fonctionne ;
- l'export est copié avec confirmation et le JSON est cohérent ;
- les événements persistent après redémarrage ;
- en mode avion, la boucle et l'export restent disponibles ;
- captures archivées dans `.tmp/screens/android-pilot-*.png`.

## Not Required

- Téléversement ou envoi automatique de la télémétrie.
- Analytics distants, A/B testing, notifications.
- Import automatisé de nouveaux livres (phase 10).
- Comptes, synchronisation, paywall.
