# Phase 6 Validation — Dictionnaire au tap

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

Tous les tests passent, y compris les tests des phases 1 à 5 (onboarding, préférences, contenu, bibliothèque, lecture, karaoké).

Tests requis :

- **Mapping** : token non annoté → `null` ; fiche complète (id, champs, provenance) ; clip borné au token ; groupe annoté « Sleepy Hollow » → clip du premier au dernier token ; chapitre v1 sans audio → fiche sans clip.
- **Stockage** : aller-retour JSON complet (dont clip), ordre d'insertion, déduplication par id, entrées invalides ignorées, `toggle` ajoute puis retire, remplacement du même mot, persistance relue par un nouveau repository, clé `words.saved` seule ajoutée.
- **Prononciation** : clip présent → lecteur pack appelé, TTS non ; clip absent → TTS ; lecteur pack en échec → TTS ; deux échecs → exception gérée ; `stop` arrête les deux collaborateurs.
- **Recognizers** : un span de mot annoté porte une action de tap, un mot non annoté n'en porte pas ; le rebuild karaoké ne recrée pas les recognizers ; ils sont libérés au `dispose`.
- **Widget** : tap (via le recognizer du span) sur « mist » → fiche avec mot, `/mɪst/`, « nom », traduction, définition, exemple ; « Écouter » appelle la prononciation avec le clip du pack ; ajout → bouton « Dans ma liste de mots » + prefs `words.saved` ; retrait → prefs vidées ; la narration audio se met en pause à l'ouverture en Lire + Écouter ; liste vide, liste pleine, suppression, réouverture depuis la liste ; 360 px sans overflow ; non-régression des tests existants.

### 3. Contenu et préférences

- Aucun changement de `packVersion`, de `schemaVersion` ni d'asset de contenu.
- `prefs.version` reste à `1` ; seules `words.saved` s'ajoute.
- Le manifeste Android déclare l'intention `TTS_SERVICE` (visibilité du moteur sur Android 11+).

### 4. Interaction dans le lecteur

- Les mots surlignés sont cliquables ; le reste du texte ne réagit pas.
- Une fiche s'ouvre en feuille modale, lisible en clair et en sombre, sans déborder à 360 px.
- La fiche affiche mot, phonétique, nature, traduction, définition, exemple.
- Chaque tap répété sur le même mot rouvre une fiche cohérente ; deux mots différents ouvrent deux fiches différentes.
- L'aide du lecteur mentionne le tap.
- La barre du lecteur expose « Ma liste de mots » avec un badge à jour.

### 5. Prononciation

- La tranche audio du pack prononce le mot (ou le groupe) puis s'arrête ; le déclenchement est immédiat et hors-ligne.
- Un second tap pendant la lecture arrête la première lecture avant de relancer.
- Fermer la fiche arrête la prononciation.
- Sans passage de timing, la synthèse vocale prend le relais ; en cas d'échec total, le message « Prononciation indisponible. » s'affiche dans la fiche sans crash.

### 6. Liste de mots

- Ajout et retrait depuis la fiche persistent après fermeture de l'application.
- La liste est accessible depuis le lecteur, depuis les trois onglets et depuis la fiche.
- L'état vide est explicite ; le compteur est correct.
- Ouvrir une carte affiche la fiche complète ; retirer une carte met la liste à jour immédiatement.
- Les mots ajoutés depuis plusieurs fiches coexistent sans doublon.

### 7. Hors-ligne

- En mode avion : lecture, tap, fiche, prononciation pack, ajout/retrait et consultation de la liste fonctionnent.
- Aucun appel réseau n'est introduit par la fonctionnalité.
- Les préférences et la progression existantes sont intactes.

### 8. Accessibilité et ergonomie

- Cibles tactiles ≥ 44 × 44 px (bouton prononciation, ajout, retrait, action de barre).
- Libellés : « Prononcer le mot », « Ma liste de mots », « Retirer de la liste ».
- Contraste suffisant en thème clair et sombre ; le texte de la fiche reste sélectionnable/lisible avec la police système agrandie raisonnablement.
- Aucun rebuild de recognizer à chaque frame karaoké.

### 9. CI

Le workflow existant reste vert : `flutter pub get`, `flutter analyze`, `flutter test`.

### 10. Aperçu visuel

Build web puis captures Chrome : fiche en thème clair, fiche en thème sombre, liste pleine, état vide. Captures archivées dans `.tmp/screens/web-*.png`.

### 11. Runtime Android

Sur l'émulateur existant (`storylingo_api36`) :

- un tap sur un mot surligné ouvre la fiche ;
- « Écouter » joue la prononciation issue du pack ;
- L'ajout affiche la confirmation dans la fiche et met à jour le badge ; le retrait depuis la liste affiche une snackbar et met la liste à jour.
- « Ma liste de mots » liste le mot, permet de le rouvrir et de le retirer ;
- la liste survit à un redémarrage de l'application ;
- en mode avion, fiche, prononciation et liste fonctionnent ;
- captures archivées dans `.tmp/screens/android-*.png`.

## Not Required

- Pas de flashcards, SRS, objectif quotidien ni statistiques de vocabulaire.
- Pas de recherche, de dictionnaire général ni de traduction de mots non annotés.
- Pas de prononciation enregistrée par mot dans le pack.
- Pas de synchronisation cloud, de partage ni d'export.
- Pas de prononciation ralentie, répétée en boucle ou comparée à l'utilisateur.
- Pas de modification du lecteur au-delà du tap et de l'aide.
