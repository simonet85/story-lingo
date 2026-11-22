# Phase 5 Requirements — Audio & synchronisation karaoké

## Scope

Deuxième tranche du lecteur : l'écoute.

- Audio natif **embarqué** pour le chapitre pilote, sans réseau.
- Trois modes de lecture : **Lire**, **Écouter**, **Lire + Écouter**.
- Vitesse de lecture **0.8x à 1.5x** (0.8 / 1.0 / 1.25 / 1.5).
- **Surlignage karaoké** : mot actif et phrase active pilotés par un index de timings mot → offset audio.
- **Transport** : lecture/pause, −15 s, +15 s, barre de position et temps écoulé/total.
- Contrat de contenu **v2** avec bloc `audio` et alignement strict tokens ↔ timings.
- Persistance additive du dernier mode et de la vitesse.
- Suivi automatique du texte pendant l'écoute (désactivable par défilement manuel).
- Tests unitaires, widget et validation runtime Android + web.

Tout fonctionne **hors-ligne** : l'audio est un asset du pack.

## Out of Scope

- Tap sur un mot, dictionnaire, prononciation à la demande (phase 6).
- Audio d'autres chapitres ou livres, téléchargement, streaming CDN (phases 9–12).
- Lecture en arrière-plan, notification média, contrôles casque (`just_audio_background`).
- Mode boucle, saut de phrase, favoris, reprise intra-mot de l'audio.
- Analyse de prononciation, enregistrement micro.
- Modification de la fin de chapitre, du récapitulatif ou du timer de session (phase 4).
- Détection des mots nouveaux, SRS, flashcards (phase 7).

## Content Contract v2

### Chapitre

```json
{
  "schemaVersion": 2,
  "id": "chapter-01",
  "bookId": "sleepy-hollow",
  "number": 1,
  "title": "A Quiet Valley",
  "level": "a2",
  "paragraphs": [ ... ],
  "vocabulary": [ ... ],
  "audio": {
    "asset": "assets/content/sleepy-hollow-a2/audio/chapter-01.mp3",
    "durationMs": 142600,
    "voice": "en-US-AriaNeural",
    "words": [
      {"text": "In", "startMs": 100, "endMs": 475},
      {"text": "the", "startMs": 475, "endMs": 560}
    ]
  }
}
```

Règles :

- `schemaVersion` vaut `1` (sans audio) ou `2` (audio **obligatoire**).
- `audio.asset` non vide ; fichier présent dans les assets Flutter.
- `audio.durationMs > 0` et `≥ words.last.endMs`.
- `words` non vide ; `0 ≤ startMs < endMs`, `startMs` strictement croissants.
- `words.length` égale exactement le nombre de tokens du chapitre.
- Chaque `words[i].text` égale le i-ème token du chapitre (comparaison normalisée : casse, apostrophes typographiques, ponctuation).
- Les tokens couvrent le texte des paragraphes dans l'ordre de lecture ; le titre n'est pas lu par l'audio.

### Tokens

Un token est une suite `[A-Za-z0-9]+` pouvant contenir des apostrophes internes et une apostrophe finale (`don’t`, `farmers’`). Espaces et ponctuation restent des spans de texte non karaoké. Ce tokenizer est identique dans le pipeline Python et dans l'app (`chapter_tokens.dart`).

### Pipeline

`tools/content/generate_chapter_audio.py` (outil de développement, jamais embarqué) :

- synthèse `edge-tts` avec `boundary="WordBoundary"` ;
- alignement DP tokens ↔ sous-mots des boundaries ;
- groupe fusionné (« The road ») réparti proportionnellement dans sa fenêtre ;
- échec explicite si l'alignement n'est pas total ;
- écriture du MP3, du bloc `audio` et bump de `packVersion`.

L'usage d'edge-tts est un choix de pipeline : le runtime, lui, ne dépend d'aucun service.

## Comportement

### Modes

| Mode | Texte | Karaoké | Transport | Audio |
|---|---|---|---|---|
| Lire | visible | non | absent | arrêté |
| Écouter | masqué | non | panneau complet | actif |
| Lire + Écouter | visible | oui | barre compacte | actif |

- Le dernier mode choisi est mémorisé (`settings.reading_mode`), défaut `Lire`.
- Passer en Lire met l'audio en pause.
- Ouvrir un mode audio ne lance pas la lecture automatiquement.
- Quitter l'écran et terminer le chapitre mettent l'audio en pause.

### Transport et vitesse

| Action | Règle |
|---|---|
| Play/pause | démarre ou met en pause ; si l'audio est terminé, rejoue depuis 0:00 |
| −15 s / +15 s | seek borné à `[0, duration]` |
| Slider | seek à la position choisie au relâchement |
| Vitesse | 0.8 / 1.0 / 1.25 / 1.5, appliquée immédiatement et mémorisée (`settings.audio_speed`) |
| Fin d'audio | pause en fin, bouton « Rejouer », **pas** de récapitulatif automatique |

### Karaoké

- Mot actif : la position audio tombe dans `[startMs, endMs)` du token.
- Phrase active : tokens entre deux ponctuations terminales (`. ! ? …`) ou fin de paragraphe.
- Position avant le premier mot → premier mot ; après la fin → dernier mot.
- Styles : mot actif = fond `primary`, texte `onPrimary`, gras ; phrase active = soulignement `secondary` ; le surlignage de vocabulaire de la phase 3 est préservé hors mot actif.
- En mode Lire (audio arrêté), aucun style karaoké n'est appliqué.

### Suivi et position

- En Lire + Écouter, le paragraphe du mot actif est amené à l'écran quand il change (tant que l'utilisateur n'a pas défilé manuellement).
- Un défilement manuel désactive le suivi ; play ou seek le réactive.
- À la sortie, la position de lecture est sauvegardée si l'utilisateur a défilé **ou** écouté.
- Le timer de session, la reprise de paragraphe et le récapitulatif de la phase 4 sont inchangés.

### Erreurs

- Échec de chargement audio → message inline « Audio indisponible » avec « Réessayer ».
- La lecture texte reste utilisable ; aucun crash si le fichier ou le moteur défaille.

## Decisions

### Audio embarqué, pas de streaming

Le pack pilote est un asset : démonstration hors-ligne, zéro latence, zéro configuration serveur. Le streaming CDN arrive en phase 10 avec le catalogue distant ; l'interface `AudioEngine` isole déjà ce changement.

### Timings par token fournis par le pipeline

L'application n'aligne rien à la volée : elle valide et lit un index. Les timings sont produits hors ligne, y compris le cas d'un boundary TTS qui couvre plusieurs mots. C'est le contrat prévu par la phase 3 (`timings` différé) et par la tech stack.

### Schema v2 plutôt qu'un champ optionnel en v1

Un chapitre v2 **doit** avoir un audio complet et aligné ; un chapitre v1 reste lisible sans audio. Cela garde une frontière nette pour le pipeline et permet d'ajouter plus tard des chapitres non enregistrés sans ambiguïté.

### Abstraction `AudioEngine`

`just_audio` dépend de canaux de plateforme : il n'est pas testable en widget test. Une interface minimaliste + factory Riverpod permet un faux moteur déterministe dans les tests, sans mocker le plugin. Le vrai moteur n'est créé qu'en mode audio (mode Lire inchangé).

### Soulignement de phrase

Un fond de phrase entrerait en conflit visuel avec les surlignages de vocabulaire et le mot actif. Le soulignement garde les trois couches lisibles (vocabulaire, phrase, mot) en clair comme en sombre.

### Mode et vitesse persistés

Ce sont des préférences de confort : les redemander à chaque chapitre serait une friction. Clés additives, sans bump de `prefs.version`, et validation des valeurs autorisées au chargement.

### Pas de lecture automatique

Ouvrir un chapitre ne doit jamais produire de son inattendu (contexte mobile). L'utilisateur appuie sur play, ce qui satisfait aussi les politiques d'autoplay du web.

## Context

La promesse produit est le **double canal** : relier orthographe, prononciation et sens. La phase 4 a livré la lecture et la session ; la phase 5 apporte l'écoute synchronisée qui distingue Storylingo d'un simple lecteur de texte.

Le chapitre pilote (392 mots, ~2 min 22 d'audio) doit rester une expérience de 7 à 10 minutes avec révision (phase 7) : l'audio complète la lecture, il ne la remplace pas.

## Stakeholder Notes

- **Produit** : trois modes explicites, vitesse réglable, karaoké fluide, aucune culpabilisation ; le texte reste l'ancre d'apprentissage.
- **Technique** : contrat strict validé au chargement, moteur isolé et testable, aucun réseau ajouté, mode Lire sans régression.
- **Business** : l'audio embarqué est démontrable en test utilisateur sans backend ; la qualité de la voix et la synchronisation sont des arguments premium.
- **Éditorial** : voix en-US cohérente, prononciation du texte original simplifié ; l'audio est généré par pipeline et versionné avec le pack.
