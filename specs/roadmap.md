# Roadmap

Les phases sont volontairement petites : chacune est une tranche livrable, testable et révisable seule. La stratégie est **offline-first** — l'application est utilisable et démontrable avec un pack de contenu embarqué, sans backend ni compte, avant d'ajouter le cloud.

---

## Phase 1 — Squelette Flutter
- Projet Flutter vides + shell de navigation (Aujourd'hui, Bibliothèque, Progrès)
- Design tokens (couleurs, typographie, espacements) et thèmes clair/sombre
- CI qui lance `flutter analyze` et les tests

## Phase 2 — Onboarding & niveau
- 3 écrans d'onboarding : accueil, test de niveau court (~10 questions à seuils A2/B1/B2), choix d'intérêts
- Préférences stockées localement
- Niveau estimé visible et modifiable dans les réglages

## Phase 3 — Modèle de contenu & pack pilote
- Schéma de pack versionné : livre, chapitres, tokens, mots annotés (CEFR, définition EN/FR, exemple, prononciation), timings audio
- Pack pilote : premier chapitre de *Sleepy Hollow* niveau A2, chargé depuis les assets
- Rendu du chapitre en texte simple avec mots-clés surlignés

## Phase 4 — Lecteur
- Écran de lecture immersif (typographie, marges, confort)
- Timer de session toujours visible, reprise à la dernière position
- Fin de chapitre : récapitulatif et retour au parcours

## Phase 5 — Audio & synchronisation karaoké
- Lecture audio native, contrôle vitesse 0.8x–1.5x
- Trois modes : Lire / Écouter / Lire + Écouter
- Surlignage mot et phrase piloté par l'index de timings ; transport (play/pause, ±15 s)

## Phase 6 — Dictionnaire au tap
- Tap sur un mot → définition, traduction, exemple, prononciation (audio du pack, TTS en secours)
- Ajout à « Ma liste de mots »
- Entièrement fonctionnel hors-ligne

## Phase 7 — Vocabulaire & répétition espacée
- Détection des mots nouveaux selon le niveau de l'utilisateur (comparaison aux listes CEFR)
- Flashcards générées à partir des mots rencontrés
- Planification FSRS, objectif quotidien de +10 à +20 nouveaux mots
- Révision de fin de session (≈ 2–3 minutes)

## Phase 8 — Programme 28 jours
- Parcours guidé de 28 jours : un chapitre + la révision du jour
- Streak protégé (une journée manquée ne casse pas l'élan), statistiques et badges
- Écran « Aujourd'hui » : objectif unique, minutes estimées, état d'avancement

## Phase 9 — Boucle pilote complète
- Livre pilote entier (*Sleepy Hollow* A2) et enchaînement chapitre → révision → encouragement
- Test utilisateurs sur 28 jours avec télémétrie locale exportable
- Ajustements de rythme, de difficulté et de copy

## Phase 10 — API contenu & catalogue
- Service FastAPI + PostgreSQL : livres, chapitres, vocabulaire, entitlements
- CLI d'import du pipeline Python (EPUB → chapitre annoté → pack + timings)
- Endpoints catalogue et packs, audio servi par CDN
- L'application passe des assets embarqués à un catalogue distant, avec cache local

## Phase 11 — Comptes & synchronisation
- Inscription/connexion (Supabase Auth, JWT vérifiés par FastAPI)
- Push/pull différentiel : progression, positions, SRS, préférences ; last-write-wins horodaté
- Migration des données locales vers le compte, usage multi-appareils

## Phase 12 — Hors-ligne complet
- Téléchargement d'un livre + audio, gestion de l'espace et des téléchargements
- Vérification d'intégrité des packs et mise à jour atomique
- Lecture et révision garanties sans réseau

## Phase 13 — Freemium & paywall
- 1 à 2 livres gratuits, verrouillage du reste du catalogue
- Abonnements mensuel/annuel via RevenueCat, restauration d'achats, gestion d'état
- Écrans de conversion alignés avec les principes produit (pas de culpabilisation)

## Phase 14 — Analytics, notifications & release
- Événements Mixpanel : funnel onboarding → J1 → J7 → J28, sessions, conversion
- Rappel quotidien doux (heure locale, désactivable)
- Audit accessibilité et performance du lecteur
- TestFlight + Play internal, puis soumission aux stores

---

Non planifié pour l'instant : partage social des progrès, statistiques avancées, autres niveaux et langues sources, mode traduction de phrase entière, application web.
