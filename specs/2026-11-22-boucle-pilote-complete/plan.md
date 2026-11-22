# Phase 9 — Plan : boucle pilote complète

Objectif : rendre le pack pilote démontrable de bout en bout pendant 28 jours —
histoire complète, boucle chapitre → révision → encouragement, et données locales
exportables pour un test utilisateur.

## A. Contenu — livre pilote entier

- Ajouter `chapter-02` (« The Midnight Rider ») et `chapter-03`
  (« The Morning After ») au pack *Sleepy Hollow* A2, dans la continuité du
  chapitre 1 qui s'arrête sur un bruit de cheval.
- Contraintes éditoriales identiques au chapitre 1 : 4–6 paragraphes,
  350–450 mots, 15–20 mots annotés, niveau A2, phrases courtes.
- Vocabulaire unique dans tout le livre (les identifiants servent d'identifiants
  SRS `bookId/vocabId`) ; chaque mot annoté est référencé dans le texte et
  possède CEFR, phonétique, définition EN, traduction FR et exemple.
- Manifeste : 3 chapitres numérotés 1–3, `packVersion` 1.3.0, minutes estimées
  5–8, `newWordCount` égal à la taille du vocabulaire.
- Outillage : généraliser `tools/content/generate_chapter_audio.py` pour choisir
  le chapitre, mettre en cache les frontières par chapitre et fixer la version du
  pack. L'application ne change pas : elle lit les assets et timings commités.
- Le parcours 28 jours continue de boucler sur les chapitres du livre
  (`chapterForDay` modulo) ; relire un chapitre déjà terminé repart du début.

## B. Boucle chapitre → révision → encouragement

- Récapitulatif de fin de chapitre : afficher la validation du jour et la série,
  puis une carte « Votre révision du jour » avec l'accès à la révision.
- Écran de révision : la fin de séance devient un encouragement, pas seulement
  un compteur — « Belle session ! », mots revus, à revoir, état du jour et série,
  puis « Terminer la session » qui ramène à « Aujourd'hui ».
- Aucun ton punitif : une séance vide reste neutre (« Rien à réviser pour le
  moment ») ; l'encouragement ne dépend jamais d'un objectif non atteint.
- Si tous les chapitres du livre sont terminés, le récapitulatif le signale
  (« Vous avez terminé le livre pilote ! »).

## C. Télémétrie locale exportable

- Nouvelle feature `telemetry`, 100 % locale, aucun appel réseau :
  - `TelemetryEvent` : nom, horodatage UTC, propriétés JSON simples.
  - `TelemetryRepository` : liste JSON sous `telemetry.events`, lecture
    tolérante, plafond de 500 événements (les plus anciens sont retirés).
  - `TelemetryController` (Riverpod) : `record(name, properties)` horodaté par
    `nowProvider`, persistance immédiate.
- Événements du parcours pilote :
  - `app_opened` (une fois par lancement, niveau et onboarding) ;
  - `chapter_started` (chapitre, numéro) ;
  - `chapter_completed` (chapitre, secondes lues, minutes enregistrées, nouveaux
    mots introduits, jour du programme) ;
  - `review_started` (taille de la file) ;
  - `review_completed` (revus, à revoir, notes again/hard/good/easy).
- Export JSON construit par une fonction pure :
  `participant` (niveau, intérêts), `program` (progression, série, sessions),
  `vocabulary` (cartes, révisions, nouveaux mots du jour), `content`
  (version du pack, nombre de chapitres), `events`.
- Réglages : section « Données de test » avec compteur d'événements, bouton
  « Copier l'export JSON » (presse-papiers + confirmation) et action d'effacement
  confirmée. Aucune donnée nominative, aucun identifiant d'appareil.

## D. Ajustements rythme, difficulté, copy

- « Aujourd'hui » affiche une estimation réelle :
  `minutes du chapitre + 3 min de révision` (au lieu d'un 10 min fixe).
- Chapitres de 6 minutes avec 17–18 nouveaux mots : le plafond de 10 nouveaux
  mots revus par jour répartit naturellement la charge sur plusieurs jours.
- Copy de fin de séance orientée encouragement et prochaine étape ; CTA uniques
  et cohérents (« Commencer la session », « Réviser ces mots », « Terminer la
  session »).

## E. Tests et validation

- Tests contenu : trois chapitres valides, vocabulaire unique et référencé,
  timings alignés, assets audio présents, pack 1.3.0.
- Tests télémétrie : sérialisation tolérante, plafond, contrôleur horodaté,
  export complet et sans donnée personnelle.
- Tests boucle : fin de chapitre → récap avec validation/série → révision →
  encouragement ; export depuis les réglages (presse-papiers).
- Tests widget : 360 px sans overflow pour le récap de révision et les réglages.
- Validation web (Chrome) : bibliothèque 3 chapitres, dernier chapitre, révision
  encouragée, réglages/export, thèmes clair et sombre.
- Validation Android : lecture des chapitres 2–3, boucle complète, export copié,
  persistance de la télémétrie, mode avion, captures archivées.
