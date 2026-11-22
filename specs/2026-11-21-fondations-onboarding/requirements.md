# Phase 1–2 Requirements — Fondations & Onboarding

## Scope

Regroupe les phases 1 et 2 du roadmap en un seul livrable :

- Squelette **Flutter** iOS + Android avec design system Material 3, thèmes clair et sombre.
- Shell de navigation à trois onglets : Aujourd'hui, Bibliothèque, Progrès (contenu provisoire).
- Onboarding en trois étapes : accueil, test de niveau court (10 questions), choix des intérêts.
- Estimation du niveau CEFR **A2 / B1 / B2**, affichée et modifiable dans les réglages.
- Persistance locale des préférences (niveau, intérêts, thème, onboarding terminé).
- Écran de réglages accessible depuis le shell.
- Tests unitaires et widget, workflow CI.

Tout fonctionne **sans réseau ni compte**.

## Out of Scope

- Pack de contenu, catalogue, lecteur, audio synchronisé (phases 3 à 6).
- Vocabulaire, SRS, parcours 28 jours (phases 7 et 8).
- Backend, comptes, synchronisation (phases 10 et 11).
- Téléchargements hors-ligne, paywall, analytics, notifications (phases 12 à 14).
- Interface multilingue : **français uniquement** au MVP.
- Mise en production sur les stores et tests en conditions réelles.
- Audit d'accessibilité complet (phase 14) ; les bases (libellés, contrastes, zones tactiles) sont incluses.

## Decisions

### Persistance avec `shared_preferences` pour cette phase

Les données de cette phase sont des scalaires et une petite liste d'identifiants : pas besoin de base relationnelle. `shared_preferences` évite d'introduire `drift` avant le pack de contenu (phase 3).

- Clés versionnées : `prefs.version = 1`, `onboarding.completed`, `user.level`, `user.interests`, `settings.theme_mode`.
- Les valeurs absentes ou illisibles retombent sur des défauts sans crash.
- Migration future : les préférences seront recopiées dans la base locale lors de l'adoption de `drift`, pas supprimées.

### Test de niveau court et transparent

- **10 questions** à choix unique, réparties 4 A2 / 3 B1 / 3 B2, embarquées dans `assets/onboarding/level_test_fr.json`.
- Barème pondéré : A2 = 1 point, B1 = 2, B2 = 3. Total maximum : **19**.
- Seuils : **< 8 → A2**, **8 à 12 → B1**, **≥ 13 → B2**. Le plancher est A2, car le produit cible A2–B2.
- Le résultat est présenté comme une **estimation**, jamais comme une certification, et reste modifiable dans les réglages.
- Le calcul est une fonction pure (`level_scoring.dart`) testée unitairement ; l'UI n'embarque aucune règle de score.
- Durée cible du test : **moins d'une minute**. L'onboarding complet vise **3 minutes maximum**.

### Aucune création de compte

- Tout est local. Au premier lancement, l'utilisateur passe par l'onboarding ; ensuite, l'application ouvre directement Aujourd'hui.
- La redirection d'onboarding s'applique à froid et aussi aux liens profonds : un utilisateur n'ayant pas terminé l'onboarding ne peut pas accéder au shell par URL.
- Les réglages permettent de modifier niveau et thème, pas de relancer l'onboarding en phase 1–2.

### Intérêts : liste fermée de six genres

| Identifiant | Libellé FR |
|---|---|
| `mystery` | Policier & mystère |
| `adventure` | Aventure |
| `gothic` | Gothique & horreur |
| `fantasy` | Fantastique |
| `satire` | Humour & satire |
| `history` | Histoire |

**Minimum 2 sélections** pour continuer : la recommandation du premier livre (phase 3) a besoin d'un signal, un seul genre ne suffit pas à éviter une recommandation triviale. Les identifiants sont stables et stockés tels quels.

### Thème

- Trois modes : **Système** (défaut), **Clair**, **Sombre**, persistés et appliqués immédiatement.
- Thème Material 3 dérivé d'une couleur source unique ; les deux variantes couvrent onboarding, shell et réglages.
- `locale: Locale('fr')` avec les délégués `flutter_localizations` ; les textes produit restent en français inline (pas de framework i18n avant la phase 14).

### Shell à trois onglets, réglages hors onglet

- Trois destinations fixes : Aujourd'hui, Bibliothèque, Progrès. Les écrans sont provisoires.
- Les réglages s'ouvrent depuis l'icône de l'`AppBar` sur une route dédiée avec retour, afin de ne pas ajouter un quatrième onglet.

### Versions épinglées

Les dépendances directes sont fixées à des versions exactes (sans `^`) et `pubspec.lock` est commité. Toute mise à jour est une décision explicite, jamais la conséquence d'un `pub upgrade`.

## Context

C'est la première surface visible du produit : elle doit tenir la promesse d'une expérience épurée et immédiate. L'onboarding est aussi la seule mécanique fonctionnelle de cette tranche ; il produit le niveau utilisé ensuite par la détection de vocabulaire (phase 7) et le catalogue (phase 10), d'où l'exigence de règles simples, testées et réversibles.

Le feedback reste positif et non culpabilisant : aucune question chronométrée, aucune notion d'échec, un résultat expliqué et modifiable.

Rien ici ne dépend du réseau : l'installation vierge doit être utilisable en mode avion.

## Stakeholder Notes

- **Produit** : la promesse des 28 jours apparaît dès le premier écran ; le niveau est une estimation modifiable, pas une barrière ; les intérêts préparent des recommandations pertinentes sans questionnaire long.
- **Technique** : offline-first dès la première ligne ; préférences découplées de l'UI via Riverpod et un dépôt testable ; structure `features/` prête à accueillir contenu et lecteur sans refonte.
- **Business** : l'onboarding est le premier entonnoir à instrumenter en phase 14 ; aucun événement analytics n'est ajouté ici, mais chaque étape est un écran distinct pour permettre la mesure ultérieure.
