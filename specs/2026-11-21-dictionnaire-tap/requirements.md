# Phase 6 Requirements — Dictionnaire au tap

## Scope

Troisième tranche du lecteur : le dictionnaire.

- **Tap sur un mot clé** (mot surligné du chapitre) → fiche : mot, phonétique, nature, traduction FR, définition EN, exemple.
- **Prononciation** : tranche de la narration du pack pour le mot (ou le groupe de mots), repli sur la synthèse vocale `en-US` de l'appareil.
- **« Ma liste de mots »** : ajout/retrait depuis la fiche, liste persistée localement, consultable et modifiable.
- Accès à la liste depuis le lecteur, les onglets principaux et la fiche.
- Entièrement **hors-ligne** : les définitions viennent du pack, la liste et les clips audio sont locaux.

## Out of Scope

- Flashcards, SRS/FSRS, objectif quotidien de mots nouveaux (phase 7).
- Détection automatique des mots inconnus selon le niveau (phase 7).
- Recherche dans un dictionnaire, traduction de mots non annotés, traduction de phrase.
- Enregistrement micro, analyse de prononciation.
- Synchronisation cloud de la liste (phase 11).
- Audio dédié par mot livré dans le pack (la prononciation est une tranche de la narration).
- Modification du format de pack, du schéma de contenu ou de `prefs.version`.

## Modèle local

### Fiche (`WordEntry`)

| Champ | Rôle |
|---|---|
| `id` | `${bookId}/${vocabId}`, identité stable dans la liste |
| `word` | Mot affiché (peut contenir plusieurs mots : « Sleepy Hollow ») |
| `partOfSpeech` | Nature issue du pack (`noun`, `verb`, `adjective`, `proper noun`…) |
| `phonetic` | Transcription IPA |
| `translationFr` | Traduction française |
| `definitionEn` | Définition en anglais |
| `example` | Exemple en anglais |
| `bookId`, `chapterId` | Provenance |
| `clip` | `PronunciationClip?` : `asset`, `startMs`, `endMs` de la narration du pack |

### Mot enregistré (`SavedWord`)

- Instantané complet de la fiche + `savedAt` (millisecondes epoch).
- Stocké sous `words.saved` : liste de chaînes JSON, ordre d'insertion conservé.
- Chargement **tolérant** : une entrée malformée ou dupliquée est ignorée ; la liste reste utilisable.
- Clé additive, pas de bump de `prefs.version`.

## Comportement

### Tap

- Seuls les tokens **annotés** (`vocabId` non nul, donc surlignés) sont cliquables. Les autres mots et la ponctuation restent du texte simple.
- Un tap sur un mot annoté ouvre la fiche de son `vocabId`. « Sleepy » ou « Hollow » ouvrent la même fiche « Sleepy Hollow ».
- En modes audio, l'ouverture de la fiche met la narration en pause ; la fermeture ne la relance pas.
- Le tap est exposé à l'accessibilité comme une action sur le mot.

### Fiche

Contenu, dans l'ordre :

1. Le mot (grand), la phonétique et la nature traduite (nom, verbe, adjectif, adverbe, nom propre ; valeur brute sinon).
2. La traduction française, mise en avant.
3. La définition anglaise et l'exemple.
4. Actions : « Écouter » (prononciation), « Ajouter à ma liste de mots » / « Dans ma liste de mots » (retrait), « Voir ma liste de mots ».

- Ajout → message « Ajouté à votre liste de mots. » dans la fiche ; retrait → « Retiré de votre liste de mots. ». Ces messages sont affichés sous les actions, car une snackbar serait masquée par la feuille modale.
- L'état du bouton suit la liste en temps réel (y compris si la fiche est rouverte depuis la liste).
- Fermer la fiche arrête toute prononciation en cours.

### Prononciation

| Situation | Comportement |
|---|---|
| `clip` présent | Lit la tranche `[startMs, endMs]` de l'audio du pack, puis s'arrête |
| Groupe de mots | Tranche du premier au dernier token du groupe annoté |
| `clip` absent (chapitre sans audio) | Synthèse vocale `en-US` du mot affiché |
| Échec du lecteur pack | Repli immédiat sur la synthèse vocale |
| Échec des deux | Message « Prononciation indisponible. » dans la fiche, aucun crash |
| Plusieurs taps | La lecture précédente est arrêtée avant la suivante |

Aucun appel réseau n'est requis : la tranche vient de l'asset du pack, la synthèse utilise le moteur local de l'appareil.

### Liste

- Route `/words`, titre « Ma liste de mots ».
- État vide : icône, « Votre liste est vide », « Touchez un mot surligné pendant votre lecture pour l’ajouter ici. »
- Liste non vide : compteur (« 1 mot » / « N mots »), cartes mot + phonétique + traduction, les plus récents en premier.
- Tap sur une carte → fiche ; action de retrait avec snackbar.
- Accès : badge dans la barre du lecteur, action dans `StorylingoAppBar` (Aujourd'hui, Bibliothèque, Progrès), lien dans la fiche.

### Hors-ligne et persistance

- La fiche, la prononciation pack et la liste fonctionnent en mode avion.
- La liste survit à la fermeture de l'application.
- Aucune clé existante n'est modifiée ; seules `words.saved` s'ajoute.

## Decisions

### Seuls les mots annotés sont cliquables

Le pack ne contient de définition que pour les mots clés. Rendre tous les tokens cliquables créerait une promesse impossible (mot sans fiche) ou un faux dictionnaire. Le surlignage existant devient l'affordance, et l'aide du lecteur l'explicite.

### Prononciation = tranche de narration + TTS

La phase 3 a livré des timings mot par mot ; ils permettent une prononciation immédiate et hors-ligne sans nouveaux assets ni pipeline. La synthèse de l'appareil couvre les chapitres sans audio et les futurs packs non enregistrés. Une voix dédiée par mot serait un raffinement de contenu, pas un prérequis de la phase.

### Instantané complet dans la liste

Chaque entrée enregistrée contient définition, traduction, exemple et clip. La liste reste lisible sans charger le chapitre, sans dépendre d'un pack mis à jour, et alimentera directement les flashcards de la phase 7.

### `flutter_tts` plutôt qu'un service en ligne

Le repli doit fonctionner hors-ligne et sans backend. Le moteur TTS du système est la seule option gratuite et locale ; il est isolé derrière `WordPronouncer` et remplaçable.

### Pas de bump de schéma

La liste est une donnée additive. `prefs.version` reste `1`, les préférences existantes sont inchangées et les installations actuelles conservent leur progression.

## Context

La promesse produit est la lecture immersive : rencontrer un mot dans l'histoire, puis comprendre son sens sans quitter le texte. La phase 5 a ajouté le double canal ; la phase 6 rend le vocabulaire explorable d'un geste, et prépare la révision de la phase 7 (les mots rencontrés deviennent des cartes).

## Stakeholder Notes

- **Produit** : un tap, une fiche claire, zéro friction ; l'ajout est réversible et jamais culpabilisant.
- **Technique** : aucun réseau, aucune migration, plugins isolés et testables, recognizers libérés proprement.
- **Business** : la liste de mots et la prononciation sont des fonctionnalités de base attractives ; la révision espacée premium s'appuiera dessus.
- **Éditorial** : aucune nouvelle donnée à produire ; la qualité des fiches dépend du pack existant (20 mots pour le chapitre pilote).
