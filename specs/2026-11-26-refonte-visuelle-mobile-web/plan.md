# Plan — Phase 16a : refonte visuelle mobile & web

## Cadrage

- Branche : `feature/phase-16a-refonte-visuelle`
- Spec validée avant implémentation ; une fois le `validation.md` rempli et
  vert, merge fast-forward dans `main`, push, suppression de la branche
  (règle habituelle du dépôt).
- Aucune modification serveur, aucun changement de dépendance fonctionnelle.
  Seules des dépendances de présentation peuvent être ajoutées si un
  composant l'exige (aucune n'est prévue : tout tient dans Flutter Material).
- Les flux, routes, libellés et providers existants sont conservés. La
  refonte change tokens, composants et dispositions.

## Processus Impeccable (avant tout éditage UI)

1. `/impeccable init` : écrire `PRODUCT.md` à la racine à partir de
   `specs/constitution.md`, `specs/tech-stack.md`, `docs/` et des specs
   livrées ; hypothèses étiquetées. Une seule passe de questions si un point
   bloque (cible, ton, contraintes de marque).
2. `new-work` : établir le monde visuel hybride et remplacer/compléter
   `DESIGN.md` (palette, typographie, surfaces, composants, mouvement).
3. Lire `reference/craft-floor.md` immédiatement avant le premier edit UI.
4. Vérifier au rendu réel (Chrome + émulateur) aux tailles de livraison,
   par lots : corriger ce qu'un regard révèle avant de re-regarder.
5. Après la dernière modification web : `impeccable detect --json <cibles>`
   une seule fois, corriger les constats pertinents ou les documenter.
6. Aucun sous-agent nécessaire ; travail en fil principal.

Nota : une version plus récente d'Impeccable (v4.8.2) est disponible ;
la mise à jour n'est pas exécutée dans cette session.

## Décisions visuelles (hybrides)

- Primaire : vert Storylingo actuel (`#2F5D50`) décliné par
  `ColorScheme` explicites (pas de `fromSeed` seul) pour contrôler surfaces,
  conteneurs et contours.
- Surfaces : crème chaud en clair, encre bleu-noir en sombre, cartes à grand
  rayon (`AppRadii.card` à 20, sur-cartes 24 pour les blocs éditoriaux),
  bordures fines, ombre douce remplacée par bordure + élévation 0–1.
- Secondaire : ambre (série, badges, mise en avant de la session) ; corail
  réservé aux erreurs ; pas de dégradés décoratifs en fond de contenu.
- Typographie : échelle éditoriale (display 32/36, titre 24/28, section
  18/22, corps 16/24, méta 13/18), police système via Material, graisses
  fortes sur les titres — aucune nouvelle dépendance de police.
- Formes : pilules pour filtres et chips, boutons pleins à rayon 14,
  barre de navigation 72 dp conservée sur mobile.
- Mouvement : transitions courtes 150–220 ms, opacité + glissement léger ;
  aucun parallaxe ni animation continue hors lecture audio.

## Tâches

### 1. Tokens et thème

- `lib/core/theme/app_tokens.dart` : ajouter `AppColors` (surfaces clair/
  sombre, ambre, succès/erreur alignés Material), échelles typographiques
  (`AppTypes`), rayons supplémentaires, durées de transition.
- `lib/core/theme/app_theme.dart` : construire `ColorScheme.light()` /
  `ColorScheme.dark()` explicites (primaire vert conservé), thèmes AppBar,
  Card, FilledButton, OutlinedButton, Chip, NavigationBar, Divider,
  InputDecoration, SnackBar, NavigationRail (web).
- Vérifier les paires de contraste AA (texte sur surface, sur primaire,
  texte secondaire, ambre sur surface) au moyen d'un petit test unitaire de
  ratios (fonction locale, pas de dépendance).

### 2. Composants partagés (`lib/core/ui/`)

- `section_header.dart`, `app_card.dart`, `stat_card.dart`, `pill_chip.dart`,
  `progress_bar.dart`, `empty_state.dart`, `activity_table.dart` (web),
  `app_sidebar.dart` (web), `responsive_scaffold.dart` avec points de
  rupture : compact `< 720`, moyen `720–959`, large `≥ 960`.
- Remplacer les cartes/chips ad hoc des écrans par ces composants au fil de
  la refonte, sans changer la logique.

### 3. Coquille responsive

- `lib/features/shell/presentation/home_shell.dart` : `NavigationBar` mobile
  inchangée fonctionnellement ; en large, `NavigationRail` étendu façon barre
  latérale (logo, trois destinations, Réglages, Compte, pied avec état
  d'abonnement via `billing`/`premium` existant). Routes inchangées :
  `/today`, `/library`, `/progress`, `/settings`, `/account`, `/paywall`,
  `/read/:bookId[/:chapterId]`.
- `storylingo_app_bar.dart` : en-tête éditorial (titre large, actions
  série + réglages), actions conservées ; en large, l'en-tête se fond dans
  la coquille.
- Pas de nouvelle route, pas de nouveau menu.

### 4. Mobile — écrans

Restyler, sans changer les flux ni les textes :

- Onboarding : `welcome_screen.dart`, `interests_screen.dart`,
  `level_test_screen.dart`, `level_result_screen.dart`,
  `onboarding_flow_screen.dart` (pagination, illustrations originales).
- Aujourd'hui : `today_screen.dart`, `program_streak_chip.dart` (carte de
  session type « Jump back in », carte mots du jour, série).
- Bibliothèque : `library_screen.dart`, `pilot_book_card.dart`,
  `catalogue_book_card.dart` (grille de couvertures, filtres en pilules
  existants, verrou paywall inchangé).
- Lecture : `book_entry_screen.dart`, `reading_screen.dart`,
  `chapter_paragraph_text.dart`, `audio_transport.dart`
  (plein écran immersif, mode écoute avec couverture et transport mis en
  scène ; surlignage karaoké intact).
- Vocabulaire : `review_screen.dart`, `word_list_screen.dart`,
  `word_sheet.dart`.
- Progrès : `progress_screen.dart` (cartes d'indicateurs et badges).
- Réglages et compte : `settings_screen.dart`, `account_screen.dart`,
  `downloads_section.dart`.
- Paiement : `paywall_screen.dart`, `mobile_money_screen.dart`,
  `subscription_section.dart`, `locked_book_screen.dart` (mise en forme
  seulement ; flag mobile money inchangé, masqué sur web).

### 5. Web — tableau de bord calqué sur l'existant

- Aucun écran nouveau : la route `/today` rend une variante large.
- `today_screen.dart` : si large, en-tête « Bonjour » + carte de session +
  rangée de `StatCard` :
  - série : `programProgressProvider` ;
  - minutes sur 7 jours : somme des `chapter_completed.elapsedSeconds` et
    `review_completed` de la télémétrie locale (fenêtre glissante) ;
  - chapitres terminés : événements `chapter_completed` distincts ;
  - mots maîtrisés : cartes SRS existantes au-delà d'un seuil d'intervalle
    (constante dans le code, pas de nouveau stockage).
  Ces calculs vivent dans un provider de présentation dédié
  (`lib/features/today/presentation/dashboard_stats_provider.dart`),
  pur et testé.
- Table « Activité récente » : 8 derniers événements télémétrie parmi
  `chapter_completed` et `review_completed`, libellés existants, horodatage
  local ; état vide soigné.
- `library_screen.dart` large : grille multi-colonnes, même filtrage local ;
  `reading_screen.dart` large : deux volets — texte au centre
  (largeur de lecture bornée), panneau de lecture à droite avec couverture,
  transport, vitesse, mode ; en compact, lecteur mobile actuel.
- `progress_screen.dart`, réglages, compte, paywall : disposition large
  (cartes en grille), contenus identiques.
- Vérifier le build web tôt (stubs `billing_gateway_stub`, téléchargements,
  `kIsWeb` mobile money).

### 6. Illustrations

- Générer avec l'outil ImageGen deux illustrations originales (accueil,
  écoute) en PNG (aucun convertisseur webp disponible dans l'environnement),
  aux proportions des emplacements, style cohérent avec la palette hybride ;
  les livrer dans `assets/onboarding/` et les déclarer dans `pubspec.yaml`.
- Aucune image ni marque tierce reprise des captures.

### 7. Tests

- `test/ui/` (ou `test/core/ui/`) : tests widget des composants et des
  points de rupture ; `dashboard_stats_provider` (fenêtre 7 jours, somme,
  dédoublonnage, état vide).
- Goldens : « Aujourd'hui », Bibliothèque, paywall, lecteur, tableau de bord
  web — clair et sombre, tailles 390×844 et 1280×800 (goldens générés sur
  la machine de dev ; à documenter).
- Mettre à jour les tests existants uniquement pour ce que la mise en forme
  déplace, sans changer les textes attendus.
- Naviguer sur les routes existantes depuis la barre latérale web (test
  widget avec `router`).

### 8. Documentation

- `README.md` : section « Interface » (principes hybrides, thèmes,
  dispositions web), ligne d'index de la spec.
- `specs/roadmap.md` : insérer « Phase 16a » avant la phase 16 ;
  retirer « application web » de la liste « non planifié ».
- Phase 16 : remplacer la note « docs/ non normatifs » par un renvoi à cette
  phase ; préciser que l'audit a11y/perf et la release portent sur ce design.

## Vérification

Commandes, dans l'ordre :

```
C:/dev/flutter/bin/flutter analyze
C:/dev/flutter/bin/dart format --output=none --set-exit-if-changed <fichiers de la phase>
C:/dev/flutter/bin/flutter test
C:/dev/flutter/bin/flutter build web --release
```

Puis, sur le rendu :

- émulateur `demo36` : parcours onboarding → aujourd'hui → bibliothèque →
  lecture (texte et écoute) → révision → progrès → réglages → paywall ;
  captures clair et sombre ;
- Chrome : `flutter run -d chrome` (ou serveur sur le build web) aux largeurs
  360, 768 et 1280 ; parcours des trois destinations, lecteur deux volets,
  dashboard, table d'activité, paywall ;
- `impeccable detect --json` sur les fichiers UI modifiés, une fois.

Critères de sortie : aucune régression fonctionnelle, contrastes AA sur les
paires clés, tests verts, build web fonctionnel, zéro donnée inventée.

## Livraison

1. Commit de la spec (requirements + plan + validation) sur la branche.
2. Implémentation par lots : thème → composants → coquille → écrans mobile →
   web → illustrations → tests → doc.
3. `validation.md` rempli avec résultats mesurés et captures référencées.
4. Merge fast-forward dans `main`, push, suppression de la branche, après
   accord explicite.
