# Phase 9 — Exigences : boucle pilote complète

## Périmètre

- Livre pilote complet : chapitres 2 et 3 ajoutés au chapitre 1 existant.
- Boucle de session : chapitre → révision → encouragement → retour au parcours.
- Télémétrie locale exportable depuis les réglages.
- Ajustements de rythme et de copy mesurables dans l'interface.

## Hors périmètre

- Backend, comptes, synchronisation et envoi automatique de la télémétrie.
- Analytics distants (Mixpanel), notifications et rappels (phase 14).
- Nouvelles fonctionnalités SRS, objectif quotidien configurable.
- Import EPUB automatisé (phase 10).

## A. Contenu

| Chapitre | Titre | Paragraphes | Mots | Mots annotés | Minutes |
| --- | --- | --- | --- | --- | --- |
| 1 | A Quiet Valley | 6 | 392 | 20 | 6 |
| 2 | The Midnight Rider | 5 | 350–450 | 15–20 | 6 |
| 3 | The Morning After | 5 | 350–450 | 15–20 | 6 |

- `packVersion` = `1.3.0` ; `schemaVersion` du manifeste inchangé (1).
- Identifiants de vocabulaire uniques dans le livre ; chaque entrée porte
  `cefr`, `word`, `partOfSpeech`, `phonetic`, `definitionEn`, `translationFr`,
  `example`.
- Chaque identifiant annoté dans un paragraphe existe dans `vocabulary` et
  inversement ; l'audio couvre chaque token du texte.
- L'audio de chaque chapitre est un MP3 commité, généré hors application.

## B. Boucle de session

1. « Terminer le chapitre » valide le jour, enregistre la session et introduit
   les mots nouveaux (phases 7–8 inchangées).
2. Le récapitulatif affiche :
   - le titre et les statistiques de lecture ;
   - la validation : « Jour X validé » et la série courante ;
   - la carte « Votre révision du jour » et le CTA « Réviser ces mots » ;
   - « Vous avez terminé le livre pilote ! » lorsque tous les chapitres sont
     terminés.
3. La fin de révision affiche « Belle session ! », le nombre de mots revus et de
   mots à revoir, l'état du jour (validé ou non) avec la série, puis
   « Terminer la session » qui revient à « Aujourd'hui ».
4. Une file vide conserve le message neutre existant ; aucun reproche.

## C. Télémétrie

### Modèle

`TelemetryEvent` :

| Champ | Type | Règle |
| --- | --- | --- |
| `name` | String | non vide |
| `at` | DateTime UTC | horodatage ISO 8601 |
| `properties` | Map clé → String/num/bool/null | aplaties, sans objet imbriqué |

- Stockage : `prefs.telemetry.events` (liste de chaînes JSON), `prefs.version`
  reste `1`.
- Plafond : 500 événements ; au-delà, les plus anciens sont supprimés.
- Une entrée invalide est ignorée au chargement.

### Événements

| Événement | Propriétés |
| --- | --- |
| `app_opened` | `level`, `onboardingCompleted` |
| `chapter_started` | `chapterId`, `chapterNumber` |
| `chapter_completed` | `chapterId`, `chapterNumber`, `elapsedSeconds`, `minutes`, `newWords`, `programDay` |
| `review_started` | `queueSize` |
| `review_completed` | `reviewed`, `again`, `hard`, `good`, `easy`, `queueSize` |

- `app_opened` est émis une fois par lancement de l'application.
- L'horloge utilisée est `nowProvider`, injectable en test.

### Export

Objet JSON stable, sans donnée nominative :

```json
{
  "schemaVersion": 1,
  "exportedAt": "2026-11-22T12:00:00.000Z",
  "participant": {"level": "b1", "interests": ["mystery"]},
  "content": {"packVersion": "1.3.0", "chapters": 3},
  "program": {
    "daysCompleted": 1, "currentDay": 2, "doneToday": false,
    "streak": 1, "bestStreak": 1, "shieldAvailable": true,
    "totalMinutes": 6, "totalSessions": 1, "programComplete": false,
    "sessions": [{"date": "2026-11-21", "minutes": 6}]
  },
  "vocabulary": {"cards": 18, "reviews": 42, "newStudiedToday": 0},
  "events": [
    {"name": "app_opened", "at": "2026-11-22T07:59:00.000Z", "level": "b1"}
  ]
}
```

- L'export est copié dans le presse-papiers ; un message confirme l'action.
- L'effacement de la télémétrie demande une confirmation et ne touche ni la
  progression, ni le SRS, ni les préférences.

## D. Rythme et copy

- Estimation de « Aujourd'hui » = `estimatedMinutes` du chapitre du jour + 3
  minutes de révision.
- Le chronomètre de lecture reste plafonné à 10 minutes.
- Objectif de 10 nouveaux mots par jour inchangé (borne basse produit).
- CTAs : « Commencer la session », « Réviser ces mots », « Terminer la session ».

## Décisions

- **Deux chapitres suffisent** pour finir l'arc narratif du pilote ; le parcours
  28 jours boucle déjà sur le livre, et chaque relecture repart du début car la
  position d'un chapitre terminé est effacée.
- **Presse-papiers comme export** : aucune dépendance native, aucun réseau,
  compatible web et Android ; le testeur colle le JSON dans son canal habituel.
- **Plafond de 500 événements** : 28 jours de boucle quotidienne tiennent
  largement, tout en bornant le stockage local.
- **Pas de consentement bloquant** : les données restent sur l'appareil et ne
  sont partagées que par une action explicite de copie.
- **Encouragement dérivé** de la progression existante (jour, série) ; aucun
  nouvel état persistant n'est nécessaire.
