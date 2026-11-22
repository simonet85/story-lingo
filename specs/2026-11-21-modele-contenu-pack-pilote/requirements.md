# Phase 3 Requirements — Modèle de contenu & pack pilote

## Scope

Première tranche de contenu réel :

- Format de **pack de contenu versionné** (manifeste + chapitres) embarqué dans les assets.
- **Pack pilote** : *The Legend of Sleepy Hollow* (Washington Irving, domaine public), un chapitre adapté en anglais A2 de 350 à 450 mots, 15 à 20 mots clés annotés.
- Modèles Dart validés strictement et dépôt de contenu chargeant les assets.
- Bibliothèque affichant le livre pilote avec ses métadonnées.
- Écran de lecture simple affichant le chapitre avec les mots clés surlignés.
- Tests unitaires, test d’intégrité du pack et tests widget.

Tout reste 100 % local et utilisable hors-ligne.

## Out of Scope

- Audio, timings de synchronisation et mode karaoké (phase 5).
- Tap sur un mot, dictionnaire interactif, prononciation audio (phase 6).
- Détection des mots nouveaux selon le niveau utilisateur, SRS, flashcards (phase 7).
- Progression de lecture, reprise de position, timer de session (phase 4).
- Catalogue distant, API de contenu, téléchargements (phases 10 et 12).
- Livres supplémentaires, illustration de couverture, fin de chapitre.
- Persistance locale du contenu (`drift`), analytics, paywall.

## Content Contract

### Arborescence

```
assets/content/sleepy-hollow-a2/
  manifest.json
  chapters/
    chapter-01.json
```

### `manifest.json`

| Champ | Type | Règles |
|---|---|---|
| `schemaVersion` | int | Doit valoir `1` |
| `packVersion` | string | Semver `X.Y.Z` |
| `id` | string | Identifiant stable (`sleepy-hollow`) |
| `title` | string | Titre original |
| `titleFr` | string | Titre français |
| `author` | string | Washington Irving |
| `level` | string | `a2` (A2/B1/B2 autorisés) |
| `descriptionFr` | string | 1 à 2 phrases, non vide |
| `chapters` | liste | ≥ 1 chapitre, ids et numéros uniques, numérotation à partir de 1 |

Chaque chapitre du manifeste contient : `id`, `number`, `title`, `asset` (chemin Flutter), `estimatedMinutes` (1–30), `newWordCount` (≥ 0).

### `chapter-01.json`

```json
{
  "schemaVersion": 1,
  "id": "chapter-01",
  "bookId": "sleepy-hollow",
  "number": 1,
  "title": "A Quiet Valley",
  "level": "a2",
  "paragraphs": [
    {
      "id": "p-01",
      "segments": [
        {"text": "In the quiet valley of "},
        {"text": "Sleepy Hollow", "vocabId": "sleepy-hollow"},
        {"text": ", the farms were rich and the people were slow to wake."}
      ]
    }
  ],
  "vocabulary": [
    {
      "id": "sleepy-hollow",
      "word": "Sleepy Hollow",
      "partOfSpeech": "proper noun",
      "phonetic": "/ˈsliːpi ˈhɒləʊ/",
      "definitionEn": "a small, quiet valley",
      "translationFr": "un vallon endormi",
      "example": "Sleepy Hollow was a quiet place by the river."
    }
  ]
}
```

Règles :

- `schemaVersion == 1`, `id` et `bookId` cohérents avec le manifeste.
- Au moins un paragraphe ; aucun paragraphe sans segment ; aucun segment avec un texte vide.
- Chaque `vocabId` référence une entrée existante ; chaque entrée de vocabulaire est référencée au moins une fois ; ids de vocabulaire uniques.
- Chaque entrée a `word`, `partOfSpeech`, `phonetic` (IPA), `definitionEn`, `translationFr` et `example` non vides.
- Champ `timings` **absent** en schéma v1 ; l’audio introduira une version de schéma supérieure en phase 5.

### Contenu éditorial

- Adaptation **originale** en anglais simplifié, pas une copie du texte de 1819 ; l’œuvre source est dans le domaine public et l’auteur est crédité.
- 350–450 mots au total (comptés sur les segments), 4–6 paragraphes, niveau A2 : phrases courtes, vocabulaire courant, pas de tournures archaïques.
- 15–20 mots ou expressions clés utiles à la compréhension, choisis parmi le vocabulaire qui dépasse le socle A2.
- Durée estimée du chapitre : 5 à 8 minutes, cohérente avec l’objectif de session de 7–10 minutes du produit.

## Decisions

### Segments de texte plutôt qu’offsets de caractères

Le contenu est stocké en **segments** (`text` + `vocabId` optionnel) plutôt qu’en texte brut avec des offsets. Avantages :

- rendu direct en `TextSpan`, sans calcul d’offsets ni risque d’annotation décalée ;
- validation simple : un `vocabId` soit référence une entrée, soit est invalide ;
- extension naturelle en phase 5 : chaque segment pourra recevoir un timing audio sans changer la structure du chapitre.

### Contenu embarqué, pas encore de base locale

Le pack pilote est en lecture seule dans les assets. `drift` reste réservé aux données utilisateur (progression, SRS) dans les phases suivantes ; charger du contenu immuable dans une base n’apporterait rien ici. Le dépôt de contenu isole déjà le chargement pour pouvoir le remplacer par une API distante en phase 10 sans toucher à l’UI.

### Pas de personnalisation par niveau utilisateur

Tous les mots annotés sont surlignés de la même manière pour l’instant. La détection des mots nouveaux selon le niveau (phase 7) modifiera la sélection affichée ; le pack pilote sert d’abord à valider le format et le rendu.

### Lecture seule, sans reprise de position

Cette phase prouve le rendu du contenu, pas la boucle de session. Position de lecture, timer, fin de chapitre et récompenses arrivent en phase 4. La bibliothèque et l’écran de lecture ne modifient aucune préférence.

### Niveau de contenu et niveau utilisateur partagent `UserLevel`

Le niveau CEFR est le même concept que celui estimé à l’onboarding. Réutiliser l’enum `UserLevel` évite deux vocabulaires divergents ; un futur besoin de niveaux de contenu différents (C1) fera l’objet d’une décision explicite.

## Context

C’est le premier moment où l’utilisateur voit du **vrai contenu d’apprentissage** après l’onboarding. La promesse « 7 à 10 minutes par jour » doit se matérialiser : un chapitre court, lisible d’une traite, dont les mots clés sont immédiatement identifiables.

Le schéma de contenu est la fondation des phases 4 à 7 (lecteur, audio, dictionnaire, SRS) et 10 à 12 (catalogue, synchronisation, hors-ligne). Il doit être strict, versionné et assez simple pour être régénéré par un pipeline éditorial ultérieur.

## Stakeholder Notes

- **Produit** : un classique reconnaissable, une adaptation réellement lisible en A2, des métadonnées qui rassurent (durée, mots nouveaux, niveau).
- **Technique** : schéma validé à la frontière, chargement remplaçable par une source distante, aucun couplage de l’UI au format JSON.
- **Business** : le pack pilote est le support des tests utilisateurs du parcours 28 jours ; il ne doit dépendre d’aucun serveur ni d’aucun paiement.
- **Éditorial** : l’adaptation est originale, crédite Washington Irving et respecte le domaine public ; aucune illustration ou extrait sous licence n’est embarqué.
