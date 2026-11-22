# Phase 1–2 Plan — Fondations & Onboarding

## Group 1 — Projet & dépendances

1. Dans `Storylingo/`, lancer `flutter create --org com.storylingo --project-name storylingo --platforms ios,android .` en conservant `specs/` et le `README.md` projet (restaurer le README s'il est écrasé par le scaffold).
2. Ajouter les dépendances directes avec versions exactes (sans `^`) : `flutter_riverpod`, `go_router`, `shared_preferences` ; ajouter `flutter_localizations` (SDK).
3. Commiter `pubspec.lock` et fixer la contrainte SDK Flutter sur la version stable installée.
4. Conserver `analysis_options.yaml` basé sur `flutter_lints` ; activer en plus d'éventuelles règles de tri d'imports.
5. `lib/main.dart` : charger `SharedPreferences` avant `runApp`, créer le `ProviderScope` et surcharger le provider du dépôt de préférences.
6. Remplacer l'application compteur par `lib/app.dart` (`StorylingoApp`) : `MaterialApp.router`, `locale: Locale('fr')`, délégués de localisation, `theme`, `darkTheme`, `themeMode` piloté par un provider.

## Group 2 — Design system & thèmes

7. `lib/core/theme/app_tokens.dart` : espacements, rayons, taille des zones tactiles (minimum 44 px) et styles de texte partagés.
8. `lib/core/theme/app_theme.dart` : `ThemeData` clair et sombre Material 3 à partir d'une couleur source unique, avec `useMaterial3: true` et hiérarchie typographique.
9. `lib/core/theme/theme_mode_provider.dart` : `Notifier` exposant `ThemeMode` (défaut : système), état lu depuis les préférences et persisté à chaque changement.

## Group 3 — Shell de navigation

10. `lib/core/router/app_router.dart` : `go_router` avec `StatefulShellRoute.indexedStack` et trois branches `/today`, `/library`, `/progress`.
11. `lib/features/shell/presentation/home_shell.dart` : `NavigationBar` à trois destinations (Aujourd'hui, Bibliothèque, Progrès), libellés visibles, zone tactile ≥ 44 px.
12. Écrans provisoires `today_screen.dart`, `library_screen.dart`, `progress_screen.dart` : titre, phrase d'attente, action d'ouverture des réglages dans l'`AppBar`.
13. Route `/settings` hors du shell (avec retour) ; route `/onboarding` hors du shell.
14. Bascule de démarrage : si `onboarding.completed` est faux, rediriger vers `/onboarding` ; sinon ouvrir `/today`. La redirection s'applique aussi aux liens profonds.

## Group 4 — Onboarding : domaine & persistance

15. `lib/features/onboarding/domain/user_level.dart` : enum `UserLevel { a2, b1, b2 }` avec libellés français ("A2 — Élémentaire", etc.).
16. `lib/features/onboarding/domain/user_prefs.dart` : modèle immuable `level`, `interests` (liste d'identifiants), `onboardingCompleted`, `themeMode`.
17. `lib/core/prefs/prefs_keys.dart` : `prefs.version = 1`, `onboarding.completed`, `user.level`, `user.interests`, `settings.theme_mode`.
18. `lib/core/prefs/prefs_repository.dart` : lecture/écriture typée avec valeurs par défaut et résistance aux clés manquantes ou corrompues (retour au défaut, pas de crash).
19. `assets/onboarding/level_test_fr.json` : exactement 10 questions, réparties 4 A2 / 3 B1 / 3 B2 ; champs `id`, `level`, `prompt`, `options` (4), `answerIndex`, `explanation_fr`.
20. `lib/features/onboarding/domain/level_scoring.dart` : fonction pure de calcul du niveau — A2 = 1 point, B1 = 2, B2 = 3 ; total max 19 ; `< 8` → A2, `8–12` → B1, `≥ 13` → B2 ; plancher A2.

## Group 5 — Onboarding : parcours UI

21. `welcome_screen.dart` : promesse « Améliore ton anglais en 28 jours avec des livres adaptés », explication en une phrase, bouton « Commencer ».
22. `level_test_screen.dart` : une question par écran, indicateur de progression « n/10 », une seule réponse sélectionnable, bouton « Suivant » désactivé tant qu'aucune réponse n'est choisie ; état des réponses en mémoire via un `Notifier`.
23. `level_result_screen.dart` : niveau estimé, explication honnête (« estimation, modifiable à tout moment »), bouton « Continuer ».
24. `interests_screen.dart` : grille de 6 genres (Policier & mystère, Aventure, Gothique & horreur, Fantastique, Humour & satire, Histoire) ; minimum 2 sélections ; bouton « Continuer » désactivé avec texte d'aide sinon.
25. Fin d'onboarding : enregistrer niveau, intérêts et drapeau `onboarding.completed` **avant** de naviguer vers `/today` ; si l'écriture échoue, rester sur l'écran et afficher une erreur.

## Group 6 — Réglages

26. `settings_screen.dart` : niveau actuel affiché et modifiable (segmented control A2/B1/B2) ; choix du thème (Système / Clair / Sombre) ; application immédiate et persistance.
27. Vérifier que le changement de niveau depuis les réglages ne relance pas l'onboarding et reste cohérent avec les préférences stockées.

## Group 7 — Intégration, tests & CI

28. Tests unitaires : seuils de `level_scoring` (4 bonnes réponses A2 → A2 ; A2+B1 → B1 ; ≥ 13 points → B2 ; 0 → A2) ; validation de l'asset (10 items, 4/3/3, 4 options, `answerIndex` valide).
29. Tests du dépôt de préférences : valeurs par défaut, persistance, données corrompues.
30. Tests widget : préférences vierges → écran d'accueil d'onboarding ; parcours complet → `/today` ; intérêts < 2 → bouton désactivé ; préférences complètes → démarrage direct sur le shell.
31. Workflow GitHub Actions : Flutter stable, `flutter pub get`, `flutter analyze`, `flutter test`.
32. Passe manuelle : installation vierge, relance, réglages, thème clair/sombre, mode avion, texte agrandi.

## Group 8 — Vérification finale

33. `flutter analyze` — doit sortir en code 0 sans avertissement.
34. `flutter test` — tous les tests passent.
35. `flutter run` sur un émulateur Android : parcours d'onboarding complet, navigation à trois onglets, redémarrage sans onboarding. Sur Windows, la vérification iOS est reportée à un poste macOS ou à la CI ; le code reste cross-platform par construction.
