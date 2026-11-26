# Phase 16a — Refonte visuelle mobile & web

## Contexte

La phase 16 (analytics, notifications, release) suppose un design stable :
l'audit d'accessibilité et la distribution doivent porter sur l'interface
finale. Les captures de `docs/` servent désormais de cible visuelle, mais
uniquement pour **la forme** : la refonte ne doit ajouter aucune fonctionnalité.

Décisions validées :

- **Palette hybride** : structure, cartes, typographie et composants inspirés
  des captures, **accent principal vert Storylingo conservé** ; l'ambre sert
  d'accent secondaire (badges, série, mises en avant), le corail n'est pas
  utilisé pour ne pas concurrencer la couleur d'erreur.
- **Web = tableau de bord calqué sur l'existant** : la même application
  compilée pour le web, présentée comme le dashboard de `docs/` (barre
  latérale, cartes d'indicateurs, table d'activité récente, grille de
  bibliothèque, lecture en deux volets) — avec **uniquement les données et
  les actions qui existent déjà**.
- Ordre d'exécution : cette phase **précède la phase 16** (l'audit a11y de la
  phase 16 couvre le design livré ici ; la release embarque ce design).

## Décisions de cadrage

- **Aucun débordement fonctionnel** : pas de recherche catalogue, auteurs,
  notes, genres nouveaux au-delà de l'existant, pas de découverte, pas de
  social (groupes, fil d'activité, réactions, Inbox), pas de profil enrichi,
  pas de lien Discord, pas d'achat « Book Now ».
- **Aucune donnée factice** reprise des maquettes : pas de notes par étoiles,
  pas d'auteurs, pas de progression de groupe. Les cartes d'indicateurs
  n'affichent que des valeurs calculées à partir des providers existants
  (programme, progression de lecture, vocabulaire, télémétrie locale).
- **Mobile** : navigation à trois onglets conservée (Aujourd'hui,
  Bibliothèque, Progrès) ; Réglages et Compte restent accessibles par l'en-tête.
- **Web** : mêmes routes et mêmes écrans ; la disposition change selon la
  largeur (barre latérale ≥ 960 px, navigation compacte en dessous). Pas de
  site vitrine, pas de SEO, pas de PWA installable dans cette phase.
- **Thèmes clair et sombre conservés**, tous deux refaits : surfaces crème et
  encre, cartes à grand rayon, bordures fines, typographie plus éditoriale
  (titres affirmés, corps inchangé en taille de lecture).
- **Illustrations originales** : les visuels d'onboarding sont recréés pour
  Storylingo ; aucune image tierce des captures n'est reprise, ainsi qu'aucun
  nom de marque (ReadStream, BookTok, BookScope).
- **Textes visibles stables** autant que possible : la refonte change la
  forme, pas la copy, afin de limiter la casse des tests existants.
- Accessibilité : contrastes AA respectés dès cette phase (vérification
  ciblée), l'audit complet et les mesures de performance restent dans la
  phase 16.

## Périmètre

### 1. Design system

- `lib/core/theme/app_tokens.dart` : jetons complétés (surfaces clair/sombre,
  accent ambre, rayons, ombres douces, échelles typographiques des titres).
- `lib/core/theme/app_theme.dart` : `ColorScheme` explicites clair et sombre
  (vert primaire conservé, surfaces crème/encre inspirées des captures),
  styles de boutons (pilules, boutons pleins), cartes, chips, barre de
  navigation, tableaux.
- Composants partagés réutilisables (dans `lib/core/ui/`) :
  `SectionHeader`, `AppCard`, `StatCard`, `PillChip`, `ProgressBar`,
  `ActivityTable`, `AppSidebar`, `ResponsiveScaffold` (points de rupture
  uniques : compact < 720 px, moyen 720–959 px, large ≥ 960 px).

### 2. Mobile — mise en forme des écrans existants

Écrans concernés, sans changement de comportement : onboarding (illustrations
et pagination), « Aujourd'hui » (carte de session façon « Jump back in »,
carte mots du jour, série), Bibliothèque (grille de couvertures, filtres en
pilules existants), lecteur (plein écran immersif ; mode écoute avec
couverture, ligne surlignée et transport mis en scène), révision,
« Ma liste de mots », Progrès (cartes d'indicateurs et badges), Réglages
(sections et interrupteurs), paywall, compte, téléchargements.

Contraintes : mêmes flux, mêmes libellés, même logique ; seuls les tokens,
composants et dispositions changent.

### 3. Web — tableau de bord calqué sur l'existant

- Coquille responsive : barre latérale avec les trois destinations plus
  Réglages/Compte et état de l'abonnement ; en-tête avec recherche
  **de bibliothèque locale** (filtrage existant) si l'écran la propose déjà.
- Accueil large (route `/today`) : cartes d'indicateurs calculées depuis
  l'existant (série, minutes cumulées sur 7 jours via télémétrie locale,
  chapitres terminés, mots maîtrisés), carte de session, table « Activité
  récente » alimentée par les événements télémétrie locaux (chapitre terminé,
  révision terminée).
- Bibliothèque large : grille de couvertures, filtres en pilules, accès aux
  livres verrouillés (paywall) inchangé.
- Lecteur large : deux volets — texte du chapitre au centre, panneau de
  lecture (couverture, transport, vitesse, mode) à droite ; en compact,
  retour au lecteur mobile.
- Progrès, paywall, réglages, compte : mêmes contenus, disposition large.
- `flutter build web` doit produire une application fonctionnelle hors-ligne
  (prefs locales) ; les plugins mobiles restent derrière leurs stubs web
  existants ; le paiement mobile money reste masqué sur le web
  (`kIsWeb`).

### 4. Illustrations et assets

- Deux illustrations originales d'onboarding (accueil, écoute) livrées en
  assets optimisés (`webp` ou `png` compressé), plus une couverture de
  remplacement cohérente si une image manque.

### 5. Tests et documentation

- Tests widget : coquille responsive aux trois points de rupture, cartes
  d'indicateurs (valeurs dérivées uniquement), table d'activité, navigation
  web (barre latérale → routes existantes).
- Goldens (ou captures automatisées) pour « Aujourd'hui », Bibliothèque,
  paywall, lecteur, tableau de bord web — thème clair et sombre.
- Tests existants maintenus verts (aucune copy modifiée sans nécessité).
- `README` : section « Interface » (principes visuels, thèmes, dispositions
  web) ; note d'ordre avec la phase 16.

## Hors périmètre

- Toute fonctionnalité absente aujourd'hui : recherche catalogue, auteurs,
  notes, genres, découverte, social, Inbox, profil enrichi, Discord.
- Données factices issues des maquettes (notes, auteurs, progression de
  groupe, revenus, conversion).
- Site vitrine, SEO, PWA installable, notifications web.
- Refonte de la copy ou de la structure d'information.
- Audit a11y complet et mesures de performance (phase 16).
- Captures pour les stores, TestFlight, soumission.
- Changements serveur, package `money_fusion`, paiement.
- CI (toujours différé).

## Risques et parades

- **Régression fonctionnelle masquée par le restyle** : mêmes flux, mêmes
  libellés, suite de tests complète avant/après, revue par écran.
- **Dérive de contraste avec la nouvelle palette** : paires de couleurs
  vérifiées dès cette phase (AA), audit complet en phase 16.
- **Enfermement dans les maquettes tierces** : assets originaux, marques
  tierces exclues, aucune donnée inventée.
- **Web incomplet** (plugin mobile non stubé) : build web vérifié tôt dans
  la phase, stubs existants réutilisés.
- **Dérive de portée** : toute demande fonctionnelle est renvoyée vers une
  phase dédiée.

## Références

- `docs/` (captures : ReadStream, BookTok, écoute, onboarding, exploration,
  interface web, dashboard)
- `specs/2026-11-26-analytics-notifications-release/` (phase 16, exécutée
  après celle-ci)
- `lib/core/theme/` (tokens et thèmes actuels)
- `specs/tech-stack.md` (Material 3, thèmes clair/sombre)
