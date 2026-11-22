# Phase 3 Validation — Modèle de contenu & pack pilote

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

Tous les tests passent, y compris les 15 tests existants (non-régression onboarding, préférences, scoring).

Tests requis :

- **Manifeste** : schéma 1 accepté ; `schemaVersion` inconnu, `packVersion` non semver, niveau invalide, durée hors 1–30, ids dupliqués ou JSON malformé rejetés par `FormatException`.
- **Chapitre** : segment vide, `vocabId` inconnu, vocabulaire dupliqué, entrée non référencée, `bookId` incohérent et champs de vocabulaire manquants rejetés.
- **Pack réel** : les assets se chargent ; le chapitre fait 350–450 mots ; 15–20 entrées de vocabulaire ; toutes référencées ; ids uniques ; le `newWordCount` du manifeste correspond au nombre d’entrées ; le chemin `asset` du chapitre se charge réellement.
- **UI** : avec onboarding terminé, l’onglet Bibliothèque affiche la carte du livre pilote ; le bouton ouvre le chapitre ; le titre et le premier paragraphe s’affichent.
- **Surbrillance** : au moins un segment annoté est rendu avec un fond de surbrillance distinct du texte courant, dans le `RichText` du paragraphe.

### 3. Bibliothèque

- La carte affiche : *The Legend of Sleepy Hollow*, son titre français, Washington Irving, le badge **A2**, la durée (5–8 min), le nombre de mots nouveaux (15–20) et « 1 chapitre ».
- Les valeurs affichées proviennent du manifeste, pas de constantes codées en dur dans l’UI.
- En cas d’asset absent ou corrompu (simulé par test), un état d’erreur avec « Réessayer » s’affiche, sans crash.

### 4. Écran de lecture

- S’ouvre depuis la carte, avec un retour arrière fonctionnel.
- Le titre du chapitre, le niveau et la durée estimée sont visibles.
- Tous les paragraphes du JSON sont rendus, dans l’ordre, sans perte ni duplication de texte.
- Les segments annotés sont surlignés et lisibles en thème clair **et** sombre.
- La note « Les mots surliqués sont les mots clés du chapitre » (orthographe corrigée : « surlignés ») est présente.
- Aucun tap sur un mot n’est attendu à cette phase.

### 5. Contenu éditorial

- L’adaptation est originale (aucune reproduction du texte de 1819), en anglais A2, créditée à Washington Irving dans le manifeste.
- 4 à 6 paragraphes, phrases courtes, pas d’archaïsmes.
- Les 15 à 20 mots clés ont une définition EN, une traduction FR, un exemple, une phonétique IPA et une nature grammaticale.

### 6. Hors-ligne

En mode avion, la bibliothèque et le chapitre s’ouvrent intégralement. Aucun appel réseau n’est introduit.

### 7. Thèmes et mise en page

- Les écrans Bibliothèque et Lecture restent lisibles en clair et en sombre.
- Aucun débordement horizontal à 360 px de large ; le texte se replie normalement.
- Les cibles tactiles du bouton de lecture et des actions d’en-tête font au moins 44 × 44 px.

### 8. CI

Le workflow existant reste vert : `flutter pub get`, `flutter analyze`, `flutter test`.

### 9. Aperçu visuel

Build web puis captures Chrome de la bibliothèque (clair et sombre) et du chapitre avec mots clés surlignés, archivées dans `.tmp/screens/`.

## Not Required

- Pas d’audio, de timings ni de karaoké.
- Pas de dictionnaire interactif, de traduction au tap ni de prononciation audio.
- Pas de SRS, de progression, de reprise de position ni de fin de chapitre.
- Pas de catalogue distant, de téléchargement ni de base locale de contenu.
- Pas d’illustrations de couverture ni de finition éditoriale du livre complet.
- Pas d’exécution Android/iOS réelle sur ce poste Windows (aperçu web + tests seulement).
